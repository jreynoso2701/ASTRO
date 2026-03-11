import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_comment.dart';

/// Repositorio CRUD de Tickets en Firestore.
///
/// Colección: `Incidentes/{docId}` (V1 compat).
/// Comentarios: `Comentarios/{docId}` (V1: top-level con refIncidente).
class TicketRepository {
  TicketRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('Incidentes');

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      _firestore.collection('Comentarios');

  // ── Tickets ────────────────────────────────────────────

  /// Stream de tickets activos de un proyecto (por nombre V1).
  Stream<List<Ticket>> watchByProject(String projectName) {
    return _ref
        .where('fkxProyecto', isEqualTo: projectName)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final tickets = snap.docs.map(Ticket.fromFirestore).toList();
          tickets.sort(
            (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
              a.updatedAt ?? DateTime(2000),
            ),
          );
          return tickets;
        });
  }

  /// Stream de un ticket individual.
  Stream<Ticket?> watchTicket(String ticketId) {
    return _ref.doc(ticketId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Ticket.fromFirestore(doc);
    });
  }

  /// Genera folio V1: EMPRESA-PROYECTO-MÓDULO-NUM.
  Future<String> _nextFolio(
    String projectName,
    String moduleName, [
    String? empresaName,
  ]) async {
    final snap = await _ref.where('fkxProyecto', isEqualTo: projectName).get();

    int maxNum = 0;
    for (final doc in snap.docs) {
      final folio = doc.data()['folioIncidente'] as String? ?? '';
      final parts = folio.split('-');
      if (parts.isNotEmpty) {
        final num = int.tryParse(parts.last) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }

    final empAbbr = _abbreviate(empresaName ?? '');
    final projAbbr = _abbreviate(projectName);
    final modAbbr = _abbreviate(moduleName);

    final prefix = empAbbr.isNotEmpty
        ? '$empAbbr-$projAbbr-$modAbbr'
        : '$projAbbr-$modAbbr';
    return '$prefix-${maxNum + 1}';
  }

  static String _abbreviate(String name) {
    if (name.isEmpty) return '';
    final firstWord = name.trim().split(RegExp(r'\s+')).first;
    return firstWord.substring(0, min(3, firstWord.length)).toUpperCase();
  }

  /// Crea un nuevo ticket.
  Future<String> create(Ticket ticket) async {
    final folio = await _nextFolio(
      ticket.projectName,
      ticket.moduleName,
      ticket.empresaName,
    );

    final data = ticket.toFirestore();
    data['folioIncidente'] = folio;
    data['folio'] = folio;

    final doc = await _ref.add(data);
    return doc.id;
  }

  /// Actualiza un ticket (merge para preservar campos V1).
  Future<void> update(Ticket ticket) async {
    await _ref
        .doc(ticket.id)
        .set(ticket.toFirestore(), SetOptions(merge: true));
  }

  /// Actualiza solo las evidencias de un ticket.
  Future<void> updateEvidencias(String ticketId, List<String> urls) async {
    final now = DateTime.now();
    await _ref.doc(ticketId).update({
      'evidenciasIncidente': FieldValue.arrayUnion(urls),
      'fhActualizacion': _nowV1String(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Añade una referencia de minuta a un ticket.
  Future<void> addRefMinuta(String ticketId, String minutaId) async {
    await _ref.doc(ticketId).update({
      'refMinutas': FieldValue.arrayUnion([minutaId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Elimina una referencia de minuta de un ticket.
  Future<void> removeRefMinuta(String ticketId, String minutaId) async {
    await _ref.doc(ticketId).update({
      'refMinutas': FieldValue.arrayRemove([minutaId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Añade una referencia de cita a un ticket.
  Future<void> addRefCita(String ticketId, String citaId) async {
    await _ref.doc(ticketId).update({
      'refCitas': FieldValue.arrayUnion([citaId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Elimina una referencia de cita de un ticket.
  Future<void> removeRefCita(String ticketId, String citaId) async {
    await _ref.doc(ticketId).update({
      'refCitas': FieldValue.arrayRemove([citaId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Cambia el estado de un ticket.
  Future<void> updateStatus(String ticketId, TicketStatus newStatus) async {
    final now = DateTime.now();
    final updates = <String, dynamic>{
      // V1
      'estatusIncidente': newStatus.v1Label,
      'fhActualizacion': _nowV1String(now),
      // V2
      'status': newStatus.label,
      'updatedAt': Timestamp.fromDate(now),
    };
    if (newStatus == TicketStatus.cerrado ||
        newStatus == TicketStatus.resuelto) {
      updates['closedAt'] = Timestamp.fromDate(now);
    }
    await _ref.doc(ticketId).update(updates);
  }

  /// Asigna el ticket a un usuario de Soporte.
  Future<void> assign(
    String ticketId,
    String assignedTo,
    String assignedToName,
  ) async {
    final now = DateTime.now();
    await _ref.doc(ticketId).update({
      // V1
      'fkxSoporte': assignedToName,
      'fhActualizacion': _nowV1String(now),
      // V2
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Soft delete.
  Future<void> deactivate(String ticketId) async {
    final now = DateTime.now();
    await _ref.doc(ticketId).update({
      'isActive': false,
      'fhActualizacion': _nowV1String(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Reactivar.
  Future<void> activate(String ticketId) async {
    final now = DateTime.now();
    await _ref.doc(ticketId).update({
      'isActive': true,
      'fhActualizacion': _nowV1String(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  // ── Comentarios (colección top-level V1) ────────────────

  /// Stream de comentarios de un ticket (por refIncidente).
  Stream<List<TicketComment>> watchComments(String ticketId) {
    return _commentsRef
        .where('refIncidente', isEqualTo: ticketId)
        .orderBy('fechaCreacion')
        .snapshots()
        .map((snap) => snap.docs.map(TicketComment.fromFirestore).toList());
  }

  /// Agrega un comentario al ticket.
  Future<void> addComment(String ticketId, TicketComment comment) async {
    final data = comment.toFirestore();
    data['refIncidente'] = ticketId;
    await _commentsRef.add(data);
  }

  static String _nowV1String(DateTime now) {
    return '${now.year}/${now.month}/${now.day} '
        '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }
}
