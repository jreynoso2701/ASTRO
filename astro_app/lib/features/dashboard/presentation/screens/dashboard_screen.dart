import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/core/models/proyecto.dart';
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

    int totalOpenTickets = 0;
    for (final p in projects) {
      totalOpenTickets += ref.watch(openTicketCountProvider(p.id));
    }

    // Progreso general (promedio de todos los proyectos)
    double avgProgress = 0;
    if (projects.isNotEmpty) {
      double total = 0;
      for (final p in projects) {
        total += ref.watch(projectProgressProvider(p.nombreProyecto));
      }
      avgProgress = total / projects.length;
    }

    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBreakpoints.medium;
    final upcomingCount = ref.watch(upcomingCitasCountProvider);

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
            icon: Icons.confirmation_num_outlined,
            label: 'Tickets abiertos',
            value: '$totalOpenTickets',
            color: totalOpenTickets > 0
                ? const Color(0xFFFFC107)
                : const Color(0xFF4CAF50),
          ),
        ),
        SizedBox(
          width: isWide ? null : double.infinity,
          child: _StatCard(
            icon: Icons.trending_up,
            label: 'Progreso general',
            value: '${avgProgress.round()}%',
            color: progressColor(avgProgress),
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
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

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
    final openTickets = ref.watch(openTicketCountProvider(proyecto.id));
    final members = ref.watch(projectMembersProvider(proyecto.id));

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
