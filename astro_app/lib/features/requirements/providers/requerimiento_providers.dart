import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/proyecto.dart';
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

class ReqEtiquetaFilterNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }

  void clear() => state = {};
}

final reqEtiquetaFilterProvider =
    NotifierProvider<ReqEtiquetaFilterNotifier, Set<String>>(
      ReqEtiquetaFilterNotifier.new,
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
      final etiquetaFilter = ref.watch(reqEtiquetaFilterProvider);

      return allReqs.where((r) {
        if (statusFilter != null && r.status != statusFilter) return false;
        if (tipoFilter != null && r.tipo != tipoFilter) return false;
        // Etiquetas: OR logic — el requerimiento debe tener al menos una de las seleccionadas.
        if (etiquetaFilter.isNotEmpty) {
          final hasMatch = r.etiquetaIds.any(
            (id) => etiquetaFilter.contains(id),
          );
          if (!hasMatch) return false;
        }
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

/// Solo Root, Supervisor y Lider Proyecto pueden archivar/eliminar/descartar requerimientos.
final canArchiveReqProvider = Provider.family<bool, String>((ref, projectId) {
  final isRoot = ref.watch(isCurrentUserRootProvider);
  if (isRoot) return true;

  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return false;

  final assignments = ref.watch(userAssignmentsProvider(uid)).value ?? [];
  return assignments.any(
    (a) =>
        a.projectId == projectId &&
        a.isActive &&
        (a.role == UserRole.supervisor || a.role == UserRole.liderProyecto),
  );
});

// ── Dashboard — conteo global por estado ─────────────────

/// Conteo global de requerimientos por estado (suma todos los proyectos).
/// Incluye todos los `kanbanValues` (excluye archivados que no están en la lista).
final globalReqCountsByStatusProvider = Provider<Map<RequerimientoStatus, int>>(
  (ref) {
    final projects = ref.watch(myProjectsProvider);
    final counts = <RequerimientoStatus, int>{};
    for (final status in RequerimientoStatus.kanbanValues) {
      counts[status] = 0;
    }
    for (final p in projects) {
      final reqs =
          ref.watch(requerimientosByProjectProvider(p.nombreProyecto)).value ??
          [];
      for (final r in reqs) {
        if (counts.containsKey(r.status)) {
          counts[r.status] = (counts[r.status] ?? 0) + 1;
        }
      }
    }
    return counts;
  },
);

/// Requerimientos agrupados por estado → lista de (proyecto, requerimiento).
/// Se usa en el dashboard para el bottom sheet de detalle por estado.
final globalReqsByStatusProvider =
    Provider<
      Map<RequerimientoStatus, List<({Proyecto project, Requerimiento req})>>
    >((ref) {
      final projects = ref.watch(myProjectsProvider);
      final result =
          <
            RequerimientoStatus,
            List<({Proyecto project, Requerimiento req})>
          >{};
      for (final status in RequerimientoStatus.kanbanValues) {
        result[status] = [];
      }
      for (final p in projects) {
        final reqs =
            ref
                .watch(requerimientosByProjectProvider(p.nombreProyecto))
                .value ??
            [];
        for (final r in reqs) {
          if (result.containsKey(r.status)) {
            result[r.status]!.add((project: p, req: r));
          }
        }
      }
      return result;
    });

// ── Dashboard — semáforo de fechas compromiso (reqs) ─────

/// Zonas de deadline para requerimientos (misma lógica que tickets).
final globalReqsByDeadlineProvider =
    Provider<
      Map<String, List<({Proyecto project, Requerimiento req, int days})>>
    >((ref) {
      final projects = ref.watch(myProjectsProvider);
      final result =
          <String, List<({Proyecto project, Requerimiento req, int days})>>{
            'red': [],
            'orange': [],
            'amber': [],
          };
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final p in projects) {
        final reqs =
            ref
                .watch(requerimientosByProjectProvider(p.nombreProyecto))
                .value ??
            [];
        for (final r in reqs) {
          // Solo requerimientos activos con fecha compromiso que no estén completados/descartados
          if (r.fechaCompromiso == null) continue;
          if (r.status == RequerimientoStatus.completado ||
              r.status == RequerimientoStatus.descartado) {
            continue;
          }
          final deadline = DateTime(
            r.fechaCompromiso!.year,
            r.fechaCompromiso!.month,
            r.fechaCompromiso!.day,
          );
          final diff = deadline.difference(today).inDays;
          if (diff < 0) {
            result['red']!.add((project: p, req: r, days: diff));
          } else if (diff <= 1) {
            result['orange']!.add((project: p, req: r, days: diff));
          } else if (diff <= 5) {
            result['amber']!.add((project: p, req: r, days: diff));
          }
        }
      }
      return result;
    });

/// Requerimientos activos sin fecha compromiso asignada.
final globalReqsWithoutDeadlineProvider =
    Provider<List<({Proyecto project, Requerimiento req})>>((ref) {
      final projects = ref.watch(myProjectsProvider);
      final result = <({Proyecto project, Requerimiento req})>[];
      for (final p in projects) {
        final reqs =
            ref
                .watch(requerimientosByProjectProvider(p.nombreProyecto))
                .value ??
            [];
        for (final r in reqs) {
          if (r.fechaCompromiso != null) continue;
          if (r.status == RequerimientoStatus.completado ||
              r.status == RequerimientoStatus.descartado) {
            continue;
          }
          result.add((project: p, req: r));
        }
      }
      return result;
    });
