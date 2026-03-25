import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/cita.dart';
import 'package:astro/core/models/cita_comment.dart';
import 'package:astro/core/models/cita_status.dart';

/// Repositorio CRUD de Citas en Firestore.
///
/// Colección: `Citas/{docId}`.
class CitaRepository {
  CitaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('Citas');

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      _firestore.collection('ComentariosCitas');

  // ── Citas ──────────────────────────────────────────────

  /// Stream de citas activas de un proyecto (por nombre).
  Stream<List<Cita>> watchByProject(String projectName) {
    return _ref
        .where('projectName', isEqualTo: projectName)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(Cita.fromFirestore).toList();
          list.sort(
            (a, b) => (b.fecha ?? DateTime(2000)).compareTo(
              a.fecha ?? DateTime(2000),
            ),
          );
          return list;
        });
  }

  /// Stream de una cita individual.
  Stream<Cita?> watchCita(String citaId) {
    return _ref.doc(citaId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Cita.fromFirestore(doc);
    });
  }

  /// Genera folio: CITA-EMPRESA-PROYECTO-NUM.
  Future<String> _nextFolio(String projectName, [String? empresaName]) async {
    final snap = await _ref.where('projectName', isEqualTo: projectName).get();

    int maxNum = 0;
    for (final doc in snap.docs) {
      final folio = doc.data()['folio'] as String? ?? '';
      final parts = folio.split('-');
      if (parts.isNotEmpty) {
        final num = int.tryParse(parts.last) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }

    final empAbbr = _abbreviate(empresaName ?? '');
    final projAbbr = _abbreviate(projectName);
    final prefix = empAbbr.isNotEmpty
        ? 'CITA-$empAbbr-$projAbbr'
        : 'CITA-$projAbbr';
    return '$prefix-${maxNum + 1}';
  }

  static String _abbreviate(String name) {
    if (name.isEmpty) return '';
    final firstWord = name.trim().split(RegExp(r'\s+')).first;
    return firstWord.substring(0, min(3, firstWord.length)).toUpperCase();
  }

  /// Construye la lista desnormalizada de UIDs (participantes + createdBy).
  static List<String> _buildParticipantUids(Cita cita) {
    final uids = <String>{};
    if (cita.createdBy != null && cita.createdBy!.isNotEmpty) {
      uids.add(cita.createdBy!);
    }
    for (final p in cita.participantes) {
      if (p.uid.isNotEmpty) uids.add(p.uid);
    }
    return uids.toList();
  }

  /// Crea una nueva cita.
  Future<String> create(Cita cita) async {
    final folio = await _nextFolio(cita.projectName, cita.empresaName);

    final data = cita.toFirestore();
    data['folio'] = folio;
    data['participantUids'] = _buildParticipantUids(cita);

    final doc = await _ref.add(data);
    return doc.id;
  }

  /// Actualiza una cita (merge).
  Future<void> update(Cita cita, {required String updatedBy}) async {
    final data = cita.toFirestore();
    data['participantUids'] = _buildParticipantUids(cita);
    data['updatedBy'] = updatedBy;
    await _ref.doc(cita.id).set(data, SetOptions(merge: true));
  }

  /// Cambia el estado de una cita.
  Future<void> updateStatus(
    String citaId,
    CitaStatus newStatus, {
    required String updatedBy,
  }) async {
    final now = DateTime.now();
    await _ref.doc(citaId).update({
      'status': newStatus.label,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Desactiva (soft delete) una cita.
  Future<void> deactivate(String citaId) async {
    final now = DateTime.now();
    await _ref.doc(citaId).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Reactiva una cita.
  Future<void> activate(String citaId) async {
    final now = DateTime.now();
    await _ref.doc(citaId).update({
      'isActive': true,
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Stream de citas activas donde el usuario es participante (cross-project).
  Stream<List<Cita>> watchByParticipantUid(String uid) {
    return _ref
        .where('participantUids', arrayContains: uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(Cita.fromFirestore).toList();
          list.sort(
            (a, b) => (a.fecha ?? DateTime(2099)).compareTo(
              b.fecha ?? DateTime(2099),
            ),
          );
          return list;
        });
  }

  // ── Comentarios ────────────────────────────────────────

  /// Stream de comentarios de una cita.
  Stream<List<CitaComment>> watchComments(String citaId) {
    return _commentsRef
        .where('refCita', isEqualTo: citaId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(CitaComment.fromFirestore).toList());
  }

  /// Añade un comentario a una cita.
  Future<void> addComment(String citaId, CitaComment comment) async {
    final data = comment.toFirestore();
    data['refCita'] = citaId;
    await _commentsRef.add(data);
  }

  // ── Referencias ─────────────────────────────────────────

  /// Establece la minuta generada tras completar la cita.
  Future<void> setRefMinuta(String citaId, String minutaId) async {
    await _ref.doc(citaId).update({
      'refMinuta': minutaId,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Añade una referencia de ticket a una cita.
  Future<void> addRefTicket(String citaId, String ticketId) async {
    await _ref.doc(citaId).update({
      'refTickets': FieldValue.arrayUnion([ticketId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Añade una referencia de requerimiento a una cita.
  Future<void> addRefRequerimiento(String citaId, String reqId) async {
    await _ref.doc(citaId).update({
      'refRequerimientos': FieldValue.arrayUnion([reqId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Actualiza la agenda (items checklist) de una cita.
  Future<void> updateAgenda(String citaId, List<AgendaItem> agenda) async {
    await _ref.doc(citaId).update({
      'agenda': agenda.map((a) => a.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
