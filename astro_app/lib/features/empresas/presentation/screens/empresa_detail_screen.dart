import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/empresa.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de detalle de una empresa — muestra info, proyectos asociados
/// y acciones de gestión (editar, desactivar/reactivar).
class EmpresaDetailScreen extends ConsumerWidget {
  const EmpresaDetailScreen({required this.empresaId, super.key});

  final String empresaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresaAsync = ref.watch(empresaByIdProvider(empresaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de empresa'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          empresaAsync.whenOrNull(
                data: (empresa) {
                  if (empresa == null) return null;
                  return IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar',
                    onPressed: () => context.push('/empresas/$empresaId/edit'),
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: empresaAsync.when(
        data: (empresa) {
          if (empresa == null) {
            return const Center(child: Text('Empresa no encontrada'));
          }
          return _EmpresaDetailBody(empresa: empresa, ref: ref);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _EmpresaDetailBody extends StatelessWidget {
  const _EmpresaDetailBody({required this.empresa, required this.ref});

  final Empresa empresa;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proyectosAsync = ref.watch(allProyectosProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ── Header con logo ──
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: empresa.logoUrl != null
                    ? NetworkImage(empresa.logoUrl!)
                    : null,
                child: empresa.logoUrl == null
                    ? Text(
                        empresa.nombreEmpresa.isNotEmpty
                            ? empresa.nombreEmpresa[0].toUpperCase()
                            : '?',
                        style: theme.textTheme.headlineMedium,
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                empresa.nombreEmpresa,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      (empresa.isActive
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFD32F2F))
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  empresa.isActive ? 'Activa' : 'Inactiva',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: empresa.isActive
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFD32F2F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Información ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INFORMACIÓN',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (empresa.rfc != null)
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'RFC',
                    value: empresa.rfc!,
                  ),
                if (empresa.contacto != null)
                  _InfoTile(
                    icon: Icons.person_outline,
                    label: 'Contacto',
                    value: empresa.contacto!,
                  ),
                if (empresa.email != null)
                  _InfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: empresa.email!,
                  ),
                if (empresa.telefono != null)
                  _InfoTile(
                    icon: Icons.phone_outlined,
                    label: 'Teléfono',
                    value: empresa.telefono!,
                  ),
                if (empresa.direccion != null)
                  _InfoTile(
                    icon: Icons.location_on_outlined,
                    label: 'Dirección',
                    value: empresa.direccion!,
                  ),
                if (empresa.rfc == null &&
                    empresa.contacto == null &&
                    empresa.email == null &&
                    empresa.telefono == null &&
                    empresa.direccion == null)
                  Text(
                    'Sin información adicional registrada.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Proyectos asociados ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROYECTOS ASOCIADOS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                proyectosAsync.when(
                  data: (all) {
                    final mine =
                        all
                            .where(
                              (p) =>
                                  p.fkEmpresa == empresa.nombreEmpresa ||
                                  p.empresaId == empresa.id,
                            )
                            .toList()
                          ..sort((a, b) {
                            // Activos primero
                            if (a.estatusProyecto != b.estatusProyecto) {
                              return a.estatusProyecto ? -1 : 1;
                            }
                            return a.nombreProyecto.compareTo(b.nombreProyecto);
                          });
                    if (mine.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No hay proyectos asociados.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: mine
                          .map((p) => _ProyectoTile(proyecto: p))
                          .toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Acción desactivar / reactivar ──
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Icon(
              empresa.isActive
                  ? Icons.block_outlined
                  : Icons.check_circle_outline,
            ),
            label: Text(
              empresa.isActive ? 'Desactivar empresa' : 'Reactivar empresa',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: empresa.isActive
                  ? theme.colorScheme.error
                  : const Color(0xFF4CAF50),
              side: BorderSide(
                color: empresa.isActive
                    ? theme.colorScheme.error
                    : const Color(0xFF4CAF50),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _confirmToggleStatus(context, theme),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _confirmToggleStatus(BuildContext context, ThemeData theme) {
    if (empresa.isActive) {
      _confirmDeactivate(context, theme);
    } else {
      _confirmReactivate(context, theme);
    }
  }

  void _confirmDeactivate(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar empresa'),
        content: Text(
          'Se desactivará "${empresa.nombreEmpresa}" junto con '
          'todos sus proyectos activos y asignaciones de usuarios.\n\n'
          '¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(empresaRepositoryProvider);
              final count = await repo.deactivateEmpresaWithCascade(empresa);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Empresa desactivada · $count proyecto(s) desactivado(s)',
                    ),
                  ),
                );
              }
            },
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
  }

  void _confirmReactivate(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivar empresa'),
        content: Text(
          '¿Deseas reactivar "${empresa.nombreEmpresa}" '
          'y también reactivar todos sus proyectos asociados?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(empresaRepositoryProvider);
              await repo.activateEmpresaWithCascade(
                empresa,
                reactivateProjects: false,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Empresa reactivada (proyectos sin cambio)'),
                  ),
                );
              }
            },
            child: const Text('Solo empresa'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(empresaRepositoryProvider);
              final count = await repo.activateEmpresaWithCascade(
                empresa,
                reactivateProjects: true,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Empresa y $count proyecto(s) reactivado(s)'),
                  ),
                );
              }
            },
            child: const Text('Empresa + proyectos'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProyectoTile extends StatelessWidget {
  const _ProyectoTile({required this.proyecto});
  final Proyecto proyecto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = proyecto.estatusProyecto;
    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          child: Text(
            proyecto.folioProyecto.isNotEmpty
                ? proyecto.folioProyecto.substring(
                    0,
                    proyecto.folioProyecto.length.clamp(0, 2),
                  )
                : '?',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          proyecto.nombreProyecto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          proyecto.folioProyecto,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color:
                (proyecto.estatusProyecto
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFD32F2F))
                    .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            proyecto.estatusProyecto ? 'Activo' : 'Inactivo',
            style: theme.textTheme.labelSmall?.copyWith(
              color: proyecto.estatusProyecto
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFD32F2F),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => context.push('/projects/${proyecto.id}'),
      ),
    );
  }
}
