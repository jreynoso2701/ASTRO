import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/empresa.dart';

/// Repositorio de Empresas en Firestore — CRUD completo.
class EmpresaRepository {
  EmpresaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('Empresas');

  /// Obtiene todas las empresas activas.
  Future<List<Empresa>> getActiveEmpresas() async {
    final snapshot = await _ref.where('isActive', isEqualTo: true).get();
    return snapshot.docs.map(Empresa.fromFirestore).toList();
  }

  /// Stream de todas las empresas activas.
  Stream<List<Empresa>> watchActiveEmpresas() {
    return _ref
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(Empresa.fromFirestore).toList());
  }

  /// Stream de TODAS las empresas (activas e inactivas) — para gestión Root.
  Stream<List<Empresa>> watchAllEmpresas() {
    return _ref
        .orderBy('nombreEmpresa')
        .snapshots()
        .map((snap) => snap.docs.map(Empresa.fromFirestore).toList());
  }

  /// Obtiene una empresa por ID.
  Future<Empresa?> getEmpresa(String id) async {
    final doc = await _ref.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Empresa.fromFirestore(doc);
  }

  /// Stream de una empresa por ID.
  Stream<Empresa?> watchEmpresa(String id) {
    return _ref.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Empresa.fromFirestore(doc);
    });
  }

  /// Crea una nueva empresa y retorna su ID.
  Future<String> createEmpresa(Empresa empresa) async {
    final data = empresa.toFirestore();
    data['createdAt'] = Timestamp.now();
    data['updatedAt'] = Timestamp.now();
    final doc = await _ref.add(data);
    return doc.id;
  }

  /// Actualiza campos de una empresa existente (merge).
  Future<void> updateEmpresa(String id, Map<String, dynamic> fields) async {
    fields['updatedAt'] = Timestamp.now();
    await _ref.doc(id).update(fields);
  }

  /// Desactiva una empresa (soft delete).
  Future<void> deactivateEmpresa(String id) async {
    await _ref.doc(id).update({
      'isActive': false,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Reactiva una empresa.
  Future<void> activateEmpresa(String id) async {
    await _ref.doc(id).update({'isActive': true, 'updatedAt': Timestamp.now()});
  }

  /// Desactiva empresa + proyectos asociados + asignaciones en cascada.
  ///
  /// Retorna la cantidad de proyectos desactivados.
  Future<int> deactivateEmpresaWithCascade(Empresa empresa) async {
    final batch = _firestore.batch();

    // 1. Desactivar empresa
    batch.update(_ref.doc(empresa.id), {
      'isActive': false,
      'updatedAt': Timestamp.now(),
    });

    // 2. Obtener proyectos activos de esta empresa
    final proyectosRef = _firestore.collection('Proyectos');
    final byName = await proyectosRef
        .where('fkEmpresa', isEqualTo: empresa.nombreEmpresa)
        .where('estatusProyecto', isEqualTo: true)
        .get();
    final byId = await proyectosRef
        .where('empresaId', isEqualTo: empresa.id)
        .where('estatusProyecto', isEqualTo: true)
        .get();

    // Unificar IDs para evitar duplicados
    final projectIds = <String>{};
    for (final doc in [...byName.docs, ...byId.docs]) {
      projectIds.add(doc.id);
    }

    // 3. Desactivar cada proyecto
    for (final pid in projectIds) {
      batch.update(proyectosRef.doc(pid), {'estatusProyecto': false});
    }

    // 4. Desactivar asignaciones de esos proyectos
    final assignRef = _firestore.collection('projectAssignments');
    for (final pid in projectIds) {
      final assignments = await assignRef
          .where('projectId', isEqualTo: pid)
          .where('isActive', isEqualTo: true)
          .get();
      for (final doc in assignments.docs) {
        batch.update(assignRef.doc(doc.id), {'isActive': false});
      }
    }

    await batch.commit();
    return projectIds.length;
  }

  /// Reactiva empresa + opcionalmente reactiva proyectos y asignaciones.
  ///
  /// Retorna la cantidad de proyectos reactivados.
  Future<int> activateEmpresaWithCascade(
    Empresa empresa, {
    required bool reactivateProjects,
  }) async {
    final batch = _firestore.batch();

    // 1. Reactivar empresa
    batch.update(_ref.doc(empresa.id), {
      'isActive': true,
      'updatedAt': Timestamp.now(),
    });

    var count = 0;

    if (reactivateProjects) {
      // 2. Obtener proyectos inactivos de esta empresa
      final proyectosRef = _firestore.collection('Proyectos');
      final byName = await proyectosRef
          .where('fkEmpresa', isEqualTo: empresa.nombreEmpresa)
          .where('estatusProyecto', isEqualTo: false)
          .get();
      final byId = await proyectosRef
          .where('empresaId', isEqualTo: empresa.id)
          .where('estatusProyecto', isEqualTo: false)
          .get();

      final projectIds = <String>{};
      for (final doc in [...byName.docs, ...byId.docs]) {
        projectIds.add(doc.id);
      }

      // 3. Reactivar cada proyecto
      for (final pid in projectIds) {
        batch.update(proyectosRef.doc(pid), {'estatusProyecto': true});
      }

      // 4. Reactivar asignaciones de esos proyectos
      final assignRef = _firestore.collection('projectAssignments');
      for (final pid in projectIds) {
        final assignments = await assignRef
            .where('projectId', isEqualTo: pid)
            .where('isActive', isEqualTo: false)
            .get();
        for (final doc in assignments.docs) {
          batch.update(assignRef.doc(doc.id), {'isActive': true});
        }
      }

      count = projectIds.length;
    }

    await batch.commit();
    return count;
  }
}
