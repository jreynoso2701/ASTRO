import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_comment.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';
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

  return allTickets.where((t) {
    if (statusFilter != null && t.status != statusFilter) return false;
    if (priorityFilter != null && t.priority != priorityFilter) return false;
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

/// Cuenta tickets abiertos de un proyecto (para badges).
final openTicketCountProvider = Provider.family<int, String>((ref, projectId) {
  final proyecto = ref.watch(proyectoByIdProvider(projectId)).value;
  if (proyecto == null) return 0;
  final tickets =
      ref.watch(ticketsByProjectProvider(proyecto.nombreProyecto)).value ?? [];
  return tickets.where((t) => t.status == TicketStatus.abierto).length;
});
