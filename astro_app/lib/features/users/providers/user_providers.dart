import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/app_user.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/core/models/empresa.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/registration_status.dart';
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

/// Estado de registro del usuario actual.
final currentUserRegistrationStatusProvider = Provider<RegistrationStatus?>((
  ref,
) {
  final profile = ref.watch(currentUserProfileProvider);
  return profile.value?.registrationStatus;
});

/// Stream de usuarios pendientes de aprobación (para Root).
final pendingUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchPendingUsers();
});

/// Conteo de solicitudes pendientes (para badge).
final pendingUsersCountProvider = Provider<int>((ref) {
  final pending = ref.watch(pendingUsersProvider);
  return pending.value?.length ?? 0;
});

/// Indica si el usuario actual tiene al menos una asignación activa,
/// o es Root (Root siempre tiene acceso completo).
/// Retorna null mientras se carga la información.
final hasProjectAssignmentsProvider = Provider<bool?>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  if (profile.isLoading) return null;

  final user = profile.value;
  if (user == null) return false; // No user doc → treat as no assignments
  if (user.isRoot) return true;

  final uid = user.uid;
  final assignments = ref.watch(userAssignmentsProvider(uid));
  if (assignments.isLoading) return null;

  final list = assignments.value ?? [];
  return list.isNotEmpty;
});

/// Indica si el usuario actual puede gestionar módulos/funcionalidades
/// de un proyecto: es Root global **o** tiene rol Soporte o Lider Proyecto en ese proyecto.
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
    (a) =>
        a.projectId == projectId &&
        a.isActive &&
        (a.role == UserRole.soporte || a.role == UserRole.liderProyecto),
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

/// Stream de TODAS las empresas (activas + inactivas) — para gestión Root.
final allEmpresasProvider = StreamProvider<List<Empresa>>((ref) {
  return ref.watch(empresaRepositoryProvider).watchAllEmpresas();
});

/// Stream de una empresa por ID.
final empresaByIdProvider = StreamProvider.family<Empresa?, String>((ref, id) {
  return ref.watch(empresaRepositoryProvider).watchEmpresa(id);
});

/// Stream de proyectos activos.
final activeProyectosProvider = StreamProvider<List<Proyecto>>((ref) {
  return ref.watch(proyectoRepositoryProvider).watchActiveProyectos();
});

/// Stream de TODOS los proyectos (activos + inactivos) — para gestión Root.
final allProyectosProvider = StreamProvider<List<Proyecto>>((ref) {
  return ref.watch(proyectoRepositoryProvider).watchAllProyectos();
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

/// Usuarios filtrados por el término de búsqueda y ordenados A-Z.
/// Solo incluye usuarios aprobados y activos.
final filteredUsersProvider = Provider<List<AppUser>>((ref) {
  final users = ref.watch(allUsersProvider);
  final query = ref.watch(userSearchProvider).toUpperCase();

  // Solo mostrar usuarios aprobados y activos
  final list = (users.value ?? [])
      .where(
        (u) =>
            u.registrationStatus == RegistrationStatus.approved && u.isActive,
      )
      .toList();
  final filtered = query.isEmpty
      ? [...list]
      : list
            .where(
              (u) =>
                  u.displayName.toUpperCase().contains(query) ||
                  u.email.toUpperCase().contains(query),
            )
            .toList();

  filtered.sort(
    (a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
  );
  return filtered;
});

/// Usuarios desactivados (aprobados pero isActive == false), ordenados A-Z.
final deactivatedUsersProvider = Provider<List<AppUser>>((ref) {
  final users = ref.watch(allUsersProvider).value ?? [];
  final list = users
      .where(
        (u) =>
            u.registrationStatus == RegistrationStatus.approved && !u.isActive,
      )
      .toList();
  list.sort(
    (a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
  );
  return list;
});
