import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/aviso.dart';
import 'package:astro/features/avisos/data/aviso_repository.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';

// ── Repository ───────────────────────────────────────────

final avisoRepositoryProvider = Provider<AvisoRepository>(
  (ref) => AvisoRepository(),
);

// ── Stream providers ─────────────────────────────────────

/// Todos los avisos activos de un proyecto (Root ve todos).
final avisosByProjectProvider = StreamProvider.family<List<Aviso>, String>((
  ref,
  projectId,
) {
  return ref.watch(avisoRepositoryProvider).watchByProject(projectId);
});

/// Avisos que un usuario puede ver en un proyecto (filtrado por destinatario).
final avisosByRecipientProvider =
    StreamProvider.family<List<Aviso>, ({String projectId, String uid})>((
      ref,
      params,
    ) {
      return ref
          .watch(avisoRepositoryProvider)
          .watchByRecipient(params.projectId, params.uid);
    });

/// Avisos visibles según el rol del usuario actual.
/// Root → todos los del proyecto.
/// Demás roles → solo los que les corresponden.
final visibleAvisosProvider = Provider.family<List<Aviso>, String>((
  ref,
  projectId,
) {
  final profile = ref.watch(currentUserProfileProvider).value;
  if (profile == null) return [];

  final proyecto = ref.watch(proyectoByIdProvider(projectId)).value;
  if (proyecto == null) return [];

  if (profile.isRoot) {
    return ref.watch(avisosByProjectProvider(projectId)).value ?? [];
  }

  final uid = profile.uid;
  return ref
          .watch(avisosByRecipientProvider((projectId: projectId, uid: uid)))
          .value ??
      [];
});

/// Aviso individual por ID.
final avisoByIdProvider = StreamProvider.family<Aviso?, String>((ref, avisoId) {
  return ref.watch(avisoRepositoryProvider).watchAviso(avisoId);
});

/// Conteo de avisos activos de un proyecto (para badge).
final avisoCountProvider = Provider.family<int, String>((ref, projectId) {
  final avisos = ref.watch(avisosByProjectProvider(projectId)).value ?? [];
  return avisos.length;
});

/// Conteo de avisos no leídos por el usuario actual en un proyecto.
final unreadAvisoCountProvider = Provider.family<int, String>((ref, projectId) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return 0;

  final avisos = ref.watch(visibleAvisosProvider(projectId));
  return avisos.where((a) {
    final lectura = a.lecturas[uid];
    return lectura == null || !lectura.leido;
  }).length;
});

// ── Search ───────────────────────────────────────────────

/// Notifier para búsqueda de avisos.
class AvisoSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final avisoSearchProvider = NotifierProvider<AvisoSearchNotifier, String>(
  AvisoSearchNotifier.new,
);

/// Avisos filtrados por búsqueda.
final filteredAvisosProvider = Provider.family<List<Aviso>, String>((
  ref,
  projectId,
) {
  final avisos = ref.watch(visibleAvisosProvider(projectId));
  final query = ref.watch(avisoSearchProvider).toUpperCase();
  if (query.isEmpty) return avisos;

  return avisos.where((a) {
    return a.titulo.toUpperCase().contains(query) ||
        a.mensaje.toUpperCase().contains(query) ||
        a.createdByName.toUpperCase().contains(query);
  }).toList();
});
