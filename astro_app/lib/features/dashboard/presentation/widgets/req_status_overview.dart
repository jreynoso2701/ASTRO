import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/ticket_colors.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/requerimiento_status.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

// ── Requerimientos Status Overview ───────────────────────

/// Ícono representativo por estado de requerimiento.
IconData reqStatusIcon(RequerimientoStatus status) => switch (status) {
  RequerimientoStatus.propuesto => Icons.lightbulb_outline,
  RequerimientoStatus.enRevision => Icons.rate_review_outlined,
  RequerimientoStatus.enDesarrollo => Icons.code,
  RequerimientoStatus.implementado => Icons.rocket_launch_outlined,
  RequerimientoStatus.completado => Icons.check_circle_outline,
  RequerimientoStatus.descartado => Icons.cancel_outlined,
};

class ReqStatusOverview extends ConsumerWidget {
  const ReqStatusOverview({super.key, required this.projects});
  final List<Proyecto> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final profile = ref.watch(currentUserProfileProvider).value;
    final userName = profile?.displayName ?? '';
    final allAssignments = uid != null
        ? (ref.watch(userAssignmentsProvider(uid)).value ?? <ProjectAssignment>[])
        : <ProjectAssignment>[];

    final counts = <RequerimientoStatus, int>{
      for (final s in RequerimientoStatus.kanbanValues) s: 0,
    };
    final reqsByStatus =
        <RequerimientoStatus, List<({Proyecto project, Requerimiento req})>>{
          for (final s in RequerimientoStatus.kanbanValues) s: [],
        };
    for (final p in projects) {
      var reqs =
          ref.watch(requerimientosByProjectProvider(p.nombreProyecto)).value ??
          [];

      final projectAssignments =
          allAssignments.where((a) => a.projectId == p.id && a.isActive);
      final isUsuarioOnly = !isRoot &&
          projectAssignments.isNotEmpty &&
          projectAssignments.every((a) => a.role == UserRole.usuario);

      if (isUsuarioOnly && uid != null) {
        reqs = reqs
            .where(
              (r) =>
                  r.createdBy == uid ||
                  r.createdByName.toUpperCase() == userName.toUpperCase(),
            )
            .toList();
      }

      for (final r in reqs) {
        if (counts.containsKey(r.status)) {
          counts[r.status] = (counts[r.status] ?? 0) + 1;
          reqsByStatus[r.status]!.add((project: p, req: r));
        }
      }
    }
    final width = MediaQuery.sizeOf(context).width;

    final statuses = RequerimientoStatus.kanbanValues;
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    void onStatusTap(RequerimientoStatus status) {
      final entries = reqsByStatus[status] ?? [];
      showReqsByStatusSheet(context, status, entries);
    }

    final isWide = width >= AppBreakpoints.medium;

    if (isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: statuses
                      .map(
                        (s) => SizedBox(
                          width: (width - 48 - 20) * 3 / 4 / 3 - 10,
                          child: ReqStatusCard(
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
              Expanded(
                flex: 1,
                child: ReqDonutChart(counts: counts, total: total),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: statuses
              .map(
                (s) => SizedBox(
                  width: (width - 48 - 10) / 2,
                  child: ReqStatusCard(
                    status: s,
                    count: counts[s] ?? 0,
                    onTap: () => onStatusTap(s),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        ReqDonutChart(counts: counts, total: total),
      ],
    );
  }
}

/// Card individual para un estado de requerimiento.
class ReqStatusCard extends StatelessWidget {
  const ReqStatusCard({
    super.key,
    required this.status,
    required this.count,
    this.onTap,
  });

  final RequerimientoStatus status;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = reqStatusColor(status);

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
              Row(
                children: [
                  Icon(reqStatusIcon(status), color: color, size: 20),
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

/// Donut chart de distribución de requerimientos por estado.
class ReqDonutChart extends StatelessWidget {
  const ReqDonutChart({super.key, required this.counts, required this.total});

  final Map<RequerimientoStatus, int> counts;
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
                  painter: _ReqDonutChartPainter(
                    counts: counts,
                    total: total,
                    centerTextColor: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                            color: reqStatusColor(e.key),
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

/// Custom painter for requerimiento donut chart.
class _ReqDonutChartPainter extends CustomPainter {
  _ReqDonutChartPainter({
    required this.counts,
    required this.total,
    required this.centerTextColor,
  });

  final Map<RequerimientoStatus, int> counts;
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

    final bgPaint = Paint()
      ..color = centerTextColor.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    if (total == 0) {
      _drawCenterText(canvas, center, '0');
      return;
    }

    double startAngle = -math.pi / 2;
    final segmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    for (final status in RequerimientoStatus.kanbanValues) {
      final count = counts[status] ?? 0;
      if (count == 0) continue;
      final sweepAngle = (count / total) * 2 * math.pi;
      segmentPaint.color = reqStatusColor(status);
      canvas.drawArc(rect, startAngle, sweepAngle, false, segmentPaint);
      startAngle += sweepAngle;
    }

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
  bool shouldRepaint(covariant _ReqDonutChartPainter oldDelegate) =>
      oldDelegate.counts != counts || oldDelegate.total != total;
}

// ── Bottom Sheet: requerimientos por estado ───────────────

void showReqsByStatusSheet(
  BuildContext context,
  RequerimientoStatus status,
  List<({Proyecto project, Requerimiento req})> entries,
) {
  final color = reqStatusColor(status);
  final theme = Theme.of(context);

  final sorted = [...entries]
    ..sort((a, b) {
      final aDate = a.req.updatedAt ?? a.req.createdAt;
      final bDate = b.req.updatedAt ?? b.req.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

  final grouped = <String, ({Proyecto project, List<Requerimiento> reqs})>{};
  for (final e in sorted) {
    final key = e.project.id;
    if (grouped.containsKey(key)) {
      grouped[key]!.reqs.add(e.req);
    } else {
      grouped[key] = (project: e.project, reqs: [e.req]);
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(reqStatusIcon(status), color: color, size: 24),
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
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: grouped.length,
              itemBuilder: (ctx, i) {
                final entry = grouped.values.elementAt(i);
                final project = entry.project;
                final reqs = entry.reqs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/projects/${project.id}/requirements');
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
                              '${reqs.length}',
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
                    ...reqs.map((r) {
                      final dateStr = r.updatedAt != null
                          ? dateFmt.format(r.updatedAt!)
                          : r.createdAt != null
                          ? dateFmt.format(r.createdAt!)
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
                            color: ticketPriorityColor(r.prioridad),
                          ),
                        ),
                        title: Text(
                          r.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          '${r.folio} · ${r.prioridad.label} · ${r.tipo.label}\n$dateStr',
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
                          final pid = r.projectId ?? project.id;
                          context.push('/projects/$pid/requirements/${r.id}');
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
