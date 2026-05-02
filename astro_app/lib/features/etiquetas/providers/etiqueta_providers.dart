import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/etiqueta.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/features/etiquetas/data/etiqueta_repository.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

// ── Repository ───────────────────────────────────────────

final etiquetaRepositoryProvider = Provider<EtiquetaRepository>((ref) {
  return EtiquetaRepository();
});

// ── Streams globales ─────────────────────────────────────

/// Stream de etiquetas globales activas.
final globalEtiquetasProvider = StreamProvider<List<Etiqueta>>((ref) {
  return ref.watch(etiquetaRepositoryProvider).watchGlobal();
});

/// Stream de etiquetas de un proyecto específico.
final projectEtiquetasProvider = StreamProvider.family<List<Etiqueta>, String>((
  ref,
  projectId,
) {
  return ref.watch(etiquetaRepositoryProvider).watchByProject(projectId);
});

/// Stream de etiquetas disponibles en el contexto de un proyecto
/// (globales + específicas del proyecto), ordenadas globales primero.
final availableEtiquetasProvider =
    StreamProvider.family<List<Etiqueta>, String>((ref, projectId) {
      return ref
          .watch(etiquetaRepositoryProvider)
          .watchAvailableForProject(projectId);
    });

/// Stream de etiquetas resueltas a partir de sus IDs.
/// Recibe los IDs como String separados por coma (ej. 'id1,id2'), ordenados,
/// para garantizar igualdad por valor en Riverpod family.
final etiquetasByIdsProvider = StreamProvider.family<List<Etiqueta>, String>((
  ref,
  idsKey,
) {
  final ids = idsKey.isEmpty ? <String>[] : idsKey.split(',');
  return ref.watch(etiquetaRepositoryProvider).watchByIds(ids);
});

// ── Permisos ─────────────────────────────────────────────

/// Puede gestionar etiquetas globales solo Root.
final canManageGlobalEtiquetasProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).value;
  if (profile == null) return false;
  return profile.isRoot;
});

/// Puede gestionar etiquetas de proyecto: Root, Lider Proyecto, Soporte.
final canManageProjectEtiquetasProvider = Provider.family<bool, String>((
  ref,
  projectId,
) {
  final profile = ref.watch(currentUserProfileProvider).value;
  if (profile == null) return false;
  if (profile.isRoot) return true;
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return false;
  final assignments = ref.watch(userAssignmentsProvider(uid)).value ?? [];
  final assignment = assignments
      .where((a) => a.projectId == projectId && a.isActive)
      .firstOrNull;
  if (assignment == null) return false;
  return assignment.role == UserRole.liderProyecto ||
      assignment.role == UserRole.soporte ||
      assignment.role == UserRole.supervisor;
});
