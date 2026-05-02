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
import 'package:astro/features/etiquetas/providers/etiqueta_providers.dart';
import 'package:astro/features/etiquetas/presentation/widgets/etiqueta_chip.dart';

/// Pantalla global de tareas (cross-proyecto) para la navegación principal.
class TareasGlobalScreen extends ConsumerStatefulWidget {
  const TareasGlobalScreen({super.key});

  @override
  ConsumerState<TareasGlobalScreen> createState() => _TareasGlobalScreenState();
}

class _TareasGlobalScreenState extends ConsumerState<TareasGlobalScreen>
    with SingleTickerProviderStateMixin {
  String _search = '';
  TareaStatus? _statusFilter;
  TareaPrioridad? _prioridadFilter;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TareaConProyecto> _applyFilters(List<TareaConProyecto> items) {
    return items.where((item) {
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = ref.watch(authStateProvider).value?.uid;
    final allTareas = ref.watch(myAllTareasProvider);
    final projects = ref.watch(myProjectsProvider);
    final canArchive = ref.watch(canArchiveAnyProvider);
    final canSeeOthers = ref.watch(canSeeOthersTasksProvider);

    // Separar: mis tareas vs tareas de compañeros
    final myTareas = _applyFilters(
      allTareas.where((t) => t.tarea.assignedToUid == uid).toList(),
    );
    final othersTareas = canSeeOthers
        ? _applyFilters(
            allTareas.where((t) => t.tarea.assignedToUid != uid).toList(),
          )
        : <TareaConProyecto>[];

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
        bottom: canSeeOthers
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Mis tareas'),
                  Tab(text: 'Compañeros'),
                ],
              )
            : null,
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
                        color: statusColor(s),
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
                        color: prioridadColor(p),
                      ),
                    ),
                ],
              ),
            ),

            // Contenido con tabs
            if (canSeeOthers)
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ProjectGroupedTareaList(
                      items: myTareas,
                      canArchive: canArchive,
                      onBulkArchive: _bulkArchiveTareas,
                      emptyMessage: 'No tienes tareas asignadas',
                    ),
                    _ProjectGroupedTareaList(
                      items: othersTareas,
                      canArchive: canArchive,
                      onBulkArchive: _bulkArchiveTareas,
                      emptyMessage: 'No hay tareas de compañeros',
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: _ProjectGroupedTareaList(
                  items: myTareas,
                  canArchive: canArchive,
                  onBulkArchive: _bulkArchiveTareas,
                  emptyMessage: 'No hay tareas',
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

  Future<void> _showProjectPicker(
    BuildContext context,
    List<dynamic> projects,
  ) async {
    if (projects.length == 1) {
      final p = projects.first;
      context.push('/projects/${p.id}/tareas/new');
      return;
    }

    // Ordenar por nombre A → Z una sola vez.
    final sorted = [...projects]
      ..sort(
        (a, b) => a.nombreProyecto.toLowerCase().compareTo(
          b.nombreProyecto.toLowerCase(),
        ),
      );

    // Retorna el ID del proyecto seleccionado. La navegación ocurre
    // DESPUÉS del await, cuando el sheet ya terminó de cerrarse.
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      // removeViewInsets evita que el sheet se redimensione al aparecer
      // el teclado, cortando el flood de viewport-metrics que causaba ANR.
      builder: (ctx) => MediaQuery.removeViewInsets(
        removeBottom: true,
        context: ctx,
        child: _ProjectPickerSheet(projects: sorted),
      ),
    );

    if (selectedId != null && context.mounted) {
      context.push('/projects/$selectedId/tareas/new');
    }
  }

  Future<void> _bulkArchiveTareas(
    List<TareaConProyecto> tareas,
    String statusLabel,
  ) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.archive_rounded, size: 36),
        title: Text('Archivar tareas $statusLabel'),
        content: Text(
          '¿Archivar las ${tareas.length} tarea(s) $statusLabel?\n\n'
          'Podrás restaurarlas desde la sección de archivadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.archive_rounded, size: 18),
            label: Text('Archivar ${tareas.length}'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = ref.read(tareaRepositoryProvider);
    for (final item in tareas) {
      await repo.archive(item.tarea.id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tareas.length} tarea(s) archivada(s)')),
      );
    }
  }

  static Color statusColor(TareaStatus s) => switch (s) {
    TareaStatus.pendiente => const Color(0xFFFFC107),
    TareaStatus.enProgreso => const Color(0xFF42A5F5),
    TareaStatus.completada => const Color(0xFF4CAF50),
    TareaStatus.cancelada => const Color(0xFF9E9E9E),
  };

  static Color prioridadColor(TareaPrioridad p) => switch (p) {
    TareaPrioridad.baja => const Color(0xFF4CAF50),
    TareaPrioridad.media => const Color(0xFFFFC107),
    TareaPrioridad.alta => const Color(0xFFFF9800),
    TareaPrioridad.urgente => const Color(0xFFD32F2F),
  };
}

