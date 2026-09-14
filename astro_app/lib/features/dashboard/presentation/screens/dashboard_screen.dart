import 'package:flutter/material.dart';
import 'package:astro/core/constants/app_typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/app_user.dart';
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
import 'package:astro/features/dashboard/presentation/widgets/dashboard_charts.dart';

/// Pantalla de Dashboard — vista principal tras login.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(myProjectsProvider);
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final profile = ref.watch(currentUserProfileProvider).value;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Dos paneles en cuanto hay sitio: a la izquierda la operación del
            // día (incidencias), a la derecha los proyectos. En una sola
            // columna todo queda estirado y obliga a bajar mucho para llegar a
            // los proyectos.
            final twoPane = constraints.maxWidth >= AppBreakpoints.expanded;

            final incidents = _IncidentsColumn(
              isRoot: isRoot,
              projects: projects,
            );
            // Las columnas del grid se calculan sobre el ancho del panel, no
            // el de la pantalla: en dos paneles cada uno tiene la mitad.
            final projectsSection = _ProjectsColumn(
              projects: projects,
              columns: adaptiveGridColumns(
                twoPane ? constraints.maxWidth * 0.45 : constraints.maxWidth,
              ),
            );

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AdaptiveBody.wide),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashboardHeader(profile: profile, isRoot: isRoot),
                      const SizedBox(height: 24),
                      if (twoPane)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: incidents),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: projectsSection),
                          ],
                        )
                      else ...[
                        incidents,
                        const SizedBox(height: 24),
                        projectsSection,
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Saludo, distintivo de Root y acceso al perfil.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.profile, required this.isRoot});

  final AppUser? profile;
  final bool isRoot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
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
            // Distintivo invertido: negro sobre blanco (o a la inversa), sin
            // color de marca.
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'ROOT',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.surface,
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
    );
  }
}

/// Resumen de Root y pestañas de Tickets / Requerimientos.
class _IncidentsColumn extends StatelessWidget {
  const _IncidentsColumn({required this.isRoot, required this.projects});

  final bool isRoot;
  final List<Proyecto> projects;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isRoot) ...[
          DashboardStatsSummary(
            activeCount: projects.where((p) => p.estatusProyecto).length,
          ),
          const SizedBox(height: 24),
        ],
        // Las graficas van antes del listado: dan el estado del conjunto, y
        // las pestanas de abajo son ya el detalle ticket a ticket.
        const TicketStatusChart(),
        const SizedBox(height: 12),
        const TicketFlowChart(),
        const SizedBox(height: 24),
        DashboardIncidentsTabbedSection(isRoot: isRoot),
      ],
    );
  }
}

/// Cabecera "MIS PROYECTOS" y su rejilla de tarjetas.
class _ProjectsColumn extends ConsumerWidget {
  const _ProjectsColumn({required this.projects, required this.columns});

  final List<Proyecto> projects;
  final int columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sortOption = ref.watch(projectSortProvider);
    // Se ordena una vez por build, no dentro del itemBuilder.
    final sorted = _sortProjects(projects, sortOption, ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'MIS PROYECTOS',
              style: AppTypography.overline.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (projects.length > 1) const DashboardProjectSortButton(),
          ],
        ),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          Card(
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
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 180,
            ),
            itemCount: sorted.length,
            itemBuilder: (context, index) => DashboardProjectCard(
              proyecto: sorted[index],
              ref: ref,
              onTap: () => context.push('/projects/${sorted[index].id}'),
            ),
          ),
      ],
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
