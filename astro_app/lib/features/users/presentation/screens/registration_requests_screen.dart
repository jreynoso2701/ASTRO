import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/models/app_user.dart';
import 'package:astro/core/models/empresa.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de administración de solicitudes de registro (solo Root).
///
/// Muestra usuarios pendientes de aprobación con opción de aprobar
/// (asignar proyecto/rol) o rechazar (con justificación).
class RegistrationRequestsScreen extends ConsumerWidget {
  const RegistrationRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pendingAsync = ref.watch(pendingUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOLICITUDES DE REGISTRO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/gestion');
            }
          },
        ),
      ),
      body: pendingAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sin solicitudes pendientes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todas las solicitudes han sido procesadas.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // Ordenar por fecha de registro (más antiguo primero)
          final sorted = [...users]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _RequestCard(user: sorted[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hoursSince = DateTime.now().difference(user.createdAt).inHours;
    final isOverdue = hoursSince >= 24;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: theme.textTheme.titleLarge,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName.isNotEmpty
                            ? user.displayName
                            : user.email,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (user.displayName.isNotEmpty)
                        Text(
                          user.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                // Badge tiempo transcurrido
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? theme.colorScheme.error.withValues(alpha: 0.15)
                        : theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatTimeSince(hoursSince),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isOverdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context, ref),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showApproveDialog(context, ref),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Aprobar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeSince(int hours) {
    if (hours < 1) return 'Hace momentos';
    if (hours < 24) return 'Hace ${hours}h';
    final days = hours ~/ 24;
    return 'Hace ${days}d ${hours % 24}h';
  }

  // ── Rechazar ───────────────────────────────

  void _showRejectDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se notificará a ${user.displayName.isNotEmpty ? user.displayName : user.email} '
                'que su solicitud no fue aprobada.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Justificación (obligatoria)',
                  hintText: 'Escribe el motivo del rechazo...',
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'La justificación es obligatoria';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await _rejectUser(context, ref, reasonController.text.trim());
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectUser(
    BuildContext context,
    WidgetRef ref,
    String reason,
  ) async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.rejectUser(uid: user.uid, reason: reason);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Solicitud de ${user.displayName.isNotEmpty ? user.displayName : user.email} rechazada',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Aprobar ────────────────────────────────

  void _showApproveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _ApproveDialog(user: user),
    );
  }
}

// ── Diálogo de aprobación con asignación de proyecto/rol ──

class _ApproveDialog extends ConsumerStatefulWidget {
  const _ApproveDialog({required this.user});

  final AppUser user;

  @override
  ConsumerState<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends ConsumerState<_ApproveDialog> {
  Empresa? _selectedEmpresa;
  Proyecto? _selectedProyecto;
  UserRole _selectedRole = UserRole.usuario;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empresasAsync = ref.watch(activeEmpresasProvider);
    final proyectosAsync = ref.watch(activeProyectosProvider);
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width >= AppBreakpoints.compact ? 480.0 : width * 0.9;

    final filteredProyectos = _selectedEmpresa == null
        ? <Proyecto>[]
        : (proyectosAsync.value ?? [])
              .where((p) => p.fkEmpresa == _selectedEmpresa!.nombreEmpresa)
              .toList();

    return AlertDialog(
      title: Text(
        'Aprobar a ${widget.user.displayName.isNotEmpty ? widget.user.displayName : widget.user.email}',
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Asigna al menos un proyecto y rol para completar '
                'la aprobación.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Empresa
              Text('Empresa:', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              empresasAsync.when(
                data: (empresas) => DropdownButtonFormField<Empresa>(
                  initialValue: _selectedEmpresa,
                  decoration: const InputDecoration(
                    hintText: 'Seleccionar empresa...',
                  ),
                  items: empresas
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.nombreEmpresa),
                        ),
                      )
                      .toList(),
                  onChanged: (empresa) {
                    setState(() {
                      _selectedEmpresa = empresa;
                      _selectedProyecto = null;
                    });
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 16),

              // Proyecto
              Text('Proyecto:', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<Proyecto>(
                key: ValueKey(_selectedEmpresa?.id),
                initialValue: _selectedProyecto,
                decoration: const InputDecoration(
                  hintText: 'Seleccionar proyecto...',
                ),
                items: filteredProyectos
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.folioProyecto} — ${p.nombreProyecto}'),
                      ),
                    )
                    .toList(),
                onChanged: _selectedEmpresa == null
                    ? null
                    : (proyecto) {
                        setState(() => _selectedProyecto = proyecto);
                      },
              ),
              const SizedBox(height: 16),

              // Rol
              Text('Rol:', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<UserRole>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  hintText: 'Seleccionar rol...',
                ),
                items: [UserRole.supervisor, UserRole.usuario, UserRole.soporte]
                    .map(
                      (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                    )
                    .toList(),
                onChanged: (role) {
                  if (role != null) setState(() => _selectedRole = role);
                },
              ),
              const SizedBox(height: 8),
              Text(
                _roleHint(_selectedRole),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed:
              _selectedEmpresa != null &&
                  _selectedProyecto != null &&
                  !_isSaving
              ? _approve
              : null,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 18),
          label: const Text('Aprobar'),
        ),
      ],
    );
  }

  String _roleHint(UserRole role) {
    switch (role) {
      case UserRole.supervisor:
        return 'Puede ver progreso de usuarios y todos los incidentes del proyecto.';
      case UserRole.soporte:
        return 'Da soporte a incidentes y levanta requerimientos.';
      case UserRole.usuario:
        return 'Reporta sus propios incidentes y participa en requerimientos.';
      case UserRole.root:
        return 'Control total (se asigna desde la gestión de usuarios).';
    }
  }

  Future<void> _approve() async {
    setState(() => _isSaving = true);

    try {
      final userRepo = ref.read(userRepositoryProvider);
      final assignRepo = ref.read(projectAssignmentRepositoryProvider);
      final currentUid = ref.read(authStateProvider).value?.uid ?? '';

      // 1. Aprobar el registro.
      await userRepo.approveUser(
        uid: widget.user.uid,
        approvedByUid: currentUid,
      );

      // 2. Asignar al proyecto con el rol seleccionado.
      await assignRepo.assignUserToProject(
        userId: widget.user.uid,
        projectId: _selectedProyecto!.id,
        empresaId: _selectedEmpresa!.id,
        role: _selectedRole,
        assignedBy: currentUid,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.user.displayName} aprobado y asignado a '
              '${_selectedProyecto!.nombreProyecto}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
