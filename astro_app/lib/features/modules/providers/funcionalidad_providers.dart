import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/funcionalidad.dart';
import 'package:astro/features/modules/data/funcionalidad_repository.dart';
import 'package:astro/features/modules/providers/module_providers.dart';

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

/// Auto-sync: actualiza porcentCompletaModulo cuando cambia el progreso.
///
/// Debe ser watcheado en module_detail_screen para que permanezca activo.
final moduleProgressSyncProvider = Provider.family<void, String>((
  ref,
  moduleId,
) {
  final progress = ref.watch(funcProgressProvider(moduleId));

  progress.whenData((data) {
    if (data.total == 0) return;
    final percent = (data.completed / data.total) * 100;

    // Leer repo directamente y actualizar si el valor cambió.
    final moduloRepo = ref.read(moduloRepositoryProvider);
    moduloRepo.updateProgress(moduleId, percent);
  });
});
