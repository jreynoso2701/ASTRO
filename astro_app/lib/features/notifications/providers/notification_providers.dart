import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/in_app_notification.dart';
import 'package:astro/core/models/notification_config.dart';
import 'package:astro/core/services/notification_service.dart';
import 'package:astro/features/notifications/data/notification_config_repository.dart';
import 'package:astro/features/notifications/data/notification_repository.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';

// ── Repositories ─────────────────────────────────────────

final notificationConfigRepoProvider = Provider<NotificationConfigRepository>(
  (ref) => NotificationConfigRepository(),
);

final notificationRepoProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(),
);

// ── Service ──────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

// ── Inbox (bandeja de notificaciones del usuario) ────────

/// Todas las notificaciones del usuario actual (últimas 100).
final inboxNotificationsProvider = StreamProvider<List<InAppNotification>>((
  ref,
) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(notificationRepoProvider).watchByUser(uid);
});

/// Notificaciones no leídas del usuario actual.
final unreadNotificationsProvider = StreamProvider<List<InAppNotification>>((
  ref,
) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(notificationRepoProvider).watchUnreadByUser(uid);
});

/// Conteo de no leídas (para badge).
final unreadCountProvider = Provider<int>((ref) {
  final unread = ref.watch(unreadNotificationsProvider);
  return unread.value?.length ?? 0;
});

// ── Config por proyecto ──────────────────────────────────

/// Configuraciones de notificación de todos los miembros de un proyecto.
final projectNotifConfigsProvider =
    StreamProvider.family<List<NotificationConfig>, String>((ref, projectId) {
      return ref
          .watch(notificationConfigRepoProvider)
          .watchByProject(projectId);
    });

/// Configuración de notificación de un usuario específico en un proyecto.
final userNotifConfigProvider =
    StreamProvider.family<
      NotificationConfig?,
      ({String projectId, String userId})
    >((ref, params) {
      return ref
          .watch(notificationConfigRepoProvider)
          .watch(params.projectId, params.userId);
    });
