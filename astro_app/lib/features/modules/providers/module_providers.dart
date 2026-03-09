import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/modulo.dart';
import 'package:astro/features/modules/data/modulo_repository.dart';

// ── Repository ───────────────────────────────────────────

final moduloRepositoryProvider = Provider<ModuloRepository>((ref) {
  return ModuloRepository();
});

// ── Módulos por proyecto ─────────────────────────────────

/// Stream de todos los módulos de un proyecto (por nombre V1).
final modulosByProjectProvider = StreamProvider.family<List<Modulo>, String>((
  ref,
  projectName,
) {
  return ref.watch(moduloRepositoryProvider).watchModulosByProject(projectName);
});

/// Stream de módulos activos de un proyecto.
final activeModulosByProjectProvider =
    StreamProvider.family<List<Modulo>, String>((ref, projectName) {
      return ref
          .watch(moduloRepositoryProvider)
          .watchActiveModulosByProject(projectName);
    });

// ── Módulo individual ────────────────────────────────────

/// Stream de un módulo por ID.
final moduloByIdProvider = StreamProvider.family<Modulo?, String>((ref, id) {
  return ref.watch(moduloRepositoryProvider).watchModulo(id);
});

// ── Búsqueda / filtro ────────────────────────────────────

class ModuleSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final moduleSearchProvider = NotifierProvider<ModuleSearchNotifier, String>(
  ModuleSearchNotifier.new,
);

/// Módulos de un proyecto filtrados por búsqueda.
/// Requiere pasar el nombre del proyecto como parámetro.
final filteredModulesProvider = Provider.family<List<Modulo>, String>((
  ref,
  projectName,
) {
  final modules = ref.watch(modulosByProjectProvider(projectName)).value ?? [];
  final query = ref.watch(moduleSearchProvider).toUpperCase();

  if (query.isEmpty) return modules;

  return modules
      .where(
        (m) =>
            m.nombreModulo.toUpperCase().contains(query) ||
            m.folioModulo.toUpperCase().contains(query),
      )
      .toList();
});

// ── Progreso del proyecto ────────────────────────────────

/// Calcula el porcentaje promedio de completado de los módulos activos
/// de un proyecto. Retorna 0 si no hay módulos.
final projectProgressProvider = Provider.family<double, String>((
  ref,
  projectName,
) {
  final modules =
      ref.watch(activeModulosByProjectProvider(projectName)).value ?? [];
  if (modules.isEmpty) return 0;

  final total = modules.fold<double>(
    0,
    (sum, m) => sum + (m.porcentCompletaModulo ?? 0),
  );
  return total / modules.length;
});
