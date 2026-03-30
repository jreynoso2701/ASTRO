import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/app_user.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/core/models/empresa.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Provider para cargar un usuario individual por UID.
final userByIdProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

/// Pantalla de detalle de usuario — muestra info + asignaciones.
class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByIdProvider(userId));
    final assignmentsAsync = ref.watch(userAssignmentsProvider(userId));
    final empresasAsync = ref.watch(activeEmpresasProvider);
    final proyectosAsync = ref.watch(activeProyectosProvider);
    final isViewerRoot = ref.watch(isCurrentUserRootProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DETALLE DE USUARIO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Usuario no encontrado'));
          }

          final width = MediaQuery.sizeOf(context).width;
          final isWide = width >= AppBreakpoints.medium;

          final infoSection = _UserInfoSection(
            user: user,
            onToggleActive: () => _toggleActive(ref, user),
            isViewerRoot: isViewerRoot,
            onEdit: () => _showEditDialog(context, ref, user),
          );

          final assignmentsSection = _AssignmentsSection(
            userId: userId,
            assignments: assignmentsAsync.value ?? [],
            empresas: empresasAsync.value ?? [],
            proyectos: proyectosAsync.value ?? [],
            isLoading: assignmentsAsync.isLoading,
            isViewerRoot: isViewerRoot,
            onAssign: () => context.push('/users/$userId/assign'),
            onDeactivate: (id) => _deactivateAssignment(ref, id),
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
                    child: assignmentsSection,
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
                assignmentsSection,
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleActive(WidgetRef ref, AppUser user) async {
    final repo = ref.read(userRepositoryProvider);
    if (user.isActive) {
      await repo.deactivateUser(user.uid);
    } else {
      await repo.activateUser(user.uid);
    }
  }

  Future<void> _deactivateAssignment(WidgetRef ref, String id) async {
    await ref
        .read(projectAssignmentRepositoryProvider)
        .deactivateAssignment(id);
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final nameController = TextEditingController(text: user.displayName);
    final phoneController = TextEditingController(text: user.phoneNumber ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final newName = nameController.text.trim();
      final newPhone = phoneController.text.trim();
      final nameChanged = newName.isNotEmpty && newName != user.displayName;
      final phoneChanged = newPhone != (user.phoneNumber ?? '');

      if (nameChanged || phoneChanged) {
        await ref
            .read(userRepositoryProvider)
            .updateProfile(
              user.uid,
              displayName: nameChanged ? newName : null,
              phoneNumber: phoneChanged ? newPhone : null,
            );
      }
    }

    nameController.dispose();
    phoneController.dispose();
  }
}

// ── Info Section ─────────────────────────────────────────

class _UserInfoSection extends StatelessWidget {
  const _UserInfoSection({
    required this.user,
    required this.onToggleActive,
    required this.isViewerRoot,
    required this.onEdit,
  });

  final AppUser user;
  final VoidCallback onToggleActive;
  final bool isViewerRoot;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = user.globalRole;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar + nombre
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: _roleColor(role).withValues(alpha: 0.15),
                child: Text(
                  _initials(user.displayName),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: _roleColor(role),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(user.displayName, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'INFORMACIÓN',
                      style: theme.textTheme.labelLarge?.copyWith(
                        letterSpacing: 1,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isViewerRoot)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: onEdit,
                        tooltip: 'Editar información',
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const Divider(height: 24),
                _InfoRow(label: 'Rol plataforma', value: role.label),
                if (user.phoneNumber != null)
                  _InfoRow(label: 'Teléfono', value: user.phoneNumber!),
                _InfoRow(
                  label: 'Estatus',
                  value: user.isActive ? 'Activo' : 'Inactivo',
                ),
                _InfoRow(
                  label: 'Registrado',
                  value: _formatDate(user.createdAt),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Actions — solo visible para Root
        if (isViewerRoot && !user.isRoot) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onToggleActive,
              icon: Icon(user.isActive ? Icons.person_off : Icons.person),
              label: Text(
                user.isActive ? 'Desactivar usuario' : 'Reactivar usuario',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: user.isActive
                    ? theme.colorScheme.error
                    : const Color(0xFF4CAF50),
              ),
            ),
          ),

          // Eliminar definitivamente — solo para usuarios desactivados
          if (!user.isActive)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _PermanentDeleteButton(user: user),
            ),
        ],
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0];
    return '?';
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
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

// ── Assignments Section ──────────────────────────────────

class _AssignmentsSection extends StatelessWidget {
  const _AssignmentsSection({
    required this.userId,
    required this.assignments,
    required this.empresas,
    required this.proyectos,
    required this.isLoading,
    required this.isViewerRoot,
    required this.onAssign,
    required this.onDeactivate,
  });

  final String userId;
  final List<ProjectAssignment> assignments;
  final List<Empresa> empresas;
  final List<Proyecto> proyectos;
  final bool isLoading;
  final bool isViewerRoot;
  final VoidCallback onAssign;
  final void Function(String id) onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ASIGNACIONES A PROYECTOS',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (isViewerRoot)
              FilledButton.icon(
                onPressed: onAssign,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Asignar'),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (assignments.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sin asignaciones',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Asigna este usuario a un proyecto para que pueda acceder.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...assignments.map((a) {
            final proyecto = proyectos
                .where((p) => p.id == a.projectId)
                .firstOrNull;
            final empresa = empresas
                .where((e) => e.id == a.empresaId)
                .firstOrNull;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.folder_outlined, color: _roleColor(a.role)),
                title: Text(proyecto?.nombreProyecto ?? a.projectId),
                subtitle: Text(
                  '${empresa?.nombreEmpresa ?? a.empresaId} · ${a.role.label}',
                ),
                trailing: isViewerRoot
                    ? IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: theme.colorScheme.error,
                        ),
                        tooltip: 'Desactivar asignación',
                        onPressed: () => _confirmDeactivate(context, a),
                      )
                    : null,
              ),
            );
          }),
      ],
    );
  }

  void _confirmDeactivate(BuildContext context, ProjectAssignment a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar asignación'),
        content: Text(
          '¿Remover la asignación de rol "${a.role.label}" en este proyecto?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDeactivate(a.id);
            },
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
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

// ── Botón de eliminación permanente ──────────────────────

class _PermanentDeleteButton extends ConsumerStatefulWidget {
  const _PermanentDeleteButton({required this.user});

  final AppUser user;

  @override
  ConsumerState<_PermanentDeleteButton> createState() =>
      _PermanentDeleteButtonState();
}

class _PermanentDeleteButtonState
    extends ConsumerState<_PermanentDeleteButton> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isDeleting ? null : () => _confirmDelete(context),
        icon: _isDeleting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.delete_forever),
        label: Text(_isDeleting ? 'Eliminando...' : 'Eliminar definitivamente'),
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final user = widget.user;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 48,
        ),
        title: const Text('Eliminar definitivamente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Eliminar permanentemente la cuenta de ${user.displayName}?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Esta acción es IRREVERSIBLE. Se realizará lo siguiente:',
            ),
            const SizedBox(height: 8),
            const Text('• Su nombre se anonimizará en todos los registros'),
            const Text('• Se eliminarán sus datos personales'),
            const Text('• Se eliminará su cuenta de autenticación'),
            const Text('• No podrá volver a acceder a la plataforma'),
            const SizedBox(height: 12),
            const Text(
              'Los archivos del proyecto se conservarán.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeDelete();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar permanentemente'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDelete() async {
    setState(() => _isDeleting = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'adminAnonymizeAndDeleteUser',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      await callable.call({'targetUid': widget.user.uid});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario eliminado permanentemente')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
