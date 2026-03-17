import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/requerimiento_status.dart';
import 'package:astro/core/models/requerimiento_tipo.dart';
import 'package:astro/core/models/requerimiento_comment.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/requirements/presentation/widgets/req_kanban_board.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/core/widgets/adaptive_body.dart';

/// Pantalla de listado de requerimientos de un proyecto.
/// En móvil muestra lista; en pantallas anchas, tablero Kanban.
class RequerimientoListScreen extends ConsumerStatefulWidget {
  const RequerimientoListScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<RequerimientoListScreen> createState() =>
      _RequerimientoListScreenState();
}

class _RequerimientoListScreenState
    extends ConsumerState<RequerimientoListScreen> {
  /// null = auto (list on mobile, kanban on wide).
  bool? _forceKanban;

  bool _isKanban(double width) {
    if (_forceKanban != null) return _forceKanban!;
    return width >= AppBreakpoints.medium;
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final proyectoAsync = ref.watch(proyectoByIdProvider(widget.projectId));
    final projectId = widget.projectId;

    return proyectoAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('REQUERIMIENTOS')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('REQUERIMIENTOS')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (proyecto) {
        if (proyecto == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('REQUERIMIENTOS')),
            body: const Center(child: Text('Proyecto no encontrado')),
          );
        }

        final projectName = proyecto.nombreProyecto;
        final reqsAsync = ref.watch(
          requerimientosByProjectProvider(projectName),
        );
        final filteredReqs = ref.watch(
          filteredRequerimientosProvider(projectId),
        );
        final searchQuery = ref.watch(reqSearchProvider);
        final statusFilter = ref.watch(reqStatusFilterProvider);
        final tipoFilter = ref.watch(reqTipoFilterProvider);
        final canArchive = ref.watch(canArchiveReqProvider(projectId));
        final width = MediaQuery.sizeOf(context).width;
        final kanban = _isKanban(width);

        return Scaffold(
          appBar: AppBar(
            title: Text('REQUERIMIENTOS — $projectName'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              // Archivados (Root + Supervisor)
              if (canArchive)
                IconButton(
                  icon: const Icon(Icons.inventory_2_outlined),
                  tooltip: 'Requerimientos archivados',
                  onPressed: () =>
                      _showArchivedSheet(context, projectId, projectName),
                ),
              // Toggle vista
              IconButton(
                icon: Icon(
                  kanban ? Icons.view_list_rounded : Icons.view_kanban_rounded,
                ),
                tooltip: kanban ? 'Vista lista' : 'Vista Kanban',
                onPressed: () => setState(() => _forceKanban = !kanban),
              ),
              // Crear requerimiento
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Nuevo requerimiento',
                onPressed: () =>
                    context.push('/projects/$projectId/requirements/new'),
              ),
            ],
          ),
          body: reqsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (_) {
              return Column(
                children: [
                  // Búsqueda
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar requerimiento...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => ref
                                    .read(reqSearchProvider.notifier)
                                    .clear(),
                              )
                            : null,
                        isDense: true,
                      ),
                      onChanged: (v) =>
                          ref.read(reqSearchProvider.notifier).setQuery(v),
                    ),
                  ),

                  // Filtros de estado — solo en modo lista
                  if (!kanban)
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
                                .read(reqStatusFilterProvider.notifier)
                                .clear(),
                          ),
                          for (final s in RequerimientoStatus.values)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _FilterChip(
                                label: s.label,
                                selected: statusFilter == s,
                                onSelected: (_) => ref
                                    .read(reqStatusFilterProvider.notifier)
                                    .set(s),
                                color: _statusColor(s),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Filtros de tipo
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _FilterChip(
                          label: 'Tipo: Todos',
                          selected: tipoFilter == null,
                          onSelected: (_) =>
                              ref.read(reqTipoFilterProvider.notifier).clear(),
                        ),
                        for (final t in RequerimientoTipo.values)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _FilterChip(
                              label: t.label,
                              selected: tipoFilter == t,
                              onSelected: (_) => ref
                                  .read(reqTipoFilterProvider.notifier)
                                  .set(t),
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
                          '${filteredReqs.length} requerimiento${filteredReqs.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  // Contenido: Kanban o Lista
                  Expanded(
                    child: kanban
                        ? _buildKanban(context, filteredReqs, projectId)
                        : _buildList(context, filteredReqs, projectId),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ── Kanban view ──

  Widget _buildKanban(
    BuildContext context,
    List<Requerimiento> reqs,
    String projectId,
  ) {
    return ReqKanbanBoard(
      requerimientos: reqs,
      onReqTap: (req) =>
          context.push('/projects/$projectId/requirements/${req.id}'),
      onStatusChange: (req, newStatus) async {
        final repo = ref.read(requerimientoRepositoryProvider);
        final profile = ref.read(currentUserProfileProvider).value;
        await repo.updateStatus(
          req.id,
          newStatus,
          updatedBy: profile?.uid ?? '',
        );
        if (profile != null) {
          await repo.addComment(
            req.id,
            RequerimientoComment(
              id: '',
              text:
                  'Cambió estado de "${req.status.label}" a "${newStatus.label}"',
              authorId: profile.uid,
              authorName: profile.displayName,
              type: ReqCommentType.statusChange,
              createdAt: DateTime.now(),
            ),
          );
        }
      },
    );
  }

  // ── List view ──

  Widget _buildList(
    BuildContext context,
    List<Requerimiento> reqs,
    String projectId,
  ) {
    if (reqs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin requerimientos',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return AdaptiveBody(
      maxWidth: 960,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: reqs.length,
        itemBuilder: (context, index) {
          final req = reqs[index];
          return _ReqCard(
            req: req,
            onTap: () =>
                context.push('/projects/$projectId/requirements/${req.id}'),
          );
        },
      ),
    );
  }

  // ── Bottom sheet de requerimientos archivados ──

  void _showArchivedSheet(
    BuildContext context,
    String projectId,
    String projectName,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _ArchivedReqsSheet(
          projectId: projectId,
          projectName: projectName,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

// ── Requerimiento Card ───────────────────────────────────

class _ReqCard extends StatelessWidget {
  const _ReqCard({required this.req, required this.onTap});

  final Requerimiento req;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final divider = Divider(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
      height: 20,
    );
    final pct = req.porcentajeCalculado;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Folio + Estado
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Folio:  ${req.folio}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _StatusBadge(status: req.status),
                ],
              ),
              const SizedBox(height: 8),

              // Título
              Text(
                req.titulo,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Info
              _InfoLine(label: 'Tipo', value: req.tipo.label),
              if (req.moduleName != null && req.moduleName!.isNotEmpty)
                _InfoLine(label: 'Módulo', value: req.moduleName!),
              if (req.moduloPropuesto != null &&
                  req.moduloPropuesto!.isNotEmpty)
                _InfoLine(
                  label: 'Módulo propuesto',
                  value: req.moduloPropuesto!,
                ),
              if (req.faseAsignada != null)
                _InfoLine(label: 'Fase', value: req.faseAsignada!.label),
              if (req.empresaName != null && req.empresaName!.isNotEmpty)
                _InfoLine(label: 'Empresa', value: req.empresaName!),

              divider,

              // Prioridad + Criterios
              Row(
                children: [
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.priority_high,
                      label: 'Prioridad:',
                      value: req.prioridad.label,
                    ),
                  ),
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.checklist,
                      label: 'Criterios:',
                      value:
                          '${req.criteriosAceptacion.where((c) => c.completado).length}'
                          '/${req.criteriosAceptacion.length}',
                    ),
                  ),
                ],
              ),

              divider,

              // Fechas
              Row(
                children: [
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.note_alt_outlined,
                      label: 'Creado:',
                      value: _formatDate(req.createdAt),
                    ),
                  ),
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.fast_forward,
                      label: 'Actualización:',
                      value: _formatDate(req.updatedAt),
                    ),
                  ),
                ],
              ),

              divider,

              // Reportó + Responsable
              Row(
                children: [
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.person_outline,
                      label: 'Solicitó:',
                      value: req.createdByName,
                    ),
                  ),
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.engineering_outlined,
                      label: 'Responsable:',
                      value: req.assignedToName ?? 'Sin asignar',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Barra inferior: avance + botón detalle
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: pct / 100,
                          strokeWidth: 3,
                          backgroundColor: muted.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(
                            progressColor(pct),
                          ),
                        ),
                        Text(
                          '${pct.toInt()}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: progressColor(pct),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Ver detalle'),
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

