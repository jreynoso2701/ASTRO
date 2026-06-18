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

  /// Stream de **todos** los tickets de un proyecto (activos + archivados +
  /// desactivados). Usado para estadísticas.
  Stream<List<Ticket>> watchAllByProject(String projectName) {
    return _ref.where('fkxProyecto', isEqualTo: projectName).snapshots().map((
      snap,
    ) {
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
  Future<void> update(Ticket ticket, {required String updatedBy}) async {
    final data = ticket.toFirestore();
    data['updatedBy'] = updatedBy;
    await _ref.doc(ticket.id).set(data, SetOptions(merge: true));
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
  ///
  /// Auto-ajusta porcentajeAvance: 100% para Resuelto, 0% para Pendiente.
  Future<void> updateStatus(
    String ticketId,
    TicketStatus newStatus, {
    required String updatedBy,
  }) async {
    final now = DateTime.now();
    final updates = <String, dynamic>{
      // V1
      'estatusIncidente': newStatus.v1Label,
      'fhActualizacion': _nowV1String(now),
      // V2
      'status': newStatus.label,
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': updatedBy,
      // Timestamp del cambio de estado (excepto archivado/desarchivado)
      if (newStatus != TicketStatus.archivado)
        'statusChangedAt': Timestamp.fromDate(now),
    };
    // Auto-progress según estado
    if (newStatus == TicketStatus.resuelto) {
      updates['porcentajeAvance'] = 100.0;
      updates['closedAt'] = Timestamp.fromDate(now);
    } else if (newStatus == TicketStatus.pendiente) {
      updates['porcentajeAvance'] = 0.0;
    }
    // Limpiar razón de archivado al cambiar a otro estado.
    if (newStatus != TicketStatus.archivado) {
      updates['archiveReason'] = FieldValue.delete();
      updates['archivedByName'] = FieldValue.delete();
    }
    await _ref.doc(ticketId).update(updates);
  }

  /// Archiva un ticket con justificación obligatoria.
  Future<void> archiveTicket(
    String ticketId, {
    required String reason,
    required String archivedByName,
    required String updatedBy,
  }) async {
    final now = DateTime.now();
    await _ref.doc(ticketId).update({
      // V1
      'estatusIncidente': TicketStatus.archivado.v1Label,
      'fhActualizacion': _nowV1String(now),
      // V2
      'status': TicketStatus.archivado.label,
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': updatedBy,
      'archiveReason': reason,
      'archivedByName': archivedByName,
    });
  }

  /// Asigna el ticket a un usuario de Soporte.
  Future<void> assign(
    String ticketId,
    String assignedTo,
    String assignedToName, {
    required String updatedBy,
  }) async {
    final now = DateTime.now();
    await _ref.doc(ticketId).update({
      // V1
      'fkxSoporte': assignedToName,
      'fhActualizacion': _nowV1String(now),
      // V2
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': updatedBy,
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

  /// Agrega un comentario al ticket e incrementa el contador desnormalizado.
  /// Si es un comentario de usuario (no de sistema), actualiza el preview del chat.
  Future<void> addComment(String ticketId, TicketComment comment) async {
    final data = comment.toFirestore();
    data['refIncidente'] = ticketId;
    await _commentsRef.add(data);

    final updates = <String, dynamic>{'commentCount': FieldValue.increment(1)};
    if (comment.type == CommentType.comment && !comment.deleted) {
      updates['lastCommentAt'] = FieldValue.serverTimestamp();
      updates['lastCommentPreview'] = _chatPreview(comment.text);
      updates['lastCommentAuthorId'] = comment.authorId;
      updates['lastCommentAuthorName'] = comment.authorName;
    }
    await _ref.doc(ticketId).update(updates);
  }

  static String _chatPreview(String text) {
    // Strip basic markdown/quill JSON to plain text preview
    String plain = text.trim();
    if (plain.startsWith('{') || plain.startsWith('[')) {
      plain = plain.replaceAll(RegExp(r'\{[^}]*\}'), '').replaceAll('[', '').replaceAll(']', '');
    }
    plain = plain.replaceAll(RegExp(r'[*_~`#>]'), '').replaceAll('\n', ' ').trim();
    if (plain.length > 60) return '${plain.substring(0, 60)}…';
    return plain;
  }

  /// Stream de tickets con al menos un comentario de usuario, para la lista de chats.
  /// Usa el campo V1 `fkxProyecto` (nombre del proyecto) para compatibilidad con datos históricos.
  Stream<List<Ticket>> watchTicketsWithComments(List<String> projectNames) {
    if (projectNames.isEmpty) return Stream.value([]);
    return _ref
        .where('fkxProyecto', whereIn: projectNames.take(30).toList())
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final tickets = snap.docs
              .map(Ticket.fromFirestore)
              .where((t) => t.lastCommentAt != null)
              .toList()
            ..sort((a, b) =>
                (b.lastCommentAt ?? DateTime(2000)).compareTo(a.lastCommentAt ?? DateTime(2000)));
          return tickets;
        });
  }

  /// Guarda la fecha de última lectura del chat de un ticket por el usuario.
  Future<void> markChatAsRead(String uid, String ticketId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chatReads')
        .doc(ticketId)
        .set({'lastReadAt': FieldValue.serverTimestamp()});
  }

  /// Stream de la última fecha de lectura del chat de un ticket para un usuario.
  Stream<DateTime?> watchChatRead(String uid, String ticketId) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('chatReads')
        .doc(ticketId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final ts = doc.data()?['lastReadAt'];
          if (ts is Timestamp) return ts.toDate();
          return null;
        })
        .handleError((_) => null);
  }

  /// Marca un comentario como eliminado (soft-delete) y limpia sus adjuntos.
  Future<void> deleteComment(String commentId) async {
    await _commentsRef.doc(commentId).update({
      'deleted': true,
      'comentario': 'Comentario eliminado',
      'text': 'Comentario eliminado',
      'adjuntos': [],
    });
  }

  static String _nowV1String(DateTime now) {
    return '${now.year}/${now.month}/${now.day} '
        '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }
}
