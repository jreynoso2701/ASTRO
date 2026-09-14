import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/core/models/app_user.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
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

// ── Ordenamiento ────────────────────────────────────────

/// Criterios de ordenamiento de la lista de proyectos.
enum ProjectListSort {
  nombreAsc('Nombre (A-Z)'),
  nombreDesc('Nombre (Z-A)'),
  avanceDesc('Mayor avance'),
  avanceAsc('Menor avance'),
  empresa('Empresa'),
  folio('Folio');

  const ProjectListSort(this.label);

  final String label;
}

class ProjectListSortNotifier extends Notifier<ProjectListSort> {
  @override
  ProjectListSort build() => ProjectListSort.nombreAsc;

  void set(ProjectListSort sort) => state = sort;
}

final projectListSortProvider =
    NotifierProvider<ProjectListSortNotifier, ProjectListSort>(
      ProjectListSortNotifier.new,
    );

// ── Filtro por empresa ──────────────────────────────────

/// Empresa seleccionada en el filtro, o `null` para "todas".
class ProjectEmpresaFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? empresa) => state = empresa;
}

final projectEmpresaFilterProvider =
    NotifierProvider<ProjectEmpresaFilterNotifier, String?>(
      ProjectEmpresaFilterNotifier.new,
    );

/// Empresas presentes en los proyectos visibles, para poblar el filtro.
final projectEmpresasProvider = Provider<List<String>>((ref) {
  final empresas = ref
      .watch(myProjectsProvider)
      .map((p) => p.fkEmpresa)
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();
  empresas.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return empresas;
});

/// Proyectos filtrados por búsqueda y empresa, ordenados según
/// [projectListSortProvider].
final filteredProjectsProvider = Provider<List<Proyecto>>((ref) {
  final projects = ref.watch(myProjectsProvider);
  final query = ref.watch(projectSearchProvider).toUpperCase();
  final empresa = ref.watch(projectEmpresaFilterProvider);
  final sort = ref.watch(projectListSortProvider);

  final filtered = projects.where((p) {
    if (empresa != null && p.fkEmpresa != empresa) return false;
    if (query.isEmpty) return true;
    return p.nombreProyecto.toUpperCase().contains(query) ||
        p.folioProyecto.toUpperCase().contains(query) ||
        p.fkEmpresa.toUpperCase().contains(query);
  }).toList();

  int byNombre(Proyecto a, Proyecto b) =>
      a.nombreProyecto.toLowerCase().compareTo(b.nombreProyecto.toLowerCase());

  // El avance vive en los módulos, no en el proyecto, así que ordenar por él
  // obliga a observar el progreso de cada proyecto listado.
  double avance(Proyecto p) =>
      ref.watch(projectProgressProvider(p.nombreProyecto));

  filtered.sort(switch (sort) {
    ProjectListSort.nombreAsc => byNombre,
    ProjectListSort.nombreDesc => (a, b) => byNombre(b, a),
    ProjectListSort.avanceDesc => (a, b) {
      final c = avance(b).compareTo(avance(a));
      return c != 0 ? c : byNombre(a, b);
    },
    ProjectListSort.avanceAsc => (a, b) {
      final c = avance(a).compareTo(avance(b));
      return c != 0 ? c : byNombre(a, b);
    },
    ProjectListSort.empresa => (a, b) {
      final c = a.fkEmpresa.toLowerCase().compareTo(b.fkEmpresa.toLowerCase());
      return c != 0 ? c : byNombre(a, b);
    },
    ProjectListSort.folio => (a, b) => a.folioProyecto.toLowerCase().compareTo(
      b.folioProyecto.toLowerCase(),
    ),
  });
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

      // Deduplicate by userId — keep first assignment per user
      final seen = <String>{};
      return assignments
          .where((a) => seen.add(a.userId))
          .map((a) => (assignment: a, user: userMap[a.userId]))
          .toList();
    });

// ── Responsables principales ─────────────────────────────

/// Miembros marcados como responsables principales del proyecto.
///
/// Se deriva de [projectMembersProvider], así que un responsable deja de serlo
/// automáticamente si se le retira del proyecto.
final projectLeadsProvider =
    Provider.family<
      List<({ProjectAssignment assignment, AppUser? user})>,
      String
    >((ref, projectId) {
      final members = ref.watch(projectMembersProvider(projectId));
      var leads = members.where((m) => m.assignment.isLead).toList();
      // `isLead` se marca a mano y hoy casi ningun proyecto lo tiene, asi que
      // sin respaldo las tarjetas salian sin responsable. El rol Lider
      // Proyecto ya expresa lo mismo en los datos que existen; en cuanto
      // alguien marque responsables explicitos, esos mandan.
      if (leads.isEmpty) {
        leads = members
            .where((m) => m.assignment.role == UserRole.liderProyecto)
            .toList();
      }
      leads.sort((a, b) {
        final an = a.user?.displayName ?? '';
        final bn = b.user?.displayName ?? '';
        return an.toLowerCase().compareTo(bn.toLowerCase());
      });
      return leads;
    });

/// Nombres de los responsables principales, listos para mostrar en una tarjeta.
final projectLeadNamesProvider = Provider.family<List<String>, String>((
  ref,
  projectId,
) {
  return ref
      .watch(projectLeadsProvider(projectId))
      .map((m) => m.user?.displayName ?? 'Usuario')
      .toList();
});
