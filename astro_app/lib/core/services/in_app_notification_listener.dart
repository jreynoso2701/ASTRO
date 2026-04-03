import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:astro/core/models/in_app_notification.dart';
import 'package:astro/core/models/notification_type.dart';
import 'package:astro/core/services/notification_sound_service.dart';
import 'package:astro/core/widgets/in_app_toast_widget.dart';
import 'package:astro/features/notifications/providers/notification_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Provider del servicio de sonido de notificación.
final _soundServiceProvider = Provider<NotificationSoundService>((ref) {
  final svc = NotificationSoundService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

/// Widget que escucha notificaciones nuevas en tiempo real y muestra
/// toasts overlay en la parte superior de la pantalla.
///
/// Debe estar dentro de [MaterialApp] para tener acceso al [Overlay].
/// Se integra en `MaterialApp.router(builder: ...)`.
class InAppNotificationListener extends ConsumerStatefulWidget {
  const InAppNotificationListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<InAppNotificationListener> createState() =>
      _InAppNotificationListenerState();
}

class _InAppNotificationListenerState
    extends ConsumerState<InAppNotificationListener> {
  /// IDs de notificaciones ya vistas (para detectar nuevas).
  final _seenIds = <String>{};

  /// Indica si la primera emisión del stream ya fue procesada.
  bool _initialized = false;

  /// Overlay entries activos.
  final _activeEntries = <String, OverlayEntry>{};

  /// Cola de toasts pendientes (para no saturar la pantalla).
  final _pendingQueue = <InAppNotification>[];

  /// Máximo de toasts simultáneos.
  static const _maxVisible = 3;

  @override
  void dispose() {
    for (final entry in _activeEntries.values) {
      entry.remove();
    }
    _activeEntries.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios en notificaciones no leídas
    ref.listen(unreadNotificationsProvider, (prev, next) {
      final notifications = next.value;
      if (notifications == null) return;

      if (!_initialized) {
        // Primera emisión → registrar IDs existentes sin mostrar toasts
        _seenIds.addAll(notifications.map((n) => n.id));
        _initialized = true;
        return;
      }

      // Verificar si las notificaciones in-app están habilitadas
      final profile = ref.read(currentUserProfileProvider).value;
      if (profile == null) return;
      if (!profile.inAppNotificationsEnabled) return;

      // Detectar notificaciones nuevas
      for (final notif in notifications) {
        if (!_seenIds.contains(notif.id)) {
          _seenIds.add(notif.id);
          _enqueueToast(notif);
        }
      }
    });

    return widget.child;
  }

  void _enqueueToast(InAppNotification notification) {
    if (_activeEntries.length < _maxVisible) {
      _showToast(notification);
    } else {
      _pendingQueue.add(notification);
    }
  }

  void _showToast(InAppNotification notification) {
    // Reproducir sonido
    ref.read(_soundServiceProvider).play();

    final entry = OverlayEntry(
      builder: (context) {
        final topPadding = MediaQuery.of(context).padding.top;
        // Posicionar debajo del safe area, apilado si hay varios
        final index = _activeEntries.keys.toList().indexOf(notification.id);
        final topOffset = topPadding + (index * 84);

        return Positioned(
          top: topOffset.toDouble(),
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: InAppToastWidget(
              notification: notification,
              onTap: () => _navigateToRef(notification),
              onDismissed: () => _removeEntry(notification.id),
            ),
          ),
        );
      },
    );

    _activeEntries[notification.id] = entry;
    Overlay.of(context).insert(entry);
  }

  void _removeEntry(String id) {
    final entry = _activeEntries.remove(id);
    entry?.remove();

    // Mostrar siguiente de la cola si hay espacio
    if (_pendingQueue.isNotEmpty && _activeEntries.length < _maxVisible) {
      final next = _pendingQueue.removeAt(0);
      _showToast(next);
    }
  }

  void _navigateToRef(InAppNotification n) {
    // Marcar como leída
    ref.read(notificationRepoProvider).markAsRead(n.id);

    final router = GoRouter.of(context);
    switch (n.refType) {
      case NotificationRefType.ticket:
        router.push('/projects/${n.projectId}/tickets/${n.refId}');
      case NotificationRefType.requerimiento:
        router.push('/projects/${n.projectId}/requirements/${n.refId}');
      case NotificationRefType.minuta:
        router.push('/projects/${n.projectId}/minutas/${n.refId}');
      case NotificationRefType.tarea:
        router.push('/projects/${n.projectId}/tareas/${n.refId}');
      case NotificationRefType.cita:
        router.push('/projects/${n.projectId}/citas/${n.refId}');
      case NotificationRefType.aviso:
        router.push('/projects/${n.projectId}/avisos/${n.refId}');
    }
  }
}
