import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';

import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/tickets/presentation/widgets/ticket_kanban_board.dart'
    show deadlineInfo, parseDeadlineDate;

// ── Semáforo de Deadlines ────────────────────────────────

class TicketDeadlineOverview extends ConsumerWidget {
  const TicketDeadlineOverview({super.key, required this.projects});
  final List<Proyecto> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Calcular semáforo inline desde los proyectos seleccionados
    final byDeadline =
        <DeadlineZone, List<({Proyecto project, Ticket ticket, int days})>>{
          for (final z in DeadlineZone.values) z: [],
        };
    final withoutDeadline = <({Proyecto project, Ticket ticket})>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final p in projects) {
      final tickets =
          ref.watch(ticketsByProjectProvider(p.nombreProyecto)).value ?? [];
      for (final t in tickets) {
        if (t.status == TicketStatus.resuelto ||
            t.status == TicketStatus.archivado) {
          continue;
        }
        final target = parseDeadlineDate(t.solucionProgramada);
        if (target == null) {
          final d = t.solucionProgramada;
          if (d == null || d.trim().isEmpty) {
            withoutDeadline.add((project: p, ticket: t));
          }
          continue;
        }
        final deadline = DateTime(target.year, target.month, target.day);
        final days = deadline.difference(today).inDays;
        if (days < 0) {
          byDeadline[DeadlineZone.red]!.add((
            project: p,
            ticket: t,
            days: days,
          ));
        } else if (days <= 1) {
          byDeadline[DeadlineZone.orange]!.add((
            project: p,
            ticket: t,
            days: days,
          ));
        } else if (days <= 5) {
          byDeadline[DeadlineZone.amber]!.add((
            project: p,
            ticket: t,
            days: days,
          ));
        }
      }
    }
    final width = MediaQuery.sizeOf(context).width;

    final total =
        byDeadline.values.fold<int>(0, (a, list) => a + list.length) +
        withoutDeadline.length;
    if (total == 0) return const SizedBox.shrink();

    void onZoneTap(DeadlineZone zone) {
      final entries = byDeadline[zone] ?? [];
      if (entries.isEmpty) return;
      showTicketsByDeadlineSheet(context, zone, entries);
    }

    final cardWidth = width >= AppBreakpoints.medium
        ? (width - 48 - 20) / 3 - 10
        : (width - 48 - 20) / 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SEMÁFORO DE FECHAS COMPROMISO - TICKETS',
          style: theme.textTheme.labelLarge?.copyWith(
            letterSpacing: 1,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...DeadlineZone.values.map((zone) {
              final count = byDeadline[zone]?.length ?? 0;
              return SizedBox(
                width: cardWidth,
                child: DeadlineZoneCard(
                  zone: zone,
                  count: count,
                  onTap: () => onZoneTap(zone),
                ),
              );
            }),
            SizedBox(
              width: cardWidth,
              child: NoDeadlineCard(
                count: withoutDeadline.length,
                onTap: () {
                  if (withoutDeadline.isEmpty) return;
                  showTicketsWithoutDeadlineSheet(context, withoutDeadline);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DeadlineZoneCard extends StatelessWidget {
  const DeadlineZoneCard({
    super.key,
    required this.zone,
    required this.count,
    this.onTap,
  });

  final DeadlineZone zone;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(zone.colorValue);

    IconData icon;
    switch (zone) {
      case DeadlineZone.red:
        icon = Icons.error_outline;
      case DeadlineZone.orange:
        icon = Icons.warning_amber_outlined;
      case DeadlineZone.amber:
        icon = Icons.schedule;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  zone.label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const Spacer(),
                  Text(
                    '$count',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: count > 0
                          ? color
                          : theme.colorScheme.onSurfaceVariant,
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
}

class NoDeadlineCard extends StatelessWidget {
  const NoDeadlineCard({super.key, required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'SIN FECHA',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.event_busy_outlined, color: color, size: 20),
                  const Spacer(),
                  Text(
                    '$count',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: count > 0
                          ? color
                          : theme.colorScheme.onSurfaceVariant,
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
}

// ── Bottom Sheet: tickets sin fecha compromiso ────────────

void showTicketsWithoutDeadlineSheet(
  BuildContext context,
  List<({Proyecto project, Ticket ticket})> entries,
) {
  final theme = Theme.of(context);
  final color = theme.colorScheme.onSurfaceVariant;

  // Agrupar por proyecto
  final grouped = <String, ({Proyecto project, List<Ticket> items})>{};
  for (final e in entries) {
    final key = e.project.id;
    if (grouped.containsKey(key)) {
      grouped[key]!.items.add(e.ticket);
    } else {
      grouped[key] = (project: e.project, items: [e.ticket]);
    }
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // ─ Handle ─
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ─ Header ─
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.event_busy_outlined, color: color, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sin fecha compromiso',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${entries.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ─ Lista agrupada ─
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: grouped.length,
              itemBuilder: (ctx, i) {
                final entry = grouped.values.elementAt(i);
                final project = entry.project;
                final items = entry.items;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/projects/${project.id}/tickets');
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                project.nombreProyecto,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${items.length}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    ...items.map((t) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 28,
                        ),
                        leading: Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: 0.5),
                          ),
                        ),
                        title: Text(
                          t.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          '${t.folio} · ${t.priority.label} · Sin fecha',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          final pid = t.projectId ?? project.id;
                          context.push('/projects/$pid/tickets/${t.id}');
                        },
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Bottom Sheet: tickets por deadline zone ───────────────

void showTicketsByDeadlineSheet(
  BuildContext context,
  DeadlineZone zone,
  List<({Proyecto project, Ticket ticket, int days})> entries,
) {
  final color = Color(zone.colorValue);
  final theme = Theme.of(context);

  // Ordenar: los más urgentes primero
  final sorted = [...entries]..sort((a, b) => a.days.compareTo(b.days));

  // Agrupar por proyecto
  final grouped =
      <String, ({Proyecto project, List<({Ticket ticket, int days})> items})>{};
  for (final e in sorted) {
    final key = e.project.id;
    if (grouped.containsKey(key)) {
      grouped[key]!.items.add((ticket: e.ticket, days: e.days));
    } else {
      grouped[key] = (
        project: e.project,
        items: [(ticket: e.ticket, days: e.days)],
      );
    }
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // ─ Handle ─
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ─ Header ─
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(
                  zone == DeadlineZone.red
                      ? Icons.error_outline
                      : zone == DeadlineZone.orange
                      ? Icons.warning_amber_outlined
                      : Icons.schedule,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    zone.label,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${entries.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ─ Lista agrupada ─
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: grouped.length,
              itemBuilder: (ctx, i) {
                final entry = grouped.values.elementAt(i);
                final project = entry.project;
                final items = entry.items;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/projects/${project.id}/tickets');
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                project.nombreProyecto,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${items.length}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    ...items.map((item) {
                      final t = item.ticket;
                      final info = deadlineInfo(t.solucionProgramada);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 28,
                        ),
                        leading: Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: info.color,
                          ),
                        ),
                        title: Text(
                          t.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          '${t.folio} · ${t.priority.label} · ${info.label}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          final pid = t.projectId ?? project.id;
                          context.push('/projects/$pid/tickets/${t.id}');
                        },
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
