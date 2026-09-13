import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/constants/app_colors.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/core/widgets/animated_progress_bar.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/gestion');
      },
      child: SafeArea(
        child: Column(
          children: [
            // ── Header + Search ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.go('/gestion'),
                        tooltip: 'Volver a Gestión',
                      ),
                      Expanded(
                        child: Text(
                          'PROYECTOS',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
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
                  const SizedBox(height: 12),
                  const _ProjectFilterBar(),
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
      ),
    );
  }
}

/// Ordenamiento y filtro por empresa, en una sola fila desplazable para que
/// quepan ambos también en móvil.
class _ProjectFilterBar extends ConsumerWidget {
  const _ProjectFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(projectListSortProvider);
    final empresa = ref.watch(projectEmpresaFilterProvider);
    final empresas = ref.watch(projectEmpresasProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          PopupMenuButton<ProjectListSort>(
            initialValue: sort,
            onSelected: ref.read(projectListSortProvider.notifier).set,
            itemBuilder: (_) => [
              for (final s in ProjectListSort.values)
                PopupMenuItem(value: s, child: Text(s.label)),
            ],
            child: Chip(
              avatar: const Icon(Icons.swap_vert, size: 18),
              label: Text(sort.label),
            ),
          ),
          if (empresas.length > 1) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String?>(
              initialValue: empresa,
              onSelected: ref.read(projectEmpresaFilterProvider.notifier).set,
              itemBuilder: (_) => [
                const PopupMenuItem<String?>(
                  value: null,
                  child: Text('Todas las empresas'),
                ),
                for (final e in empresas)
                  PopupMenuItem<String?>(value: e, child: Text(e)),
              ],
              child: Chip(
                avatar: const Icon(Icons.business_outlined, size: 18),
                label: Text(empresa ?? 'Todas las empresas'),
                onDeleted: empresa == null
                    ? null
                    : () => ref
                          .read(projectEmpresaFilterProvider.notifier)
                          .set(null),
              ),
            ),
          ],
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
          mainAxisExtent: 190,
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

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});

  final Proyecto project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(projectProgressProvider(project.nombreProyecto));
    // Un proyecto sin modulos no esta al 0%: no tiene avance que medir.
    final hasModules = ref.watch(
      projectHasModulesProvider(project.nombreProyecto),
    );
    // Peso en crudo de los tickets abiertos; la resta al porcentaje queda
    // diluida entre los modulos y no se aprecia.
    final pendingWeight = ref.watch(
      projectPendingWeightProvider(project.nombreProyecto),
    );
    final leads = ref.watch(projectLeadNamesProvider(project.id));
    final activeColor = project.estatusProyecto
        ? AppColors.success
        : theme.colorScheme.onSurfaceVariant;

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
                    color: activeColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    project.estatusProyecto ? 'Activo' : 'Inactivo',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: activeColor,
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

              // Responsables principales
              if (leads.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        leads.join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),
              if (!hasModules)
                Text(
                  'Sin módulos',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else ...[
                ProgressSummary(percent: progress),
                if (pendingWeight >= 1) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 12,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Pendiente ${pendingWeight.toStringAsFixed(0)} pts por tickets',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.warning,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
