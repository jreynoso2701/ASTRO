import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
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
            context.pop();
          },
        ),
        actions: [
          if (canManage)
            moduloAsync.whenOrNull(
                  data: (m) => m != null
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar módulo',
                          onPressed: () => context.push(
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
                      backgroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                      child: Text(
                        modulo.folioModulo.isNotEmpty
                            ? modulo.folioModulo.substring(
                                0,
                                modulo.folioModulo.length.clamp(0, 3),
                              )
                            : '?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        modulo.folioModulo,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
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

              // Progreso — editable para Root/Soporte
              Text('Progreso', style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              _ProgressSection(
                percent: percent,
                canManage: canManage,
                moduleId: modulo.id,
              ),

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

          if (isWide) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: infoSection,
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: infoSection,
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

class _ProgressSection extends ConsumerStatefulWidget {
  const _ProgressSection({
    required this.percent,
    required this.canManage,
    required this.moduleId,
  });

  final double percent;
  final bool canManage;
  final String moduleId;

  @override
  ConsumerState<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends ConsumerState<_ProgressSection> {
  late double _value;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _value = widget.percent;
  }

  @override
  void didUpdateWidget(_ProgressSection old) {
    super.didUpdateWidget(old);
    if (!_editing) _value = widget.percent;
  }

  Future<void> _save() async {
    final rounded = _value.roundToDouble();
    await ref
        .read(moduloRepositoryProvider)
        .updateProgress(widget.moduleId, rounded);
    if (mounted) {
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Progreso actualizado a ${rounded.toInt()}%')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayPercent = _value.clamp(0, 100).toDouble();

    return Column(
      children: [
        // Gran número de porcentaje
        Center(
          child: Text(
            '${displayPercent.toStringAsFixed(0)}%',
            style: theme.textTheme.displaySmall?.copyWith(
              color: progressColor(displayPercent),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: displayPercent / 100,
            minHeight: 10,
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              progressColor(displayPercent),
            ),
          ),
        ),
        if (widget.canManage) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('0%'),
              Expanded(
                child: Slider(
                  value: displayPercent,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '${displayPercent.toStringAsFixed(0)}%',
                  onChanged: (v) => setState(() {
                    _editing = true;
                    _value = v;
                  }),
                  onChangeEnd: (_) => _save(),
                ),
              ),
              const Text('100%'),
            ],
          ),
        ],
      ],
    );
  }
}
