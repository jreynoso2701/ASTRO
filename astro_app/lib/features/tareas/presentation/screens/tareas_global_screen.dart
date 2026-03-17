import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/tarea.dart';
import 'package:astro/core/models/tarea_status.dart';
import 'package:astro/core/models/tarea_prioridad.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/tareas/providers/tarea_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';

/// Pantalla global de tareas (cross-proyecto) para la navegación principal.
class TareasGlobalScreen extends ConsumerStatefulWidget {
  const TareasGlobalScreen({super.key});

  @override
  ConsumerState<TareasGlobalScreen> createState() => _TareasGlobalScreenState();
}

class _TareasGlobalScreenState extends ConsumerState<TareasGlobalScreen> {
  String _search = '';
  TareaStatus? _statusFilter;
  TareaPrioridad? _prioridadFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTareas = ref.watch(myAllTareasProvider);
    final projects = ref.watch(myProjectsProvider);
    final canArchive = ref.watch(canArchiveAnyProvider);

    // Filtrar localmente
    final filtered = allTareas.where((item) {
      final t = item.tarea;
      if (_statusFilter != null && t.status != _statusFilter) return false;
      if (_prioridadFilter != null && t.prioridad != _prioridadFilter) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toUpperCase();
        final matches =
            t.titulo.toUpperCase().contains(q) ||
            t.folio.toUpperCase().contains(q) ||
            t.descripcion.toUpperCase().contains(q) ||
            item.projectName.toUpperCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TAREAS'),
        actions: [
          if (canArchive)
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined),
              tooltip: 'Tareas archivadas',
              onPressed: () => _showArchivedSheet(context),
            ),
        ],
      ),
      floatingActionButton: projects.isNotEmpty
          ? FloatingActionButton(
              heroTag: 'new_tarea_fab',
              onPressed: () => _showProjectPicker(context, projects),
              tooltip: 'Nueva tarea',
              child: const Icon(Icons.add),
            )
          : null,
      body: AdaptiveBody(
        maxWidth: 960,
        child: Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar tarea...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Limpiar',
                          onPressed: () => setState(() => _search = ''),
                        )
                      : null,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
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
                    selected: _statusFilter == null,
                    onSelected: (_) => setState(() => _statusFilter = null),
                  ),
                  for (final s in TareaStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _FilterChip(
                        label: s.label,
                        selected: _statusFilter == s,
                        onSelected: (_) => setState(() => _statusFilter = s),
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
                    selected: _prioridadFilter == null,
                    onSelected: (_) => setState(() => _prioridadFilter = null),
                  ),
                  for (final p in TareaPrioridad.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _FilterChip(
                        label: p.label,
                        selected: _prioridadFilter == p,
                        onSelected: (_) => setState(() => _prioridadFilter = p),
                        color: _prioridadColor(p),
                      ),
                    ),
                ],
              ),
            ),

            // Contador
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} tarea${filtered.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // Lista
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay tareas',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _GlobalTareaTile(
                          tarea: item.tarea,
                          projectId: item.projectId,
                          projectName: item.projectName,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showArchivedSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, controller) =>
            _GlobalArchivedSheet(scrollController: controller),
      ),
    );
  }

  void _showProjectPicker(BuildContext context, List<dynamic> projects) {
    if (projects.length == 1) {
      final p = projects.first;
      context.push('/projects/${p.id}/tareas/new');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  'Selecciona un proyecto',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: projects.length,
                  itemBuilder: (_, i) {
                    final p = projects[i];
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(p.nombreProyecto),
                      subtitle: Text(p.fkEmpresa),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/projects/${p.id}/tareas/new');
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
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

// ── Global tarea tile ────────────────────────────────────

class _GlobalTareaTile extends StatelessWidget {
  const _GlobalTareaTile({
    required this.tarea,
    required this.projectId,
    required this.projectName,
  });

  final Tarea tarea;
  final String projectId;
  final String projectName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _TareasGlobalScreenState._statusColor(tarea.status);
    final prioridadColor = _TareasGlobalScreenState._prioridadColor(
      tarea.prioridad,
    );

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
                        '$projectName • ${tarea.folio}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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

// ── Global Archived Sheet ────────────────────────────────

class _GlobalArchivedSheet extends ConsumerStatefulWidget {
  const _GlobalArchivedSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_GlobalArchivedSheet> createState() =>
      _GlobalArchivedSheetState();
}

class _GlobalArchivedSheetState extends ConsumerState<_GlobalArchivedSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final archived = ref.watch(myArchivedTareasProvider);

    final filtered = _search.isEmpty
        ? archived
        : archived.where((item) {
            final q = _search.toUpperCase();
            return item.tarea.titulo.toUpperCase().contains(q) ||
                item.tarea.folio.toUpperCase().contains(q) ||
                item.projectName.toUpperCase().contains(q);
          }).toList();

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
          child: Text('Tareas archivadas', style: theme.textTheme.titleMedium),
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
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No hay tareas archivadas',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _GlobalArchivedTile(
                      tarea: item.tarea,
                      projectId: item.projectId,
                      projectName: item.projectName,
                      onRestore: () => _restoreTarea(item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _restoreTarea(TareaConProyecto item) async {
    final newStatus = await showDialog<TareaStatus>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Restaurar "${item.tarea.titulo}"'),
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
      await repo.restore(
        item.tarea.id,
        newStatus: newStatus.name,
        updatedBy: uid,
      );
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

class _GlobalArchivedTile extends StatelessWidget {
  const _GlobalArchivedTile({
    required this.tarea,
    required this.projectId,
    required this.projectName,
    required this.onRestore,
  });

  final Tarea tarea;
  final String projectId;
  final String projectName;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _TareasGlobalScreenState._statusColor(tarea.status);
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
                      '$projectName • ${tarea.folio} • ${tarea.status.label}',
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
