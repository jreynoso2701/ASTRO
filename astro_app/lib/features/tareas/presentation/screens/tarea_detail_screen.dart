import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/tarea.dart';
import 'package:astro/core/models/tarea_status.dart';
import 'package:astro/core/models/tarea_prioridad.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/presentation/widgets/storage_image.dart';
import 'package:astro/core/presentation/screens/file_viewer_screen.dart';
import 'package:astro/features/tareas/providers/tarea_providers.dart';
import 'package:astro/features/minutas/data/minuta_repository.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/core/widgets/resolved_ref_text.dart';
import 'package:astro/core/widgets/rich_text_viewer.dart';
import 'package:astro/features/etiquetas/providers/etiqueta_providers.dart';
import 'package:astro/features/etiquetas/presentation/widgets/etiqueta_chip.dart';

/// Pantalla de detalle de una tarea.
class TareaDetailScreen extends ConsumerStatefulWidget {
  const TareaDetailScreen({
    required this.projectId,
    required this.tareaId,
    super.key,
  });

  final String projectId;
  final String tareaId;

  @override
  ConsumerState<TareaDetailScreen> createState() => _TareaDetailScreenState();
}

class _TareaDetailScreenState extends ConsumerState<TareaDetailScreen> {
  bool _isLoading = false;

  Future<void> _updateStatus(TareaStatus newStatus) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(tareaRepositoryProvider);
      final uid = ref.read(authStateProvider).value?.uid ?? '';
      await repo.updateStatus(widget.tareaId, newStatus.name, updatedBy: uid);

