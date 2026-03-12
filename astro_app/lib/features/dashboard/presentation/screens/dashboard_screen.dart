import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/core/utils/ticket_colors.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/core/models/cita.dart';
import 'package:astro/core/models/cita_status.dart';
import 'package:astro/core/models/minuta_modalidad.dart';

/// Pantalla de Dashboard — vista principal tras login.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final projects = ref.watch(myProjectsProvider);
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final profile = ref.watch(currentUserProfileProvider).value;
    final width = MediaQuery.sizeOf(context).width;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ASTRO', style: theme.textTheme.displaySmall),
                          const SizedBox(height: 4),
                          Text(
                            'Hola, ${profile?.displayName.split(' ').first ?? ''}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (isRoot)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFD71921,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ROOT',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFFD71921),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundImage: profile?.photoUrl != null
                              ? NetworkImage(profile!.photoUrl!)
                              : null,
                          child: profile?.photoUrl == null
                              ? Text(
                                  profile?.displayName.isNotEmpty == true
                                      ? profile!.displayName[0].toUpperCase()
                                      : '?',
                                  style: theme.textTheme.labelLarge,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Stats summary ──────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _StatsSummary(projects: projects),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── Resumen de incidentes por estado ───────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _TicketStatusOverview(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── Próximas citas ────────────────────────
          SliverToBoxAdapter(child: _UpcomingCitasSection()),

          // ── Mis proyectos ──────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'MIS PROYECTOS',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Grid de proyectos ──────────────────────
          if (projects.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_off_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sin proyectos asignados',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: adaptiveGridColumns(width),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 180,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ProjectCard(
                    proyecto: projects[index],
                    ref: ref,
                    onTap: () =>
                        context.push('/projects/${projects[index].id}'),
                  ),
                  childCount: projects.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Stats Summary ────────────────────────────────────────

class _StatsSummary extends ConsumerWidget {
  const _StatsSummary({required this.projects});

  final List<Proyecto> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Calcular stats rápidos
    final activeProjects = projects.where((p) => p.estatusProyecto).length;

    // Progreso general (promedio de todos los proyectos) — ajustado por tickets
    double avgProgress = 0;
    double avgBaseProgress = 0;
    if (projects.isNotEmpty) {
      double total = 0;
      double totalBase = 0;
      for (final p in projects) {
        total += ref.watch(projectProgressProvider(p.nombreProyecto));
        totalBase += ref.watch(projectBaseProgressProvider(p.nombreProyecto));
      }
      avgProgress = total / projects.length;
      avgBaseProgress = totalBase / projects.length;
    }

    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBreakpoints.medium;
    final upcomingCount = ref.watch(upcomingCitasCountProvider);
    final hasPenalty = avgBaseProgress > avgProgress;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: isWide ? null : double.infinity,
          child: _StatCard(
            icon: Icons.folder_outlined,
            label: 'Proyectos activos',
            value: '$activeProjects',
            color: const Color(0xFF2196F3),
          ),
        ),
        SizedBox(
          width: isWide ? null : double.infinity,
          child: _StatCard(
            icon: Icons.trending_up,
            label: 'Progreso general',
            value: '${avgProgress.round()}%',
            color: progressColor(avgProgress),
            subtitle: hasPenalty
                ? 'Base: ${avgBaseProgress.round()}%  (-${(avgBaseProgress - avgProgress).toStringAsFixed(1)}%)'
                : null,
          ),
        ),
        SizedBox(
          width: isWide ? null : double.infinity,
          child: _StatCard(
            icon: Icons.calendar_today_outlined,
            label: 'Próximas citas',
            value: '$upcomingCount',
            color: const Color(0xFF2196F3),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFFF9800),
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upcoming Citas Section ───────────────────────────────

class _UpcomingCitasSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final upcoming = ref.watch(upcomingCitasProvider);

    if (upcoming.isEmpty) return const SizedBox.shrink();

    // Mostrar máximo 3 citas
    final citas = upcoming.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PRÓXIMAS CITAS',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => GoRouter.of(context).go('/calendar'),
                child: Text(
                  'Ver todas',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...citas.map((cita) => _DashboardCitaTile(cita: cita)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DashboardCitaTile extends StatelessWidget {
  const _DashboardCitaTile({required this.cita});

  final Cita cita;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _citaStatusColor(cita.status);
    final modalIcon = _citaModalidadIcon(cita.modalidad);

    // Formatear fecha
    final fecha = cita.fecha;
    if (fecha == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final citaDay = DateTime(fecha.year, fecha.month, fecha.day);
    final diff = citaDay.difference(today).inDays;

    String dateLabel;
    if (diff == 0) {
      dateLabel = 'Hoy';
    } else if (diff == 1) {
      dateLabel = 'Mañana';
    } else {
      dateLabel =
          '${fecha.day}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    }

    final timeStr = cita.horaInicio ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => GoRouter.of(
            context,
          ).push('/projects/${cita.projectId}/citas/${cita.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Status accent bar
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  modalIcon,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cita.titulo,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cita.projectName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: diff == 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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

  static Color _citaStatusColor(CitaStatus status) => switch (status) {
    CitaStatus.programada => const Color(0xFF2196F3),
    CitaStatus.enCurso => const Color(0xFFFFC107),
    CitaStatus.completada => const Color(0xFF4CAF50),
    CitaStatus.cancelada => const Color(0xFFD32F2F),
  };

  static IconData _citaModalidadIcon(MinutaModalidad modalidad) =>
      switch (modalidad) {
        MinutaModalidad.videoconferencia => Icons.videocam_outlined,
        MinutaModalidad.presencial => Icons.place_outlined,
        MinutaModalidad.llamada => Icons.phone_outlined,
        MinutaModalidad.hibrida => Icons.devices_outlined,
      };
}

// ── Ticket Status Overview ───────────────────────────────

/// Ícono representativo por estado de ticket.
IconData _ticketStatusIcon(TicketStatus status) => switch (status) {
  TicketStatus.pendiente => Icons.schedule_outlined,
  TicketStatus.enDesarrollo => Icons.code,
  TicketStatus.pruebasInternas => Icons.science_outlined,
  TicketStatus.pruebasCliente => Icons.checklist_outlined,
  TicketStatus.bugs => Icons.bug_report_outlined,
  TicketStatus.resuelto => Icons.check_circle_outline,
  TicketStatus.archivado => Icons.archive_outlined,
};

class _TicketStatusOverview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final counts = ref.watch(globalTicketCountsByStatusProvider);
    final ticketsByStatus = ref.watch(globalTicketsByStatusProvider);
    final width = MediaQuery.sizeOf(context).width;

    // Statuses to display (Kanban-visible: no Archivado)
    final statuses = TicketStatus.kanbanValues;
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    void onStatusTap(TicketStatus status) {
      final entries = ticketsByStatus[status] ?? [];
      _showTicketsByStatusSheet(context, status, entries);
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
                          child: _TicketStatusCard(
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
                child: _TicketDonutChart(counts: counts, total: total),
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
                  child: _TicketStatusCard(
                    status: s,
                    count: counts[s] ?? 0,
                    onTap: () => onStatusTap(s),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        _TicketDonutChart(counts: counts, total: total),
      ],
    );
  }
}

/// Card individual para un estado de ticket.
class _TicketStatusCard extends StatelessWidget {
  const _TicketStatusCard({
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
                  Icon(_ticketStatusIcon(status), color: color, size: 20),
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

void _showTicketsByStatusSheet(
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
                Icon(_ticketStatusIcon(status), color: color, size: 24),
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
class _TicketDonutChart extends StatelessWidget {
  const _TicketDonutChart({required this.counts, required this.total});

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
            SizedBox(
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

// ── Project Card ─────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.proyecto,
    required this.ref,
    required this.onTap,
  });

  final Proyecto proyecto;
  final WidgetRef ref;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ref.watch(
      projectProgressProvider(proyecto.nombreProyecto),
    );
    final baseProgress = ref.watch(
      projectBaseProgressProvider(proyecto.nombreProyecto),
    );
    final openTickets = ref.watch(openTicketCountProvider(proyecto.id));
    final members = ref.watch(projectMembersProvider(proyecto.id));
    final penalty = baseProgress - progress;
    final hasPenalty = penalty > 0.5;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre y folio
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.08,
                    ),
                    child: Text(
                      proyecto.folioProyecto.isNotEmpty
                          ? proyecto.folioProyecto.substring(
                              0,
                              proyecto.folioProyecto.length.clamp(0, 2),
                            )
                          : '?',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proyecto.nombreProyecto,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          proyecto.fkEmpresa,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Progress bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 100) / 100,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: progressColor(progress),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${progress.round()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: progressColor(progress),
                    ),
                  ),
                ],
              ),

              // Penalty indicator (only when tickets are dragging progress down)
              if (hasPenalty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: const Color(0xFFFF9800),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Base: ${baseProgress.round()}%  ▼${penalty.toStringAsFixed(1)}% por tickets',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFFF9800),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Footer: tickets + members
              Row(
                children: [
                  Icon(
                    Icons.confirmation_num_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$openTickets abierto${openTickets != 1 ? 's' : ''}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.people_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${members.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
