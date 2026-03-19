import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/core/models/app_user.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/documentation/providers/documento_providers.dart';
import 'package:astro/features/minutas/providers/minuta_providers.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/features/tareas/providers/tarea_providers.dart';

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
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isRoot)
            proyectoAsync.whenOrNull(
                  data: (p) => p != null
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar proyecto',
                          onPressed: () =>
                              context.push('/projects/$projectId/edit'),
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
            onModulesTap: () => context.push('/projects/$projectId/modules'),
            onTicketsTap: () => context.push('/projects/$projectId/tickets'),
            openTickets: ref.watch(openTicketCountProvider(projectId)),
            onRequirementsTap: () =>
                context.push('/projects/$projectId/requirements'),
            pendingReqs: ref.watch(pendingReqCountProvider(projectId)),
            onDocumentsTap: () =>
                context.push('/projects/$projectId/documents'),
            formalDocCount: ref.watch(formalDocCountProvider(projectId)),
            onMinutasTap: () => context.push('/projects/$projectId/minutas'),
            minutaCount: ref.watch(minutaCountProvider(projectId)),
            onCitasTap: () => context.push('/projects/$projectId/citas'),
            citasProgramadas: ref.watch(
              citasProgramadasCountProvider(projectId),
            ),
            onTareasTap: () => context.push('/projects/$projectId/tareas'),
            pendingTareas: ref.watch(pendingTareaCountProvider(projectId)),
            onNotifSettingsTap: isRoot
                ? () =>
                      context.push('/projects/$projectId/notification-settings')
                : null,
          );

          final membersSection = _MembersSection(
            members: members,
            projectId: projectId,
            isRoot: isRoot,
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
    required this.onRequirementsTap,
    required this.pendingReqs,
    required this.onDocumentsTap,
    required this.formalDocCount,
    required this.onMinutasTap,
    required this.minutaCount,
    required this.onCitasTap,
    required this.citasProgramadas,
    required this.onTareasTap,
    required this.pendingTareas,
    this.onNotifSettingsTap,
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
  final VoidCallback onRequirementsTap;
  final int pendingReqs;
  final VoidCallback onDocumentsTap;
  final int formalDocCount;
  final VoidCallback onMinutasTap;
  final int minutaCount;
  final VoidCallback onCitasTap;
  final int citasProgramadas;
  final VoidCallback onTareasTap;
  final int pendingTareas;
  final VoidCallback? onNotifSettingsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Botones de navegación deshabilitados si el proyecto está inactivo.
    final enabled = estatus;

    return Column(
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
                  folio.isNotEmpty
                      ? folio.substring(0, folio.length.clamp(0, 3))
                      : '?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  folio,
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
                        color: progressColor(progress),
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

        // Banner de proyecto inactivo
        if (!estatus)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Proyecto inactivo — no se pueden crear nuevos elementos.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Botón de módulos
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onModulesTap : null,
            icon: const Icon(Icons.view_module_outlined),
            label: const Text('Ver módulos'),
          ),
        ),

        const SizedBox(height: 8),

        // Botón de tickets
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onTicketsTap : null,
            icon: Badge(
              isLabelVisible: openTickets > 0,
              label: Text('$openTickets'),
              child: const Icon(Icons.confirmation_num_outlined),
            ),
            label: const Text('Ver tickets'),
          ),
        ),

        const SizedBox(height: 8),

        // Botón de requerimientos
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onRequirementsTap : null,
            icon: Badge(
              isLabelVisible: pendingReqs > 0,
              label: Text('$pendingReqs'),
              child: const Icon(Icons.assignment_outlined),
            ),
            label: const Text('Ver requerimientos'),
          ),
        ),

        const SizedBox(height: 8),

        // Botón de documentación
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onDocumentsTap : null,
            icon: Badge(
              isLabelVisible: formalDocCount > 0,
              label: Text('$formalDocCount'),
              child: const Icon(Icons.folder_outlined),
            ),
            label: const Text('Ver documentación'),
          ),
        ),

        const SizedBox(height: 8),

        // Botón de minutas
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onMinutasTap : null,
            icon: Badge(
              isLabelVisible: minutaCount > 0,
              label: Text('$minutaCount'),
              child: const Icon(Icons.description_outlined),
            ),
            label: const Text('Ver minutas'),
          ),
        ),

        const SizedBox(height: 8),

        // Botón de citas
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onCitasTap : null,
            icon: Badge(
              isLabelVisible: citasProgramadas > 0,
              label: Text('$citasProgramadas'),
              child: const Icon(Icons.event_outlined),
            ),
            label: const Text('Ver citas'),
          ),
        ),

        const SizedBox(height: 8),

        // Botón de tareas
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onTareasTap : null,
            icon: Badge(
              isLabelVisible: pendingTareas > 0,
              label: Text('$pendingTareas'),
              child: const Icon(Icons.task_outlined),
            ),
            label: const Text('Ver tareas'),
          ),
        ),

        // Botón de notificaciones (solo Root)
        if (isRoot && onNotifSettingsTap != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onNotifSettingsTap,
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Configurar notificaciones'),
            ),
          ),
        ],

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

