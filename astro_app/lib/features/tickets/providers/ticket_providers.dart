import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_comment.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/features/tickets/data/ticket_repository.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/core/models/project_assignment.dart';

// ── Repository ───────────────────────────────────────────

final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  return TicketRepository();
});

// ── Tickets por proyecto (V1: por nombre de proyecto) ────

/// Stream de todos los tickets activos de un proyecto (por nombre V1).
final ticketsByProjectProvider = StreamProvider.family<List<Ticket>, String>((
  ref,
  projectName,
) {
  return ref.watch(ticketRepositoryProvider).watchByProject(projectName);
});

// ── Ticket individual ────────────────────────────────────

/// Stream de un ticket por ID.
final ticketByIdProvider = StreamProvider.family<Ticket?, String>((ref, id) {
  return ref.watch(ticketRepositoryProvider).watchTicket(id);
});

// ── Comentarios ──────────────────────────────────────────

/// Stream de comentarios de un ticket.
final ticketCommentsProvider =
    StreamProvider.family<List<TicketComment>, String>((ref, ticketId) {
      return ref.watch(ticketRepositoryProvider).watchComments(ticketId);
    });

// ── Filtros ──────────────────────────────────────────────

class TicketSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final ticketSearchProvider = NotifierProvider<TicketSearchNotifier, String>(
  TicketSearchNotifier.new,
);

class TicketStatusFilterNotifier extends Notifier<TicketStatus?> {
  @override
  TicketStatus? build() => null;

  void set(TicketStatus? status) => state = status;
  void clear() => state = null;
}

final ticketStatusFilterProvider =
    NotifierProvider<TicketStatusFilterNotifier, TicketStatus?>(
      TicketStatusFilterNotifier.new,
    );

class TicketPriorityFilterNotifier extends Notifier<TicketPriority?> {
  @override
  TicketPriority? build() => null;

  void set(TicketPriority? priority) => state = priority;
  void clear() => state = null;
}

final ticketPriorityFilterNotifier =
    NotifierProvider<TicketPriorityFilterNotifier, TicketPriority?>(
      TicketPriorityFilterNotifier.new,
    );

/// Nivel de impacto para filtrar tickets.
enum ImpactLevel {
  bajo('Bajo (1-3)'),
  medio('Medio (4-6)'),
  alto('Alto (7-9)'),
  critico('Crítico (10)');

  const ImpactLevel(this.label);
  final String label;

  bool matches(int? impacto) {
    if (impacto == null) return false;
    return switch (this) {
      bajo => impacto >= 1 && impacto <= 3,
      medio => impacto >= 4 && impacto <= 6,
      alto => impacto >= 7 && impacto <= 9,
      critico => impacto == 10,
    };
  }
}

class TicketImpactFilterNotifier extends Notifier<ImpactLevel?> {
  @override
  ImpactLevel? build() => null;

  void set(ImpactLevel? level) => state = level;
  void clear() => state = null;
}

final ticketImpactFilterProvider =
    NotifierProvider<TicketImpactFilterNotifier, ImpactLevel?>(
      TicketImpactFilterNotifier.new,
    );