// ── Widgets auxiliares ───────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final RequerimientoStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor(status).withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _statusColor(status),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: muted),
              ),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
      selectedColor: color?.withValues(alpha: 0.2),
      side: selected && color != null
          ? BorderSide(color: color!.withValues(alpha: 0.5))
          : null,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Helpers ──────────────────────────────────────────────

Color _statusColor(RequerimientoStatus status) => switch (status) {
  RequerimientoStatus.propuesto => const Color(0xFF90A4AE),
  RequerimientoStatus.enRevision => const Color(0xFF42A5F5),
  RequerimientoStatus.enDesarrollo => const Color(0xFFFFC107),
  RequerimientoStatus.implementado => const Color(0xFF4CAF50),
  RequerimientoStatus.completado => const Color(0xFF388E3C),
  RequerimientoStatus.descartado => const Color(0xFFEF5350),
};

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.day}/${date.month}/${date.year}';
}

// ── Archived Reqs Sheet ──────────────────────────────────

class _ArchivedReqsSheet extends ConsumerStatefulWidget {
  const _ArchivedReqsSheet({
    required this.projectId,
    required this.projectName,
    required this.scrollController,
  });

  final String projectId;
  final String projectName;
  final ScrollController scrollController;

  @override
  ConsumerState<_ArchivedReqsSheet> createState() => _ArchivedReqsSheetState();
}

