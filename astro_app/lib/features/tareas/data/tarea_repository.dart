import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/tarea.dart';

/// Repositorio CRUD de Tareas en Firestore.
///
/// Colección: `Tareas/{docId}`.
class TareaRepository {
  TareaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('Tareas');

  // ── Streams ────────────────────────────────────────────

  /// Stream de tareas activas de un proyecto.
  Stream<List<Tarea>> watchByProject(String projectId) {
    return _ref
        .where('projectId', isEqualTo: projectId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final tareas = snap.docs.map(Tarea.fromFirestore).toList();
          tareas.sort(
            (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
              a.updatedAt ?? DateTime(2000),
            ),
          );
          return tareas;
        });
  }

  /// Stream de tareas asignadas a un usuario (cross-project).
  Stream<List<Tarea>> watchByAssignee(String uid) {
    return _ref
        .where('assignedToUid', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final tareas = snap.docs.map(Tarea.fromFirestore).toList();
          tareas.sort(
            (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
              a.updatedAt ?? DateTime(2000),
            ),
          );
          return tareas;
        });
  }

  /// Stream de una tarea individual.
  Stream<Tarea?> watchTarea(String tareaId) {
    return _ref.doc(tareaId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Tarea.fromFirestore(doc);
    });
  }

  // ── CRUD ───────────────────────────────────────────────

  /// Genera folio: TAR-PROYECTO_ABBR-NUM.
  Future<String> _nextFolio(String projectName) async {
    final snap = await _ref.get();
    int maxNum = 0;
    for (final doc in snap.docs) {
      final folio = doc.data()['folio'] as String? ?? '';
      final parts = folio.split('-');
      if (parts.length >= 2) {
        final num = int.tryParse(parts.last) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    final projAbbr = _abbreviate(projectName);
    return 'TAR-$projAbbr-${maxNum + 1}';
  }

  static String _abbreviate(String name) {
    if (name.isEmpty) return '';
    final firstWord = name.trim().split(RegExp(r'\s+')).first;
    return firstWord.substring(0, min(3, firstWord.length)).toUpperCase();
  }

  /// Crea una nueva tarea.
  Future<String> create(Tarea tarea) async {
    final folio = await _nextFolio(tarea.projectName);
    final data = tarea.toFirestore();
    data['folio'] = folio;
    final doc = await _ref.add(data);
    return doc.id;
  }

  /// Actualiza una tarea (merge).
  Future<void> update(Tarea tarea) async {
    await _ref.doc(tarea.id).set(tarea.toFirestore(), SetOptions(merge: true));
  }

  /// Actualiza solo los adjuntos de una tarea.
  Future<void> updateAdjuntos(String tareaId, List<String> urls) async {
    final now = DateTime.now();
    await _ref.doc(tareaId).update({
      'adjuntos': FieldValue.arrayUnion(urls),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Archiva (desactiva) una tarea.
  Future<void> archive(String tareaId) async {
    await _ref.doc(tareaId).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Restaura una tarea archivada (reactivar + cambiar estado).
  Future<void> restore(String tareaId, {required String newStatus}) async {
    await _ref.doc(tareaId).update({
      'isActive': true,
      'status': newStatus,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Actualiza solo el status de una tarea.
  Future<void> updateStatus(String tareaId, String newStatus) async {
    await _ref.doc(tareaId).update({
      'status': newStatus,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Stream de todas las tareas (activas e inactivas) vinculadas a una minuta.
  Stream<List<Tarea>> watchByMinuta(String minutaId) {
    return _ref.where('refMinutaId', isEqualTo: minutaId).snapshots().map((
      snap,
    ) {
      final tareas = snap.docs.map(Tarea.fromFirestore).toList();
      tareas.sort(
        (a, b) =>
            (a.refCompromisoNumero ?? 0).compareTo(b.refCompromisoNumero ?? 0),
      );
      return tareas;
    });
  }

  /// Stream de tareas archivadas de un proyecto.
  Stream<List<Tarea>> watchArchivedByProject(String projectId) {
    return _ref
        .where('projectId', isEqualTo: projectId)
        .where('isActive', isEqualTo: false)
        .snapshots()
        .map((snap) {
          final tareas = snap.docs.map(Tarea.fromFirestore).toList();
          tareas.sort(
            (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
              a.updatedAt ?? DateTime(2000),
            ),
          );
          return tareas;
        });
  }
}
