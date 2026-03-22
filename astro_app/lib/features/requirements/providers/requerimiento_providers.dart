import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/requerimiento_comment.dart';
import 'package:astro/core/models/requerimiento_status.dart';
import 'package:astro/core/models/requerimiento_tipo.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/features/requirements/data/requerimiento_repository.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';

// ── Repository ───────────────────────────────────────────

final requerimientoRepositoryProvider = Provider<RequerimientoRepository>((
  ref,
) {
  return RequerimientoRepository();
});

// ── Requerimientos por proyecto (por nombre) ─────────────

final requerimientosByProjectProvider =
    StreamProvider.family<List<Requerimiento>, String>((ref, projectName) {
      return ref
          .watch(requerimientoRepositoryProvider)
          .watchByProject(projectName);
    });

/// Todos los requerimientos (activos + archivados) de un proyecto.
final allRequerimientosByProjectProvider =
    StreamProvider.family<List<Requerimiento>, String>((ref, projectName) {
      return ref
          .watch(requerimientoRepositoryProvider)
          .watchAllByProject(projectName);
    });

// ── Requerimiento individual ─────────────────────────────

final requerimientoByIdProvider = StreamProvider.family<Requerimiento?, String>(
  (ref, id) {
    return ref.watch(requerimientoRepositoryProvider).watchRequerimiento(id);
  },
);

// ── Comentarios ──────────────────────────────────────────

final reqCommentsProvider =
    StreamProvider.family<List<RequerimientoComment>, String>((ref, reqId) {
      return ref.watch(requerimientoRepositoryProvider).watchComments(reqId);
    });

// ── Filtros ──────────────────────────────────────────────

class ReqSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final reqSearchProvider = NotifierProvider<ReqSearchNotifier, String>(
  ReqSearchNotifier.new,
);

class ReqStatusFilterNotifier extends Notifier<RequerimientoStatus?> {
  @override
  RequerimientoStatus? build() => null;
  void set(RequerimientoStatus? status) => state = status;
  void clear() => state = null;
}

final reqStatusFilterProvider =
    NotifierProvider<ReqStatusFilterNotifier, RequerimientoStatus?>(
      ReqStatusFilterNotifier.new,
    );

class ReqTipoFilterNotifier extends Notifier<RequerimientoTipo?> {
  @override
  RequerimientoTipo? build() => null;
  void set(RequerimientoTipo? tipo) => state = tipo;
  void clear() => state = null;
}

final reqTipoFilterProvider =
    NotifierProvider<ReqTipoFilterNotifier, RequerimientoTipo?>(
      ReqTipoFilterNotifier.new,
    );

/// Requerimientos filtrados para un proyecto dado.
///
/// Visibilidad por rol:
/// - Root / Supervisor / Soporte → todos los requerimientos del proyecto.
/// - Usuario → solo los suyos (createdBy == uid).
final filteredRequerimientosProvider =
    Provider.family<List<Requerimiento>, String>((ref, projectId) {
      final proyecto = ref.watch(proyectoByIdProvider(projectId)).value;
      if (proyecto == null) return [];
      final projectName = proyecto.nombreProyecto;

      final isRoot = ref.watch(isCurrentUserRootProvider);
      final uid = ref.watch(authStateProvider).value?.uid;
      final profile = ref.watch(currentUserProfileProvider).value;
      final userName = profile?.displayName ?? '';

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

      List<Requerimiento> allReqs =
          ref.watch(requerimientosByProjectProvider(projectName)).value ?? [];

      // Rol Usuario → solo sus propios requerimientos.
      if (isUsuarioOnly && uid != null) {
        allReqs = allReqs
            .where(
              (r) =>
                  r.createdBy == uid ||
                  r.createdByName.toUpperCase() == userName.toUpperCase(),
            )
            .toList();
      }

      final query = ref.watch(reqSearchProvider).toUpperCase();
      final statusFilter = ref.watch(reqStatusFilterProvider);
      final tipoFilter = ref.watch(reqTipoFilterProvider);

      return allReqs.where((r) {
        if (statusFilter != null && r.status != statusFilter) return false;
        if (tipoFilter != null && r.tipo != tipoFilter) return false;
        if (query.isNotEmpty) {
          final matchesQuery =
              r.titulo.toUpperCase().contains(query) ||
              r.folio.toUpperCase().contains(query) ||
              r.descripcion.toUpperCase().contains(query);
          if (!matchesQuery) return false;
        }
        return true;
      }).toList();
    });

// ── Contadores rápidos ───────────────────────────────────

/// Cuenta requerimientos pendientes (propuesto / en revisión) de un proyecto.
final pendingReqCountProvider = Provider.family<int, String>((ref, projectId) {
  final proyecto = ref.watch(proyectoByIdProvider(projectId)).value;
  if (proyecto == null) return 0;
  final reqs =
      ref
          .watch(requerimientosByProjectProvider(proyecto.nombreProyecto))
          .value ??
      [];
  return reqs
      .where(
        (r) =>
            r.status == RequerimientoStatus.propuesto ||
            r.status == RequerimientoStatus.enRevision,
      )
      .length;
});

// ── Requerimientos archivados ────────────────────────────

/// Stream de requerimientos archivados (isActive == false) de un proyecto.
final archivedReqsByProjectProvider =
    StreamProvider.family<List<Requerimiento>, String>((ref, projectId) {
      final proyecto = ref.watch(proyectoByIdProvider(projectId)).value;
      if (proyecto == null) return const Stream.empty();
      return ref
          .watch(requerimientoRepositoryProvider)
          .watchArchivedByProject(proyecto.nombreProyecto);
    });

// ── Permisos de archivo ──────────────────────────────────

/// Solo Root y Supervisor pueden archivar/eliminar/descartar requerimientos.
final canArchiveReqProvider = Provider.family<bool, String>((ref, projectId) {
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
