import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/funcionalidad.dart';
import 'package:astro/features/modules/data/funcionalidad_repository.dart';

// ── Repository ───────────────────────────────────────────

final funcionalidadRepositoryProvider = Provider<FuncionalidadRepository>((
  ref,
) {
  return FuncionalidadRepository();
});

// ── Funcionalidades por módulo ───────────────────────────

/// Stream de todas las funcionalidades de un módulo.
final funcionalidadesByModuleProvider =
    StreamProvider.family<List<Funcionalidad>, String>((ref, moduleId) {
      return ref.watch(funcionalidadRepositoryProvider).watchByModule(moduleId);
    });

/// Stream de funcionalidades activas de un módulo.
final activeFuncionalidadesByModuleProvider =
    StreamProvider.family<List<Funcionalidad>, String>((ref, moduleId) {
      return ref
          .watch(funcionalidadRepositoryProvider)
          .watchActiveByModule(moduleId);
    });

// ── Progreso del módulo basado en funcionalidades ────────

/// Record con total y completadas de un módulo.
final funcProgressProvider =
    StreamProvider.family<({int total, int completed}), String>((
      ref,
      moduleId,
    ) {
      return ref.watch(funcionalidadRepositoryProvider).watchProgress(moduleId);
    });
