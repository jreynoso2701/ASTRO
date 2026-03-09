import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/in_app_notification.dart';

/// Repositorio para la bandeja de notificaciones del usuario.
///
/// Colección: `Notificaciones/{docId}`
class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
    : _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _fs;

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('Notificaciones');

  /// Stream de notificaciones del usuario, ordenadas por fecha descendente.
  Stream<List<InAppNotification>> watchByUser(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(InAppNotification.fromFirestore).toList());
  }

  /// Stream de notificaciones no leídas del usuario.
  Stream<List<InAppNotification>> watchUnreadByUser(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('leida', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(InAppNotification.fromFirestore).toList());
  }

  /// Marca una notificación como leída.
  Future<void> markAsRead(String notificationId) async {
    await _col.doc(notificationId).update({'leida': true});
  }

  /// Marca todas las notificaciones del usuario como leídas.
  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _col
        .where('userId', isEqualTo: userId)
        .where('leida', isEqualTo: false)
        .get();

    final batch = _fs.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'leida': true});
    }
    await batch.commit();
  }

  /// Elimina una notificación.
  Future<void> delete(String notificationId) async {
    await _col.doc(notificationId).delete();
  }

  /// Crea una notificación (usado por Cloud Functions, pero disponible client-side).
  Future<void> create(InAppNotification notification) async {
    await _col.add(notification.toFirestore());
  }
}
