import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/cita.dart';
import 'package:astro/core/models/cita_comment.dart';
import 'package:astro/core/models/cita_status.dart';
import 'package:astro/features/citas/data/cita_repository.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

// ── Repository ───────────────────────────────────────────

final citaRepositoryProvider = Provider<CitaRepository>((ref) {
  return CitaRepository();
});

// ── Citas por proyecto (por nombre) ──────────────────────

/// Stream de todas las citas activas de un proyecto.
final citasByProjectProvider = StreamProvider.family<List<Cita>, String>((
  ref,
  projectName,
) {
  return ref.watch(citaRepositoryProvider).watchByProject(projectName);
});

// ── Cita individual ──────────────────────────────────────

/// Stream de una cita por ID.
final citaByIdProvider = StreamProvider.family<Cita?, String>((ref, id) {
  return ref.watch(citaRepositoryProvider).watchCita(id);
});

// ── Comentarios de cita ────────────────────────────────

/// Stream de comentarios de una cita.
final citaCommentsProvider = StreamProvider.family<List<CitaComment>, String>((
  ref,
  citaId,
) {
  return ref.watch(citaRepositoryProvider).watchComments(citaId);
});

// ── Filtros ──────────────────────────────────────────────

class CitaSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final citaSearchProvider = NotifierProvider<CitaSearchNotifier, String>(
  CitaSearchNotifier.new,
);

class CitaStatusFilterNotifier extends Notifier<CitaStatus?> {
  @override
  CitaStatus? build() => null;

  void set(CitaStatus? status) => state = status;
  void clear() => state = null;
}

final citaStatusFilterProvider =
    NotifierProvider<CitaStatusFilterNotifier, CitaStatus?>(
      CitaStatusFilterNotifier.new,
    );

/// Citas filtradas para un proyecto dado.
final filteredCitasProvider = Provider.family<List<Cita>, String>((
  ref,
  projectId,
) {
  final proyecto = ref.watch(proyectoByIdProvider(projectId)).value;
  if (proyecto == null) return [];
  final projectName = proyecto.nombreProyecto;

  List<Cita> allCitas =
      ref.watch(citasByProjectProvider(projectName)).value ?? [];

  final query = ref.watch(citaSearchProvider).toUpperCase();
  final statusFilter = ref.watch(citaStatusFilterProvider);

  return allCitas.where((c) {
    if (statusFilter != null && c.status != statusFilter) return false;
    if (query.isNotEmpty) {
      final matchesQuery =
          c.titulo.toUpperCase().contains(query) ||
          c.folio.toUpperCase().contains(query) ||
          (c.descripcion?.toUpperCase().contains(query) ?? false);
      if (!matchesQuery) return false;
    }
    return true;
  }).toList();
});

// ── Contadores rápidos ───────────────────────────────────

/// Cuenta citas programadas de un proyecto (para badges).
final citasProgramadasCountProvider = Provider.family<int, String>((
  ref,
  projectId,
) {
  final proyecto = ref.watch(proyectoByIdProvider(projectId)).value;
  if (proyecto == null) return 0;
  final citas =
      ref.watch(citasByProjectProvider(proyecto.nombreProyecto)).value ?? [];
  return citas.where((c) => c.status == CitaStatus.programada).length;
});

// ── Providers globales (cross-project, para calendario) ──

/// Todas las citas donde el usuario actual es participante.
final myCitasProvider = StreamProvider<List<Cita>>((ref) {
  final uid = ref.watch(currentUserProfileProvider).value?.uid;
  if (uid == null || uid.isEmpty) return Stream.value([]);
  return ref.watch(citaRepositoryProvider).watchByParticipantUid(uid);
});

/// Citas próximas (programadas, con fecha >= hoy), ordenadas cronológicamente.
final upcomingCitasProvider = Provider<List<Cita>>((ref) {
  final allCitas = ref.watch(myCitasProvider).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return allCitas
      .where(
        (c) =>
            c.status == CitaStatus.programada &&
            c.fecha != null &&
            !c.fecha!.isBefore(today),
      )
      .toList();
});

/// Conteo total de citas programadas (próximas) para badge / dashboard.
final upcomingCitasCountProvider = Provider<int>((ref) {
  return ref.watch(upcomingCitasProvider).length;
});
