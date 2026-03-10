import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de listado de proyectos — todos los roles ven sus proyectos.
class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectosAsync = ref.watch(activeProyectosProvider);
    final searchQuery = ref.watch(projectSearchProvider);
    final filteredProjects = ref.watch(filteredProjectsProvider);
    final isRoot = ref.watch(isCurrentUserRootProvider);

    return SafeArea(
      child: Column(
        children: [
          // ── Header + Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PROYECTOS',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (isRoot)
                      FilledButton.icon(
                        onPressed: () => context.push('/projects/new'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nuevo'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, folio o empresa...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => ref
                                .read(projectSearchProvider.notifier)
                                .clear(),
                          )
                        : null,
                  ),
                  onChanged: (v) =>
                      ref.read(projectSearchProvider.notifier).setQuery(v),
                ),
              ],
            ),
          ),

          // ── Count ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: proyectosAsync.when(
                data: (_) => Text(
                  '${filteredProjects.length} proyecto${filteredProjects.length != 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Grid / List ──
          Expanded(
            child: proyectosAsync.when(
              data: (_) => _ProjectListContent(projects: filteredProjects),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error al cargar proyectos: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectListContent extends StatelessWidget {
  const _ProjectListContent({required this.projects});

  final List<Proyecto> projects;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No se encontraron proyectos',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;

    if (width >= AppBreakpoints.medium) {
      final crossAxisCount = adaptiveGridColumns(width);
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 130,
        ),
        itemCount: projects.length,
        itemBuilder: (context, index) => _ProjectCard(project: projects[index]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ProjectCard(project: projects[index]),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Proyecto project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/projects/${project.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Folio + status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),
                    child: Text(
                      project.folioProyecto,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    project.estatusProyecto
                        ? Icons.circle
                        : Icons.circle_outlined,
                    size: 10,
                    color: project.estatusProyecto
                        ? const Color(0xFF4CAF50)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    project.estatusProyecto ? 'Activo' : 'Inactivo',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: project.estatusProyecto
                          ? const Color(0xFF4CAF50)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Nombre
              Text(
                project.nombreProyecto,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Empresa
              Row(
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      project.fkEmpresa,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              // Descripción si hay
              if (project.descripcion != null &&
                  project.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  project.descripcion!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
