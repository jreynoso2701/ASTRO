import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

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
    final isWide = width >= AppBreakpoints.medium;

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
                        Container(
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
              child: _StatsSummary(projects: projects, ref: ref),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

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
                  crossAxisCount: isWide ? 2 : 1,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 180,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ProjectCard(
                    proyecto: projects[index],
                    ref: ref,
                    onTap: () => context.go('/projects/${projects[index].id}'),
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

class _StatsSummary extends StatelessWidget {
  const _StatsSummary({required this.projects, required this.ref});

  final List<Proyecto> projects;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
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
                    backgroundColor: const Color(
                      0xFFD71921,
                    ).withValues(alpha: 0.12),
                    child: Text(
                      proyecto.folioProyecto.isNotEmpty
                          ? proyecto.folioProyecto.substring(
                              0,
                              proyecto.folioProyecto.length.clamp(0, 2),
                            )
                          : '?',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFD71921),
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