// ── Project picker sheet ─────────────────────────────────

class _ProjectPickerSheet extends StatefulWidget {
  const _ProjectPickerSheet({required this.projects});

  final List<dynamic> projects;

  @override
  State<_ProjectPickerSheet> createState() => _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends State<_ProjectPickerSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase().trim();
    final filtered = query.isEmpty
        ? widget.projects
        : widget.projects
              .where(
                (p) =>
                    p.nombreProyecto.toLowerCase().contains(query) ||
                    p.fkEmpresa.toLowerCase().contains(query),
              )
              .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Focus trap: captura el foco inicial para que el teclado
            // NO se abra automáticamente al aparecer el sheet.
            const Focus(autofocus: true, child: SizedBox.shrink()),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Selecciona un proyecto',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar proyecto...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Limpiar',
                          onPressed: () =>
                              setState(() => _searchController.clear()),
                        )
                      : null,
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Divider(),
            Flexible(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Sin resultados')),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        return ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(p.nombreProyecto),
                          subtitle: Text(p.fkEmpresa),
                          onTap: () => Navigator.pop(context, p.id as String),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
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

// ── Global tarea tile ────────────────────────────────────

class _GlobalTareaTile extends ConsumerWidget {
  const _GlobalTareaTile({
    required this.tarea,
    required this.projectId,
    required this.projectName,
  });

  final Tarea tarea;
  final String projectId;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusColor = _TareasGlobalScreenState.statusColor(tarea.status);
    final prioridadColor = _TareasGlobalScreenState.prioridadColor(
      tarea.prioridad,
    );
    final projColor = _projectColor(projectId);

    final fechaStr = tarea.fechaEntrega != null
        ? DateFormat('dd/MM/yyyy').format(tarea.fechaEntrega!)
        : null;

    // Deadline urgency
    final deadlineInfo = _deadlineLabel(tarea.fechaEntrega, tarea.status);

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
                  height: 56,
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
                      // Título
                      Text(
                        tarea.titulo,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // Proyecto (con color) + folio
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: projColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '$projectName • ${tarea.folio}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: projColor,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                              color:
                                  deadlineInfo?.color ??
                                  theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              deadlineInfo?.label ?? fechaStr,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    deadlineInfo?.color ??
                                    theme.colorScheme.onSurfaceVariant,
                                fontWeight: deadlineInfo != null
                                    ? FontWeight.w600
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Etiquetas
                      if (tarea.etiquetaIds.isNotEmpty)
                        Builder(
                          builder: (_) {
                            final idsKey = tarea.etiquetaIds.join(',');
                            final etiquetas =
                                ref
                                    .watch(etiquetasByIdsProvider(idsKey))
                                    .value ??
                                [];
                            if (etiquetas.isEmpty)
                              return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: EtiquetasRow(
                                etiquetas: etiquetas,
                                compact: true,
                                maxVisible: 3,
                              ),
                            );
                          },
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
    final statusColor = _TareasGlobalScreenState.statusColor(tarea.status);
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

// ── Agrupación por tiempo ────────────────────────────────

enum _TimeGroup {
  overdue('Vencidas', Icons.warning_amber_rounded, Color(0xFFD32F2F)),
  today('Hoy', Icons.today, Color(0xFFFF9800)),
  tomorrow('Mañana', Icons.event, Color(0xFFFFC107)),
  thisWeek('Esta semana', Icons.date_range, Color(0xFF42A5F5)),
  upcoming('Próximamente', Icons.event_note, Color(0xFF66BB6A)),
  noDate('Sin fecha', Icons.event_busy, Color(0xFF9E9E9E)),
  completed('Completadas', Icons.task_alt, Color(0xFF4CAF50)),
  cancelled('Canceladas', Icons.cancel_outlined, Color(0xFF9E9E9E));

  const _TimeGroup(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

Map<_TimeGroup, List<TareaConProyecto>> _groupByTime(
  List<TareaConProyecto> items,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final daysUntilSunday = DateTime.sunday - today.weekday;
  final endOfWeek = today.add(
    Duration(days: daysUntilSunday > 0 ? daysUntilSunday : 7),
  );

  final groups = <_TimeGroup, List<TareaConProyecto>>{};

  for (final item in items) {
    final fecha = item.tarea.fechaEntrega;
    final status = item.tarea.status;

    // Completadas y canceladas van a sus secciones propias
    if (status == TareaStatus.completada) {
      (groups[_TimeGroup.completed] ??= []).add(item);
      continue;
    }
    if (status == TareaStatus.cancelada) {
      (groups[_TimeGroup.cancelled] ??= []).add(item);
      continue;
    }

    _TimeGroup group;
    if (fecha == null) {
      group = _TimeGroup.noDate;
    } else {
      final d = DateTime(fecha.year, fecha.month, fecha.day);
      if (d.isBefore(today)) {
        group = _TimeGroup.overdue;
      } else if (d.isAtSameMomentAs(today)) {
        group = _TimeGroup.today;
      } else if (d.isAtSameMomentAs(tomorrow)) {
        group = _TimeGroup.tomorrow;
      } else if (d.isBefore(endOfWeek) || d.isAtSameMomentAs(endOfWeek)) {
        group = _TimeGroup.thisWeek;
      } else {
        group = _TimeGroup.upcoming;
      }
    }

    (groups[group] ??= []).add(item);
  }

  return groups;
}

/// Lista agrupada por proyecto, con sub-agrupación temporal.
class _ProjectGroupedTareaList extends StatelessWidget {
  const _ProjectGroupedTareaList({
    required this.items,
    required this.canArchive,
    required this.onBulkArchive,
    required this.emptyMessage,
  });

  final List<TareaConProyecto> items;
  final bool canArchive;
  final void Function(List<TareaConProyecto> items, String statusLabel)
  onBulkArchive;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('0 tareas', style: theme.textTheme.bodySmall),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emptyMessage,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Agrupar por proyecto
    final byProject = <String, List<TareaConProyecto>>{};
    for (final item in items) {
      (byProject[item.projectId] ??= []).add(item);
    }

    // Ordenar proyectos alfabéticamente
    final sortedEntries = byProject.entries.toList()
      ..sort(
        (a, b) =>
            a.value.first.projectName.compareTo(b.value.first.projectName),
      );

    final widgets = <Widget>[];

    for (final entry in sortedEntries) {
      final projectId = entry.key;
      final projectTareas = entry.value;
      final projectName = projectTareas.first.projectName;
      final projColor = _projectColor(projectId);

      // Header de proyecto
      widgets.add(
        _ProjectSectionHeader(
          projectName: projectName,
          count: projectTareas.length,
          color: projColor,
        ),
      );

      // Sub-grupos de tiempo dentro del proyecto
      final timeGroups = _groupByTime(projectTareas);
      for (final group in _TimeGroup.values) {
        final tareas = timeGroups[group];
        if (tareas == null || tareas.isEmpty) continue;

        final showArchiveBtn =
            canArchive &&
            (group == _TimeGroup.completed || group == _TimeGroup.cancelled);

        // Sub-header temporal (indentado bajo el proyecto)
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 16, 4),
            child: Row(
              children: [
                Icon(group.icon, size: 14, color: group.color),
                const SizedBox(width: 5),
                Text(
                  group.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: group.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: group.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${tareas.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: group.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (showArchiveBtn) ...[
                  const Spacer(),
                  _BulkArchiveButton(
                    count: tareas.length,
                    statusLabel: group.label.toLowerCase(),
                    onPressed: () =>
                        onBulkArchive(tareas, group.label.toLowerCase()),
                  ),
                ],
              ],
            ),
          ),
        );

        for (final item in tareas) {
          widgets.add(
            _GlobalTareaTile(
              tarea: item.tarea,
              projectId: item.projectId,
              projectName: item.projectName,
            ),
          );
        }
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${items.length} tarea${items.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: widgets,
          ),
        ),
      ],
    );
  }
}

class _ProjectSectionHeader extends StatelessWidget {
  const _ProjectSectionHeader({
    required this.projectName,
    required this.count,
    required this.color,
  });

  final String projectName;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              projectName,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón de archivado masivo ────────────────────────────

class _BulkArchiveButton extends StatelessWidget {
  const _BulkArchiveButton({
    required this.count,
    required this.onPressed,
    required this.statusLabel,
  });

  final int count;
  final VoidCallback onPressed;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.archive_rounded, size: 16),
      label: Text(
        'Archivar $count',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}

// ── Color de proyecto (paleta determinista) ──────────────

const _kProjectPalette = [
  Color(0xFF42A5F5), // Blue
  Color(0xFFAB47BC), // Purple
  Color(0xFF26A69A), // Teal
  Color(0xFFEF5350), // Red
  Color(0xFFFF7043), // Deep Orange
  Color(0xFF66BB6A), // Green
  Color(0xFFFFA726), // Orange
  Color(0xFF78909C), // Blue Grey
  Color(0xFFEC407A), // Pink
  Color(0xFF5C6BC0), // Indigo
];

Color _projectColor(String projectId) {
  return _kProjectPalette[projectId.hashCode.abs() % _kProjectPalette.length];
}

// ── Deadline label helper ────────────────────────────────

({String label, Color color})? _deadlineLabel(
  DateTime? fecha,
  TareaStatus status,
) {
  if (fecha == null) return null;
  if (status == TareaStatus.completada || status == TareaStatus.cancelada) {
    return null;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(fecha.year, fecha.month, fecha.day);
  final days = d.difference(today).inDays;

  if (days < 0) {
    return (label: 'Vencida (${-days}d)', color: const Color(0xFFD32F2F));
  } else if (days == 0) {
    return (label: 'Hoy', color: const Color(0xFFFF9800));
  } else if (days == 1) {
    return (label: 'Mañana', color: const Color(0xFFFFC107));
  }
  return null;
}
