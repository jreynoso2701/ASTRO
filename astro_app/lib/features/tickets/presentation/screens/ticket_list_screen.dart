import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/core/widgets/adaptive_body.dart';

/// Pantalla de listado de tickets de un proyecto.
class TicketListScreen extends ConsumerWidget {
  const TicketListScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        final filteredTickets = ref.watch(filteredTicketsProvider(projectId));
        final searchQuery = ref.watch(ticketSearchProvider);
        final statusFilter = ref.watch(ticketStatusFilterProvider);
        final priorityFilter = ref.watch(ticketPriorityFilterNotifier);

        return Scaffold(
          appBar: AppBar(
            title: Text('TICKETS — $projectName'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              // Cualquier usuario puede crear tickets
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
              return AdaptiveBody(
                maxWidth: 960,
                child: Column(
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
                                color: _statusColor(s),
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
                                color: _priorityColor(p),
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

                    // Lista
                    Expanded(
                      child: filteredTickets.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.confirmation_num_outlined,
                                    size: 64,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Sin tickets',
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filteredTickets.length,
                              itemBuilder: (context, index) {
                                final ticket = filteredTickets[index];
                                return _TicketCard(
                                  ticket: ticket,
                                  onTap: () => context.push(
                                    '/projects/$projectId/tickets/${ticket.id}',
                                  ),
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
}

// ── Ticket Card (V1 design) ──────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

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
              // ── Folio + Estado ──
              Row(
                children: [
                  Text(
                    'Folio:  ${ticket.folio}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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

              // ── Prioridad + Cobertura ──
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

              // ── Barra inferior: porcentaje + Seguimiento ──
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
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Icon(icon, size: 22, color: muted),
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
    final color = _statusColor(status);
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

Color _statusColor(TicketStatus status) {
  return switch (status) {
    TicketStatus.abierto => const Color(0xFF2196F3),
    TicketStatus.enProgreso => const Color(0xFFFFC107),
    TicketStatus.resuelto => const Color(0xFF4CAF50),
    TicketStatus.cerrado => Colors.grey,
  };
}

Color _priorityColor(TicketPriority priority) {
  return switch (priority) {
    TicketPriority.baja => const Color(0xFF4CAF50),
    TicketPriority.media => const Color(0xFF2196F3),
    TicketPriority.alta => const Color(0xFFFFC107),
    TicketPriority.critica => const Color(0xFFD71921),
  };
}
