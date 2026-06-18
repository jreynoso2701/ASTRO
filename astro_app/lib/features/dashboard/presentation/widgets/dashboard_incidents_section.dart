import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/features/tickets/presentation/screens/chats_list_screen.dart';
import 'package:astro/features/dashboard/presentation/widgets/dashboard_ticket_search_sheet.dart';
import 'package:astro/features/dashboard/presentation/widgets/quick_ticket_sheet.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/features/dashboard/providers/dashboard_providers.dart';
import 'package:astro/features/dashboard/presentation/widgets/dashboard_project_filter.dart';
import 'package:astro/features/dashboard/presentation/widgets/dashboard_tab_stat_cards.dart';
import 'package:astro/features/dashboard/presentation/widgets/ticket_status_overview.dart';
import 'package:astro/features/dashboard/presentation/widgets/ticket_deadline_overview.dart';
import 'package:astro/features/dashboard/presentation/widgets/req_status_overview.dart';
import 'package:astro/features/dashboard/presentation/widgets/req_deadline_overview.dart';

// ── Tabbed Incidents / Requirements ──────────────────────

/// Sección con pestañas Tickets / Requerimientos.
/// Contiene las cards de estados + dona + semáforo de cada tipo.
class DashboardIncidentsTabbedSection extends ConsumerStatefulWidget {
  const DashboardIncidentsTabbedSection({super.key, required this.isRoot});
  final bool isRoot;

  @override
  ConsumerState<DashboardIncidentsTabbedSection> createState() =>
      _DashboardIncidentsTabbedSectionState();
}

class _DashboardIncidentsTabbedSectionState
    extends ConsumerState<DashboardIncidentsTabbedSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Tab bar ──
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            letterSpacing: 1,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
            letterSpacing: 1,
          ),
          tabs: const [
            Tab(text: 'TICKETS'),
            Tab(text: 'REQUERIMIENTOS'),
            Tab(text: 'CHATS'),
          ],
        ),

        // ── Botones de acción (solo en pestaña TICKETS) ──
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            if (_tabController.index != 0) return const SizedBox(height: 12);
            // En tab CHATS no se muestran botones de acción
            if (_tabController.index == 2) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Row(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('Buscar tickets'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () => showDashboardTicketSearchSheet(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nuevo ticket'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () => showQuickTicketSheet(context),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 10),

        // ── Tab content (no PageView — just listen to index) ──
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            if (_tabController.index == 0) {
              return _TicketsTabContent(isRoot: widget.isRoot);
            } else if (_tabController.index == 1) {
              return _ReqsTabContent(isRoot: widget.isRoot);
            } else {
              return const ChatsListScreen();
            }
          },
        ),
      ],
    );
  }
}

/// Contenido de la pestaña "Tickets": filtro de proyectos, stats, cards y semáforo.
class _TicketsTabContent extends ConsumerWidget {
  const _TicketsTabContent({required this.isRoot});
  final bool isRoot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProjects = ref.watch(myProjectsProvider);
    final selectedIds = ref.watch(dashboardTicketProjectFilterProvider);
    final effectiveProjects = selectedIds.isEmpty
        ? allProjects
        : allProjects.where((p) => selectedIds.contains(p.id)).toList();

    // Avg progress para los proyectos seleccionados
    double avgProgress = 0;
    double avgBaseProgress = 0;
    if (effectiveProjects.isNotEmpty) {
      double total = 0, totalBase = 0;
      for (final p in effectiveProjects) {
        total += ref.watch(projectProgressProvider(p.nombreProyecto));
        totalBase += ref.watch(projectBaseProgressProvider(p.nombreProyecto));
      }
      avgProgress = total / effectiveProjects.length;
      avgBaseProgress = totalBase / effectiveProjects.length;
    }

    // Citas próximas filtradas por proyectos seleccionados
    final allUpcoming = ref.watch(upcomingCitasProvider);
    final effectiveIds = effectiveProjects.map((p) => p.id).toSet();
    final filteredCitas = allUpcoming
        .where((c) => effectiveIds.contains(c.projectId))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (allProjects.length > 1)
          DashboardProjectFilterSelector(
            allProjects: allProjects,
            filterProvider: dashboardTicketProjectFilterProvider,
          ),
        if (allProjects.length > 1) const SizedBox(height: 12),
        DashboardTabStatCards(
          avgProgress: avgProgress,
          avgBaseProgress: avgBaseProgress,
          upcomingCitas: filteredCitas,
        ),
        const SizedBox(height: 16),
        TicketStatusOverview(projects: effectiveProjects),
        if (isRoot) ...[
          const SizedBox(height: 24),
          TicketDeadlineOverview(projects: effectiveProjects),
        ],
      ],
    );
  }
}

/// Contenido de la pestaña "Requerimientos": filtro de proyectos, stats, cards y semáforo.
class _ReqsTabContent extends ConsumerWidget {
  const _ReqsTabContent({required this.isRoot});
  final bool isRoot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProjects = ref.watch(myProjectsProvider);
    final selectedIds = ref.watch(dashboardReqProjectFilterProvider);
    final effectiveProjects = selectedIds.isEmpty
        ? allProjects
        : allProjects.where((p) => selectedIds.contains(p.id)).toList();

    // Avg progress para los proyectos seleccionados
    double avgProgress = 0;
    double avgBaseProgress = 0;
    if (effectiveProjects.isNotEmpty) {
      double total = 0, totalBase = 0;
      for (final p in effectiveProjects) {
        total += ref.watch(projectProgressProvider(p.nombreProyecto));
        totalBase += ref.watch(projectBaseProgressProvider(p.nombreProyecto));
      }
      avgProgress = total / effectiveProjects.length;
      avgBaseProgress = totalBase / effectiveProjects.length;
    }

    // Citas próximas filtradas por proyectos seleccionados
    final allUpcoming = ref.watch(upcomingCitasProvider);
    final effectiveIds = effectiveProjects.map((p) => p.id).toSet();
    final filteredCitas = allUpcoming
        .where((c) => effectiveIds.contains(c.projectId))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (allProjects.length > 1)
          DashboardProjectFilterSelector(
            allProjects: allProjects,
            filterProvider: dashboardReqProjectFilterProvider,
          ),
        if (allProjects.length > 1) const SizedBox(height: 12),
        DashboardTabStatCards(
          avgProgress: avgProgress,
          avgBaseProgress: avgBaseProgress,
          upcomingCitas: filteredCitas,
        ),
        const SizedBox(height: 16),
        ReqStatusOverview(projects: effectiveProjects),
        if (isRoot) ...[
          const SizedBox(height: 24),
          ReqDeadlineOverview(projects: effectiveProjects),
        ],
      ],
    );
  }
}
