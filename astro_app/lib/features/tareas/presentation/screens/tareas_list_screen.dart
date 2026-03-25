import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/tarea.dart';
import 'package:astro/core/models/tarea_status.dart';
import 'package:astro/core/models/tarea_prioridad.dart';
import 'package:astro/features/tareas/providers/tarea_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';

/// Pantalla de listado de tareas de un proyecto.
class TareasListScreen extends ConsumerWidget {
  const TareasListScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectoAsync = ref.watch(proyectoByIdProvider(projectId));

    return proyectoAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('TAREAS')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('TAREAS')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (proyecto) {
        if (proyecto == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('TAREAS')),
            body: const Center(child: Text('Proyecto no encontrado')),
          );
        }

        final projectName = proyecto.nombreProyecto;
        final tareasAsync = ref.watch(tareasByProjectProvider(projectId));
        final filteredTareas = ref.watch(filteredTareasProvider(projectId));
        final searchQuery = ref.watch(tareaSearchProvider);
        final statusFilter = ref.watch(tareaStatusFilterProvider);
        final prioridadFilter = ref.watch(tareaPrioridadFilterProvider);
        final canArchive = ref.watch(canArchiveTareaProvider(projectId));

        return Scaffold(
          appBar: AppBar(
            title: Text('TAREAS — $projectName'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (canArchive)
                IconButton(
                  icon: const Icon(Icons.inventory_2_outlined),
                  tooltip: 'Tareas archivadas',
                  onPressed: () =>
                      _showArchivedSheet(context, projectId, projectName),
                ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Nueva tarea',
                onPressed: () =>
                    context.push('/projects/$projectId/tareas/new'),
              ),
            ],
          ),
          body: tareasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (_) {
              return SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Barra de búsqueda
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar tarea...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => ref
                                      .read(tareaSearchProvider.notifier)
                                      .clear(),
                                )
                              : null,
                          isDense: true,
                        ),
                        onChanged: (v) =>
                            ref.read(tareaSearchProvider.notifier).setQuery(v),
                      ),
                    ),

                    // Filtros de estado
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _FilterChip(
                            label: 'Todos',
                            selected: statusFilter == null,
                            onSelected: (_) => ref
                                .read(tareaStatusFilterProvider.notifier)
                                .clear(),
                          ),
                          for (final s in TareaStatus.values)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _FilterChip(
                                label: s.label,
                                selected: statusFilter == s,
                                onSelected: (_) => ref
                                    .read(tareaStatusFilterProvider.notifier)
                                    .set(s),
                                color: _statusColor(s),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Filtros de prioridad
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _FilterChip(
                            label: 'Prioridad: Todas',
                            selected: prioridadFilter == null,
                            onSelected: (_) => ref
                                .read(tareaPrioridadFilterProvider.notifier)
                                .clear(),
                          ),
                          for (final p in TareaPrioridad.values)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _FilterChip(
                                label: p.label,
                                selected: prioridadFilter == p,
                                onSelected: (_) => ref
                                    .read(tareaPrioridadFilterProvider.notifier)
                                    .set(p),
                                color: _prioridadColor(p),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Contador
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${filteredTareas.length} tarea${filteredTareas.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    // Lista
                    Expanded(
                      child: filteredTareas.isEmpty
                          ? const Center(
                              child: Text('No hay tareas que mostrar'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                              itemCount: filteredTareas.length,
                              itemBuilder: (context, index) {
                                final tarea = filteredTareas[index];
                                return _TareaTile(
                                  tarea: tarea,
                                  projectId: projectId,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
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

  static void _showArchivedSheet(
    BuildContext context,
    String projectId,
    String projectName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, controller) => _ArchivedTareasSheet(
          projectId: projectId,
          projectName: projectName,
          scrollController: controller,
        ),
      ),
    );
  }
}

// ── Filter chip ──────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      side: color != null && selected ? BorderSide(color: color!) : null,
      selectedColor: color?.withValues(alpha: 0.2),
    );
  }
}

// ── Tarea tile ───────────────────────────────────────────

class _TareaTile extends StatelessWidget {
  const _TareaTile({required this.tarea, required this.projectId});

  final Tarea tarea;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = TareasListScreen._statusColor(tarea.status);
    final prioridadColor = TareasListScreen._prioridadColor(tarea.prioridad);

    final fechaStr = tarea.fechaEntrega != null
        ? DateFormat('dd/MM/yyyy').format(tarea.fechaEntrega!)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/projects/$projectId/tareas/${tarea.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Status bar
                Container(
                  width: 4,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tarea.titulo,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tarea.folio,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (tarea.assignedToName != null) ...[
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                tarea.assignedToName!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          if (fechaStr != null) ...[
                            if (tarea.assignedToName != null)
                              const SizedBox(width: 12),
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              fechaStr,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        tarea.status.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: prioridadColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: prioridadColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        tarea.prioridad.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: prioridadColor,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Archived Tareas Sheet ────────────────────────────────

class _ArchivedTareasSheet extends ConsumerStatefulWidget {
  const _ArchivedTareasSheet({
    required this.projectId,
    required this.projectName,
    required this.scrollController,
  });

  final String projectId;
  final String projectName;
  final ScrollController scrollController;

  @override
  ConsumerState<_ArchivedTareasSheet> createState() =>
      _ArchivedTareasSheetState();
}

class _ArchivedTareasSheetState extends ConsumerState<_ArchivedTareasSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final archivedAsync = ref.watch(
      archivedTareasByProjectProvider(widget.projectId),
    );

    return Column(
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Tareas archivadas — ${widget.projectName}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        const Divider(),
        // Búsqueda
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar archivada...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _search = ''),
                    )
                  : null,
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: archivedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (tareas) {
              final filtered = _search.isEmpty
                  ? tareas
                  : tareas.where((t) {
                      final q = _search.toUpperCase();
                      return t.titulo.toUpperCase().contains(q) ||
                          t.folio.toUpperCase().contains(q);
                    }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'No hay tareas archivadas',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final tarea = filtered[index];
                  return _ArchivedTareaTile(
                    tarea: tarea,
                    projectId: widget.projectId,
                    onRestore: () => _restoreTarea(tarea),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _restoreTarea(Tarea tarea) async {
    final newStatus = await showDialog<TareaStatus>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Restaurar "${tarea.titulo}"'),
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

    try {
      final repo = ref.read(tareaRepositoryProvider);
      final uid = ref.read(authStateProvider).value?.uid ?? '';
      await repo.restore(tarea.id, newStatus: newStatus.name, updatedBy: uid);
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
    }
  }
}

class _ArchivedTareaTile extends StatelessWidget {
  const _ArchivedTareaTile({
    required this.tarea,
    required this.projectId,
    required this.onRestore,
  });

  final Tarea tarea;
  final String projectId;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = TareasListScreen._statusColor(tarea.status);
    final fechaStr = tarea.updatedAt != null
        ? DateFormat('dd/MM/yyyy').format(tarea.updatedAt!)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tarea.titulo,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tarea.folio} • ${tarea.status.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (fechaStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Archivada: $fechaStr',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.unarchive_outlined),
                    tooltip: 'Restaurar',
                    onPressed: onRestore,
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    tooltip: 'Ver detalle',
                    onPressed: () =>
                        context.push('/projects/$projectId/tareas/${tarea.id}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
