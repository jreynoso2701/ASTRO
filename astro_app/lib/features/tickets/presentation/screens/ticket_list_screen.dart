import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';
import 'package:astro/core/models/ticket_comment.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/core/utils/ticket_colors.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/tickets/presentation/widgets/ticket_kanban_board.dart';

/// Pantalla de listado de tickets de un proyecto.
/// En móvil muestra lista; en pantallas anchas, tablero Kanban.
/// Toggle manual en AppBar para alternar vista.
class TicketListScreen extends ConsumerStatefulWidget {
  const TicketListScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends ConsumerState<TicketListScreen> {
  /// null = auto (list on mobile, kanban on wide).
  bool? _forceKanban;

  bool _isKanban(double width) {
    if (_forceKanban != null) return _forceKanban!;
    return width >= AppBreakpoints.medium;
  }

  @override
  Widget build(BuildContext context) {
    final projectId = widget.projectId;
    final proyectoAsync = ref.watch(proyectoByIdProvider(projectId));

    return proyectoAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('TICKETS')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('TICKETS')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (proyecto) {
        if (proyecto == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('TICKETS')),
            body: const Center(child: Text('Proyecto no encontrado')),
          );
        }

        final projectName = proyecto.nombreProyecto;
        final ticketsAsync = ref.watch(ticketsByProjectProvider(projectName));
        final width = MediaQuery.sizeOf(context).width;
        final kanban = _isKanban(width);
        final filteredTickets = ref.watch(
          filteredTicketsProvider((
            projectId: projectId,
            skipStatusFilter: kanban,
          )),
        );
        final searchQuery = ref.watch(ticketSearchProvider);
        final statusFilter = ref.watch(ticketStatusFilterProvider);
        final priorityFilter = ref.watch(ticketPriorityFilterNotifier);
        final impactFilter = ref.watch(ticketImpactFilterProvider);
        final canManage = ref.watch(canManageProjectProvider(projectId));

        return Scaffold(
          appBar: AppBar(
            title: Text('TICKETS — $projectName'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              // Estadísticas (Root + Soporte)
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.bar_chart_rounded),
                  tooltip: 'Estadísticas',
                  onPressed: () => _showStatsSheet(context, projectName),
                ),
              // Archivados (Root + Soporte)
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.inventory_2_outlined),
                  tooltip: 'Tickets archivados',
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
              // Crear ticket
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Nuevo ticket',
                onPressed: () =>
                    context.push('/projects/$projectId/tickets/new'),
              ),
            ],
          ),
          body: ticketsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (_) {
              return Column(
                children: [
                  // Barra de búsqueda
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar ticket...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => ref
                                    .read(ticketSearchProvider.notifier)
                                    .clear(),
                              )
                            : null,
                        isDense: true,
                      ),
                      onChanged: (v) =>
                          ref.read(ticketSearchProvider.notifier).setQuery(v),
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
                                .read(ticketStatusFilterProvider.notifier)
                                .clear(),
                          ),
                          for (final s in TicketStatus.values)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _FilterChip(
                                label: s.label,
                                selected: statusFilter == s,
                                onSelected: (_) => ref
                                    .read(ticketStatusFilterProvider.notifier)
                                    .set(s),
                                color: ticketStatusColor(s),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Filtro de prioridad
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _FilterChip(
                          label: 'Prioridad: Todas',
                          selected: priorityFilter == null,
                          onSelected: (_) => ref
                              .read(ticketPriorityFilterNotifier.notifier)
                              .clear(),
                        ),
                        for (final p in TicketPriority.values)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _FilterChip(
                              label: p.label,
                              selected: priorityFilter == p,
                              onSelected: (_) => ref
                                  .read(ticketPriorityFilterNotifier.notifier)
                                  .set(p),
                              color: ticketPriorityColor(p),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Filtro de impacto
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _FilterChip(
                          label: 'Impacto: Todos',
                          selected: impactFilter == null,
                          onSelected: (_) => ref
                              .read(ticketImpactFilterProvider.notifier)
                              .clear(),
                        ),
                        for (final level in ImpactLevel.values)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _FilterChip(
                              label: level.label,
                              selected: impactFilter == level,
                              onSelected: (_) => ref
                                  .read(ticketImpactFilterProvider.notifier)
                                  .set(level),
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
                          '${filteredTickets.length} ticket${filteredTickets.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  // Contenido: Kanban o Lista
                  Expanded(
                    child: kanban
                        ? _buildKanban(
                            context,
                            filteredTickets,
                            projectId,
                            canManage,
                          )
                        : _buildList(
                            context,
                            filteredTickets,
                            projectId,
                            canManage,
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

  // ── Bottom sheet de tickets archivados ─────────────────

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
        builder: (context, scrollController) => _ArchivedTicketsSheet(
          projectId: projectId,
          projectName: projectName,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showStatsSheet(BuildContext context, String projectName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _TicketStatsSheet(
          projectName: projectName,
          scrollController: scrollController,
        ),
      ),
    );
  }

  Widget _buildKanban(
    BuildContext context,
    List<Ticket> tickets,
    String projectId,
    bool canManage,
  ) {
    return TicketKanbanBoard(
      tickets: tickets,
      showDeadline: canManage,
      canManage: canManage,
      onTicketTap: (ticket) =>
          context.push('/projects/$projectId/tickets/${ticket.id}'),
      onBulkArchive: !canManage
          ? null
          : (resolvedTickets) async {
              final repo = ref.read(ticketRepositoryProvider);
              final profile = ref.read(currentUserProfileProvider).value;
              if (profile == null) return;

              for (final ticket in resolvedTickets) {
                await repo.archiveTicket(
                  ticket.id,
                  reason: 'Archivado masivo desde Kanban',
                  archivedByName: profile.displayName,
                  updatedBy: profile.uid,
                );
                await repo.addComment(
                  ticket.id,
                  TicketComment(
                    id: '',
                    text:
                        'Cambió estado de "${TicketStatus.resuelto.label}" a "${TicketStatus.archivado.label}" (archivado masivo)',
                    authorId: profile.uid,
                    authorName: profile.displayName,
                    type: CommentType.statusChange,
                  ),
                );
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${resolvedTickets.length} ticket(s) archivado(s)',
                    ),
                  ),
                );
              }
            },
      onStatusChange: (ticket, newStatus) async {
        final repo = ref.read(ticketRepositoryProvider);
        final profile = ref.read(currentUserProfileProvider).value;
        await repo.updateStatus(
          ticket.id,
          newStatus,
          updatedBy: profile?.uid ?? '',
        );
        // Registrar en bitácora
        if (profile != null) {
          await repo.addComment(
            ticket.id,
            TicketComment(
              id: '',
              text:
                  'Cambió estado de "${ticket.status.label}" a "${newStatus.label}"',
              authorId: profile.uid,
              authorName: profile.displayName,
              type: CommentType.statusChange,
            ),
          );
        }
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Ticket> tickets,
    String projectId,
    bool canManage,
  ) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.confirmation_num_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin tickets',
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
        itemCount: tickets.length,
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          return _TicketCard(
            ticket: ticket,
            showDeadline: canManage,
            onTap: () =>
                context.push('/projects/$projectId/tickets/${ticket.id}'),
          );
        },
      ),
    );
  }
}

