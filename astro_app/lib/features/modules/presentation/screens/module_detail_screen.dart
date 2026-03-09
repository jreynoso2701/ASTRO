import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/core/models/funcionalidad.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/modules/providers/funcionalidad_providers.dart';
import 'package:astro/features/modules/presentation/widgets/funcionalidad_form_dialog.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de detalle de un módulo.
class ModuleDetailScreen extends ConsumerWidget {
  const ModuleDetailScreen({
    required this.projectId,
    required this.moduleId,
    super.key,
  });

  final String projectId;
  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moduloAsync = ref.watch(moduloByIdProvider(moduleId));
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final canManage = ref.watch(canManageProjectProvider(projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('MÓDULO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/projects/$projectId/modules');
          },
        ),
        actions: [
          if (canManage)
            moduloAsync.whenOrNull(
                  data: (m) => m != null
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar módulo',
                          onPressed: () => context.go(
                            '/projects/$projectId/modules/${m.id}/edit',
                          ),
                        )
                      : null,
                ) ??
                const SizedBox.shrink(),
        ],
      ),
      body: moduloAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (modulo) {
          if (modulo == null) {
            return const Center(child: Text('Módulo no encontrado'));
          }

          final theme = Theme.of(context);
          final percent = (modulo.porcentCompletaModulo ?? 0)
              .clamp(0, 100)
              .toDouble();
          final width = MediaQuery.sizeOf(context).width;
          final isWide = width >= AppBreakpoints.medium;

          final infoSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(
                        0xFFD71921,
                      ).withValues(alpha: 0.15),
                      child: Text(
                        modulo.folioModulo.isNotEmpty
                            ? modulo.folioModulo.substring(
                                0,
                                modulo.folioModulo.length.clamp(0, 3),
                              )
                            : '?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFD71921),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      modulo.nombreModulo,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD71921).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        modulo.folioModulo,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFFD71921),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Status
              _InfoRow(
                label: 'Estatus',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: modulo.estatusModulo
                        ? Colors.green.withValues(alpha: 0.15)
                        : theme.colorScheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    modulo.estatusModulo ? 'Activo' : 'Inactivo',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: modulo.estatusModulo
                          ? Colors.green
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Proyecto
              _InfoRow(
                label: 'Proyecto',
                child: Text(
                  modulo.fkProyecto,
                  style: theme.textTheme.bodyMedium,
                ),
              ),

              if (modulo.descripcion != null &&
                  modulo.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Descripción',
                  child: Text(
                    modulo.descripcion!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Progreso
              Text('Progreso', style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              _ProgressSection(percent: percent),

              // Root: toggle status
              if (isRoot) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () =>
                      _toggleStatus(ref, modulo.id, modulo.estatusModulo),
                  icon: Icon(
                    modulo.estatusModulo
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  label: Text(
                    modulo.estatusModulo ? 'Desactivar' : 'Reactivar',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ],
            ],
          );

          // Activar auto-sync de progreso del módulo.
          ref.watch(moduleProgressSyncProvider(moduleId));

          final funcsAsync = ref.watch(
            funcionalidadesByModuleProvider(moduleId),
          );

          // Sección de funcionalidades — checklist real
          final functionalitiesSection = _FuncionalidadesSection(
            moduleId: moduleId,
            funcsAsync: funcsAsync,
            canManage: canManage,
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: infoSection,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: functionalitiesSection,
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoSection,
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                functionalitiesSection,
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleStatus(WidgetRef ref, String id, bool isActive) async {
    final repo = ref.read(moduloRepositoryProvider);
    if (isActive) {
      await repo.deactivateModulo(id);
    } else {
      await repo.activateModulo(id);
    }
  }
}

// ── Helpers ──────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

// ── Sección de funcionalidades ──────────────────────────

class _FuncionalidadesSection extends ConsumerWidget {
  const _FuncionalidadesSection({
    required this.moduleId,
    required this.funcsAsync,
    required this.canManage,
  });

  final String moduleId;
  final AsyncValue<List<Funcionalidad>> funcsAsync;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text('Funcionalidades', style: theme.textTheme.titleSmall),
            const Spacer(),
            if (canManage)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22),
                tooltip: 'Agregar funcionalidad',
                onPressed: () => _showCreateDialog(context, ref),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Progreso mini
        funcsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (funcs) {
            final active = funcs.where((f) => f.estatus).toList();
            final inactive = funcs.where((f) => !f.estatus).toList();
            final completed = active.where((f) => f.completada).length;
            final total = active.length;

            if (total == 0) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.checklist_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sin funcionalidades',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      if (canManage) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _showCreateDialog(context, ref),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Agregar primera'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de progreso + contador
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total > 0 ? completed / total : 0,
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor(
                              total > 0 ? (completed / total) * 100 : 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$completed / $total',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Lista de funcionalidades
                ...active.map(
                  (func) => _FuncionalidadTile(
                    func: func,
                    moduleId: moduleId,
                    canManage: canManage,
                  ),
                ),

                // Inactivas (solo para quien gestiona)
                if (canManage && inactive.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Inactivas (${inactive.length})',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...inactive.map(
                    (func) => _FuncionalidadTile(
                      func: func,
                      moduleId: moduleId,
                      canManage: canManage,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final funcs =
        ref.read(funcionalidadesByModuleProvider(moduleId)).value ?? [];
    final nextOrder = funcs.isEmpty
        ? 0
        : funcs.map((f) => f.orden).reduce((a, b) => a > b ? a : b) + 1;

    final result = await showDialog<Funcionalidad>(
      context: context,
      builder: (_) => FuncionalidadFormDialog(nextOrder: nextOrder),
    );

    if (result != null) {
      await ref.read(funcionalidadRepositoryProvider).create(moduleId, result);
    }
  }
}

// ── Tile de funcionalidad individual ────────────────────

class _FuncionalidadTile extends ConsumerWidget {
  const _FuncionalidadTile({
    required this.func,
    required this.moduleId,
    required this.canManage,
  });

  final Funcionalidad func;
  final String moduleId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(funcionalidadRepositoryProvider);
    final isInactive = !func.estatus;

    return Opacity(
      opacity: isInactive ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: InkWell(
          onTap: canManage ? () => _showEditDialog(context, ref) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            child: Row(
              children: [
                // Checkbox (Root puede toggle; otros solo ven)
                Checkbox(
                  value: func.completada,
                  onChanged: canManage && !isInactive
                      ? (val) => repo.toggleCompletada(
                          moduleId,
                          func.id,
                          val ?? false,
                        )
                      : null,
                  activeColor: const Color(0xFFD71921),
                ),
                // Nombre + descripción
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        func.nombre,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          decoration: func.completada
                              ? TextDecoration.lineThrough
                              : null,
                          color: func.completada
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                )
                              : null,
                        ),
                      ),
                      if (func.descripcion != null &&
                          func.descripcion!.isNotEmpty)
                        Text(
                          func.descripcion!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Root: popup menu
                if (canManage)
                  PopupMenuButton<String>(
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(
                        value: 'toggle_status',
                        child: Text(isInactive ? 'Reactivar' : 'Desactivar'),
                      ),
                    ],
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          _showEditDialog(context, ref);
                        case 'toggle_status':
                          if (isInactive) {
                            repo.activate(moduleId, func.id);
                          } else {
                            repo.deactivate(moduleId, func.id);
                          }
                      }
                    },
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Funcionalidad>(
      context: context,
      builder: (_) => FuncionalidadFormDialog(funcionalidad: func),
    );

    if (result != null) {
      await ref.read(funcionalidadRepositoryProvider).update(moduleId, result);
    }
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Gran número de porcentaje
        Center(
          child: Text(
            '${percent.toStringAsFixed(0)}%',
            style: theme.textTheme.displaySmall?.copyWith(
              color: progressColor(percent),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 10,
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor(percent)),
          ),
        ),
      ],
    );
  }
}
