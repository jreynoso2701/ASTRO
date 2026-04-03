import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/aviso.dart';

/// Repositorio CRUD de Avisos en Firestore.
///
/// Colección: `Avisos/{docId}`.
class AvisoRepository {
  AvisoRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('Avisos');

  // ── Streams ────────────────────────────────────────────

  /// Stream de avisos activos de un proyecto (para Root — ve todos).
  Stream<List<Aviso>> watchByProject(String projectId) {
    return _ref
        .where('projectId', isEqualTo: projectId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(Aviso.fromFirestore).toList();
          list.sort(
            (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
              a.createdAt ?? DateTime(2000),
            ),
          );
          return list;
        });
  }

  /// Stream de avisos que un usuario específico puede ver
  /// (enviados a todos, o donde está en destinatarios).
  Stream<List<Aviso>> watchByRecipient(String projectId, String uid) {
    // Firestore no soporta OR queries en un solo stream,
    // así que obtenemos todos los activos del proyecto y filtramos en cliente.
    return _ref
        .where('projectId', isEqualTo: projectId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map(Aviso.fromFirestore)
              .where((a) => a.todosLosUsuarios || a.destinatarios.contains(uid))
              .toList();
          list.sort(
            (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
              a.createdAt ?? DateTime(2000),
            ),
          );
          return list;
        });
  }

  /// Stream de un aviso individual.
  Stream<Aviso?> watchAviso(String avisoId) {
    return _ref.doc(avisoId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Aviso.fromFirestore(doc);
    });
  }

  // ── CRUD ───────────────────────────────────────────────

  /// Crea un nuevo aviso. Retorna el ID del documento creado.
  Future<String> create(Aviso aviso) async {
    final doc = await _ref.add(aviso.toFirestore());
    return doc.id;
  }

  /// Actualiza un aviso (merge).
  Future<void> update(Aviso aviso) async {
    await _ref.doc(aviso.id).set(aviso.toFirestore(), SetOptions(merge: true));
  }

  /// Desactiva (soft delete) un aviso.
  Future<void> deactivate(String avisoId) async {
    await _ref.doc(avisoId).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── Read Receipts ──────────────────────────────────────

  /// Marca un aviso como leído por un usuario específico.
  Future<void> markAsRead(String avisoId, String uid) async {
    await _ref.doc(avisoId).update({
      'lecturas.$uid.leido': true,
      'lecturas.$uid.leidoAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Inicializa las lecturas para una lista de destinatarios.
  /// Se llama al crear el aviso para establecer el tracking.
  Future<void> initializeLecturas(
    String avisoId,
    List<String> recipientUids,
  ) async {
    final lecturas = <String, Map<String, dynamic>>{};
    for (final uid in recipientUids) {
      lecturas[uid] = {'leido': false};
    }
    await _ref.doc(avisoId).update({
      'lecturas': lecturas,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