      // Sincronizar compromiso en la minuta vinculada (Gap 1).
      final tarea = ref.read(tareaByIdProvider(widget.tareaId)).value;
      if (tarea != null &&
          tarea.refMinutas.isNotEmpty &&
          tarea.refCompromisoNumero != null) {
        final compromisoStatus = switch (newStatus) {
          TareaStatus.completada => 'cumplido',
          _ => 'pendiente',
        };
        try {
          final minutaRepo = MinutaRepository();
          await minutaRepo.updateCompromisoStatus(
            tarea.refMinutas.first,
            compromisoNumero: tarea.refCompromisoNumero!,
            newStatus: compromisoStatus,
          );
        } catch (_) {
          // Best-effort: no bloquear el cambio de tarea.
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tarea marcada como ${newStatus.label}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _archiveTarea() async {
    // Verificar si la tarea está vinculada a una minuta.
    final tarea = ref.read(tareaByIdProvider(widget.tareaId)).value;
    final hasMinuta = tarea != null && tarea.refMinutas.isNotEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivar tarea'),
        content: Text(
          hasMinuta
              ? 'Esta tarea está vinculada a una minuta. '
                    'Al archivarla, el compromiso en la minuta se mostrará '
                    'como archivado. ¿Continuar?'
              : '¿Estás seguro de que deseas archivar esta tarea? '
                    'Podrá ser restaurada posteriormente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(tareaRepositoryProvider);
      await repo.archive(widget.tareaId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tarea archivada')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreTarea() async {
    final newStatus = await showDialog<TareaStatus>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Restaurar tarea'),
        children: [
          for (final s in [TareaStatus.pendiente, TareaStatus.enProgreso])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, s),
              child: Text('Restaurar como "${s.label}"'),
            ),
        ],
      ),
    );
    if (newStatus == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(tareaRepositoryProvider);
      final uid = ref.read(authStateProvider).value?.uid ?? '';
      await repo.restore(
        widget.tareaId,
        newStatus: newStatus.name,
        updatedBy: uid,
      );

      // Sincronizar compromiso en la minuta vinculada.
      final tarea = ref.read(tareaByIdProvider(widget.tareaId)).value;
      if (tarea != null &&
          tarea.refMinutas.isNotEmpty &&
          tarea.refCompromisoNumero != null) {
        try {
          final minutaRepo = MinutaRepository();
          await minutaRepo.updateCompromisoStatus(
            tarea.refMinutas.first,
            compromisoNumero: tarea.refCompromisoNumero!,
            newStatus: 'pendiente',
          );
        } catch (_) {
          // Best-effort.
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tarea restaurada como ${newStatus.label}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tareaAsync = ref.watch(tareaByIdProvider(widget.tareaId));
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final canArchive = ref.watch(canArchiveTareaProvider(widget.projectId));
    final canManageEtiquetas = ref.watch(
      canManageProjectEtiquetasProvider(widget.projectId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('TAREA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          tareaAsync.whenOrNull(
                data: (t) {
                  if (t == null) return null;
                  final canEdit =
                      isRoot || t.assignedToUid == uid || t.createdByUid == uid;
                  if (!canEdit) return null;
                  return IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar tarea',
                    onPressed: () => context.push(
                      '/projects/${widget.projectId}/tareas/${widget.tareaId}/edit',
                    ),
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: tareaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tarea) {
          if (tarea == null) {
            return const Center(child: Text('Tarea no encontrada'));
          }

          final canInteract =
              isRoot || tarea.assignedToUid == uid || tarea.createdByUid == uid;

          final width = MediaQuery.sizeOf(context).width;
          final isWide = width >= AppBreakpoints.medium;

          final hero = _HeroSection(
            tarea: tarea,
            canInteract: canInteract,
            canArchive: canArchive,
            isLoading: _isLoading,
            isWide: isWide,
            onUpdateStatus: _updateStatus,
            onArchive: _archiveTarea,
            onRestore: _restoreTarea,
          );

          final hasSubtareas = tarea.subtareas.isNotEmpty;
          final hasDescription = tarea.descripcion.isNotEmpty;
          final hasAdjuntos = tarea.adjuntos.isNotEmpty;
          final hasEtiquetas = tarea.etiquetaIds.isNotEmpty;
          final hasRefs =
              tarea.refTickets.isNotEmpty ||
              tarea.refRequerimientos.isNotEmpty ||
              tarea.refMinutas.isNotEmpty ||
              tarea.refCitas.isNotEmpty;

          // ── Wide layout (tablet / desktop) ──
          if (isWide) {
            final hasLeftContent = hasSubtareas || hasDescription;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hero,
                  const SizedBox(height: 24),
                  if (hasLeftContent)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Subtareas + Descripción
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (hasSubtareas)
                                _SubtareasChecklist(
                                  tarea: tarea,
                                  canInteract: canInteract,
                                ),
                              if (hasSubtareas && hasDescription)
                                const SizedBox(height: 16),
                              if (hasDescription)
                                _DescriptionCard(
                                  descripcion: tarea.descripcion,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right: Detalles + Adjuntos + Referencias
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _DetailsCard(tarea: tarea),
                              if (hasAdjuntos) ...[
                                const SizedBox(height: 16),
                                _AdjuntosCard(adjuntos: tarea.adjuntos),
                              ],
                              if (hasRefs) ...[
                                const SizedBox(height: 16),
                                _ReferencesCard(
                                  tarea: tarea,
                                  projectId: widget.projectId,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    // Sin contenido izquierdo: detalles en row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _DetailsCard(tarea: tarea)),
                        if (hasAdjuntos || hasRefs) ...[
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (hasAdjuntos)
                                  _AdjuntosCard(adjuntos: tarea.adjuntos),
                                if (hasAdjuntos && hasRefs)
                                  const SizedBox(height: 16),
                                if (hasRefs)
                                  _ReferencesCard(
                                    tarea: tarea,
                                    projectId: widget.projectId,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            );
          }

          // ── Mobile layout ──
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                hero,
                if (hasSubtareas) ...[
                  const SizedBox(height: 16),
                  _SubtareasChecklist(tarea: tarea, canInteract: canInteract),
                ],
                if (hasDescription) ...[
                  const SizedBox(height: 16),
                  _DescriptionCard(descripcion: tarea.descripcion),
                ],
                const SizedBox(height: 16),
                _DetailsCard(tarea: tarea),
                if (hasAdjuntos) ...[
                  const SizedBox(height: 16),
                  _AdjuntosCard(adjuntos: tarea.adjuntos),
                ],
                if (hasRefs) ...[
                  const SizedBox(height: 16),
                  _ReferencesCard(tarea: tarea, projectId: widget.projectId),
                ],
                if (hasEtiquetas) ...[
                  const SizedBox(height: 16),
                  _TareaEtiquetasCard(etiquetaIds: tarea.etiquetaIds),
                ],
                if (canManageEtiquetas) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/projects/${widget.projectId}/etiquetas',
                      ),
                      icon: const Icon(Icons.label_outline, size: 18),
                      label: const Text('Gestionar etiquetas'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Hero Section ─────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.tarea,
    required this.canInteract,
    required this.canArchive,
    required this.isLoading,
    required this.isWide,
    required this.onUpdateStatus,
    required this.onArchive,
    required this.onRestore,
  });

  final Tarea tarea;
  final bool canInteract;
  final bool canArchive;
  final bool isLoading;
  final bool isWide;
  final ValueChanged<TareaStatus> onUpdateStatus;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(tarea.status);
    final isArchived = !tarea.isActive;

    final hasSubtareas = tarea.subtareas.isNotEmpty;
    final completedCount = tarea.subtareas.where((s) => s.completada).length;
    final total = tarea.subtareas.length;
    final progress = total > 0 ? completedCount / total : 0.0;

    final ringSize = isWide ? 120.0 : 88.0;
    final strokeWidth = isWide ? 9.0 : 7.0;

    // Anillo de progreso animado o icono de estado
    final progressWidget = SizedBox(
      width: ringSize,
      height: ringSize,
      child: hasSubtareas
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CustomPaint(
                  painter: _ProgressRingPainter(
                    progress: value,
                    trackColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.08,
                    ),
                    progressColor: isArchived
                        ? theme.colorScheme.onSurfaceVariant
                        : statusColor,
                    strokeWidth: strokeWidth,
                  ),
                  child: Center(
                    child: Text(
                      '${(value * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: isWide ? 26 : 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: isArchived
                            ? theme.colorScheme.onSurfaceVariant
                            : statusColor,
                      ),
                    ),
                  ),
                );
              },
            )
          : Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    (isArchived
                            ? theme.colorScheme.onSurfaceVariant
                            : statusColor)
                        .withValues(alpha: 0.12),
                border: Border.all(
                  color:
                      (isArchived
                              ? theme.colorScheme.onSurfaceVariant
                              : statusColor)
                          .withValues(alpha: 0.3),
                  width: 3,
                ),
              ),
              child: Center(
                child: Icon(
                  _statusIcon(tarea.status),
                  size: ringSize * 0.4,
                  color: isArchived
                      ? theme.colorScheme.onSurfaceVariant
                      : statusColor,
                ),
              ),
            ),
    );

    // Contenido de texto
    final textContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Folio
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            tarea.folio,
            style: theme.textTheme.labelMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Título
        Text(
          tarea.titulo,
          style:
              (isWide
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleLarge)
                  ?.copyWith(fontWeight: FontWeight.bold),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),

        // Badges
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _badge(tarea.status.label, statusColor, theme),
            _badge(
              tarea.prioridad.label,
              _prioridadColor(tarea.prioridad),
              theme,
            ),
            if (isArchived) _badge('Archivada', theme.colorScheme.error, theme),
          ],
        ),

        // Deadline
        if (tarea.fechaEntrega != null && tarea.isActive) ...[
          const SizedBox(height: 10),
          _DeadlineIndicator(fecha: tarea.fechaEntrega!),
        ],

        // Texto motivacional
        const SizedBox(height: 10),
        Text(
          _motivationalText(tarea),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );

    // Botones de acción
    final actions = _buildActions(context, theme);

    return Container(
      padding: EdgeInsets.all(isWide ? 24 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: isArchived ? 0.03 : 0.08),
            statusColor.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(
          color: statusColor.withValues(alpha: isArchived ? 0.1 : 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              progressWidget,
              SizedBox(width: isWide ? 24 : 16),
              Expanded(child: textContent),
            ],
          ),
          if (actions != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            actions,
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget? _buildActions(BuildContext context, ThemeData theme) {
    final isArchived = !tarea.isActive;

    if (isArchived) {
      if (!canArchive) return null;
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: isLoading ? null : onRestore,
          icon: const Icon(Icons.unarchive_outlined),
          label: const Text('Restaurar tarea'),
        ),
      );
    }

    final buttons = <Widget>[];

    if (canInteract) {
      switch (tarea.status) {
        case TareaStatus.pendiente:
          buttons.addAll([
            _ActionButton(
              icon: Icons.play_arrow_outlined,
              label: 'Iniciar',
              color: const Color(0xFF42A5F5),
              onPressed: isLoading
                  ? null
                  : () => onUpdateStatus(TareaStatus.enProgreso),
            ),
            _ActionButton(
              icon: Icons.check_circle_outline,
              label: 'Completar',
              color: const Color(0xFF4CAF50),
              onPressed: isLoading
                  ? null
                  : () => onUpdateStatus(TareaStatus.completada),
            ),
            _ActionButton(
              icon: Icons.cancel_outlined,
              label: 'Cancelar',
              color: const Color(0xFF9E9E9E),
              onPressed: isLoading
                  ? null
                  : () => onUpdateStatus(TareaStatus.cancelada),
            ),
          ]);
        case TareaStatus.enProgreso:
          buttons.addAll([
            _ActionButton(
              icon: Icons.pause_outlined,
              label: 'Pendiente',
              color: const Color(0xFFFFC107),
              onPressed: isLoading
                  ? null
                  : () => onUpdateStatus(TareaStatus.pendiente),
            ),
            _ActionButton(
              icon: Icons.check_circle_outline,
              label: 'Completar',
              color: const Color(0xFF4CAF50),
              onPressed: isLoading
                  ? null
                  : () => onUpdateStatus(TareaStatus.completada),
            ),
            _ActionButton(
              icon: Icons.cancel_outlined,
              label: 'Cancelar',
              color: const Color(0xFF9E9E9E),
              onPressed: isLoading
                  ? null
                  : () => onUpdateStatus(TareaStatus.cancelada),
            ),
          ]);
        case TareaStatus.completada:
          if (canArchive) {
            buttons.add(
              _ActionButton(
                icon: Icons.replay_outlined,
                label: 'Reabrir',
                color: const Color(0xFFFFC107),
                onPressed: isLoading
                    ? null
                    : () => onUpdateStatus(TareaStatus.pendiente),
              ),
            );
          }
        case TareaStatus.cancelada:
          if (canArchive) {
            buttons.add(
              _ActionButton(
                icon: Icons.replay_outlined,
                label: 'Reabrir',
                color: const Color(0xFFFFC107),
                onPressed: isLoading
                    ? null
                    : () => onUpdateStatus(TareaStatus.pendiente),
              ),
            );
          }
      }
    }

    final canArchiveThis =
        canArchive &&
        (tarea.status == TareaStatus.completada ||
            tarea.status == TareaStatus.cancelada);
    if (canArchiveThis) {
      buttons.add(
        _ActionButton(
          icon: Icons.inventory_2_outlined,
          label: 'Archivar',
          color: theme.colorScheme.error,
          onPressed: isLoading ? null : onArchive,
        ),
      );
    }

    if (buttons.isEmpty) return null;

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  static Color _statusColor(TareaStatus s) => switch (s) {
    TareaStatus.pendiente => const Color(0xFFFFC107),
    TareaStatus.enProgreso => const Color(0xFF42A5F5),
    TareaStatus.completada => const Color(0xFF4CAF50),
    TareaStatus.cancelada => const Color(0xFF9E9E9E),
  };

  static Color _prioridadColor(TareaPrioridad p) => switch (p) {
    TareaPrioridad.baja => const Color(0xFF4CAF50),
    TareaPrioridad.media => const Color(0xFFFFC107),
    TareaPrioridad.alta => const Color(0xFFFF9800),
    TareaPrioridad.urgente => const Color(0xFFD32F2F),
  };

  static IconData _statusIcon(TareaStatus s) => switch (s) {
    TareaStatus.pendiente => Icons.hourglass_empty,
    TareaStatus.enProgreso => Icons.trending_up,
    TareaStatus.completada => Icons.check,
    TareaStatus.cancelada => Icons.close,
  };

  static String _motivationalText(Tarea tarea) {
    if (!tarea.isActive) return 'Esta tarea está archivada';
    final done = tarea.subtareas.where((s) => s.completada).length;
    final total = tarea.subtareas.length;

    switch (tarea.status) {
      case TareaStatus.completada:
        return '¡Tarea completada con éxito!';
      case TareaStatus.cancelada:
        return 'Esta tarea fue cancelada';
      case TareaStatus.pendiente:
        if (total == 0) return 'Lista para comenzar';
        if (done > 0) return '$done de $total subtareas listas';
        return '$total subtareas por completar';
      case TareaStatus.enProgreso:
        if (total == 0) return 'Tarea en progreso';
        if (done == total) return '¡Todas las subtareas completadas!';
        if (done >= total * 0.7) return '¡Ya casi! $done de $total subtareas';
        if (done > 0) return '¡Buen avance! $done de $total subtareas';
        return 'Comienza con las subtareas';
    }
  }
}

// ── Progress Ring Painter ────────────────────────────────

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      trackColor != oldDelegate.trackColor ||
      progressColor != oldDelegate.progressColor;
}

// ── Deadline Indicator ───────────────────────────────────

class _DeadlineIndicator extends StatelessWidget {
  const _DeadlineIndicator({required this.fecha});

  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(fecha.year, fecha.month, fecha.day);
    final days = target.difference(today).inDays;

    late final Color color;
    late final String text;

    if (days < 0) {
      color = const Color(0xFFD32F2F);
      text = 'Vencida hace ${-days} día${days == -1 ? '' : 's'}';
    } else if (days == 0) {
      color = const Color(0xFFD32F2F);
      text = 'Vence hoy';
    } else if (days <= 2) {
      color = const Color(0xFFFF9800);
      text = '$days día${days == 1 ? '' : 's'} restante${days == 1 ? '' : 's'}';
    } else if (days <= 7) {
      color = const Color(0xFFFFC107);
      text = '$days días restantes';
    } else {
      color = const Color(0xFF4CAF50);
      text = '$days días restantes';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Action Button ────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
    );
  }
}

// ── Subtareas Checklist ──────────────────────────────────

class _SubtareasChecklist extends ConsumerWidget {
  const _SubtareasChecklist({required this.tarea, required this.canInteract});

