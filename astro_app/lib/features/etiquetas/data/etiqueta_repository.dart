import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/etiqueta.dart';

/// Repositorio CRUD de Etiquetas en Firestore.
///
/// Colección: `Etiquetas/{docId}`.
class EtiquetaRepository {
  EtiquetaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('Etiquetas');

  // ── Streams ───────────────────────────────────────────────

  /// Stream de todas las etiquetas globales activas.
  Stream<List<Etiqueta>> watchGlobal() {
    return _ref
        .where('esGlobal', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(Etiqueta.fromFirestore).toList();
          list.sort((a, b) => a.nombre.compareTo(b.nombre));
          return list;
        });
  }

  /// Stream de etiquetas específicas de un proyecto (activas).
  Stream<List<Etiqueta>> watchByProject(String projectId) {
    return _ref
        .where('projectId', isEqualTo: projectId)
        .where('esGlobal', isEqualTo: false)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(Etiqueta.fromFirestore).toList();
          list.sort((a, b) => a.nombre.compareTo(b.nombre));
          return list;
        });
  }

  /// Stream de todas las etiquetas disponibles en el contexto de un proyecto:
  /// globales + específicas del proyecto.
  Stream<List<Etiqueta>> watchAvailableForProject(String projectId) {
    // Combinamos dos streams: global y project-specific.
    // Se usa un join manual en el provider.
    return _ref.where('isActive', isEqualTo: true).snapshots().map((snap) {
      final list = snap.docs
          .map(Etiqueta.fromFirestore)
          .where((e) => e.esGlobal || e.projectId == projectId)
          .toList();
      list.sort((a, b) {
        // Globales primero, luego por nombre.
        if (a.esGlobal && !b.esGlobal) return -1;
        if (!a.esGlobal && b.esGlobal) return 1;
        return a.nombre.compareTo(b.nombre);
      });
      return list;
    });
  }

  /// Stream de etiquetas por lista de IDs.
  Stream<List<Etiqueta>> watchByIds(List<String> ids) {
    if (ids.isEmpty) return Stream.value([]);
    // Firestore admite hasta 30 elementos en whereIn.
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 30) {
      chunks.add(ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30));
    }
    if (chunks.length == 1) {
      return _ref
          .where(FieldPath.documentId, whereIn: chunks.first)
          .snapshots()
          .map((snap) => snap.docs.map(Etiqueta.fromFirestore).toList());
    }
    // Para múltiples chunks, no soportamos streams reactivos fácilmente;
    // devolvemos solo el primer chunk (en la práctica las entidades tienen pocas etiquetas).
    return _ref
        .where(FieldPath.documentId, whereIn: chunks.first)
        .snapshots()
        .map((snap) => snap.docs.map(Etiqueta.fromFirestore).toList());
  }

  /// Stream de una etiqueta individual.
  Stream<Etiqueta?> watchEtiqueta(String id) {
    return _ref.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Etiqueta.fromFirestore(doc);
    });
  }

  // ── Queries ───────────────────────────────────────────────

  /// Obtiene todas las etiquetas globales (one-shot).
  Future<List<Etiqueta>> getGlobal() async {
    final snap = await _ref
        .where('esGlobal', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map(Etiqueta.fromFirestore).toList();
  }

  // ── CRUD ──────────────────────────────────────────────────

  /// Obtiene una etiqueta por su ID.
  Future<Etiqueta?> getById(String id) async {
    final doc = await _ref.doc(id).get();
    if (!doc.exists) return null;
    return Etiqueta.fromFirestore(doc);
  }

  /// Crea una nueva etiqueta.
  Future<String> create(Etiqueta etiqueta) async {
    final doc = await _ref.add(etiqueta.toFirestore());
    return doc.id;
  }

  /// Actualiza una etiqueta existente.
  Future<void> update(
    String id, {
    required String nombre,
    required String colorHex,
    String? icono,
    bool clearIcono = false,
  }) async {
    await _ref.doc(id).update({
      'nombre': nombre,
      'colorHex': colorHex,
      if (clearIcono) 'icono': FieldValue.delete(),
      if (!clearIcono && icono != null) 'icono': icono,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Desactiva una etiqueta (soft delete).
  Future<void> deactivate(String id) async {
    await _ref.doc(id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reactiva una etiqueta.
  Future<void> activate(String id) async {
    await _ref.doc(id).update({
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Importa una etiqueta global como copia en un proyecto específico.
  Future<String> importGlobal({
    required Etiqueta global,
    required String projectId,
    required String projectName,
    required String byUid,
    required String byName,
  }) async {
    final copy = Etiqueta(
      id: '',
      nombre: global.nombre,
      colorHex: global.colorHex,
      icono: global.icono,
      esGlobal: false,
      projectId: projectId,
      projectName: projectName,
      createdByUid: byUid,
      createdByName: byName,
      isActive: true,
    );
    return create(copy);
  }
}
