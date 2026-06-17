import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/ticket_colors.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Ícono representativo por estado de ticket.
IconData ticketStatusIcon(TicketStatus status) => switch (status) {
  TicketStatus.pendiente => Icons.schedule_outlined,
  TicketStatus.enDesarrollo => Icons.code,
  TicketStatus.pruebasInternas => Icons.science_outlined,
  TicketStatus.pruebasCliente => Icons.checklist_outlined,
  TicketStatus.bugs => Icons.bug_report_outlined,
  TicketStatus.resuelto => Icons.check_circle_outline,
  TicketStatus.archivado => Icons.archive_outlined,
};

class TicketStatusOverview extends ConsumerWidget {
  const TicketStatusOverview({super.key, required this.projects});
  final List<Proyecto> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final isRoot = ref.watch(isCurrentUserRootProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final profile = ref.watch(currentUserProfileProvider).value;
    final userName = profile?.displayName ?? '';
    final allAssignments = uid != null
        ? (ref.watch(userAssignmentsProvider(uid)).value ?? <ProjectAssignment>[])
        : <ProjectAssignment>[];

    final counts = <TicketStatus, int>{
      for (final s in TicketStatus.kanbanValues) s: 0,
    };
    final ticketsByStatus =
        <TicketStatus, List<({Proyecto project, Ticket ticket})>>{
          for (final s in TicketStatus.kanbanValues) s: [],
        };
    for (final p in projects) {
      var tickets =
          ref.watch(ticketsByProjectProvider(p.nombreProyecto)).value ?? [];

      final projectAssignments =
          allAssignments.where((a) => a.projectId == p.id && a.isActive);
      final isUsuarioOnly = !isRoot &&
          projectAssignments.isNotEmpty &&
          projectAssignments.every((a) => a.role == UserRole.usuario);

      if (isUsuarioOnly && uid != null) {
        tickets = tickets
            .where(
              (t) =>
                  t.createdBy == uid ||
                  t.createdByName.toUpperCase() == userName.toUpperCase(),
            )
            .toList();
      }

      for (final t in tickets) {
        if (t.status.isKanbanVisible) {
          counts[t.status] = (counts[t.status] ?? 0) + 1;
          ticketsByStatus[t.status]!.add((project: p, ticket: t));
        }
      }
    }
    final width = MediaQuery.sizeOf(context).width;

    // Statuses to display (Kanban-visible: no Archivado)
    final statuses = TicketStatus.kanbanValues;
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    void onStatusTap(TicketStatus status) {
      final entries = ticketsByStatus[status] ?? [];
      showTicketsByStatusSheet(context, status, entries);
    }

    // Responsive: on wide screens, show cards + donut side by side
    final isWide = width >= AppBreakpoints.medium;

    if (isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INCIDENTES',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status cards grid (3 columns)
              Expanded(
                flex: 3,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: statuses
                      .map(
                        (s) => SizedBox(
                          width: (width - 48 - 20) * 3 / 4 / 3 - 10,
                          child: TicketStatusCard(
                            status: s,
                            count: counts[s] ?? 0,
                            onTap: () => onStatusTap(s),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(width: 16),
              // Donut chart
              Expanded(
                flex: 1,
                child: TicketDonutChart(counts: counts, total: total),
              ),
            ],
          ),
        ],
      );
    }

    // Mobile: 2-column grid + donut below
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INCIDENTES',
          style: theme.textTheme.labelLarge?.copyWith(
            letterSpacing: 1,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: statuses
              .map(
                (s) => SizedBox(
                  width: (width - 48 - 10) / 2,
                  child: TicketStatusCard(
                    status: s,
                    count: counts[s] ?? 0,
                    onTap: () => onStatusTap(s),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        TicketDonutChart(counts: counts, total: total),
      ],
    );
  }
}

/// Card individual para un estado de ticket.
class TicketStatusCard extends StatelessWidget {
  const TicketStatusCard({
    super.key,
    required this.status,
    required this.count,
    this.onTap,
  });

  final TicketStatus status;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ticketStatusColor(status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status label badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status.label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Icon + count
              Row(
                children: [
                  Icon(ticketStatusIcon(status), color: color, size: 20),
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

// ── Bottom Sheet: tickets por estado ─────────────────────

void showTicketsByStatusSheet(
  BuildContext context,
  TicketStatus status,
  List<({Proyecto project, Ticket ticket})> entries,
) {
  final color = ticketStatusColor(status);
  final theme = Theme.of(context);

  // Ordenar por última actualización (más reciente primero)
  final sorted = [...entries]
    ..sort((a, b) {
      final aDate = a.ticket.updatedAt ?? a.ticket.createdAt;
      final bDate = b.ticket.updatedAt ?? b.ticket.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

  // Agrupar tickets por proyecto (mantiene orden de aparición)
  final grouped = <String, ({Proyecto project, List<Ticket> tickets})>{};
  for (final e in sorted) {
    final key = e.project.id;
    if (grouped.containsKey(key)) {
      grouped[key]!.tickets.add(e.ticket);
    } else {
      grouped[key] = (project: e.project, tickets: [e.ticket]);
    }
  }

  final dateFmt = DateFormat('dd/MM/yy HH:mm');

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
                Icon(ticketStatusIcon(status), color: color, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status.label,
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
                final tickets = entry.tickets;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─ Encabezado de proyecto ─
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
                              '${tickets.length}',
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

                    // ─ Ticket tiles ─
                    ...tickets.map((t) {
                      final dateStr = t.updatedAt != null
                          ? dateFmt.format(t.updatedAt!)
                          : t.createdAt != null
                          ? dateFmt.format(t.createdAt!)
                          : '—';
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
                            color: ticketPriorityColor(t.priority),
                          ),
                        ),
                        title: Text(
                          t.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          '${t.folio} · ${t.priority.label} · ${t.createdByName}\n$dateStr',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        isThreeLine: true,
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

/// Donut chart que muestra la distribución de tickets por estado.
class TicketDonutChart extends StatelessWidget {
  const TicketDonutChart({super.key, required this.counts, required this.total});

  final Map<TicketStatus, int> counts;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'DISTRIBUCIÓN',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            RepaintBoundary(
              child: SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    counts: counts,
                    total: total,
                    centerTextColor: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: counts.entries
                  .where((e) => e.value > 0)
                  .map(
                    (e) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: ticketStatusColor(e.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${e.value}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for donut chart.
class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.counts,
    required this.total,
    required this.centerTextColor,
  });

  final Map<TicketStatus, int> counts;
  final int total;
  final Color centerTextColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    // Background ring
    final bgPaint = Paint()
      ..color = centerTextColor.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    if (total == 0) {
      // Draw center text
      _drawCenterText(canvas, center, '0');
      return;
    }

    // Draw segments
    double startAngle = -math.pi / 2; // Start from top
    final segmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    for (final status in TicketStatus.kanbanValues) {
      final count = counts[status] ?? 0;
      if (count == 0) continue;
      final sweepAngle = (count / total) * 2 * math.pi;

      segmentPaint.color = ticketStatusColor(status);
      canvas.drawArc(rect, startAngle, sweepAngle, false, segmentPaint);
      startAngle += sweepAngle;
    }

    // Center text
    _drawCenterText(canvas, center, '$total');
  }

  void _drawCenterText(Canvas canvas, Offset center, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: centerTextColor,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.counts != counts || oldDelegate.total != total;
}
