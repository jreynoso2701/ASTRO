import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de detalle/dashboard de un proyecto.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectoAsync = ref.watch(proyectoByIdProvider(projectId));
    final members = ref.watch(projectMembersProvider(projectId));
    final isRoot = ref.watch(isCurrentUserRootProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROYECTO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/projects'),
        ),
        actions: [
          if (isRoot)
            proyectoAsync.whenOrNull(
                  data: (p) => p != null
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar proyecto',
                          onPressed: () =>
                              context.go('/projects/$projectId/edit'),
                        )
                      : null,
                ) ??
                const SizedBox.shrink(),
        ],
      ),
      body: proyectoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (proyecto) {
          if (proyecto == null) {
            return const Center(child: Text('Proyecto no encontrado'));
          }

          final empresaName = proyecto.fkEmpresa;

          final width = MediaQuery.sizeOf(context).width;
          final isWide = width >= AppBreakpoints.medium;

          final infoSection = _ProjectInfoSection(
            nombre: proyecto.nombreProyecto,
            folio: proyecto.folioProyecto,
            empresa: empresaName,
            descripcion: proyecto.descripcion,
            estatus: proyecto.estatusProyecto,
            isRoot: isRoot,
            onToggleStatus: () =>
                _toggleStatus(ref, proyecto.id, proyecto.estatusProyecto),
            progress: ref.watch(
              projectProgressProvider(proyecto.nombreProyecto),
            ),
            onModulesTap: () => context.go('/projects/$projectId/modules'),
            onTicketsTap: () => context.go('/projects/$projectId/tickets'),
            openTickets: ref.watch(openTicketCountProvider(projectId)),
          );

          final membersSection = _MembersSection(members: members);

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
                    child: membersSection,
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
                membersSection,
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleStatus(WidgetRef ref, String id, bool isActive) async {
    final repo = ref.read(proyectoRepositoryProvider);
    if (isActive) {
      await repo.deactivateProyecto(id);
    } else {
      await repo.activateProyecto(id);
    }
  }
}

// ── Info Section ─────────────────────────────────────────

class _ProjectInfoSection extends StatelessWidget {
  const _ProjectInfoSection({
    required this.nombre,
    required this.folio,
    required this.empresa,
    required this.estatus,
    required this.isRoot,
    required this.onToggleStatus,
    required this.progress,
    required this.onModulesTap,
    required this.onTicketsTap,
    required this.openTickets,
    this.descripcion,
  });

  final String nombre;
  final String folio;
  final String empresa;
  final String? descripcion;
  final bool estatus;
  final bool isRoot;
  final VoidCallback onToggleStatus;
  final double progress;
  final VoidCallback onModulesTap;
  final VoidCallback onTicketsTap;
  final int openTickets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
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
                  folio.isNotEmpty
                      ? folio.substring(0, folio.length.clamp(0, 3))
                      : '?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFD71921),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(nombre, style: theme.textTheme.titleLarge),
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
                  folio,
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

        // Info card
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
                const Divider(height: 24),
                _InfoRow(label: 'Empresa', value: empresa),
                _InfoRow(
                  label: 'Estatus',
                  value: estatus ? 'Activo' : 'Inactivo',
                ),
                if (descripcion != null && descripcion!.isNotEmpty)
                  _InfoRow(label: 'Descripción', value: descripcion!),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Progreso del proyecto
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PROGRESO',
                      style: theme.textTheme.labelLarge?.copyWith(
                        letterSpacing: 1,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${progress.clamp(0, 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: progress >= 100
                            ? Colors.green
                            : const Color(0xFFD71921),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 100) / 100,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.1,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressColor(progress),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Botón de módulos
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onModulesTap,
            icon: const Icon(Icons.view_module_outlined),
            label: const Text('Ver módulos'),
          ),
        ),

        const SizedBox(height: 8),

        // Botón de tickets
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onTicketsTap,
            icon: Badge(
              isLabelVisible: openTickets > 0,
              label: Text('$openTickets'),
              child: const Icon(Icons.confirmation_num_outlined),
            ),
            label: const Text('Ver tickets'),
          ),
        ),

        const SizedBox(height: 16),

        // Actions — solo Root
        if (isRoot)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onToggleStatus,
              icon: Icon(
                estatus
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
              label: Text(
                estatus ? 'Desactivar proyecto' : 'Reactivar proyecto',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: estatus
                    ? theme.colorScheme.error
                    : const Color(0xFF4CAF50),
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// ── Members Section ──────────────────────────────────────

class _MembersSection extends StatelessWidget {
  const _MembersSection({required this.members});

  final List<({dynamic assignment, dynamic user})> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EQUIPO DEL PROYECTO',
          style: theme.textTheme.labelLarge?.copyWith(
            letterSpacing: 1,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${members.length} miembro${members.length != 1 ? 's' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),

        if (members.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sin miembros asignados',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...members.map((m) {
            final assignment = m.assignment;
            final user = m.user;
            final name = user?.displayName ?? assignment.userId;
            final email = user?.email ?? '';
            final role = assignment.role as UserRole;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _roleColor(role).withValues(alpha: 0.15),
                  radius: 20,
                  child: Text(
                    _initials(name),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _roleColor(role),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '$email · ${role.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: _RoleBadge(role: role),
              ),
            );
          }),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0];
    return '?';
  }

  static Color _roleColor(UserRole role) {
    return switch (role) {
      UserRole.root => const Color(0xFFD71921),
      UserRole.supervisor => const Color(0xFF2196F3),
      UserRole.soporte => const Color(0xFFFFC107),
      UserRole.usuario => const Color(0xFF4CAF50),
    };
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = _MembersSection._roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