  final Tarea tarea;
  final bool canInteract;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtareas = tarea.subtareas;
    final completedCount = subtareas.where((s) => s.completada).length;
    final total = subtareas.length;
    final progress = total > 0 ? completedCount / total : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'SUBTAREAS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '$completedCount / $total',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.1,
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 24),
            ...subtareas.map((sub) {
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: sub.completada,
                onChanged: canInteract
                    ? (value) {
                        final repo = ref.read(tareaRepositoryProvider);
                        repo.toggleSubtarea(tarea.id, sub.id, value ?? false);
                      }
                    : null,
                title: Text(
                  sub.titulo,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: sub.completada
                        ? TextDecoration.lineThrough
                        : null,
                    color: sub.completada
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Description Card ─────────────────────────────────────

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.descripcion});

  final String descripcion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DESCRIPCIÓN',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 16),
            RichTextViewer(markdown: descripcion),
          ],
        ),
      ),
    );
  }
}

// ── Details Card ─────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.tarea});

  final Tarea tarea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fechaStr = tarea.fechaEntrega != null
        ? DateFormat('dd/MM/yyyy').format(tarea.fechaEntrega!)
        : 'Sin fecha definida';
    final creadoStr = tarea.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(tarea.createdAt!)
        : '—';
    final actualizadoStr = tarea.updatedAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(tarea.updatedAt!)
        : '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INFORMACIÓN',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            _InfoRow(label: 'Proyecto', value: tarea.projectName),
            if (tarea.moduleName != null && tarea.moduleName!.isNotEmpty)
              _InfoRow(label: 'Módulo', value: tarea.moduleName!),
            _InfoRow(
              label: 'Asignado a',
              value: tarea.assignedToName ?? 'Sin asignar',
            ),
            _InfoRow(label: 'Fecha entrega', value: fechaStr),
            _InfoRow(label: 'Creado por', value: tarea.createdByName),
            _InfoRow(label: 'Creado', value: creadoStr),
            _InfoRow(label: 'Actualizado', value: actualizadoStr),
          ],
        ),
      ),
    );
  }
}

