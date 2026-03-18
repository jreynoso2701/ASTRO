import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/core/models/app_user.dart';
import 'package:astro/features/users/providers/user_providers.dart';

// ── Proyectos del usuario actual ─────────────────────────

/// Proyectos asignados al usuario autenticado.
/// Root ve todos los proyectos; otros ven solo los asignados.
final myProjectsProvider = Provider<List<Proyecto>>((ref) {
  final isRoot = ref.watch(isCurrentUserRootProvider);
  final profile = ref.watch(currentUserProfileProvider).value;
  final allProyectos = ref.watch(activeProyectosProvider).value ?? [];

  if (profile == null) return [];

  if (isRoot) return allProyectos;

  // Obtener IDs de proyectos asignados
  final assignments =
      ref.watch(userAssignmentsProvider(profile.uid)).value ?? [];
  final assignedIds = assignments.map((a) => a.projectId).toSet();

  return allProyectos.where((p) => assignedIds.contains(p.id)).toList();
});

// ── Proyecto individual ──────────────────────────────────

/// Stream de un proyecto por ID.
final proyectoByIdProvider = StreamProvider.family<Proyecto?, String>((
  ref,
  id,
) {
  return ref.watch(proyectoRepositoryProvider).watchProyecto(id);
});

// ── Miembros de un proyecto ──────────────────────────────

/// Asignaciones activas de un proyecto.
final projectAssignmentsListProvider =
    StreamProvider.family<List<ProjectAssignment>, String>((ref, projectId) {
      return ref
          .watch(projectAssignmentRepositoryProvider)
          .watchAssignmentsByProject(projectId);
    });

// ── Búsqueda / filtro de proyectos ──────────────────────

class ProjectSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final projectSearchProvider = NotifierProvider<ProjectSearchNotifier, String>(
  ProjectSearchNotifier.new,
);

/// Proyectos filtrados por búsqueda y ordenados A-Z.
final filteredProjectsProvider = Provider<List<Proyecto>>((ref) {
  final projects = ref.watch(myProjectsProvider);
  final query = ref.watch(projectSearchProvider).toUpperCase();

  final filtered = query.isEmpty
      ? [...projects]
      : projects
            .where(
              (p) =>
                  p.nombreProyecto.toUpperCase().contains(query) ||
                  p.folioProyecto.toUpperCase().contains(query) ||
                  p.fkEmpresa.toUpperCase().contains(query),
            )
            .toList();

  filtered.sort(
    (a, b) => a.nombreProyecto.toLowerCase().compareTo(
      b.nombreProyecto.toLowerCase(),
    ),
  );
  return filtered;
});

// ── Helpers para obtener info de miembros ────────────────

/// Usuarios asignados a un proyecto (resuelve AppUser desde assignments).
final projectMembersProvider =
    Provider.family<
      List<({ProjectAssignment assignment, AppUser? user})>,
      String
    >((ref, projectId) {
      final assignments =
          ref.watch(projectAssignmentsListProvider(projectId)).value ?? [];
      final allUsers = ref.watch(allUsersProvider).value ?? [];
      final userMap = {for (final u in allUsers) u.uid: u};

      return assignments
          .map((a) => (assignment: a, user: userMap[a.userId]))
          .toList();
    });