class _ArchivedReqsSheetState extends ConsumerState<_ArchivedReqsSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const archiveColor = Color(0xFF9E9E9E);

    final archivedAsync = ref.watch(
      archivedReqsByProjectProvider(widget.projectId),
    );

    return Column(
      children: [
        // ── Drag handle ──
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // ── Header ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: archiveColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Requerimientos Archivados',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              archivedAsync.when(
                data: (list) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: archiveColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${list.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: archiveColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // ── Búsqueda ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por folio, título...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _search = ''),
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),

        const SizedBox(height: 8),
        const Divider(height: 1),

        // ── Lista ──
        Expanded(
          child: archivedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (allArchived) {
              var archived = allArchived;
              if (_search.isNotEmpty) {
                final q = _search.toUpperCase();
                archived = archived.where((r) {
                  return r.titulo.toUpperCase().contains(q) ||
                      r.folio.toUpperCase().contains(q) ||
                      r.descripcion.toUpperCase().contains(q) ||
                      r.createdByName.toUpperCase().contains(q);
                }).toList();
              }

              if (archived.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.archive_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _search.isNotEmpty
                            ? 'Sin resultados'
                            : 'No hay requerimientos archivados',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: archived.length,
                itemBuilder: (context, index) {
                  final req = archived[index];
                  return _ArchivedReqCard(
                    req: req,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(
                        '/projects/${widget.projectId}/requirements/${req.id}',
                      );
                    },
                    onUnarchive: () {
                      ref
                          .read(requerimientoRepositoryProvider)
                          .activate(req.id);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Tarjeta de requerimiento archivado ───────────────────

class _ArchivedReqCard extends StatelessWidget {
  const _ArchivedReqCard({
    required this.req,
    required this.onTap,
    required this.onUnarchive,
  });

  final Requerimiento req;
  final VoidCallback onTap;
  final VoidCallback onUnarchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final statusColor = _statusColor(req.status);
    final pct = req.porcentajeCalculado;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Folio + Status ──
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 14, color: muted),
                  const SizedBox(width: 4),
                  Text(
                    req.folio,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      req.status.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Título ──
              Text(
                req.titulo,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // ── Tipo + Solicitante ──
              Row(
                children: [
                  Icon(Icons.category_outlined, size: 12, color: muted),
                  const SizedBox(width: 4),
                  Text(
                    req.tipo.label,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.person_outline, size: 12, color: muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      req.createdByName,
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Progress + Unarchive ──
              Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: pct / 100,
                          strokeWidth: 2.5,
                          backgroundColor: muted.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(
                            progressColor(pct),
                          ),
                        ),
                        Text(
                          '${pct.toInt()}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 8,
                            color: progressColor(pct),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onUnarchive,
                    icon: const Icon(Icons.unarchive_outlined, size: 16),
                    label: const Text('Desarchivar'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Ver'),
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
