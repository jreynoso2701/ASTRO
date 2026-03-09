import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/funcionalidad.dart';

/// Repositorio CRUD de Funcionalidades en Firestore.
///
/// Sub-colección: `Modulos/{moduleId}/Funcionalidades`.
class FuncionalidadRepository {
  FuncionalidadRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _ref(String moduleId) => _firestore
      .collection('Modulos')
      .doc(moduleId)
      .collection('Funcionalidades');

  /// Stream de todas las funcionalidades de un módulo (ordenadas).
  Stream<List<Funcionalidad>> watchByModule(String moduleId) {
    return _ref(moduleId)
        .orderBy('orden')
        .snapshots()
        .map((snap) => snap.docs.map(Funcionalidad.fromFirestore).toList());
  }

  /// Stream de funcionalidades activas de un módulo.
  Stream<List<Funcionalidad>> watchActiveByModule(String moduleId) {
    return _ref(moduleId)
        .where('estatus', isEqualTo: true)
        .orderBy('orden')
        .snapshots()
        .map((snap) => snap.docs.map(Funcionalidad.fromFirestore).toList());
  }

  /// Crea una nueva funcionalidad.
  Future<String> create(String moduleId, Funcionalidad func) async {
    final doc = await _ref(moduleId).add({
      ...func.toFirestore(),
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    return doc.id;
  }

  /// Actualiza una funcionalidad existente (merge).
  Future<void> update(String moduleId, Funcionalidad func) async {
    await _ref(
      moduleId,
    ).doc(func.id).set(func.toFirestore(), SetOptions(merge: true));
  }

  /// Toggle completada.
  Future<void> toggleCompletada(
    String moduleId,
    String funcId,
    bool completada,
  ) async {
    await _ref(moduleId).doc(funcId).update({
      'completada': completada,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Desactivar (soft delete).
  Future<void> deactivate(String moduleId, String funcId) async {
    await _ref(moduleId).doc(funcId).update({
      'estatus': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Reactivar.
  Future<void> activate(String moduleId, String funcId) async {
    await _ref(moduleId).doc(funcId).update({
      'estatus': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Cuenta funcionalidades activas y completadas (para progreso).
  Stream<({int total, int completed})> watchProgress(String moduleId) {
    return _ref(moduleId).where('estatus', isEqualTo: true).snapshots().map((
      snap,
    ) {
      final docs = snap.docs.map(Funcionalidad.fromFirestore).toList();
      final completed = docs.where((f) => f.completada).length;
      return (total: docs.length, completed: completed);
    });
  }
}
