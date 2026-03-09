import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/modulo.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de listado de módulos de un proyecto.
class ModuleListScreen extends ConsumerWidget {
  const ModuleListScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectoAsync = ref.watch(proyectoByIdProvider(projectId));
    final canManage = ref.watch(canManageProjectProvider(projectId));

    return proyectoAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('MÓDULOS')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('MÓDULOS')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (proyecto) {
        if (proyecto == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('MÓDULOS')),
            body: const Center(child: Text('Proyecto no encontrado')),
          );
        }

        final projectName = proyecto.nombreProyecto;
        final modulesAsync = ref.watch(modulosByProjectProvider(projectName));
        final searchQuery = ref.watch(moduleSearchProvider);
        final filteredModules = ref.watch(filteredModulesProvider(projectName));
        final progress = ref.watch(projectProgressProvider(projectName));

        return Scaffold(
          appBar: AppBar(
            title: Text('MÓDULOS — $projectName'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/projects/$projectId'),
            ),
            actions: [
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Nuevo módulo',
                  onPressed: () =>
                      context.go('/projects/$projectId/modules/new'),
                ),
            ],
          ),
          body: modulesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (_) {
              return Column(
                children: [
                  _ProjectProgressBar(progress: progress),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar módulo...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => ref
                                    .read(moduleSearchProvider.notifier)
                                    .clear(),
                              )
                            : null,
                        isDense: true,
                      ),
                      onChanged: (v) =>
                          ref.read(moduleSearchProvider.notifier).setQuery(v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          '${filteredModules.length} módulo${filteredModules.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredModules.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.view_module_outlined,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  searchQuery.isNotEmpty
                                      ? 'Sin resultados'
                                      : 'Sin módulos',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide =
                                  constraints.maxWidth >=
                                  AppBreakpoints.compact;
                              if (isWide) {
                                return GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 400,
                                        mainAxisExtent: 140,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                      ),
                                  itemCount: filteredModules.length,
                                  itemBuilder: (context, i) => _ModuleCard(
                                    modulo: filteredModules[i],
                                    projectId: projectId,
                                  ),
                                );
                              }
                              return ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: filteredModules.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) => SizedBox(
                                  height: 140,
                                  child: _ModuleCard(
                                    modulo: filteredModules[i],
                                    projectId: projectId,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ── Barra de progreso del proyecto ──────────────────────

class _ProjectProgressBar extends StatelessWidget {
  const _ProjectProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = progress.clamp(0, 100).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progreso del proyecto', style: theme.textTheme.labelMedium),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: progressColor(percent),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.1,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor(percent)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card de módulo ──────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.modulo, required this.projectId});

  final Modulo modulo;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (modulo.porcentCompletaModulo ?? 0).clamp(0, 100);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/projects/$projectId/modules/${modulo.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: folio + status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD71921).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      modulo.folioModulo,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFD71921),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!modulo.estatusModulo)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Inactivo',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Nombre
              Text(
                modulo.nombreModulo,
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const Spacer(),

              // Progreso
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 4,
                        backgroundColor: theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressColor(percent.toDouble()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