// ── Ticket Card (V1 design) ──────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.onTap,
    this.showDeadline = false,
  });

  final Ticket ticket;
  final VoidCallback onTap;
  final bool showDeadline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final divider = Divider(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
      height: 20,
    );
    final pct = ticket.porcentajeAvance;

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
              // ── Folio + Estado + Semáforo deadline ──
              Row(
                children: [
                  Text(
                    'Folio:  ${ticket.folio}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (showDeadline)
                    _DeadlineBadge(solucion: ticket.solucionProgramada),
                  const Spacer(),
                  _StatusBadge(status: ticket.status),
                ],
              ),
              const SizedBox(height: 8),

              // ── Título ──
              Text(
                ticket.titulo,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // ── Info: Módulo, Empresa, Proyecto, Activo ──
              _InfoLine(label: 'Módulo', value: ticket.moduleName),
              if (ticket.empresaName != null && ticket.empresaName!.isNotEmpty)
                _InfoLine(label: 'Empresa', value: ticket.empresaName!),
              _InfoLine(label: 'Proyecto', value: ticket.projectName),
              _InfoLine(
                label: 'Folio activo?',
                value: ticket.isActive ? 'true' : 'false',
              ),

              divider,

              // ── Prioridad + Cobertura + Impacto ──
              Row(
                children: [
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.wb_sunny_outlined,
                      label: 'Prioridad:',
                      value: ticket.priority.v1Label,
                    ),
                  ),
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.shield_outlined,
                      label: 'Cobertura:',
                      value: ticket.cobertura ?? '—',
                    ),
                  ),
                  if (ticket.impacto != null)
                    Expanded(
                      child: _IconLabel(
                        icon: Icons.warning_amber_rounded,
                        label: 'Impacto:',
                        value: '${ticket.impacto}/10',
                        valueColor: ticket.impacto! <= 3
                            ? const Color(0xFF4CAF50)
                            : ticket.impacto! <= 6
                            ? const Color(0xFFFFC107)
                            : ticket.impacto! <= 9
                            ? const Color(0xFFFF9800)
                            : const Color(0xFFF44336),
                      ),
                    ),
                ],
              ),

              divider,

              // ── Fechas: Reportado, Actualización, Solución ──
              Row(
                children: [
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.note_alt_outlined,
                      label: 'Reportado:',
                      value: _formatDateV1(ticket.createdAt),
                    ),
                  ),
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.fast_forward,
                      label: 'Actualización:',
                      value: _formatDateV1(ticket.updatedAt),
                    ),
                  ),
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.event_available_outlined,
                      label: 'Solución\nprogramada',
                      value:
                          (ticket.solucionProgramada != null &&
                              ticket.solucionProgramada!.isNotEmpty)
                          ? ticket.solucionProgramada!
                          : 'Por definir',
                    ),
                  ),
                ],
              ),

              divider,

              // ── Reportó + Soporte ──
              Row(
                children: [
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.person_outline,
                      label: 'Reportó:',
                      value: ticket.createdByName,
                    ),
                  ),
                  Expanded(
                    child: _IconLabel(
                      icon: Icons.headset_mic_outlined,
                      label: 'Soporte:',
                      value: ticket.assignedToName ?? 'Sin asignar',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Barra inferior: porcentaje + indicadores + Seguimiento ──
              Row(
                children: [
                  // Porcentaje circular
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
                  const SizedBox(width: 10),
                  // Indicador de adjuntos
                  if (ticket.evidencias.isNotEmpty)
                    Tooltip(
                      message:
                          '${ticket.evidencias.length} adjunto${ticket.evidencias.length == 1 ? '' : 's'}',
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.attach_file, size: 15, color: muted),
                            const SizedBox(width: 2),
                            Text(
                              '${ticket.evidencias.length}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Indicador de comentarios
                  if (ticket.commentCount > 0)
                    Tooltip(
                      message:
                          '${ticket.commentCount} comentario${ticket.commentCount == 1 ? '' : 's'}',
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 14,
                              color: muted,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${ticket.commentCount}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Seguimiento'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateV1(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}/${dt.month}/${dt.day}\n'
        '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Sub-widgets de la tarjeta ────────────────────────────

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            '$label:  ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
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
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Icon(icon, size: 22, color: valueColor ?? muted),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Badges ───────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final color = ticketStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ── Deadline Badge ───────────────────────────────────────

class _DeadlineBadge extends StatelessWidget {
  const _DeadlineBadge({required this.solucion});
  final String? solucion;

  @override
  Widget build(BuildContext context) {
    final info = deadlineInfo(solucion);
    if (solucion == null || solucion!.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: info.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: info.color),
          const SizedBox(width: 4),
          Text(
            info.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: info.color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip ──────────────────────────────────────────

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
      selectedColor: (color ?? Colors.white).withValues(alpha: 0.12),
      checkmarkColor: color ?? Colors.white,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Helpers de color ─────────────────────────────────────
// Use shared helpers from ticket_colors.dart:
// ticketStatusColor() and ticketPriorityColor()

// ── Bottom Sheet · Tickets Archivados (Root) ─────────────

class _ArchivedTicketsSheet extends ConsumerStatefulWidget {
  const _ArchivedTicketsSheet({
    required this.projectId,
    required this.projectName,
    required this.scrollController,
  });

  final String projectId;
  final String projectName;
  final ScrollController scrollController;

  @override
  ConsumerState<_ArchivedTicketsSheet> createState() =>
      _ArchivedTicketsSheetState();
}

class _ArchivedTicketsSheetState extends ConsumerState<_ArchivedTicketsSheet> {
  String _search = '';
  TicketPriority? _priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final archivadoColor = ticketStatusColor(TicketStatus.archivado);

    // Obtener todos los tickets del proyecto y filtrar archivados.
    final allTickets =
        ref.watch(ticketsByProjectProvider(widget.projectName)).value ?? [];
    var archived = allTickets
        .where((t) => t.status == TicketStatus.archivado)
        .toList();

    // Filtro de prioridad.
    if (_priority != null) {
      archived = archived.where((t) => t.priority == _priority).toList();
    }

    // Filtro de búsqueda.
    if (_search.isNotEmpty) {
      final q = _search.toUpperCase();
      archived = archived.where((t) {
        return t.titulo.toUpperCase().contains(q) ||
            t.folio.toUpperCase().contains(q) ||
            t.descripcion.toUpperCase().contains(q) ||
            t.createdByName.toUpperCase().contains(q) ||
            (t.assignedToName?.toUpperCase().contains(q) ?? false);
      }).toList();
    }

    // Ordenar por fecha de archivado/actualización descendente.
    archived.sort(
      (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(2000)).compareTo(
        a.updatedAt ?? a.createdAt ?? DateTime(2000),
      ),
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
              Icon(Icons.inventory_2_outlined, color: archivadoColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tickets Archivados',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: archivadoColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${archived.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: archivadoColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Búsqueda ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por folio, título, descripción, nombre...',
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

        // ── Filtros de prioridad ──
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _FilterChip(
                label: 'Todas',
                selected: _priority == null,
                onSelected: (_) => setState(() => _priority = null),
              ),
              for (final p in TicketPriority.values)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _FilterChip(
                    label: p.label,
                    selected: _priority == p,
                    onSelected: (_) => setState(() => _priority = p),
                    color: ticketPriorityColor(p),
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Lista de tickets archivados ──
        Expanded(
          child: archived.isEmpty
              ? Center(
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
                        _search.isNotEmpty || _priority != null
                            ? 'Sin resultados'
                            : 'No hay tickets archivados',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: archived.length,
                  itemBuilder: (context, index) {
                    final ticket = archived[index];
                    return _ArchivedTicketCard(
                      ticket: ticket,
                      onTap: () {
                        Navigator.pop(context); // cerrar bottom sheet
                        context.push(
                          '/projects/${widget.projectId}/tickets/${ticket.id}',
                        );
                      },
                      onUnarchive: () {
                        final uid =
                            ref.read(currentUserProfileProvider).value?.uid ??
                            '';
                        ref
                            .read(ticketRepositoryProvider)
                            .updateStatus(
                              ticket.id,
                              TicketStatus.resuelto,
                              updatedBy: uid,
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

// ── Tarjeta de ticket archivado ──────────────────────────

class _ArchivedTicketCard extends StatelessWidget {
  const _ArchivedTicketCard({
    required this.ticket,
    required this.onTap,
    required this.onUnarchive,
  });

  final Ticket ticket;
  final VoidCallback onTap;
  final VoidCallback onUnarchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final priorityColor = ticketPriorityColor(ticket.priority);
    final pct = ticket.porcentajeAvance;

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
              // ── Folio + Prioridad ──
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 14, color: muted),
                  const SizedBox(width: 4),
                  Text(
                    ticket.folio,
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
                      ticket.priority.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: priorityColor,
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
                ticket.titulo,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // ── Info rows ──
              _ArchivedInfoRow(
                icon: Icons.widgets_outlined,
                label: 'Módulo',
                value: ticket.moduleName,
              ),
              _ArchivedInfoRow(
                icon: Icons.person_outline,
                label: 'Reportó',
                value: ticket.createdByName,
              ),
              _ArchivedInfoRow(
                icon: Icons.headset_mic_outlined,
                label: 'Soporte',
                value: ticket.assignedToName ?? 'Sin asignar',
              ),
              if (ticket.createdAt != null)
                _ArchivedInfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Creado',
                  value: _shortDate(ticket.createdAt!),
                ),
              if (ticket.closedAt != null)
                _ArchivedInfoRow(
                  icon: Icons.check_circle_outline,
                  label: 'Cerrado',
                  value: _shortDate(ticket.closedAt!),
                ),

              // Razón de archivado
              if (ticket.archiveReason != null &&
                  ticket.archiveReason!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ticketStatusColor(
                        TicketStatus.archivado,
                      ).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: ticketStatusColor(
                          TicketStatus.archivado,
                        ).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 12,
                              color: ticketStatusColor(TicketStatus.archivado),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Razón:',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                color: ticketStatusColor(
                                  TicketStatus.archivado,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ticket.archiveReason!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (ticket.archivedByName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Por: ${ticket.archivedByName}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                color: muted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // ── Progress + Actions ──
              Row(
                children: [
                  // Progress
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              minHeight: 4,
                              backgroundColor: muted.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(
                                progressColor(pct),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
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

                  // Desarchivar
                  TextButton.icon(
                    onPressed: onUnarchive,
                    icon: const Icon(Icons.unarchive_outlined, size: 16),
                    label: const Text('Desarchivar'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: theme.textTheme.labelSmall,
                    ),
                  ),

                  // Ver detalle
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Detalle'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
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

class _ArchivedInfoRow extends StatelessWidget {
  const _ArchivedInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: muted),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: muted,
              fontSize: 11,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estadísticas de tickets ──────────────────────────────

class _TicketStatsSheet extends ConsumerWidget {
  const _TicketStatsSheet({
    required this.projectName,
    required this.scrollController,
  });

  final String projectName;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allTicketsAsync = ref.watch(allTicketsByProjectProvider(projectName));
    final moduleStats = ref.watch(ticketStatsByModuleProvider(projectName));
    final creatorStats = ref.watch(ticketStatsByCreatorProvider(projectName));
    final coverageStats = ref.watch(ticketStatsByCoverageProvider(projectName));

    return Column(
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
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
          child: Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 20),
              const SizedBox(width: 8),
              Text('Estadísticas', style: theme.textTheme.titleMedium),
              const Spacer(),
              allTicketsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (tickets) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tickets.length} tickets totales',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: allTicketsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (_) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // ── Módulos con más incidentes ──
                _StatsSectionHeader(
                  icon: Icons.widgets_outlined,
                  title: 'Módulos con más incidentes',
                  color: const Color(0xFF42A5F5),
                ),
                if (moduleStats.isEmpty)
                  const _StatsEmptyMessage(text: 'Sin datos de módulos')
                else
                  ...moduleStats.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final maxCount = moduleStats.first.count.toDouble();
                    return _StatsBarItem(
                      rank: i + 1,
                      label: item.moduleName,
                      count: item.count,
                      fraction: maxCount > 0 ? item.count / maxCount : 0,
                      color: const Color(0xFF42A5F5),
                    );
                  }),

                const SizedBox(height: 24),

                // ── Usuarios que más reportan ──
                _StatsSectionHeader(
                  icon: Icons.person_outline,
                  title: 'Usuarios que más reportan',
                  color: const Color(0xFFAB47BC),
                ),
                if (creatorStats.isEmpty)
                  const _StatsEmptyMessage(text: 'Sin datos de usuarios')
                else
                  ...creatorStats.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final maxCount = creatorStats.first.count.toDouble();
                    return _StatsBarItem(
                      rank: i + 1,
                      label: item.creatorName,
                      count: item.count,
                      fraction: maxCount > 0 ? item.count / maxCount : 0,
                      color: const Color(0xFFAB47BC),
                    );
                  }),

                const SizedBox(height: 24),

                // ── Tickets por tipo de cobertura ──
                _StatsSectionHeader(
                  icon: Icons.shield_outlined,
                  title: 'Tickets por tipo de cobertura',
                  color: const Color(0xFF26A69A),
                ),
                if (coverageStats.isEmpty)
                  const _StatsEmptyMessage(text: 'Sin datos de cobertura')
                else
                  ...coverageStats.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final maxCount = coverageStats.first.count.toDouble();
                    return _StatsBarItem(
                      rank: i + 1,
                      label: item.coverage,
                      count: item.count,
                      fraction: maxCount > 0 ? item.count / maxCount : 0,
                      color: const Color(0xFF26A69A),
                    );
                  }),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsSectionHeader extends StatelessWidget {
  const _StatsSectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBarItem extends StatelessWidget {
  const _StatsBarItem({
    required this.rank,
    required this.label,
    required this.count,
    required this.fraction,
    required this.color,
  });

  final int rank;
  final String label;
  final int count;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank.',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
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
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(
                      color.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsEmptyMessage extends StatelessWidget {
  const _StatsEmptyMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
