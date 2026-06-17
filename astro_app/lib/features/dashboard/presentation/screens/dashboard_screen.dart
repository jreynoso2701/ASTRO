import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/ai_agent/presentation/screens/ai_agent_sheet.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/core/models/user_role.dart';

// ── Dashboard providers & enums ──────────────────────────
import 'package:astro/features/dashboard/providers/dashboard_providers.dart';

// ── Dashboard widgets ────────────────────────────────────
import 'package:astro/features/dashboard/presentation/widgets/dashboard_stats_summary.dart';
import 'package:astro/features/dashboard/presentation/widgets/dashboard_incidents_section.dart';
import 'package:astro/features/dashboard/presentation/widgets/dashboard_project_sort_button.dart';
import 'package:astro/features/dashboard/presentation/widgets/dashboard_project_card.dart';

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

    // El agente IA está disponible para Root, Supervisor y Soporte.
    // Los roles "Usuario" y "Lider Proyecto" no tienen acceso al asistente.
    final uid = ref.watch(authStateProvider).value?.uid;
    final assignments = uid != null
        ? ref.watch(userAssignmentsProvider(uid)).value ?? []
        : <ProjectAssignment>[];
    final hasAiAccess =
        isRoot ||
        assignments.any(
          (a) =>
              a.isActive &&
              a.role != UserRole.usuario &&
              a.role != UserRole.liderProyecto,
        );
    final showAiFab = profile != null && hasAiAccess;

    return Scaffold(
      floatingActionButton: showAiFab
          ? FloatingActionButton(
              heroTag: 'ai_agent_fab',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AiAgentSheet(),
                );
              },
              tooltip: 'ASTRO AI',
              child: const Icon(Icons.auto_awesome),
            )
          : null,
      body: SafeArea(
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

            // ── Stats summary (solo Root) ──────────────
            if (isRoot) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: DashboardStatsSummary(
                    activeCount: projects
                        .where((p) => p.estatusProyecto)
                        .length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // ── Pestañas: Tickets / Requerimientos ─────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: DashboardIncidentsTabbedSection(isRoot: isRoot),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Mis proyectos ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'MIS PROYECTOS',
                      style: theme.textTheme.labelLarge?.copyWith(
                        letterSpacing: 1,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (projects.length > 1) const DashboardProjectSortButton(),
                  ],
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
              Builder(
                builder: (context) {
                  final sortOption = ref.watch(projectSortProvider);
                  final sorted = _sortProjects(projects, sortOption, ref);
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: adaptiveGridColumns(width),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 180,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => DashboardProjectCard(
                          proyecto: sorted[index],
                          ref: ref,
                          onTap: () =>
                              context.push('/projects/${sorted[index].id}'),
                        ),
                        childCount: sorted.length,
                      ),
                    ),
                  );
                },
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

/// Ordena la lista de proyectos según la opción seleccionada.
List<Proyecto> _sortProjects(
  List<Proyecto> projects,
  ProjectSortOption option,
  WidgetRef ref,
) {
  final sorted = [...projects];
  switch (option) {
    case ProjectSortOption.nameAsc:
      sorted.sort(
        (a, b) => a.nombreProyecto.toLowerCase().compareTo(
          b.nombreProyecto.toLowerCase(),
        ),
      );
    case ProjectSortOption.nameDesc:
      sorted.sort(
        (a, b) => b.nombreProyecto.toLowerCase().compareTo(
          a.nombreProyecto.toLowerCase(),
        ),
      );
    case ProjectSortOption.progressAsc:
      sorted.sort((a, b) {
        final pa = ref.read(projectProgressProvider(a.nombreProyecto));
        final pb = ref.read(projectProgressProvider(b.nombreProyecto));
        return pa.compareTo(pb);
      });
    case ProjectSortOption.progressDesc:
      sorted.sort((a, b) {
        final pa = ref.read(projectProgressProvider(a.nombreProyecto));
        final pb = ref.read(projectProgressProvider(b.nombreProyecto));
        return pb.compareTo(pa);
      });
    case ProjectSortOption.ticketCountDesc:
      sorted.sort((a, b) {
        final ca = ref.read(openTicketCountProvider(a.id));
        final cb = ref.read(openTicketCountProvider(b.id));
        return cb.compareTo(ca);
      });
    case ProjectSortOption.ticketCountAsc:
      sorted.sort((a, b) {
        final ca = ref.read(openTicketCountProvider(a.id));
        final cb = ref.read(openTicketCountProvider(b.id));
        return ca.compareTo(cb);
      });
    case ProjectSortOption.reqCountDesc:
      sorted.sort((a, b) {
        final ca = ref.read(pendingReqCountProvider(a.id));
        final cb = ref.read(pendingReqCountProvider(b.id));
        return cb.compareTo(ca);
      });
    case ProjectSortOption.reqCountAsc:
      sorted.sort((a, b) {
        final ca = ref.read(pendingReqCountProvider(a.id));
        final cb = ref.read(pendingReqCountProvider(b.id));
        return ca.compareTo(cb);
      });
  }
  return sorted;
}
