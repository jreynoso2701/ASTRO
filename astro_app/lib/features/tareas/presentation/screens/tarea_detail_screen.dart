import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/tarea.dart';
import 'package:astro/core/models/tarea_status.dart';
import 'package:astro/core/models/tarea_prioridad.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/presentation/screens/file_viewer_screen.dart';
import 'package:astro/features/tareas/providers/tarea_providers.dart';
import 'package:astro/features/minutas/data/minuta_repository.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';

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
      await repo.updateStatus(widget.tareaId, newStatus.name);

      // Sincronizar compromiso en la minuta vinculada (Gap 1).
      final tarea = ref.read(tareaByIdProvider(widget.tareaId)).value;
      if (tarea?.refMinutaId != null && tarea?.refCompromisoNumero != null) {
        final compromisoStatus = switch (newStatus) {
          TareaStatus.completada => 'cumplido',
          _ => 'pendiente',
        };
        try {
          final minutaRepo = MinutaRepository();
          await minutaRepo.updateCompromisoStatus(
            tarea!.refMinutaId!,
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
    final hasMinuta = tarea?.refMinutaId != null;

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
      await repo.restore(widget.tareaId, newStatus: newStatus.name);

      // Sincronizar compromiso en la minuta vinculada.
      final tarea = ref.read(tareaByIdProvider(widget.tareaId)).value;
      if (tarea?.refMinutaId != null && tarea?.refCompromisoNumero != null) {
        try {
          final minutaRepo = MinutaRepository();
          await minutaRepo.updateCompromisoStatus(
            tarea!.refMinutaId!,
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

          final infoSection = _TareaInfoSection(tarea: tarea);

          final actionsSection = _ActionsSection(
            tarea: tarea,
            canInteract: canInteract,
            canArchive: canArchive,
            isLoading: _isLoading,
            onUpdateStatus: _updateStatus,
            onArchive: _archiveTarea,
            onRestore: _restoreTarea,
          );

          final refsSection = _ReferencesSection(
            tarea: tarea,
            projectId: widget.projectId,
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        infoSection,
                        const SizedBox(height: 24),
                        actionsSection,
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: refsSection,
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoSection,
                const SizedBox(height: 24),
                actionsSection,
                const SizedBox(height: 24),
                refsSection,
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Actions Section ──────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.tarea,
    required this.canInteract,
    required this.canArchive,
    required this.isLoading,
    required this.onUpdateStatus,
    required this.onArchive,
    required this.onRestore,
  });

  final Tarea tarea;
  final bool canInteract;
  final bool canArchive;
  final bool isLoading;
  final ValueChanged<TareaStatus> onUpdateStatus;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArchived = !tarea.isActive;

    // Si está archivada, solo mostrar botón de restaurar (Root/Supervisor).
    if (isArchived) {
      if (!canArchive) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ARCHIVADA',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 16),
              Text(
                'Esta tarea está archivada y no aparece en las listas activas.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : onRestore,
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Restaurar tarea'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Construir lista de acciones disponibles.
    final actions = <Widget>[];

    if (canInteract) {
      // Cambios de status según el status actual.
      switch (tarea.status) {
        case TareaStatus.pendiente:
          actions.add(
            _ActionButton(
              icon: Icons.play_arrow_outlined,
              label: 'Iniciar',
              color: const Color(0xFF42A5F5),
              onPressed: isLoading
                  ? null
                  : () => onUpdateStatus(TareaStatus.enProgreso),
            ),
          );
          actions.add(
            _ActionButton(
              icon: Icons.check_circle_outline,
              label: 'Completar',
              color: const Color(0xFF4CAF50),
              onPressed: isLoading
                  ? null
                  : () => onUpdateStatus(TareaStatus.completada),
            ),
          );
          actions.add(
            _ActionButton(
              icon: Icons.cancel_outlined,
              label: 'Cancelar',
              color: const Color(0xFF9E9E9E),
              onPressed: isLoading
                  ? null
                  : () => onUpdateStatus(TareaStatus.cancelada),
            ),
          );
        case TareaStatus.enProgreso:
          actions.add(
            _ActionButton(
              icon: Icons.pause_outlined,
              label: 'Pendiente',
              color: const Color(0xFFFFC107),
              onPressed: isLoading
                  ? null
                  : () => onUpdateStatus(TareaStatus.pendiente),
            ),
          );
          actions.add(
            _ActionButton(
              icon: Icons.check_circle_outline,
              label: 'Completar',
              color: const Color(0xFF4CAF50),
              onPressed: isLoading
                  ? null
                  : () => onUpdateStatus(TareaStatus.completada),
            ),
          );
          actions.add(
            _ActionButton(
              icon: Icons.cancel_outlined,
              label: 'Cancelar',
              color: const Color(0xFF9E9E9E),
              onPressed: isLoading
                  ? null
                  : () => onUpdateStatus(TareaStatus.cancelada),
            ),
          );
        case TareaStatus.completada:
          // Solo Root/Supervisor pueden regresar una tarea completada.
          if (canArchive) {
            actions.add(
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
          // Solo Root/Supervisor pueden regresar una tarea cancelada.
          if (canArchive) {
            actions.add(
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

    // Archivar: Root/Supervisor, solo si completada o cancelada.
    final canArchiveThis =
        canArchive &&
        (tarea.status == TareaStatus.completada ||
            tarea.status == TareaStatus.cancelada);
    if (canArchiveThis) {
      actions.add(
        _ActionButton(
          icon: Icons.inventory_2_outlined,
          label: 'Archivar',
          color: theme.colorScheme.error,
          onPressed: isLoading ? null : onArchive,
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACCIONES',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 16),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }
}

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

// ── Info Section ─────────────────────────────────────────

class _TareaInfoSection extends StatelessWidget {
  const _TareaInfoSection({required this.tarea});

  final Tarea tarea;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(tarea.status);
    final prioridadColor = _prioridadColor(tarea.prioridad);

    final fechaStr = tarea.fechaEntrega != null
        ? DateFormat('dd/MM/yyyy').format(tarea.fechaEntrega!)
        : 'Sin fecha definida';
    final creadoStr = tarea.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(tarea.createdAt!)
        : '—';
    final actualizadoStr = tarea.updatedAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(tarea.updatedAt!)
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folio + badges
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tarea.folio,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      tarea.status.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: prioridadColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: prioridadColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      tarea.prioridad.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: prioridadColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Título
        Text(
          tarea.titulo,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 16),

        // Descripción
        if (tarea.descripcion.isNotEmpty) ...[
          Text(
            'DESCRIPCIÓN',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 16),
          Text(tarea.descripcion, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
        ],

        // Info card
        Card(
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
        ),

        // Adjuntos
        if (tarea.adjuntos.isNotEmpty) ...[
          const SizedBox(height: 16),
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
            children: tarea.adjuntos.map((url) {
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
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Chip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text(
                          Uri.decodeFull(url.split('/').last.split('?').first),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ── References Section ───────────────────────────────────

class _ReferencesSection extends StatelessWidget {
  const _ReferencesSection({required this.tarea, required this.projectId});

  final Tarea tarea;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasRefs =
        tarea.refTicketId != null ||
        tarea.refRequerimientoId != null ||
        tarea.refMinutaId != null;

    if (!hasRefs) return const SizedBox.shrink();

    return Column(
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

        if (tarea.refTicketId != null)
          ListTile(
            leading: const Icon(Icons.confirmation_num_outlined),
            title: const Text('Ticket vinculado'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              '/projects/$projectId/tickets/${tarea.refTicketId}',
            ),
          ),

        if (tarea.refRequerimientoId != null)
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('Requerimiento vinculado'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              '/projects/$projectId/requirements/${tarea.refRequerimientoId}',
            ),
          ),

        if (tarea.refMinutaId != null)
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(
              tarea.refCompromisoNumero != null
                  ? 'Minuta (compromiso #${tarea.refCompromisoNumero})'
                  : 'Minuta vinculada',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              '/projects/$projectId/minutas/${tarea.refMinutaId}',
            ),
          ),
      ],
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
