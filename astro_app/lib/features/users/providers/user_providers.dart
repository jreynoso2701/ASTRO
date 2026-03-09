import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/app_user.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/core/models/empresa.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/features/users/data/user_repository.dart';
import 'package:astro/features/users/data/project_assignment_repository.dart';
import 'package:astro/features/users/data/empresa_repository.dart';
import 'package:astro/features/users/data/proyecto_repository.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';

// ── Repositories ─────────────────────────────────────────

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final projectAssignmentRepositoryProvider =
    Provider<ProjectAssignmentRepository>((ref) {
      return ProjectAssignmentRepository();
    });

final empresaRepositoryProvider = Provider<EmpresaRepository>((ref) {
  return EmpresaRepository();
});

final proyectoRepositoryProvider = Provider<ProyectoRepository>((ref) {
  return ProyectoRepository();
});

// ── Current user profile (from Firestore) ────────────────

/// Stream del perfil del usuario autenticado actual.
final currentUserProfileProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

/// Indica si el usuario actual es Root.
final isCurrentUserRootProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  return profile.value?.isRoot ?? false;
});

/// Indica si el usuario actual puede gestionar módulos/funcionalidades
/// de un proyecto: es Root global **o** tiene rol Soporte en ese proyecto.
final canManageProjectProvider = Provider.family<bool, String>((
  ref,
  projectId,
) {
  final isRoot = ref.watch(isCurrentUserRootProvider);
  if (isRoot) return true;

  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return false;

  final assignments = ref.watch(userAssignmentsProvider(uid)).value ?? [];
  return assignments.any(
    (a) => a.projectId == projectId && a.isActive && a.role == UserRole.soporte,
  );
});

// ── All users (para gestión Root) ────────────────────────

/// Stream de todos los usuarios.
final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchAllUsers();
});

// ── Asignaciones por usuario ─────────────────────────────

/// Provider family para asignaciones de un usuario específico.
final userAssignmentsProvider =
    StreamProvider.family<List<ProjectAssignment>, String>((ref, userId) {
      return ref
          .watch(projectAssignmentRepositoryProvider)
          .watchAssignmentsByUser(userId);
    });

// ── Empresas y Proyectos ─────────────────────────────────

/// Stream de empresas activas.
final activeEmpresasProvider = StreamProvider<List<Empresa>>((ref) {
  return ref.watch(empresaRepositoryProvider).watchActiveEmpresas();
});

/// Stream de proyectos activos.
final activeProyectosProvider = StreamProvider<List<Proyecto>>((ref) {
  return ref.watch(proyectoRepositoryProvider).watchActiveProyectos();
});

// ── Búsqueda de usuarios ─────────────────────────────────

/// Estado del filtro de búsqueda de usuarios.
class UserSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final userSearchProvider = NotifierProvider<UserSearchNotifier, String>(
  UserSearchNotifier.new,
);

/// Usuarios filtrados por el término de búsqueda.
final filteredUsersProvider = Provider<List<AppUser>>((ref) {
  final users = ref.watch(allUsersProvider);
  final query = ref.watch(userSearchProvider).toUpperCase();

  final list = users.value ?? [];
  if (query.isEmpty) return list;

  return list
      .where(
        (u) =>
            u.displayName.toUpperCase().contains(query) ||
            u.email.toUpperCase().contains(query),
      )
      .toList();
});
