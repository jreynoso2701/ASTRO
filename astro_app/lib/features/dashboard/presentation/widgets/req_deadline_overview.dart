import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/requerimiento_status.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';

// ── Semáforo de fechas compromiso — Requerimientos ───────

class ReqDeadlineOverview extends ConsumerWidget {
  const ReqDeadlineOverview({super.key, required this.projects});
  final List<Proyecto> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Calcular semáforo inline desde los proyectos seleccionados
    final byDeadline =
        <String, List<({Proyecto project, Requerimiento req, int days})>>{
          'red': [],
          'orange': [],
          'amber': [],
        };
    final withoutDeadline = <({Proyecto project, Requerimiento req})>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final p in projects) {
      final reqs =
          ref.watch(requerimientosByProjectProvider(p.nombreProyecto)).value ??
          [];
      for (final r in reqs) {
        if (r.fechaCompromiso == null) {
          if (r.status != RequerimientoStatus.completado &&
              r.status != RequerimientoStatus.descartado) {
            withoutDeadline.add((project: p, req: r));
          }
          continue;
        }
        if (r.status == RequerimientoStatus.completado ||
            r.status == RequerimientoStatus.descartado) {
          continue;
        }
        final deadline = DateTime(
          r.fechaCompromiso!.year,
          r.fechaCompromiso!.month,
          r.fechaCompromiso!.day,
        );
        final diff = deadline.difference(today).inDays;
        if (diff < 0) {
          byDeadline['red']!.add((project: p, req: r, days: diff));
        } else if (diff <= 1) {
          byDeadline['orange']!.add((project: p, req: r, days: diff));
        } else if (diff <= 5) {
          byDeadline['amber']!.add((project: p, req: r, days: diff));
        }
      }
    }
    final width = MediaQuery.sizeOf(context).width;

    final total =
        byDeadline.values.fold<int>(0, (a, list) => a + list.length) +
        withoutDeadline.length;
    if (total == 0) return const SizedBox.shrink();

    final zones = [
      ('red', 'VENCIDO', const Color(0xFFD32F2F), Icons.error_outline),
      (
        'orange',
        'HOY / MAÑANA',
        const Color(0xFFFF9800),
        Icons.warning_amber_outlined,
      ),
      ('amber', '2–5 DÍAS', const Color(0xFFFFC107), Icons.schedule),
    ];

    final cardWidth = width >= AppBreakpoints.medium
        ? (width - 48 - 20) / 4 - 4
        : (width - 48 - 20) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SEMÁFORO FECHAS COMPROMISO — REQUERIMIENTOS',
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
            ...zones.map((z) {
              final count = byDeadline[z.$1]?.length ?? 0;
              return SizedBox(
                width: cardWidth,
                child: GenericDeadlineCard(
                  label: z.$2,
                  color: z.$3,
                  icon: z.$4,
                  count: count,
                  onTap: () {
                    final entries = byDeadline[z.$1] ?? [];
                    if (entries.isEmpty) return;
                    showReqsByDeadlineSheet(context, z.$2, z.$3, entries);
                  },
                ),
              );
            }),
            SizedBox(
              width: cardWidth,
              child: GenericDeadlineCard(
                label: 'SIN FECHA',
                color: theme.colorScheme.onSurfaceVariant,
                icon: Icons.event_busy_outlined,
                count: withoutDeadline.length,
                onTap: () {
                  if (withoutDeadline.isEmpty) return;
                  showReqsWithoutDeadlineSheet(context, withoutDeadline);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Card genérica de zona de deadline.
class GenericDeadlineCard extends StatelessWidget {
  const GenericDeadlineCard({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.count,
    this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  label,
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

// ── Bottom Sheet: requerimientos por deadline ─────────────

void showReqsByDeadlineSheet(
  BuildContext context,
  String zoneLabel,
  Color color,
  List<({Proyecto project, Requerimiento req, int days})> entries,
) {
  final theme = Theme.of(context);
  final sorted = [...entries]..sort((a, b) => a.days.compareTo(b.days));

  final grouped =
      <
        String,
        ({Proyecto project, List<({Requerimiento req, int days})> items})
      >{};
  for (final e in sorted) {
    final key = e.project.id;
    if (grouped.containsKey(key)) {
      grouped[key]!.items.add((req: e.req, days: e.days));
    } else {
      grouped[key] = (project: e.project, items: [(req: e.req, days: e.days)]);
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
                Icon(Icons.assignment_outlined, color: color, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    zoneLabel,
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
                final items = entry.items;

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
                      final r = item.req;
                      final daysLabel = item.days < 0
                          ? '${item.days.abs()}d vencido'
                          : item.days == 0
                          ? 'Hoy'
                          : '${item.days}d restante${item.days == 1 ? '' : 's'}';
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
                            color: color,
                          ),
                        ),
                        title: Text(
                          r.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          '${r.folio} · ${r.prioridad.label} · $daysLabel',
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

// ── Bottom Sheet: reqs sin fecha compromiso ──────────────

void showReqsWithoutDeadlineSheet(
  BuildContext context,
  List<({Proyecto project, Requerimiento req})> entries,
) {
  final theme = Theme.of(context);
  final color = theme.colorScheme.onSurfaceVariant;

  final grouped = <String, ({Proyecto project, List<Requerimiento> items})>{};
  for (final e in entries) {
    final key = e.project.id;
    if (grouped.containsKey(key)) {
      grouped[key]!.items.add(e.req);
    } else {
      grouped[key] = (project: e.project, items: [e.req]);
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
                    ...items.map((r) {
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
                          r.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          '${r.folio} · ${r.prioridad.label} · Sin fecha',
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