// ── Adjuntos Card ────────────────────────────────────────

class _AdjuntosCard extends StatelessWidget {
  const _AdjuntosCard({required this.adjuntos});

  final List<String> adjuntos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ADJUNTOS',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: adjuntos.map((url) {
                final isImage = RegExp(
                  r'\.(jpg|jpeg|png|gif|webp)',
                  caseSensitive: false,
                ).hasMatch(url);
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FileViewerScreen(
                        url: url,
                        fileName: Uri.decodeFull(
                          url.split('/').last.split('?').first,
                        ),
                      ),
                    ),
                  ),
                  child: isImage
                      ? StorageImage(
                          url: url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(8),
                        )
                      : Chip(
                          avatar: const Icon(Icons.attach_file, size: 16),
                          label: Text(
                            Uri.decodeFull(
                              url.split('/').last.split('?').first,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── References Card ──────────────────────────────────────

class _ReferencesCard extends StatelessWidget {
  const _ReferencesCard({required this.tarea, required this.projectId});

  final Tarea tarea;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REFERENCIAS',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 16),

            for (final ticketId in tarea.refTickets)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.confirmation_num_outlined, size: 20),
                title: ResolvedRefText(
                  id: ticketId,
                  type: RefType.ticket,
                  showTitle: true,
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () =>
                    context.push('/projects/$projectId/tickets/$ticketId'),
              ),

            for (final reqId in tarea.refRequerimientos)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.assignment_outlined, size: 20),
                title: ResolvedRefText(
                  id: reqId,
                  type: RefType.requerimiento,
                  showTitle: true,
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () =>
                    context.push('/projects/$projectId/requirements/$reqId'),
              ),

            for (final minutaId in tarea.refMinutas)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined, size: 20),
                title:
                    tarea.refCompromisoNumero != null &&
                        minutaId == tarea.refMinutas.first
                    ? Row(
                        children: [
                          Flexible(
                            child: ResolvedRefText(
                              id: minutaId,
                              type: RefType.minuta,
                            ),
                          ),
                          Text(
                            ' (compromiso #${tarea.refCompromisoNumero})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : ResolvedRefText(
                        id: minutaId,
                        type: RefType.minuta,
                        showTitle: true,
                      ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () =>
                    context.push('/projects/$projectId/minutas/$minutaId'),
              ),

            for (final citaId in tarea.refCitas)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined, size: 20),
                title: ResolvedRefText(
                  id: citaId,
                  type: RefType.cita,
                  showTitle: true,
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => context.push('/projects/$projectId/citas/$citaId'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Etiquetas Card ────────────────────────────────────────────

class _TareaEtiquetasCard extends ConsumerWidget {
  const _TareaEtiquetasCard({required this.etiquetaIds});
  final List<String> etiquetaIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final etiquetasAsync = ref.watch(
      etiquetasByIdsProvider(([...etiquetaIds]..sort()).join(',')),
    );
    final etiquetas = etiquetasAsync.value ?? [];
    if (etiquetas.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ETIQUETAS',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: etiquetas
                  .map((e) => EtiquetaChip(etiqueta: e))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info Row ─────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
