import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/tarea.dart';
import 'package:astro/core/models/tarea_status.dart';
import 'package:astro/core/models/tarea_prioridad.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/features/tareas/data/tarea_repository.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';

// ── Repository ───────────────────────────────────────────

final tareaRepositoryProvider = Provider<TareaRepository>((ref) {
  return TareaRepository();
});

// ── Tareas por proyecto ──────────────────────────────────

/// Stream de todas las tareas activas de un proyecto.
final tareasByProjectProvider = StreamProvider.family<List<Tarea>, String>((
  ref,
  projectId,
) {
  return ref.watch(tareaRepositoryProvider).watchByProject(projectId);
});

// ── Tarea individual ─────────────────────────────────────

/// Stream de una tarea por ID.
final tareaByIdProvider = StreamProvider.family<Tarea?, String>((ref, id) {
  return ref.watch(tareaRepositoryProvider).watchTarea(id);
});

// ── Tareas asignadas a un usuario (cross-project) ────────

/// Stream de tareas asignadas al usuario actual.
final myTareasProvider = StreamProvider<List<Tarea>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(tareaRepositoryProvider).watchByAssignee(uid);
});

// ── Filtros ──────────────────────────────────────────────

class TareaSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final tareaSearchProvider = NotifierProvider<TareaSearchNotifier, String>(
  TareaSearchNotifier.new,
);

class TareaStatusFilterNotifier extends Notifier<TareaStatus?> {
  @override
  TareaStatus? build() => null;

  void set(TareaStatus? status) => state = status;
  void clear() => state = null;
}

final tareaStatusFilterProvider =
    NotifierProvider<TareaStatusFilterNotifier, TareaStatus?>(
      TareaStatusFilterNotifier.new,
    );

class TareaPrioridadFilterNotifier extends Notifier<TareaPrioridad?> {
  @override
  TareaPrioridad? build() => null;

  void set(TareaPrioridad? prioridad) => state = prioridad;
  void clear() => state = null;
}

final tareaPrioridadFilterProvider =
    NotifierProvider<TareaPrioridadFilterNotifier, TareaPrioridad?>(
      TareaPrioridadFilterNotifier.new,
    );

// ── Tareas filtradas con visibilidad por rol ─────────────

/// Tareas filtradas para un proyecto dado.
///
/// Visibilidad por rol:
/// - Root / Supervisor / Soporte → todas las tareas del proyecto.
/// - Usuario → solo sus propias tareas (assignedToUid o createdByUid).
final filteredTareasProvider = Provider.family<List<Tarea>, String>((
  ref,
  projectId,
) {
  final isRoot = ref.watch(isCurrentUserRootProvider);
  final uid = ref.watch(authStateProvider).value?.uid;

  // Determinar el rol del usuario en este proyecto.
  final List<ProjectAssignment> assignments = uid != null
      ? (ref.watch(userAssignmentsProvider(uid)).value ?? [])
      : [];
  final projectAssignment = assignments.where(
    (a) => a.projectId == projectId && a.isActive,
  );
  final isUsuarioOnly =
      !isRoot &&
      projectAssignment.isNotEmpty &&
      projectAssignment.every((a) => a.role == UserRole.usuario);

  List<Tarea> allTareas =
      ref.watch(tareasByProjectProvider(projectId)).value ?? [];

  // Rol Usuario → solo sus propias tareas.
  if (isUsuarioOnly && uid != null) {
    allTareas = allTareas
        .where((t) => t.assignedToUid == uid || t.createdByUid == uid)
        .toList();
  }

  final query = ref.watch(tareaSearchProvider).toUpperCase();
  final statusFilter = ref.watch(tareaStatusFilterProvider);
  final prioridadFilter = ref.watch(tareaPrioridadFilterProvider);

  return allTareas.where((t) {
    if (statusFilter != null && t.status != statusFilter) return false;
    if (prioridadFilter != null && t.prioridad != prioridadFilter) return false;
    if (query.isNotEmpty) {
      final matchesQuery =
          t.titulo.toUpperCase().contains(query) ||
          t.folio.toUpperCase().contains(query) ||
          t.descripcion.toUpperCase().contains(query);
      if (!matchesQuery) return false;
    }
    return true;
  }).toList();
});

// ── Contadores rápidos ───────────────────────────────────

/// Cuenta tareas pendientes/en progreso de un proyecto.
final pendingTareaCountProvider = Provider.family<int, String>((
  ref,
  projectId,
) {
  final tareas = ref.watch(tareasByProjectProvider(projectId)).value ?? [];
  return tareas
      .where(
        (t) =>
            t.status == TareaStatus.pendiente ||
            t.status == TareaStatus.enProgreso,
      )
      .length;
});

/// Registro con tarea + datos del proyecto (para vistas globales).
typedef TareaConProyecto = ({
  Tarea tarea,
  String projectId,
  String projectName,
});

