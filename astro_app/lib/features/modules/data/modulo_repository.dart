import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/modulo.dart';

/// Repositorio CRUD de Módulos en Firestore.
class ModuloRepository {
  ModuloRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('Modulos');

  /// Stream de módulos de un proyecto (por nombre V1).
  Stream<List<Modulo>> watchModulosByProject(String projectName) {
    return _ref
        .where('fkProyecto', isEqualTo: projectName)
        .snapshots()
        .map((snap) => snap.docs.map(Modulo.fromFirestore).toList());
  }

  /// Stream de módulos activos de un proyecto (por nombre V1).
  Stream<List<Modulo>> watchActiveModulosByProject(String projectName) {
    return _ref
        .where('fkProyecto', isEqualTo: projectName)
        .where('estatusModulo', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(Modulo.fromFirestore).toList());
  }

  /// Stream de un módulo específico.
  Stream<Modulo?> watchModulo(String id) {
    return _ref.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Modulo.fromFirestore(doc);
    });
  }

  /// Obtiene un módulo por ID.
  Future<Modulo?> getModulo(String id) async {
    final doc = await _ref.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Modulo.fromFirestore(doc);
  }

  /// Crea un nuevo módulo.
  Future<String> createModulo(Modulo modulo) async {
    final doc = await _ref.add(modulo.toFirestore());
    return doc.id;
  }

  /// Actualiza un módulo existente (merge para preservar campos V1).
  Future<void> updateModulo(Modulo modulo) async {
    await _ref
        .doc(modulo.id)
        .set(modulo.toFirestore(), SetOptions(merge: true));
  }

  /// Actualiza el porcentaje de completado de un módulo.
  Future<void> updateProgress(String id, double percent) async {
    await _ref.doc(id).update({
      'porcentCompletaModulo': percent,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Desactiva un módulo (soft delete).
  Future<void> deactivateModulo(String id) async {
    await _ref.doc(id).update({
      'estatusModulo': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Reactiva un módulo.
  Future<void> activateModulo(String id) async {
    await _ref.doc(id).update({
      'estatusModulo': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
