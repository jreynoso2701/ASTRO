import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/notification_config.dart';

/// Repositorio para gestionar la configuración de notificaciones por usuario/proyecto.
///
/// Colección: `NotificationConfig/{projectId_userId}`
class NotificationConfigRepository {
  NotificationConfigRepository({FirebaseFirestore? firestore})
    : _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _fs;

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('NotificationConfig');

  /// ID compuesto para el documento.
  String _docId(String projectId, String userId) => '${projectId}_$userId';

  /// Obtiene la configuración de un usuario para un proyecto.
  /// Retorna null si no hay override (se usarán defaults).
  Future<NotificationConfig?> get(String projectId, String userId) async {
    final doc = await _col.doc(_docId(projectId, userId)).get();
    if (!doc.exists || doc.data() == null) return null;
    return NotificationConfig.fromFirestore(doc);
  }

  /// Stream de la configuración de un usuario para un proyecto.
  Stream<NotificationConfig?> watch(String projectId, String userId) {
    return _col.doc(_docId(projectId, userId)).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return NotificationConfig.fromFirestore(doc);
    });
  }

  /// Stream de todas las configuraciones de un proyecto.
  Stream<List<NotificationConfig>> watchByProject(String projectId) {
    return _col
        .where('projectId', isEqualTo: projectId)
        .snapshots()
        .map(
          (snap) => snap.docs.map(NotificationConfig.fromFirestore).toList(),
        );
  }

  /// Crea o actualiza la configuración.
  Future<void> save(NotificationConfig config) async {
    await _col
        .doc(_docId(config.projectId, config.userId))
        .set(config.toFirestore(), SetOptions(merge: true));
  }

  /// Elimina el override (vuelve a defaults del rol).
  Future<void> delete(String projectId, String userId) async {
    await _col.doc(_docId(projectId, userId)).delete();
  }
}
