import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/minuta.dart';

/// Repositorio CRUD de Minutas en Firestore.
///
/// Colección: `Minutas/{docId}`.
class MinutaRepository {
  MinutaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('Minutas');

  // ── Minutas ────────────────────────────────────────────

  /// Stream de minutas activas de un proyecto (por nombre).
  Stream<List<Minuta>> watchByProject(String projectName) {
    return _ref
        .where('projectName', isEqualTo: projectName)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(Minuta.fromFirestore).toList();
          list.sort(
            (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
              a.updatedAt ?? DateTime(2000),
            ),
          );
          return list;
        });
  }

  /// Stream de minutas donde un usuario participa (asistente o responsable de compromiso).
  /// Usa el campo desnormalizado `participantUids` para query eficiente.
  Stream<List<Minuta>> watchByParticipant(String projectName, String uid) {
    return _ref
        .where('projectName', isEqualTo: projectName)
        .where('isActive', isEqualTo: true)
        .where('participantUids', arrayContains: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(Minuta.fromFirestore).toList();
          list.sort(
            (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
              a.updatedAt ?? DateTime(2000),
            ),
          );
          return list;
        });
  }

  /// Stream de una minuta individual.
  Stream<Minuta?> watchMinuta(String minutaId) {
    return _ref.doc(minutaId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Minuta.fromFirestore(doc);
    });
  }

  /// Genera folio: MIN-EMPRESA-PROYECTO-NUM.
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
        ? 'MIN-$empAbbr-$projAbbr'
        : 'MIN-$projAbbr';
    return '$prefix-${maxNum + 1}';
  }

  static String _abbreviate(String name) {
    if (name.isEmpty) return '';
    final firstWord = name.trim().split(RegExp(r'\s+')).first;
    return firstWord.substring(0, min(3, firstWord.length)).toUpperCase();
  }

  /// Crea una nueva minuta.
  Future<String> create(Minuta minuta) async {
    final folio = await _nextFolio(minuta.projectName, minuta.empresaName);

    final data = minuta.toFirestore();
    data['folio'] = folio;

    final doc = await _ref.add(data);
    return doc.id;
  }

  /// Actualiza una minuta (merge).
  Future<void> update(Minuta minuta) async {
    await _ref
        .doc(minuta.id)
        .set(minuta.toFirestore(), SetOptions(merge: true));
  }

  /// Actualiza el status de un compromiso específico dentro de una minuta.
  Future<void> updateCompromisoStatus(
    String minutaId, {
    required int compromisoNumero,
    required String newStatus,
  }) async {
    final doc = await _ref.doc(minutaId).get();
    if (!doc.exists || doc.data() == null) return;

    final minuta = Minuta.fromFirestore(doc);
    final updated = List<Map<String, dynamic>>.from(
      minuta.compromisos.map((c) {
        final map = c.toMap();
        if (c.numero == compromisoNumero) {
          map['status'] = newStatus;
        }
        return map;
      }),
    );

    await _ref.doc(minutaId).update({
      'compromisos': updated,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Añade una referencia de ticket a una minuta.
  Future<void> addRefTicket(String minutaId, String ticketId) async {
    await _ref.doc(minutaId).update({
      'refTickets': FieldValue.arrayUnion([ticketId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Añade una referencia de requerimiento a una minuta.
  Future<void> addRefRequerimiento(String minutaId, String reqId) async {
    await _ref.doc(minutaId).update({
      'refRequerimientos': FieldValue.arrayUnion([reqId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Desactiva (soft delete) una minuta.
  Future<void> deactivate(String minutaId) async {
    final now = DateTime.now();
    await _ref.doc(minutaId).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Reactiva una minuta.
  Future<void> activate(String minutaId) async {
    final now = DateTime.now();
    await _ref.doc(minutaId).update({
      'isActive': true,
      'updatedAt': Timestamp.fromDate(now),
    });
  }
}