/// Tickets filtrados para un proyecto dado.
///
/// Visibilidad por rol:
/// - Root / Supervisor / Soporte → todos los tickets del proyecto.
/// - Usuario → solo sus propios tickets (V1 por nombre, V2 por UID).
final filteredTicketsProvider = Provider.family<List<Ticket>, String>((
  ref,
  projectId,
) {
  // Resolver nombre del proyecto para consulta V1.
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

  List<Ticket> allTickets =
      ref.watch(ticketsByProjectProvider(projectName)).value ?? [];

  // Rol Usuario → solo sus propios tickets (V1 por nombre, V2 por UID).
  if (isUsuarioOnly && uid != null) {
    allTickets = allTickets
        .where(
          (t) =>
              t.createdBy == uid ||
              t.createdByName.toUpperCase() == userName.toUpperCase(),
        )
        .toList();
  }

  final query = ref.watch(ticketSearchProvider).toUpperCase();
  final statusFilter = ref.watch(ticketStatusFilterProvider);
  final priorityFilter = ref.watch(ticketPriorityFilterNotifier);
  final impactFilter = ref.watch(ticketImpactFilterProvider);

  return allTickets.where((t) {
    if (statusFilter != null && t.status != statusFilter) return false;
    if (priorityFilter != null && t.priority != priorityFilter) return false;
    if (impactFilter != null && !impactFilter.matches(t.impacto)) return false;
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

/// Cuenta tickets activos de un proyecto (excluye Resuelto y Archivado).
final openTicketCountProvider = Provider.family<int, String>((ref, projectId) {
  final proyecto = ref.watch(proyectoByIdProvider(projectId)).value;
  if (proyecto == null) return 0;
  final tickets =
      ref.watch(ticketsByProjectProvider(proyecto.nombreProyecto)).value ?? [];
  return tickets
      .where(
        (t) =>
            t.status != TicketStatus.resuelto &&
            t.status != TicketStatus.archivado,
      )
      .length;
});

/// Conteo global de tickets por estado (suma todos los proyectos del usuario).
/// Excluye Archivado del resultado.
final globalTicketCountsByStatusProvider = Provider<Map<TicketStatus, int>>((
  ref,
) {
  final projects = ref.watch(myProjectsProvider);
  final counts = <TicketStatus, int>{};
  for (final status in TicketStatus.kanbanValues) {
    counts[status] = 0;
  }
  for (final p in projects) {
    final tickets =
        ref.watch(ticketsByProjectProvider(p.nombreProyecto)).value ?? [];
    for (final t in tickets) {
      if (t.status.isKanbanVisible) {
        counts[t.status] = (counts[t.status] ?? 0) + 1;
      }
    }
  }
  return counts;
});

/// Tickets agrupados por estado → lista de (proyecto, ticket).
/// Se usa en el dashboard para el bottom sheet de detalle por estado.
final globalTicketsByStatusProvider =
    Provider<Map<TicketStatus, List<({Proyecto project, Ticket ticket})>>>((
      ref,
    ) {
      final projects = ref.watch(myProjectsProvider);
      final result =
          <TicketStatus, List<({Proyecto project, Ticket ticket})>>{};
      for (final status in TicketStatus.kanbanValues) {
        result[status] = [];
      }
      for (final p in projects) {
        final tickets =
            ref.watch(ticketsByProjectProvider(p.nombreProyecto)).value ?? [];
        for (final t in tickets) {
          if (t.status.isKanbanVisible) {
            result[t.status]!.add((project: p, ticket: t));
          }
        }
      }
      return result;
    });

// ── Penalización de tickets para progreso de módulo ──────

/// Calcula la penalización total que los tickets abiertos de un módulo
/// ejercen sobre su progreso.
///
/// Fórmula por ticket:
///   penalización = prioridad.penaltyWeight × (impacto / 10) × (1 - avance/100)
///
/// Los tickets resueltos/archivados no penalizan.
/// Si impacto es null se usa 5 (valor medio por defecto).
final modulePenaltyProvider =
    Provider.family<double, ({String projectName, String moduleName})>((
      ref,
      params,
    ) {
      final tickets =
          ref.watch(ticketsByProjectProvider(params.projectName)).value ?? [];

      double totalPenalty = 0;
      for (final t in tickets) {
        // Solo tickets abiertos del módulo indicado.
        if (t.moduleName != params.moduleName) continue;
        if (t.status == TicketStatus.resuelto ||
            t.status == TicketStatus.archivado) {
          continue;
        }

        final impactoFactor = (t.impacto ?? 5) / 10.0;
        final avanceFactor = 1.0 - (t.porcentajeAvance / 100.0);
        totalPenalty += t.priority.penaltyWeight * impactoFactor * avanceFactor;
      }
      return totalPenalty;
    });

/// Detalle de penalización por ticket para UI (detail screen).
class TicketPenaltyDetail {
  const TicketPenaltyDetail({
    required this.ticketId,
    required this.folio,
    required this.titulo,
    required this.priority,
    required this.impacto,
    required this.avance,
    required this.penalty,
  });
  final String ticketId;
  final String folio;
  final String titulo;
  final TicketPriority priority;
  final int impacto;
  final double avance;
  final double penalty;
}

/// Lista detallada de penalizaciones por ticket en un módulo.
final modulePenaltyDetailsProvider =
    Provider.family<
      List<TicketPenaltyDetail>,
      ({String projectName, String moduleName})
    >((ref, params) {
      final tickets =
          ref.watch(ticketsByProjectProvider(params.projectName)).value ?? [];

      final details = <TicketPenaltyDetail>[];
      for (final t in tickets) {
        if (t.moduleName != params.moduleName) continue;
        if (t.status == TicketStatus.resuelto ||
            t.status == TicketStatus.archivado) {
          continue;
        }

        final impacto = t.impacto ?? 5;
        final impactoFactor = impacto / 10.0;
        final avanceFactor = 1.0 - (t.porcentajeAvance / 100.0);
        final penalty = t.priority.penaltyWeight * impactoFactor * avanceFactor;
        if (penalty > 0) {
          details.add(
            TicketPenaltyDetail(
              ticketId: t.id,
              folio: t.folio,
              titulo: t.titulo,
              priority: t.priority,
              impacto: impacto,
              avance: t.porcentajeAvance,
              penalty: penalty,
            ),
          );
        }
      }
      // Ordenar de mayor a menor penalización.
      details.sort((a, b) => b.penalty.compareTo(a.penalty));
      return details;
    });
