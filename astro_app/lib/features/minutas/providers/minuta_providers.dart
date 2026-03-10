import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/minuta.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/core/services/places_service.dart';
import 'package:astro/features/minutas/data/minuta_repository.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

// ── Repository ───────────────────────────────────────────

final minutaRepositoryProvider = Provider<MinutaRepository>((ref) {
  return MinutaRepository();
});

// ── Places Service ───────────────────────────────────────

final placesServiceProvider = Provider<PlacesService>((ref) {
  return PlacesService(
    apiKey: const String.fromEnvironment(
      'GOOGLE_MAPS_API_KEY',
      defaultValue: 'AIzaSyBSOJjQT5PeN1CjYKSiXLTRHk355y1FOKo',
    ),
  );
});

// ── Minutas por proyecto — con visibilidad por rol ───────

/// Stream de minutas activas de un proyecto (todas — para Root/Supervisor/Soporte).
final minutasByProjectProvider = StreamProvider.family<List<Minuta>, String>((
  ref,
  projectName,
) {
  return ref.watch(minutaRepositoryProvider).watchByProject(projectName);
});

/// Stream de minutas donde el usuario participa (para rol Usuario).
final minutasByParticipantProvider =
    StreamProvider.family<List<Minuta>, ({String projectName, String uid})>((
      ref,
      params,
    ) {
      return ref
          .watch(minutaRepositoryProvider)
          .watchByParticipant(params.projectName, params.uid);
    });

/// Provider que resuelve las minutas visibles según el rol del usuario actual.
final visibleMinutasProvider = Provider.family<List<Minuta>, String>((
  ref,
  projectId,
) {
  final proyecto = ref.watch(proyectoByIdProvider(projectId)).value;
  if (proyecto == null) return [];
  final projectName = proyecto.nombreProyecto;

  final profile = ref.watch(currentUserProfileProvider).value;
  if (profile == null) return [];

  // Root, Supervisor, Soporte → ven todas las minutas del proyecto
  if (profile.isRoot) {
    return ref.watch(minutasByProjectProvider(projectName)).value ?? [];
  }

  // Obtener el rol del usuario en este proyecto
  final assignments =
      ref.watch(userAssignmentsProvider(profile.uid)).value ?? [];
  final projectAssignment = assignments.where(
    (a) => a.projectId == projectId && a.isActive,
  );

  final isUsuario =
      projectAssignment.isNotEmpty &&
      projectAssignment.first.role == UserRole.usuario;

  if (isUsuario) {
    // Usuario → solo minutas donde participa
    return ref
            .watch(
              minutasByParticipantProvider((
                projectName: projectName,
                uid: profile.uid,
              )),
            )
            .value ??
        [];
  }

  // Supervisor / Soporte → todas las del proyecto
  return ref.watch(minutasByProjectProvider(projectName)).value ?? [];
});

// ── Minuta individual ────────────────────────────────────

/// Stream de una minuta por ID.
final minutaByIdProvider = StreamProvider.family<Minuta?, String>((ref, id) {
  return ref.watch(minutaRepositoryProvider).watchMinuta(id);
});

// ── Permisos ─────────────────────────────────────────────

/// Indica si el usuario actual puede crear/editar minutas (Root o Soporte).
final canCreateMinutaProvider = Provider.family<bool, String>((ref, projectId) {
  final isRoot = ref.watch(isCurrentUserRootProvider);
  if (isRoot) return true;

  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return false;

  final assignments = ref.watch(userAssignmentsProvider(uid)).value ?? [];
  return assignments.any(
    (a) => a.projectId == projectId && a.isActive && a.role == UserRole.soporte,
  );
});

// ── Filtros ──────────────────────────────────────────────

class MinutaSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final minutaSearchProvider = NotifierProvider<MinutaSearchNotifier, String>(
  MinutaSearchNotifier.new,
);

/// Minutas filtradas para un proyecto dado (respeta visibilidad por rol).
final filteredMinutasProvider = Provider.family<List<Minuta>, String>((
  ref,
  projectId,
) {
  final allMinutas = ref.watch(visibleMinutasProvider(projectId));
  final query = ref.watch(minutaSearchProvider).toUpperCase();

  if (query.isEmpty) return allMinutas;

  return allMinutas.where((m) {
    return m.folio.toUpperCase().contains(query) ||
        m.objetivo.toUpperCase().contains(query) ||
        (m.lugar?.toUpperCase().contains(query) ?? false) ||
        (m.direccion?.toUpperCase().contains(query) ?? false);
  }).toList();
});

// ── Contadores rápidos ───────────────────────────────────

/// Cuenta minutas visibles de un proyecto (para badges).
final minutaCountProvider = Provider.family<int, String>((ref, projectId) {
  return ref.watch(visibleMinutasProvider(projectId)).length;
});
