import 'package:flutter/material.dart';
import 'package:astro/core/models/in_app_notification.dart';
import 'package:astro/core/models/notification_type.dart';

/// Toast overlay que muestra una notificación in-app al estilo banner.
///
/// Aparece desde la parte superior con animación de deslizamiento.
/// Se oculta automáticamente tras [autoDismissDuration] o al deslizar hacia arriba.
class InAppToastWidget extends StatefulWidget {
  const InAppToastWidget({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
    this.autoDismissDuration = const Duration(seconds: 5),
    super.key,
  });

  final InAppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final Duration autoDismissDuration;

  @override
  State<InAppToastWidget> createState() => _InAppToastWidgetState();
}

class _InAppToastWidgetState extends State<InAppToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Auto-dismiss
    Future.delayed(widget.autoDismissDuration, () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final n = widget.notification;

    final typeColor = _colorForRefType(n.refType, colors);
    final typeIcon = _iconForType(n.tipo);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dismissible(
          key: ValueKey('toast_${n.id}'),
          direction: DismissDirection.up,
          onDismissed: (_) => widget.onDismissed(),
          child: GestureDetector(
            onTap: () {
              _dismiss();
              widget.onTap();
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceContainerHighest
                    : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: typeColor.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    // Barra lateral de color
                    Container(width: 4, height: 64, color: typeColor),
                    const SizedBox(width: 12),

                    // Icono
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(typeIcon, size: 20, color: typeColor),
                    ),
                    const SizedBox(width: 12),

                    // Contenido
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Nombre del proyecto
                            if (n.projectName.isNotEmpty)
                              Text(
                                n.projectName,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: typeColor,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              n.titulo,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (n.cuerpo.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                n.cuerpo,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Indicador de cerrar
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Color por tipo de referencia.
  Color _colorForRefType(NotificationRefType refType, ColorScheme colors) {
    return switch (refType) {
      NotificationRefType.ticket => const Color(0xFFE53935), // Rojo
      NotificationRefType.requerimiento => const Color(0xFF1E88E5), // Azul
      NotificationRefType.tarea => const Color(0xFF43A047), // Verde
      NotificationRefType.cita => const Color(0xFFFF9800), // Naranja
      NotificationRefType.minuta => const Color(0xFF8E24AA), // Púrpura
      NotificationRefType.aviso => const Color(0xFFFFB300), // Ámbar
    };
  }

  /// Icono según tipo de notificación.
  IconData _iconForType(NotificationType tipo) {
    return switch (tipo) {
      NotificationType.ticketCreado => Icons.bug_report_outlined,
      NotificationType.ticketStatusCambiado => Icons.swap_horiz,
      NotificationType.ticketAsignado => Icons.person_add_outlined,
      NotificationType.ticketComentario => Icons.chat_bubble_outline,
      NotificationType.ticketPrioridadCambiada => Icons.flag_outlined,
      NotificationType.ticketFechaCompromiso => Icons.calendar_month_outlined,
      NotificationType.reqCreado => Icons.assignment_outlined,
      NotificationType.reqStatusCambiado => Icons.published_with_changes,
      NotificationType.reqAsignado => Icons.person_add_alt_1_outlined,
      NotificationType.reqComentario => Icons.chat_outlined,
      NotificationType.reqFaseAsignada => Icons.next_plan_outlined,
      NotificationType.reqPrioridadCambiada => Icons.flag_outlined,
      NotificationType.reqFechaCompromiso => Icons.calendar_month_outlined,
      NotificationType.reqDeadlineAmber => Icons.schedule,
      NotificationType.reqDeadlineOrange => Icons.warning_amber_outlined,
      NotificationType.reqDeadlineRed => Icons.error_outline,
      NotificationType.ticketDeadlineAmber => Icons.schedule,
      NotificationType.ticketDeadlineOrange => Icons.warning_amber_outlined,
      NotificationType.ticketDeadlineRed => Icons.error_outline,
      NotificationType.tareaCreada => Icons.task_outlined,
      NotificationType.tareaStatusCambiada => Icons.swap_horiz,
      NotificationType.tareaAsignada => Icons.person_add_outlined,
      NotificationType.tareaDeadlineAmber => Icons.schedule,
      NotificationType.tareaDeadlineOrange => Icons.warning_amber_outlined,
      NotificationType.tareaDeadlineRed => Icons.error_outline,
      NotificationType.compromisoDeadlineAmber => Icons.schedule,
      NotificationType.compromisoDeadlineOrange => Icons.warning_amber_outlined,
      NotificationType.compromisoDeadlineRed => Icons.error_outline,
      NotificationType.citaCreada => Icons.event_outlined,
      NotificationType.citaActualizada => Icons.event_note_outlined,
      NotificationType.citaCancelada => Icons.event_busy_outlined,
      NotificationType.citaCompletada => Icons.check_circle_outline,
      NotificationType.citaRecordatorio => Icons.notifications_active_outlined,
      NotificationType.avisoCreado => Icons.campaign_outlined,
      NotificationType.avisoUrgente => Icons.campaign,
    };
  }
}