class _MembersSection extends ConsumerWidget {
  const _MembersSection({
    required this.members,
    required this.projectId,
    required this.isRoot,
  });

  final List<({dynamic assignment, dynamic user})> members;
  final String projectId;
  final bool isRoot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
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
                ],
              ),
            ),
            if (isRoot)
              FilledButton.icon(
                onPressed: () => _showAddMemberDialog(context, ref),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Agregar'),
              ),
          ],
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
                trailing: isRoot && role != UserRole.root
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RoleBadge(role: role),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            tooltip: 'Opciones',
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showEditRoleDialog(
                                  context,
                                  ref,
                                  assignment,
                                  name,
                                );
                              } else if (value == 'remove') {
                                _showRemoveMemberDialog(
                                  context,
                                  ref,
                                  assignment,
                                  name,
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined, size: 20),
                                  title: Text('Cambiar rol'),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.person_remove_outlined,
                                    size: 20,
                                    color: Color(0xFFD32F2F),
                                  ),
                                  title: Text(
                                    'Quitar del proyecto',
                                    style: TextStyle(color: Color(0xFFD32F2F)),
                                  ),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : _RoleBadge(role: role),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _showAddMemberDialog(BuildContext context, WidgetRef ref) async {
    final allUsers = ref.read(allUsersProvider).value ?? [];
    final existingUserIds = members
        .map((m) => m.assignment.userId as String)
        .toSet();
    final availableUsers = allUsers
        .where((u) => u.isActive && !existingUserIds.contains(u.uid))
        .toList();

    if (!context.mounted) return;

    final result = await showDialog<({String userId, UserRole role})>(
      context: context,
      builder: (ctx) => _AddMemberDialog(availableUsers: availableUsers),
    );

    if (result == null || !context.mounted) return;

    final proyecto = ref.read(proyectoByIdProvider(projectId)).value;
    final currentUser = ref.read(currentUserProfileProvider).value;
    if (proyecto == null || currentUser == null) return;

    await ref
        .read(projectAssignmentRepositoryProvider)
        .assignUserToProject(
          userId: result.userId,
          projectId: projectId,
          empresaId: proyecto.fkEmpresa,
          role: result.role,
          assignedBy: currentUser.uid,
        );
  }

  Future<void> _showEditRoleDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic assignment,
    String memberName,
  ) async {
    final currentRole = assignment.role as UserRole;
    UserRole selectedRole = currentRole;

    final newRole = await showDialog<UserRole>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final theme = Theme.of(ctx);
            // Roles asignables (excluir Root)
            final assignableRoles = [
              UserRole.usuario,
              UserRole.supervisor,
              UserRole.soporte,
            ];

            return AlertDialog(
              title: const Text('Cambiar rol'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(memberName, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Nuevo rol',
                      prefixIcon: Icon(Icons.shield_outlined),
                    ),
                    items: assignableRoles
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.label)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedRole = v);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: selectedRole == currentRole
                      ? null
                      : () => Navigator.pop(ctx, selectedRole),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newRole == null || !context.mounted) return;

    await ref
        .read(projectAssignmentRepositoryProvider)
        .updateRole(assignment.id as String, newRole);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rol de $memberName actualizado a ${newRole.label}'),
        ),
      );
    }
  }

  Future<void> _showRemoveMemberDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic assignment,
    String memberName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar miembro'),
        content: Text(
          '¿Estás seguro de quitar a $memberName del proyecto?\n\n'
          'El usuario perderá acceso a este proyecto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref
        .read(projectAssignmentRepositoryProvider)
        .deactivateAssignment(assignment.id as String);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$memberName fue removido del proyecto')),
      );
    }
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

// ── Add Member Dialog ───────────────────────────────────────

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({required this.availableUsers});

  final List<AppUser> availableUsers;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  AppUser? _selectedUser;
  UserRole _selectedRole = UserRole.usuario;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _search.isEmpty
        ? widget.availableUsers
        : widget.availableUsers.where((u) {
            final q = _search.toUpperCase();
            return u.displayName.toUpperCase().contains(q) ||
                u.email.toUpperCase().contains(q);
          }).toList();

    return AlertDialog(
      title: const Text('Agregar miembro'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Búsqueda
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar usuario...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 12),

            // Lista de usuarios
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _search.isEmpty
                      ? 'No hay usuarios disponibles para asignar.'
                      : 'Sin resultados.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final user = filtered[i];
                    final selected = _selectedUser?.uid == user.uid;
                    return ListTile(
                      selected: selected,
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0]
                              : '?',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      title: Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      dense: true,
                      onTap: () => setState(() => _selectedUser = user),
                    );
                  },
                ),
              ),

            if (_selectedUser != null) ...[
              const Divider(height: 24),
              // Selector de rol
              DropdownButtonFormField<UserRole>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
                items: [UserRole.usuario, UserRole.supervisor, UserRole.soporte]
                    .map(
                      (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedRole = v);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selectedUser == null
              ? null
              : () => Navigator.pop(context, (
                  userId: _selectedUser!.uid,
                  role: _selectedRole,
                )),
          child: const Text('Asignar'),
        ),
      ],
    );
  }
}
