import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/requerimiento_status.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/core/utils/ticket_colors.dart';
import 'package:astro/features/etiquetas/providers/etiqueta_providers.dart';
import 'package:astro/features/etiquetas/presentation/widgets/etiqueta_chip.dart';

// ── Criterios de ordenamiento ────────────────────────────

enum ReqKanbanSortCriteria {
  reciente('Más reciente', Icons.schedule),
  antiguo('Más antiguo', Icons.history),
  prioridadDesc('Prioridad ↑', Icons.arrow_upward),
  prioridadAsc('Prioridad ↓', Icons.arrow_downward),
  solicitante('Solicitante', Icons.person_outline),
  responsable('Responsable', Icons.engineering_outlined),
  avance('% Avance', Icons.trending_up);

  const ReqKanbanSortCriteria(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Tablero Kanban que agrupa requerimientos por estado en columnas horizontales.
/// Soporta drag & drop entre columnas y ordenamiento.
class ReqKanbanBoard extends StatefulWidget {
  const ReqKanbanBoard({
    required this.requerimientos,
    required this.onReqTap,
    required this.onStatusChange,
    super.key,
  });

  final List<Requerimiento> requerimientos;
  final ValueChanged<Requerimiento> onReqTap;
  final void Function(Requerimiento req, RequerimientoStatus newStatus)
  onStatusChange;

  @override
  State<ReqKanbanBoard> createState() => _ReqKanbanBoardState();
}

class _ReqKanbanBoardState extends State<ReqKanbanBoard> {
  ReqKanbanSortCriteria _sort = ReqKanbanSortCriteria.reciente;

  List<Requerimiento> _sortReqs(List<Requerimiento> reqs) {
    final sorted = List<Requerimiento>.of(reqs);
    switch (_sort) {
      case ReqKanbanSortCriteria.reciente:
        sorted.sort(
          (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
            a.createdAt ?? DateTime(2000),
          ),
        );
      case ReqKanbanSortCriteria.antiguo:
        sorted.sort(
          (a, b) => (a.createdAt ?? DateTime(2000)).compareTo(
            b.createdAt ?? DateTime(2000),
          ),
        );
      case ReqKanbanSortCriteria.prioridadDesc:
        sorted.sort((a, b) => b.prioridad.index.compareTo(a.prioridad.index));
      case ReqKanbanSortCriteria.prioridadAsc:
        sorted.sort((a, b) => a.prioridad.index.compareTo(b.prioridad.index));
      case ReqKanbanSortCriteria.solicitante:
        sorted.sort(
          (a, b) => a.createdByName.toLowerCase().compareTo(
            b.createdByName.toLowerCase(),
          ),
        );
      case ReqKanbanSortCriteria.responsable:
        sorted.sort(
          (a, b) => (a.assignedToName ?? 'zzz').toLowerCase().compareTo(
            (b.assignedToName ?? 'zzz').toLowerCase(),
          ),
        );
      case ReqKanbanSortCriteria.avance:
        sorted.sort(
          (a, b) => b.porcentajeCalculado.compareTo(a.porcentajeCalculado),
        );
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final columns = RequerimientoStatus.kanbanValues;
    final theme = Theme.of(context);

    return Column(
      children: [
        // ── Sort bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.sort,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Ordenar:',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final criteria in ReqKanbanSortCriteria.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: FilterChip(
                            avatar: Icon(criteria.icon, size: 14),
                            label: Text(criteria.label),
                            selected: _sort == criteria,
                            onSelected: (_) => setState(() => _sort = criteria),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            labelStyle: theme.textTheme.labelSmall,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Board ──
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const minColumnWidth = 230.0;
              final availableWidth = constraints.maxWidth;
              final fitsAll = availableWidth >= columns.length * minColumnWidth;
              final columnWidth = fitsAll
                  ? availableWidth / columns.length
                  : minColumnWidth;

              final child = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final status in columns)
                    SizedBox(
                      width: columnWidth,
                      child: _KanbanColumn(
                        status: status,
                        requerimientos: _sortReqs(
                          widget.requerimientos
                              .where((r) => r.status == status)
                              .toList(),
                        ),
                        onReqTap: widget.onReqTap,
                        onStatusChange: widget.onStatusChange,
                      ),
                    ),
                ],
              );

              if (fitsAll) return child;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: child,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Columna Kanban ───────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.status,
    required this.requerimientos,
    required this.onReqTap,
    required this.onStatusChange,
  });

  final RequerimientoStatus status;
  final List<Requerimiento> requerimientos;
  final ValueChanged<Requerimiento> onReqTap;
  final void Function(Requerimiento req, RequerimientoStatus newStatus)
  onStatusChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(status);

    return DragTarget<Requerimiento>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) => onStatusChange(details.data, status),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isHovering
                ? color.withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering
                  ? color.withValues(alpha: 0.5)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isHovering ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              // ── Header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${requerimientos.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Cards ──
              Expanded(
                child: requerimientos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Sin requerimientos',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(6),
                        itemCount: requerimientos.length,
                        itemBuilder: (context, index) {
                          final req = requerimientos[index];
                          return LongPressDraggable<Requerimiento>(
                            data: req,
                            delay: const Duration(milliseconds: 150),
                            feedback: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 210,
                                child: _KanbanCard(req: req, isDragging: true),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _KanbanCard(req: req),
                            ),
                            child: GestureDetector(
                              onTap: () => onReqTap(req),
                              child: _KanbanCard(req: req),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tarjeta Kanban Compacta ──────────────────────────────

class _KanbanCard extends ConsumerWidget {
  const _KanbanCard({required this.req, this.isDragging = false});

  final Requerimiento req;
  final bool isDragging;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final pct = req.porcentajeCalculado;
    final priorityColor = ticketPriorityColor(req.prioridad);

    return Card(
      elevation: isDragging ? 6 : 1,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Folio + Priority badge ──
            Row(
              children: [
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
                    color: priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: priorityColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    req.prioridad.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: priorityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── Título (2 lines) ──
            Text(
              req.titulo,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Etiquetas ──
            Builder(
              builder: (_) {
                final idsKey = req.etiquetaIds.join(',');
                if (idsKey.isEmpty) return const SizedBox(height: 6);
                final etiquetas =
                    ref.watch(etiquetasByIdsProvider(idsKey)).value ?? [];
                if (etiquetas.isEmpty) return const SizedBox(height: 6);
                return Padding(
                  padding: const EdgeInsets.only(top: 5, bottom: 2),
                  child: EtiquetasRow(
                    etiquetas: etiquetas,
                    compact: true,
                    maxVisible: 3,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),

            // ── Tipo ──
            _CardInfoRow(icon: Icons.category_outlined, text: req.tipo.label),

            // ── Módulo ──
            if (req.moduleName != null && req.moduleName!.isNotEmpty)
              _CardInfoRow(icon: Icons.widgets_outlined, text: req.moduleName!),

            // ── Solicitante ──
            _CardInfoRow(icon: Icons.person_outline, text: req.createdByName),

            // ── Responsable ──
            _CardInfoRow(
              icon: Icons.engineering_outlined,
              text: req.assignedToName ?? 'Sin asignar',
            ),

            // ── Fecha creación ──
            if (req.createdAt != null)
              _CardInfoRow(
                icon: Icons.calendar_today_outlined,
                text: _shortDate(req.createdAt!),
              ),

            // ── Fecha compromiso ──
            if (req.fechaCompromiso != null)
              _CardInfoRow(
                icon: Icons.event_outlined,
                text: 'Compromiso: ${_shortDate(req.fechaCompromiso!)}',
              ),

            // ── Fase ──
            if (req.faseAsignada != null)
              _CardInfoRow(
                icon: Icons.flag_outlined,
                text: req.faseAsignada!.label,
              ),

            // ── Criterios ──
            if (req.criteriosAceptacion.isNotEmpty)
              _CardInfoRow(
                icon: Icons.checklist,
                text:
                    '${req.criteriosAceptacion.where((c) => c.completado).length}'
                    '/${req.criteriosAceptacion.length} criterios',
              ),

            // ── Indicadores: adjuntos ──
            if (req.adjuntos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.attach_file, size: 12, color: muted),
                    const SizedBox(width: 2),
                    Text(
                      '${req.adjuntos.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 6),

            // ── Progress bar + percentage ──
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 4,
                      backgroundColor: muted.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(progressColor(pct)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${pct.toInt()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    color: progressColor(pct),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _shortDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

/// Row compacto de ícono + texto para las tarjetas Kanban.
class _CardInfoRow extends StatelessWidget {
  const _CardInfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: c, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
