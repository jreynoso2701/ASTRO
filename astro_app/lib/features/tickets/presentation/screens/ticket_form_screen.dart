import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de creación / edición de ticket.
class TicketFormScreen extends ConsumerStatefulWidget {
  const TicketFormScreen({required this.projectId, this.ticketId, super.key});

  final String projectId;
  final String? ticketId;

  @override
  ConsumerState<TicketFormScreen> createState() => _TicketFormScreenState();
}

class _TicketFormScreenState extends ConsumerState<TicketFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();

  String? _selectedModuleId;
  String _selectedModuleName = '';
  TicketPriority _priority = TicketPriority.media;

  bool _isSaving = false;
  bool _isLoaded = false;

  bool get _isEditing => widget.ticketId != null;

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proyectoAsync = ref.watch(proyectoByIdProvider(widget.projectId));
    final projectName = proyectoAsync.value?.nombreProyecto ?? '';

    if (projectName.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('CARGANDO...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Módulos activos del proyecto para el dropdown
    final modulesAsync = ref.watch(activeModulosByProjectProvider(projectName));
    final modules = modulesAsync.value ?? [];

    // Si estamos editando, cargar datos del ticket
    if (_isEditing && !_isLoaded) {
      final ticketAsync = ref.watch(ticketByIdProvider(widget.ticketId!));

      ticketAsync.whenData((ticket) {
        if (ticket != null && !_isLoaded) {
          _tituloController.text = ticket.titulo;
          _descripcionController.text = ticket.descripcion;
          _selectedModuleId = ticket.moduleId;
          _selectedModuleName = ticket.moduleName;
          _priority = ticket.priority;
          _isLoaded = true;
          if (mounted) setState(() {});
        }
      });

      if (!_isLoaded) {
        return Scaffold(
          appBar: AppBar(title: const Text('CARGANDO...')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'EDITAR TICKET' : 'NUEVO TICKET'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isEditing) {
              context.go(
                '/projects/${widget.projectId}/tickets/${widget.ticketId}',
              );
            } else {
              context.go('/projects/${widget.projectId}/tickets');
            }
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Proyecto (read-only)
            TextFormField(
              initialValue: projectName,
              decoration: const InputDecoration(
                labelText: 'Proyecto',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              readOnly: true,
              enabled: false,
            ),
            const SizedBox(height: 16),

            // Módulo (obligatorio)
            DropdownButtonFormField<String>(
              initialValue: _selectedModuleId,
              decoration: const InputDecoration(
                labelText: 'Módulo *',
                prefixIcon: Icon(Icons.view_module_outlined),
              ),
              items: modules.map((m) {
                return DropdownMenuItem<String>(
                  value: m.id,
                  child: Text(m.nombreModulo),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedModuleId = value;
                  _selectedModuleName = modules
                      .firstWhere((m) => m.id == value)
                      .nombreModulo;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Selecciona un módulo';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Título
            TextFormField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título *',
                prefixIcon: Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El título es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Descripción
            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción *',
                prefixIcon: Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La descripción es obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Prioridad
            DropdownButtonFormField<TicketPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Prioridad',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: TicketPriority.values.map((p) {
                return DropdownMenuItem<TicketPriority>(
                  value: p,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _priorityColor(p),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(p.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _priority = value);
                }
              },
            ),
            const SizedBox(height: 32),

            // Botón guardar
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEditing ? 'Guardar cambios' : 'Crear ticket'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(ticketRepositoryProvider);
      final proyecto = ref.read(proyectoByIdProvider(widget.projectId)).value;
      final profile = ref.read(currentUserProfileProvider).value;

      if (proyecto == null || profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: datos no disponibles')),
          );
        }
        return;
      }

      if (_isEditing) {
        final existing = ref.read(ticketByIdProvider(widget.ticketId!)).value;
        if (existing == null) return;

        await repo.update(
          existing.copyWith(
            titulo: _tituloController.text.trim(),
            descripcion: _descripcionController.text.trim(),
            moduleId: _selectedModuleId,
            moduleName: _selectedModuleName,
            priority: _priority,
          ),
        );

        if (mounted) {
          context.go(
            '/projects/${widget.projectId}/tickets/${widget.ticketId}',
          );
        }
      } else {
        final ticket = Ticket(
          id: '',
          folio: '', // Se auto-genera en el repo
          titulo: _tituloController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          projectName: proyecto.nombreProyecto,
          moduleName: _selectedModuleName,
          status: TicketStatus.abierto,
          priority: _priority,
          createdByName: profile.displayName,
          projectId: widget.projectId,
          moduleId: _selectedModuleId!,
          createdBy: profile.uid,
        );

        await repo.create(ticket);

        if (mounted) {
          context.go('/projects/${widget.projectId}/tickets');
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

Color _priorityColor(TicketPriority priority) {
  return switch (priority) {
    TicketPriority.baja => const Color(0xFF4CAF50),
    TicketPriority.media => const Color(0xFF2196F3),
    TicketPriority.alta => const Color(0xFFFFC107),
    TicketPriority.critica => const Color(0xFFD71921),
  };
}
