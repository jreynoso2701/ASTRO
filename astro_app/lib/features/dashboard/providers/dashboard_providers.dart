import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/proyecto.dart';

// ── Ordenamiento de Mis Proyectos ────────────────────────

enum ProjectSortOption {
  nameAsc('A → Z'),
  nameDesc('Z → A'),
  progressAsc('Progreso ↑'),
  progressDesc('Progreso ↓'),
  ticketCountDesc('Tickets abiertos ↓'),
  ticketCountAsc('Tickets abiertos ↑'),
  reqCountDesc('Reqs. abiertos ↓'),
  reqCountAsc('Reqs. abiertos ↑');

  const ProjectSortOption(this.label);
  final String label;
}

class ProjectSortNotifier extends Notifier<ProjectSortOption> {
  @override
  ProjectSortOption build() => ProjectSortOption.nameAsc;
  void set(ProjectSortOption option) => state = option;
}

final projectSortProvider =
    NotifierProvider<ProjectSortNotifier, ProjectSortOption>(
      ProjectSortNotifier.new,
    );

// ── Dashboard Tab Project Filters ────────────────────────

/// Filtra los proyectos visibles en las pestañas del dashboard.
/// Estado vacío = todos seleccionados (comportamiento por defecto).
class DashboardTabFilterNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String id, List<Proyecto> allProjects) {
    final allIds = allProjects.map((p) => p.id).toSet();
    final effective = state.isEmpty ? Set.of(allIds) : Set.of(state);
    if (effective.contains(id)) {
      if (effective.length <= 1) return;
      effective.remove(id);
    } else {
      effective.add(id);
    }
    state = effective.containsAll(allIds) ? const {} : effective;
  }

  void selectAll() => state = const {};
}

final dashboardTicketProjectFilterProvider =
    NotifierProvider<DashboardTabFilterNotifier, Set<String>>(
      DashboardTabFilterNotifier.new,
    );

final dashboardReqProjectFilterProvider =
    NotifierProvider<DashboardTabFilterNotifier, Set<String>>(
      DashboardTabFilterNotifier.new,
    );
