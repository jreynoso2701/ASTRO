import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/proyecto.dart';

/// Repositorio CRUD de Proyectos en Firestore.
class ProyectoRepository {
  ProyectoRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('Proyectos');

  /// Obtiene todos los proyectos activos.
  Future<List<Proyecto>> getActiveProyectos() async {
    final snapshot = await _ref.where('estatusProyecto', isEqualTo: true).get();
    return snapshot.docs.map(Proyecto.fromFirestore).toList();
  }

  /// Stream de proyectos activos.
  Stream<List<Proyecto>> watchActiveProyectos() {
    return _ref
        .where('estatusProyecto', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(Proyecto.fromFirestore).toList());
  }

  /// Stream de todos los proyectos (incluye desactivados).
  Stream<List<Proyecto>> watchAllProyectos() {
    return _ref.snapshots().map(
      (snap) => snap.docs.map(Proyecto.fromFirestore).toList(),
    );
  }

  /// Proyectos de una empresa específica (por nombre V1).
  Future<List<Proyecto>> getProyectosByEmpresa(String empresaName) async {
    final snapshot = await _ref
        .where('fkEmpresa', isEqualTo: empresaName)
        .get();
    return snapshot.docs.map(Proyecto.fromFirestore).toList();
  }

  /// Obtiene un proyecto por ID.
  Future<Proyecto?> getProyecto(String id) async {
    final doc = await _ref.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Proyecto.fromFirestore(doc);
  }

  /// Stream de un proyecto específico.
  Stream<Proyecto?> watchProyecto(String id) {
    return _ref.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Proyecto.fromFirestore(doc);
    });
  }

  /// Crea un nuevo proyecto.
  Future<String> createProyecto(Proyecto proyecto) async {
    final doc = await _ref.add(proyecto.toFirestore());
    return doc.id;
  }

  /// Actualiza un proyecto existente (merge para preservar campos V1).
  Future<void> updateProyecto(Proyecto proyecto) async {
    await _ref
        .doc(proyecto.id)
        .set(proyecto.toFirestore(), SetOptions(merge: true));
  }

  /// Desactiva un proyecto (soft delete).
  Future<void> deactivateProyecto(String id) async {
    await _ref.doc(id).update({'estatusProyecto': false});
  }

  /// Reactiva un proyecto.
  Future<void> activateProyecto(String id) async {
    await _ref.doc(id).update({'estatusProyecto': true});
  }
}
