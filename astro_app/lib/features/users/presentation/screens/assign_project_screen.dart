import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/core/models/empresa.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';

/// Pantalla para asignar un usuario a un proyecto con un rol.
class AssignProjectScreen extends ConsumerStatefulWidget {
  const AssignProjectScreen({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<AssignProjectScreen> createState() =>
      _AssignProjectScreenState();
}

class _AssignProjectScreenState extends ConsumerState<AssignProjectScreen> {
  Empresa? _selectedEmpresa;
  Proyecto? _selectedProyecto;
  UserRole _selectedRole = UserRole.usuario;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empresasAsync = ref.watch(activeEmpresasProvider);
    final proyectosAsync = ref.watch(activeProyectosProvider);

    // Filtrar proyectos por empresa seleccionada
    final filteredProyectos = _selectedEmpresa == null
        ? <Proyecto>[]
        : (proyectosAsync.value ?? [])
              .where((p) => p.fkEmpresa == _selectedEmpresa!.nombreEmpresa)
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ASIGNAR A PROYECTO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/users/${widget.userId}'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instrucción
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Seleccione la empresa, proyecto y rol para asignar a este usuario.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Empresa ──
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

            const SizedBox(height: 24),

            // ── Proyecto ──
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

            const SizedBox(height: 24),

            // ── Rol ──
            Text('Rol en el proyecto:', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<UserRole>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(hintText: 'Seleccionar rol...'),
              items: [UserRole.supervisor, UserRole.usuario, UserRole.soporte]
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                  .toList(),
              onChanged: (role) {
                if (role != null) setState(() => _selectedRole = role);
              },
            ),

            const SizedBox(height: 16),

            // Descripción del rol
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _roleDescription(_selectedRole),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Botón Confirmar ──
            FilledButton.icon(
              onPressed:
                  _selectedEmpresa != null &&
                      _selectedProyecto != null &&
                      !_isSaving
                  ? _assignUser
                  : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Confirmar asignación'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignUser() async {
    if (_selectedEmpresa == null || _selectedProyecto == null) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(projectAssignmentRepositoryProvider);

      // Verificar si ya está asignado
      final alreadyAssigned = await repo.isUserAssigned(
        widget.userId,
        _selectedProyecto!.id,
      );

      if (!mounted) return;

      if (alreadyAssigned) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El usuario ya está asignado a este proyecto.'),
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      final currentUser = ref.read(authStateProvider).value;

      await repo.assignUserToProject(
        userId: widget.userId,
        projectId: _selectedProyecto!.id,
        empresaId: _selectedEmpresa!.id,
        role: _selectedRole,
        assignedBy: currentUser?.uid ?? '',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Usuario asignado a ${_selectedProyecto!.nombreProyecto} como ${_selectedRole.label}',
          ),
        ),
      );

      context.go('/users/${widget.userId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _roleDescription(UserRole role) {
    return switch (role) {
      UserRole.root => 'Acceso total a la plataforma.',
      UserRole.supervisor =>
        'Puede revisar el progreso de usuarios, ver la evolución del proyecto, reportar y dar seguimiento a todos los incidentes.',
      UserRole.usuario =>
        'Puede reportar sus propios incidentes, participar en requerimientos y juntas.',
      UserRole.soporte =>
        'Da soporte a los incidentes del proyecto. Puede operar en múltiples empresas, pero sin acciones destructivas.',
    };
  }
}
