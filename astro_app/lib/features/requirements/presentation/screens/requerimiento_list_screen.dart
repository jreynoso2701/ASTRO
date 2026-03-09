import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/requerimiento_status.dart';
import 'package:astro/core/models/requerimiento_tipo.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';

/// Pantalla de listado de requerimientos de un proyecto.
class RequerimientoListScreen extends ConsumerWidget {
  const RequerimientoListScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectoAsync = ref.watch(proyectoByIdProvider(projectId));

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

        return Scaffold(
          appBar: AppBar(
            title: Text('REQUERIMIENTOS — $projectName'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/projects/$projectId'),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Nuevo requerimiento',
                onPressed: () =>
                    context.go('/projects/$projectId/requirements/new'),
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

                  // Lista
                  Expanded(
                    child: filteredReqs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 64,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Sin requerimientos',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredReqs.length,
                            itemBuilder: (context, index) {
                              final req = filteredReqs[index];
                              return _ReqCard(
                                req: req,
                                onTap: () => context.go(
                                  '/projects/$projectId/requirements/${req.id}',
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
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
  RequerimientoStatus.aprobado => const Color(0xFF66BB6A),
  RequerimientoStatus.diferido => const Color(0xFFFFB74D),
  RequerimientoStatus.rechazado => const Color(0xFFEF5350),
  RequerimientoStatus.enDesarrollo => const Color(0xFFFFC107),
  RequerimientoStatus.implementado => const Color(0xFF4CAF50),
  RequerimientoStatus.cerrado => const Color(0xFF388E3C),
};

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.day}/${date.month}/${date.year}';
}
