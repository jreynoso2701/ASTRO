import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/documento_categoria.dart';
import 'package:astro/core/models/categoria_custom.dart';
import 'package:astro/features/documentation/providers/documento_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de gestión de categorías de documentos.
/// Solo accesible para Root.
class CategoriasScreen extends ConsumerWidget {
  const CategoriasScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final defaults = DocumentoCategoria.defaultLabels;
    final customsAsync = ref.watch(categoriasCustomProvider(projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('CATEGORÍAS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/projects/$projectId/documents'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nueva categoría',
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Por defecto
            Text(
              'CATEGORÍAS POR DEFECTO',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: defaults.map((cat) {
                  return ListTile(
                    leading: const Icon(Icons.label_outline),
                    title: Text(cat),
                    trailing: const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: Colors.grey,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Personalizadas
            Text(
              'CATEGORÍAS PERSONALIZADAS',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            customsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('Error: $e'),
              data: (customs) {
                if (customs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Sin categorías personalizadas.\nPulsa + para agregar.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  child: Column(
                    children: customs.map((cat) {
                      return ListTile(
                        leading: const Icon(Icons.label),
                        title: Text(cat.nombre),
                        subtitle: Text(
                          'Creada por ${cat.createdByName}',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: IconButton(
                          tooltip: 'Eliminar categoría',
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () => _confirmDelete(context, ref, cat),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
            hintText: 'Ej: SLA, Plan de Implementación...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    final repo = ref.read(documentoRepositoryProvider);
    final uid = ref.read(authStateProvider).value?.uid ?? '';
    final profile = ref.read(currentUserProfileProvider).value;
    final proyecto = ref.read(proyectoByIdProvider(projectId)).value;

    await repo.createCategoria(
      CategoriaCustom(
        id: '',
        nombre: result,
        projectId: projectId,
        projectName: proyecto?.nombreProyecto ?? '',
        createdBy: uid,
        createdByName: profile?.displayName ?? '',
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CategoriaCustom cat,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar la categoría "${cat.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final repo = ref.read(documentoRepositoryProvider);
    await repo.deactivateCategoria(cat.id);
  }
}
