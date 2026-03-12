import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/in_app_notification.dart';
import 'package:astro/core/models/notification_type.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/notifications/providers/notification_providers.dart';

/// Bandeja de notificaciones del usuario.
class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(inboxNotificationsProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('NOTIFICACIONES'),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final repo = ref.read(notificationRepoProvider);
                final uid = ref.read(authStateProvider).value?.uid;
                if (uid != null) await repo.markAllAsRead(uid);
              },
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Leer todo'),
            ),
          ],
        ),
        body: notifAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (notifications) {
            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 64,
                      color: colors.onSurface.withValues(alpha: .3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sin notificaciones',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface.withValues(alpha: .5),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) =>
                  _NotificationTile(notification: notifications[i]),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});
  final InAppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isUnread = !notification.leida;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isUnread
            ? colors.primary.withValues(alpha: .15)
            : colors.surfaceContainerHighest,
        child: Icon(
          _iconForType(notification.tipo),
          color: isUnread
              ? colors.primary
              : colors.onSurface.withValues(alpha: .5),
          size: 20,
        ),
      ),
      title: Text(
        notification.titulo,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.cuerpo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                notification.projectName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              if (notification.createdAt != null)
                Text(
                  _timeAgo(notification.createdAt!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: .4),
                  ),
                ),
            ],
          ),
        ],
      ),
      trailing: isUnread
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: () {
        // Marcar como leída
        if (isUnread) {
          ref.read(notificationRepoProvider).markAsRead(notification.id);
        }
        // Navegar al recurso
        _navigateToRef(context, notification);
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar notificación'),
            content: const Text('¿Eliminar esta notificación?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  ref.read(notificationRepoProvider).delete(notification.id);
                  Navigator.pop(ctx);
                },
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToRef(BuildContext context, InAppNotification n) {
    if (n.refType == NotificationRefType.ticket) {
      context.push('/projects/${n.projectId}/tickets/${n.refId}');
    } else if (n.refType == NotificationRefType.requerimiento) {
      context.push('/projects/${n.projectId}/requirements/${n.refId}');
    }
  }

  IconData _iconForType(NotificationType tipo) {
    return switch (tipo) {
      NotificationType.ticketCreado => Icons.bug_report_outlined,
      NotificationType.ticketStatusCambiado => Icons.swap_horiz,
      NotificationType.ticketAsignado => Icons.person_add_outlined,
      NotificationType.ticketComentario => Icons.chat_bubble_outline,
      NotificationType.ticketPrioridadCambiada => Icons.flag_outlined,
      NotificationType.reqCreado => Icons.assignment_outlined,
      NotificationType.reqStatusCambiado => Icons.published_with_changes,
      NotificationType.reqAsignado => Icons.person_add_alt_1_outlined,
      NotificationType.reqComentario => Icons.chat_outlined,
      NotificationType.reqFaseAsignada => Icons.next_plan_outlined,
      NotificationType.ticketDeadlineAmber => Icons.schedule,
      NotificationType.ticketDeadlineOrange => Icons.warning_amber_outlined,
      NotificationType.ticketDeadlineRed => Icons.error_outline,
    };
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }
}
