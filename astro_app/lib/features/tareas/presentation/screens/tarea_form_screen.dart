import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/tarea.dart';
import 'package:astro/core/models/tarea_status.dart';
import 'package:astro/core/models/tarea_prioridad.dart';
import 'package:astro/core/services/storage_service.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/tareas/providers/tarea_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de creación / edición de tarea.
class TareaFormScreen extends ConsumerStatefulWidget {
  const TareaFormScreen({
    required this.projectId,
    this.tareaId,
    this.initialRefMinutaId,
    this.initialRefCompromisoNumero,
    this.initialTitulo,
    this.initialDescripcion,
    this.initialAssignedToUid,
    this.initialAssignedToName,
    this.initialFechaEntrega,
    super.key,
  });

  final String projectId;
  final String? tareaId;

  // Pre-fill desde compromiso de minuta.
  final String? initialRefMinutaId;
  final int? initialRefCompromisoNumero;
  final String? initialTitulo;
  final String? initialDescripcion;
  final String? initialAssignedToUid;
  final String? initialAssignedToName;
  final DateTime? initialFechaEntrega;

  @override
  ConsumerState<TareaFormScreen> createState() => _TareaFormScreenState();
}

class _TareaFormScreenState extends ConsumerState<TareaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();

  String? _selectedModuleId;
  String _selectedModuleName = '';
  TareaPrioridad _prioridad = TareaPrioridad.media;
  TareaStatus _status = TareaStatus.pendiente;
  DateTime? _fechaEntrega;

  // Asignado a
  String? _assignedToUid;
  String? _assignedToName;

  // Adjuntos
  final List<String> _existingAdjuntos = [];
  final List<XFile> _newFiles = [];

  // Referencias
  String? _refTicketId;
  String? _refRequerimientoId;
  String? _refMinutaId;
  int? _refCompromisoNumero;

  bool _isSaving = false;
  bool _isLoaded = false;

  bool get _isEditing => widget.tareaId != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill desde compromiso de minuta (crear desde minuta).
    if (!_isEditing) {
      if (widget.initialTitulo != null) {
        _tituloController.text = widget.initialTitulo!;
      }
      if (widget.initialDescripcion != null) {
        _descripcionController.text = widget.initialDescripcion!;
      }
      _assignedToUid = widget.initialAssignedToUid;
      _assignedToName = widget.initialAssignedToName;
      _fechaEntrega = widget.initialFechaEntrega;
      _refMinutaId = widget.initialRefMinutaId;
      _refCompromisoNumero = widget.initialRefCompromisoNumero;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proyectoAsync = ref.watch(proyectoByIdProvider(widget.projectId));
    final proyecto = proyectoAsync.value;
    final projectName = proyecto?.nombreProyecto ?? '';

    if (projectName.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('CARGANDO...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Módulos activos del proyecto
    final modulesAsync = ref.watch(activeModulosByProjectProvider(projectName));
    final modules = modulesAsync.value ?? [];

    // Miembros del proyecto
    final members = ref.watch(projectMembersProvider(widget.projectId));

    // Si estamos editando, cargar datos
    if (_isEditing && !_isLoaded) {
      final tareaAsync = ref.watch(tareaByIdProvider(widget.tareaId!));
      tareaAsync.whenData((tarea) {
        if (tarea != null && !_isLoaded) {
          _tituloController.text = tarea.titulo;
          _descripcionController.text = tarea.descripcion;
          _selectedModuleId = tarea.moduleId;
          _selectedModuleName = tarea.moduleName ?? '';
          _prioridad = tarea.prioridad;
          _status = tarea.status;
          _fechaEntrega = tarea.fechaEntrega;
          _assignedToUid = tarea.assignedToUid;
          _assignedToName = tarea.assignedToName;
          _existingAdjuntos.addAll(tarea.adjuntos);
          _refTicketId = tarea.refTicketId;
          _refRequerimientoId = tarea.refRequerimientoId;
          _refMinutaId = tarea.refMinutaId;
          _refCompromisoNumero = tarea.refCompromisoNumero;
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
        title: Text(_isEditing ? 'EDITAR TAREA' : 'NUEVA TAREA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: AdaptiveBody(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Datos básicos ─────────────────────────
              Text(
                'INFORMACIÓN GENERAL',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),

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

              // Módulo (opcional)
              DropdownButtonFormField<String>(
                initialValue: _selectedModuleId,
                decoration: const InputDecoration(
                  labelText: 'Módulo (opcional)',
                  prefixIcon: Icon(Icons.view_module_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Sin módulo'),
                  ),
                  ...modules.map((m) {
                    return DropdownMenuItem<String>(
                      value: m.id,
                      child: Text(m.nombreModulo),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedModuleId = value;
                    _selectedModuleName = value != null
                        ? modules.firstWhere((m) => m.id == value).nombreModulo
                        : '';
                  });
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

              // Asignado a (miembros del proyecto)
              DropdownButtonFormField<String>(
                initialValue: _assignedToUid,
                decoration: const InputDecoration(
                  labelText: 'Asignar a',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Sin asignar'),
                  ),
                  ...members.map((m) {
                    return DropdownMenuItem<String>(
                      value: m.assignment.userId,
                      child: Text(m.user?.displayName ?? m.assignment.userId),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _assignedToUid = value;
                    _assignedToName = value != null
                        ? members
                              .firstWhere((m) => m.assignment.userId == value)
                              .user
                              ?.displayName
                        : null;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Prioridad
              DropdownButtonFormField<TareaPrioridad>(
                initialValue: _prioridad,
                decoration: const InputDecoration(
                  labelText: 'Prioridad',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: TareaPrioridad.values.map((p) {
                  return DropdownMenuItem<TareaPrioridad>(
                    value: p,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _prioridadColor(p),
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
                  if (value != null) setState(() => _prioridad = value);
                },
              ),
              const SizedBox(height: 16),

              // Estado (solo en edición)
              if (_isEditing) ...[
                DropdownButtonFormField<TareaStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  items: TareaStatus.values.map((s) {
                    return DropdownMenuItem<TareaStatus>(
                      value: s,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _statusColor(s),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(s.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Fecha de entrega
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(
                  _fechaEntrega != null
                      ? DateFormat('dd/MM/yyyy').format(_fechaEntrega!)
                      : 'Fecha de entrega (opcional)',
                ),
                trailing: _fechaEntrega != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _fechaEntrega = null),
                      )
                    : null,
                onTap: () => _pickDate(),
              ),

              const SizedBox(height: 24),

              // ── Adjuntos ──────────────────────────────
              Text(
                'ADJUNTOS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Existentes
              if (_existingAdjuntos.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _existingAdjuntos.map((url) {
                    final name = Uri.decodeFull(
                      url.split('/').last.split('?').first,
                    );
                    return Chip(
                      avatar: const Icon(Icons.attach_file, size: 16),
                      label: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () =>
                          setState(() => _existingAdjuntos.remove(url)),
                    );
                  }).toList(),
                ),

              // Nuevos
              if (_newFiles.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _newFiles.map((file) {
                    return Chip(
                      avatar: const Icon(Icons.upload_file, size: 16),
                      label: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _newFiles.remove(file)),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 8),

              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Imagen'),
                    onPressed: _pickImage,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: const Text('Archivo'),
                    onPressed: _pickFile,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Guardar ───────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Guardar cambios' : 'Crear tarea'),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaEntrega ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (date != null) setState(() => _fechaEntrega = date);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 80,
    );
    if (image != null) setState(() => _newFiles.add(image));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result != null) {
      final xFiles = result.files
          .where((f) => f.path != null || f.bytes != null)
          .map((f) => XFile(f.path ?? '', name: f.name, bytes: f.bytes))
          .toList();
      setState(() => _newFiles.addAll(xFiles));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(tareaRepositoryProvider);
      final profile = ref.read(currentUserProfileProvider).value;
      final proyecto = ref.read(proyectoByIdProvider(widget.projectId)).value;

      if (profile == null || proyecto == null) return;

      // Subir archivos nuevos
      List<String> newUrls = [];
      if (_newFiles.isNotEmpty) {
        final storage = StorageService();
        final docId =
            widget.tareaId ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
        for (final file in _newFiles) {
          final url = await storage.uploadToPath(
            'tareas/$docId/adjuntos',
            file,
          );
          newUrls.add(url);
        }
      }

      final allAdjuntos = [..._existingAdjuntos, ...newUrls];

      final tarea = Tarea(
        id: widget.tareaId ?? '',
        folio: '', // Se genera en create.
        titulo: _tituloController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        projectId: widget.projectId,
        projectName: proyecto.nombreProyecto,
        status: _isEditing ? _status : TareaStatus.pendiente,
        prioridad: _prioridad,
        createdByUid: profile.uid,
        createdByName: profile.displayName,
        moduleId: _selectedModuleId,
        moduleName: _selectedModuleName.isNotEmpty ? _selectedModuleName : null,
        assignedToUid: _assignedToUid,
        assignedToName: _assignedToName,
        fechaEntrega: _fechaEntrega,
        adjuntos: allAdjuntos,
        refTicketId: _refTicketId,
        refRequerimientoId: _refRequerimientoId,
        refMinutaId: _refMinutaId,
        refCompromisoNumero: _refCompromisoNumero,
      );

      if (_isEditing) {
        await repo.update(tarea);
      } else {
        await repo.create(tarea);
      }

      if (mounted) context.pop();
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

  static Color _statusColor(TareaStatus s) => switch (s) {
    TareaStatus.pendiente => const Color(0xFFFFC107),
    TareaStatus.enProgreso => const Color(0xFF42A5F5),
    TareaStatus.completada => const Color(0xFF4CAF50),
    TareaStatus.cancelada => const Color(0xFF9E9E9E),
  };

  static Color _prioridadColor(TareaPrioridad p) => switch (p) {
    TareaPrioridad.baja => const Color(0xFF4CAF50),
    TareaPrioridad.media => const Color(0xFFFFC107),
    TareaPrioridad.alta => const Color(0xFFFF9800),
    TareaPrioridad.urgente => const Color(0xFFD32F2F),
  };
}