/// Helper: determina si el usuario solo tiene rol Usuario en un proyecto.
bool _isUsuarioOnly({
  required bool isRoot,
  required List<ProjectAssignment> assignments,
  required String projectId,
}) {
  if (isRoot) return false;
  final pa = assignments.where((a) => a.projectId == projectId && a.isActive);
  return pa.isNotEmpty && pa.every((a) => a.role == UserRole.usuario);
}

/// Tareas pendientes del usuario actual (solo pendiente/enProgreso).
/// Se usa para el badge de navegación y como vista filtrada.
///
/// (Mantiene el typedef anterior como alias para compatibilidad.)
typedef TareaPendiente = TareaConProyecto;

final myPendingTareasProvider = Provider<List<TareaPendiente>>((ref) {
  final all = ref.watch(myAllTareasProvider);
  return all
      .where(
        (item) =>
            item.tarea.status == TareaStatus.pendiente ||
            item.tarea.status == TareaStatus.enProgreso,
      )
      .toList();
});

/// Todas las tareas activas del usuario actual (todos los estados).
///
/// Visibilidad por rol:
/// - Root → todas las tareas de todos los proyectos.
/// - Supervisor / Soporte → todas las tareas de sus proyectos asignados.
/// - Usuario → solo tareas asignadas a él.
final myAllTareasProvider = Provider<List<TareaConProyecto>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return [];

  final isRoot = ref.watch(isCurrentUserRootProvider);
  final projects = ref.watch(myProjectsProvider);

  final List<ProjectAssignment> assignments =
      ref.watch(userAssignmentsProvider(uid)).value ?? [];

  final result = <TareaConProyecto>[];

  for (final p in projects) {
    final tareas = ref.watch(tareasByProjectProvider(p.id)).value ?? [];

    final isUserOnly = _isUsuarioOnly(
      isRoot: isRoot,
      assignments: assignments,
      projectId: p.id,
    );

    for (final t in tareas) {
      if (isUserOnly && t.assignedToUid != uid) continue;
      result.add((tarea: t, projectId: p.id, projectName: p.nombreProyecto));
    }
  }

  // Ordenar: por fecha de entrega más próxima, nulls al final.
  result.sort((a, b) {
    final da = a.tarea.fechaEntrega;
    final db = b.tarea.fechaEntrega;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });

  return result;
});

/// Todas las tareas archivadas del usuario (cross-proyecto).
///
/// Misma lógica de visibilidad por rol que myAllTareasProvider.
final myArchivedTareasProvider = Provider<List<TareaConProyecto>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return [];

  final isRoot = ref.watch(isCurrentUserRootProvider);
  final projects = ref.watch(myProjectsProvider);

  final List<ProjectAssignment> assignments =
      ref.watch(userAssignmentsProvider(uid)).value ?? [];

  final result = <TareaConProyecto>[];

  for (final p in projects) {
    final archived =
        ref.watch(archivedTareasByProjectProvider(p.id)).value ?? [];

    final isUserOnly = _isUsuarioOnly(
      isRoot: isRoot,
      assignments: assignments,
      projectId: p.id,
    );

    for (final t in archived) {
      if (isUserOnly && t.assignedToUid != uid) continue;
      result.add((tarea: t, projectId: p.id, projectName: p.nombreProyecto));
    }
  }

  result.sort((a, b) {
    final da = a.tarea.updatedAt;
    final db = b.tarea.updatedAt;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da); // Más recientes primero.
  });

  return result;
});

/// True si el usuario puede archivar/restaurar en algún proyecto (Root o Supervisor).
final canArchiveAnyProvider = Provider<bool>((ref) {
  final isRoot = ref.watch(isCurrentUserRootProvider);
  if (isRoot) return true;

  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return false;

  final assignments = ref.watch(userAssignmentsProvider(uid)).value ?? [];
  return assignments.any((a) => a.isActive && a.role == UserRole.supervisor);
});

// ── Tareas por minuta ────────────────────────────────────

/// Stream de todas las tareas vinculadas a una minuta (activas e inactivas).
final tareasByMinutaProvider = StreamProvider.family<List<Tarea>, String>((
  ref,
  minutaId,
) {
  return ref.watch(tareaRepositoryProvider).watchByMinuta(minutaId);
});

// ── Tareas archivadas ────────────────────────────────────

/// Stream de tareas archivadas (isActive == false) de un proyecto.
final archivedTareasByProjectProvider =
    StreamProvider.family<List<Tarea>, String>((ref, projectId) {
      return ref
          .watch(tareaRepositoryProvider)
          .watchArchivedByProject(projectId);
    });

// ── Permisos de archivo ──────────────────────────────────

/// Solo Root y Supervisor pueden archivar/restaurar tareas.
final canArchiveTareaProvider = Provider.family<bool, String>((ref, projectId) {
  final isRoot = ref.watch(isCurrentUserRootProvider);
  if (isRoot) return true;

  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return false;

  final assignments = ref.watch(userAssignmentsProvider(uid)).value ?? [];
  return assignments.any(
    (a) =>
        a.projectId == projectId && a.isActive && a.role == UserRole.supervisor,
  );
});
