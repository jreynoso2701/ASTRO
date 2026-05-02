import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/subtarea.dart';
import 'package:astro/core/models/tarea.dart';
import 'package:astro/core/models/tarea_status.dart';
import 'package:astro/core/models/tarea_prioridad.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/minuta.dart';
import 'package:astro/core/models/cita.dart';
import 'package:astro/core/services/storage_service.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/tareas/providers/tarea_providers.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/minutas/providers/minuta_providers.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/core/widgets/resolved_ref_text.dart';
import 'package:astro/core/widgets/rich_text_editor.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/etiquetas/providers/etiqueta_providers.dart';
import 'package:astro/features/etiquetas/presentation/widgets/etiqueta_chip.dart';
import 'package:astro/features/etiquetas/presentation/widgets/etiqueta_picker.dart';

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
  final _richDescripcionKey = GlobalKey<RichTextEditorState>();
  String _initialDescripcionMd = '';

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
  bool _isDragging = false;

  // Referencias (listas)
  final List<String> _refTickets = [];
  final List<String> _refRequerimientos = [];
  final List<String> _refMinutas = [];
  final List<String> _refCitas = [];
  int? _refCompromisoNumero;

  // Etiquetas asignadas
  final List<String> _etiquetaIds = [];

  // Subtareas
  final List<Subtarea> _subtareas = [];

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
        _initialDescripcionMd = widget.initialDescripcion!;
      }
      _assignedToUid = widget.initialAssignedToUid;
      _assignedToName = widget.initialAssignedToName;
      _fechaEntrega = widget.initialFechaEntrega;
      if (widget.initialRefMinutaId != null) {
        _refMinutas.add(widget.initialRefMinutaId!);
      }
      _refCompromisoNumero = widget.initialRefCompromisoNumero;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
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

    // Pre-calentar providers de referencias para que estén listos al buscar
    ref.watch(allTicketsByProjectProvider(projectName));
    ref.watch(allRequerimientosByProjectProvider(projectName));
    ref.watch(minutasByProjectProvider(projectName));
    ref.watch(citasByProjectProvider(projectName));

    // Si estamos editando, cargar datos
    if (_isEditing && !_isLoaded) {
      final tareaAsync = ref.watch(tareaByIdProvider(widget.tareaId!));
      tareaAsync.whenData((tarea) {
        if (tarea != null && !_isLoaded) {
          _tituloController.text = tarea.titulo;
          _initialDescripcionMd = tarea.descripcion;
          _selectedModuleId = tarea.moduleId;
          _selectedModuleName = tarea.moduleName ?? '';
          _prioridad = tarea.prioridad;
          _status = tarea.status;
          _fechaEntrega = tarea.fechaEntrega;
          _assignedToUid = tarea.assignedToUid;
          _assignedToName = tarea.assignedToName;
          _existingAdjuntos.addAll(tarea.adjuntos);
          _refTickets.addAll(tarea.refTickets);
          _refRequerimientos.addAll(tarea.refRequerimientos);
          _refMinutas.addAll(tarea.refMinutas);
          _refCitas.addAll(tarea.refCitas);
          _etiquetaIds.addAll(tarea.etiquetaIds);
          _refCompromisoNumero = tarea.refCompromisoNumero;
          _subtareas.addAll(tarea.subtareas);
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
              Text(
                'Descripción *',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              RichTextEditor(
                key: _richDescripcionKey,
                initialMarkdown: _initialDescripcionMd,
                toolbarLevel: RichTextToolbarLevel.full,
                placeholder: 'Describe la tarea...',
                minHeight: 150,
                maxHeight: 400,
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

              // ── Referencias ───────────────────────────
              Text(
                'REFERENCIAS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Tickets
              _RefSubSection(
                label: 'Tickets',
                icon: Icons.confirmation_number_outlined,
                refType: RefType.ticket,
                ids: _refTickets,
                onAdd: () => _searchTickets(projectName),
                onRemove: (id) => setState(() => _refTickets.remove(id)),
              ),
              const SizedBox(height: 12),

              // Requerimientos
              _RefSubSection(
                label: 'Requerimientos',
                icon: Icons.assignment_outlined,
                refType: RefType.requerimiento,
                ids: _refRequerimientos,
                onAdd: () => _searchRequerimientos(projectName),
                onRemove: (id) => setState(() => _refRequerimientos.remove(id)),
              ),
              const SizedBox(height: 12),

              // Minutas
              _RefSubSection(
                label: 'Minutas',
                icon: Icons.description_outlined,
                refType: RefType.minuta,
                ids: _refMinutas,
                onAdd: () => _searchMinutas(projectName),
                onRemove: (id) => setState(() => _refMinutas.remove(id)),
              ),
              const SizedBox(height: 12),

              // Citas
              _RefSubSection(
                label: 'Citas',
                icon: Icons.event_outlined,
                refType: RefType.cita,
                ids: _refCitas,
                onAdd: () => _searchCitas(projectName),
                onRemove: (id) => setState(() => _refCitas.remove(id)),
              ),

              const SizedBox(height: 24),

              // ── Subtareas ─────────────────────────────
              Text(
                'SUBTAREAS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),

              _SubtareasSection(
                subtareas: _subtareas,
                onAdd: (titulo) {
                  setState(() {
                    _subtareas.add(
                      Subtarea(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        titulo: titulo,
                        orden: _subtareas.length,
                      ),
                    );
                  });
                },
                onRemove: (id) {
                  setState(() {
                    _subtareas.removeWhere((s) => s.id == id);
                    // Reindexar orden
                    for (int i = 0; i < _subtareas.length; i++) {
                      _subtareas[i] = _subtareas[i].copyWith(orden: i);
                    }
                  });
                },
                onEdit: (id, titulo) {
                  setState(() {
                    final idx = _subtareas.indexWhere((s) => s.id == id);
                    if (idx != -1) {
                      _subtareas[idx] = _subtareas[idx].copyWith(
                        titulo: titulo,
                      );
                    }
                  });
                },
                onToggle: (id) {
                  setState(() {
                    final idx = _subtareas.indexWhere((s) => s.id == id);
                    if (idx != -1) {
                      _subtareas[idx] = _subtareas[idx].copyWith(
                        completada: !_subtareas[idx].completada,
                      );
                    }
                  });
                },
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _subtareas.removeAt(oldIndex);
                    _subtareas.insert(newIndex, item);
                    for (int i = 0; i < _subtareas.length; i++) {
                      _subtareas[i] = _subtareas[i].copyWith(orden: i);
                    }
                  });
                },
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

              DropTarget(
                onDragEntered: (_) => setState(() => _isDragging = true),
                onDragExited: (_) => setState(() => _isDragging = false),
                onDragDone: (details) {
                  setState(() {
                    _isDragging = false;
                    _newFiles.addAll(details.files);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isDragging
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: _isDragging ? 2 : 1,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                    color: _isDragging
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.08)
                        : null,
                  ),
                  child: Column(
                    children: [
                      // Indicador visual de drop zone
                      if (_existingAdjuntos.isEmpty && _newFiles.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              Icon(
                                _isDragging
                                    ? Icons.file_download
                                    : Icons.cloud_upload_outlined,
                                size: 36,
                                color: _isDragging
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isDragging
                                    ? 'Suelta los archivos aquí'
                                    : kIsWeb
                                    ? 'Arrastra archivos aquí o usa los botones'
                                    : 'Adjunta archivos con los botones',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: _isDragging
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                      // Dragging indicator when files already exist
                      if ((_existingAdjuntos.isNotEmpty ||
                              _newFiles.isNotEmpty) &&
                          _isDragging)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.file_download,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Suelta los archivos aquí',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),

                      // Existentes
                      if (_existingAdjuntos.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _existingAdjuntos.map((url) {
                              final name = Uri.decodeFull(
                                url.split('/').last.split('?').first,
                              );
                              return Chip(
                                avatar: Icon(_fileIcon(name), size: 16),
                                label: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => setState(
                                  () => _existingAdjuntos.remove(url),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // Nuevos
                      if (_newFiles.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _newFiles.map((file) {
                              return Chip(
                                avatar: Icon(_fileIcon(file.name), size: 16),
                                label: Text(
                                  file.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () =>
                                    setState(() => _newFiles.remove(file)),
                              );
                            }).toList(),
                          ),
                        ),

                      // Botones
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Etiquetas ─────────────────────────────
              Text(
                'ETIQUETAS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              if (_etiquetaIds.isNotEmpty)
                Consumer(
                  builder: (context, ref, _) {
                    final etiquetasAsync = ref.watch(
                      etiquetasByIdsProvider(
                        ([..._etiquetaIds]..sort()).join(','),
                      ),
                    );
                    final etiquetas = etiquetasAsync.value ?? [];
                    return Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: etiquetas
                          .map(
                            (e) => EtiquetaChip(
                              etiqueta: e,
                              onDelete: () =>
                                  setState(() => _etiquetaIds.remove(e.id)),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              TextButton.icon(
                onPressed: () async {
                  final selected = await EtiquetaPicker.show(
                    context,
                    ref,
                    projectId: widget.projectId,
                    selectedIds: List.from(_etiquetaIds),
                  );
                  if (selected != null) {
                    setState(() {
                      _etiquetaIds
                        ..clear()
                        ..addAll(selected);
                    });
                  }
                },
                icon: const Icon(Icons.label_outline),
                label: const Text('Gestionar etiquetas'),
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

    // Validar descripción del editor enriquecido
    final descripcionState = _richDescripcionKey.currentState;
    if (descripcionState == null || descripcionState.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La descripción es obligatoria')),
      );
      return;
    }
    final descripcionMd = descripcionState.markdown;

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
        descripcion: descripcionMd,
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
        refTickets: _refTickets,
        refRequerimientos: _refRequerimientos,
        refMinutas: _refMinutas,
        refCitas: _refCitas,
        etiquetaIds: _etiquetaIds,
        refCompromisoNumero: _refCompromisoNumero,
        subtareas: _subtareas,
      );

      if (_isEditing) {
        await repo.update(tarea, updatedBy: profile.uid);
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

  static IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' ||
      'jpeg' ||
      'png' ||
      'gif' ||
      'webp' ||
      'bmp' => Icons.image_outlined,
      'mp4' || 'mov' || 'avi' || 'mkv' || 'webm' => Icons.videocam_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'doc' || 'docx' => Icons.description_outlined,
      'xls' || 'xlsx' => Icons.table_chart_outlined,
      'ppt' || 'pptx' => Icons.slideshow_outlined,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => Icons.folder_zip_outlined,
      'mp3' || 'wav' || 'aac' || 'ogg' || 'flac' => Icons.audiotrack_outlined,
      _ => Icons.attach_file,
    };
  }

  // ─── Búsqueda de referencias ──────────────────────────

  Future<void> _searchTickets(String projectName) async {
    final tickets = await ref.read(
      allTicketsByProjectProvider(projectName).future,
    );
    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchRefDialog<Ticket>(
        title: 'Buscar ticket',
        items: tickets.where((t) => !_refTickets.contains(t.id)).toList(),
        labelBuilder: (t) => '${t.folio} — ${t.titulo}',
        idBuilder: (t) => t.id,
        searchBuilder: (t) => [
          t.folio,
          t.titulo,
          t.descripcion,
          t.status.label,
          t.priority.label,
          t.createdByName,
          t.assignedToName ?? '',
          t.moduleName,
        ].join(' '),
        leadingBuilder: (t) => Icon(
          t.isActive
              ? Icons.confirmation_number_outlined
              : Icons.archive_outlined,
          color: t.isActive
              ? Theme.of(ctx).colorScheme.primary
              : Theme.of(ctx).colorScheme.onSurfaceVariant,
          size: 20,
        ),
        subtitleBuilder: (t) {
          final cs = Theme.of(ctx).colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(
                    label: t.status.label,
                    color: cs.primaryContainer,
                  ),
                  const SizedBox(width: 4),
                  _StatusChip(
                    label: t.priority.label,
                    color: cs.tertiaryContainer,
                  ),
                  if (!t.isActive) ...[
                    const SizedBox(width: 4),
                    _StatusChip(label: 'Archivado', color: cs.errorContainer),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${t.moduleName} · ${t.createdByName}',
                style: Theme.of(ctx).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
    if (selected != null) setState(() => _refTickets.add(selected));
  }

  Future<void> _searchRequerimientos(String projectName) async {
    final reqs = await ref.read(
      allRequerimientosByProjectProvider(projectName).future,
    );
    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchRefDialog<Requerimiento>(
        title: 'Buscar requerimiento',
        items: reqs.where((r) => !_refRequerimientos.contains(r.id)).toList(),
        labelBuilder: (r) => '${r.folio} — ${r.titulo}',
        idBuilder: (r) => r.id,
        searchBuilder: (r) => [
          r.folio,
          r.titulo,
          r.descripcion,
          r.status.label,
          r.prioridad.label,
          r.tipo.label,
          r.createdByName,
          r.assignedToName ?? '',
          r.moduleName ?? '',
        ].join(' '),
        leadingBuilder: (r) => Icon(
          r.isActive ? Icons.assignment_outlined : Icons.archive_outlined,
          color: r.isActive
              ? Theme.of(ctx).colorScheme.primary
              : Theme.of(ctx).colorScheme.onSurfaceVariant,
          size: 20,
        ),
        subtitleBuilder: (r) {
          final cs = Theme.of(ctx).colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(
                    label: r.status.label,
                    color: cs.primaryContainer,
                  ),
                  const SizedBox(width: 4),
                  _StatusChip(
                    label: r.prioridad.label,
                    color: cs.tertiaryContainer,
                  ),
                  const SizedBox(width: 4),
                  _StatusChip(
                    label: r.tipo.label,
                    color: cs.secondaryContainer,
                  ),
                  if (!r.isActive) ...[
                    const SizedBox(width: 4),
                    _StatusChip(label: 'Archivado', color: cs.errorContainer),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${r.moduleName ?? 'Sin módulo'} · ${r.createdByName}',
                style: Theme.of(ctx).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
    if (selected != null) setState(() => _refRequerimientos.add(selected));
  }

  Future<void> _searchMinutas(String projectName) async {
    final minutas = await ref.read(
      minutasByProjectProvider(projectName).future,
    );
    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchRefDialog<Minuta>(
        title: 'Buscar minuta',
        items: minutas.where((m) => !_refMinutas.contains(m.id)).toList(),
        labelBuilder: (m) => '${m.folio} — ${m.objetivo}',
        idBuilder: (m) => m.id,
        searchBuilder: (m) => [
          m.folio,
          m.objetivo,
          m.createdByName,
          m.observaciones ?? '',
          m.lugar ?? '',
          m.modalidad.label,
          m.isActive ? '' : 'archivado',
        ].join(' '),
        leadingBuilder: (m) => Icon(
          m.isActive ? Icons.description_outlined : Icons.archive_outlined,
          color: m.isActive
              ? Theme.of(ctx).colorScheme.primary
              : Theme.of(ctx).colorScheme.onSurfaceVariant,
          size: 20,
        ),
        subtitleBuilder: (m) {
          final cs = Theme.of(ctx).colorScheme;
          final fecha = m.fecha != null
              ? DateFormat('dd/MM/yyyy').format(m.fecha!)
              : 'Sin fecha';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(
                    label: m.modalidad.label,
                    color: cs.primaryContainer,
                  ),
                  if (!m.isActive) ...[
                    const SizedBox(width: 4),
                    _StatusChip(label: 'Archivada', color: cs.errorContainer),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$fecha · ${m.createdByName}',
                style: Theme.of(ctx).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
    if (selected != null) setState(() => _refMinutas.add(selected));
  }

  Future<void> _searchCitas(String projectName) async {
    final citas = await ref.read(citasByProjectProvider(projectName).future);
    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchRefDialog<Cita>(
        title: 'Buscar cita',
        items: citas.where((c) => !_refCitas.contains(c.id)).toList(),
        labelBuilder: (c) => '${c.folio} — ${c.titulo}',
        idBuilder: (c) => c.id,
        searchBuilder: (c) => [
          c.folio,
          c.titulo,
          c.descripcion ?? '',
          c.status.label,
          c.modalidad.label,
          c.createdByName,
          c.direccion ?? '',
          c.isActive ? '' : 'archivado',
        ].join(' '),
        leadingBuilder: (c) => Icon(
          c.isActive ? Icons.event_outlined : Icons.archive_outlined,
          color: c.isActive
              ? Theme.of(ctx).colorScheme.primary
              : Theme.of(ctx).colorScheme.onSurfaceVariant,
          size: 20,
        ),
        subtitleBuilder: (c) {
          final cs = Theme.of(ctx).colorScheme;
          final fecha = c.fecha != null
              ? DateFormat('dd/MM/yyyy').format(c.fecha!)
              : 'Sin fecha';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(
                    label: c.status.label,
                    color: cs.primaryContainer,
                  ),
                  const SizedBox(width: 4),
                  _StatusChip(
                    label: c.modalidad.label,
                    color: cs.secondaryContainer,
                  ),
                  if (!c.isActive) ...[
                    const SizedBox(width: 4),
                    _StatusChip(label: 'Archivada', color: cs.errorContainer),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$fecha · ${c.createdByName}',
                style: Theme.of(ctx).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
    if (selected != null) setState(() => _refCitas.add(selected));
  }
}

// ── Subtareas Section ────────────────────────────────────

class _SubtareasSection extends StatefulWidget {
  const _SubtareasSection({
    required this.subtareas,
    required this.onAdd,
    required this.onRemove,
    required this.onEdit,
    required this.onToggle,
    required this.onReorder,
  });

  final List<Subtarea> subtareas;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final void Function(String id, String titulo) onEdit;
  final ValueChanged<String> onToggle;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  State<_SubtareasSection> createState() => _SubtareasSectionState();
}

class _SubtareasSectionState extends State<_SubtareasSection> {
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _addSubtarea() {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    _addController.clear();
  }

  void _showEditDialog(Subtarea sub) {
    final editController = TextEditingController(text: sub.titulo);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar subtarea'),
        content: TextField(
          controller: editController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Título',
            hintText: 'Nombre de la subtarea',
          ),
          onSubmitted: (_) {
            final newTitle = editController.text.trim();
            if (newTitle.isNotEmpty) {
              widget.onEdit(sub.id, newTitle);
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = editController.text.trim();
              if (newTitle.isNotEmpty) {
                widget.onEdit(sub.id, newTitle);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).then((_) => editController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedCount = widget.subtareas.where((s) => s.completada).length;
    final total = widget.subtareas.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress indicator
        if (total > 0) ...[
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completedCount / total,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$completedCount / $total',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Add subtarea field
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Nueva subtarea...',
                  isDense: true,
                  prefixIcon: Icon(Icons.add, size: 20),
                ),
                onSubmitted: (_) => _addSubtarea(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Agregar subtarea',
              onPressed: _addSubtarea,
            ),
          ],
        ),

        if (total > 0) ...[
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: total,
            onReorder: widget.onReorder,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                ),
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final sub = widget.subtareas[index];
              return ListTile(
                key: ValueKey(sub.id),
                dense: true,
                contentPadding: const EdgeInsets.only(left: 0, right: 0),
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle, size: 20),
                ),
                title: Text(
                  sub.titulo,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: sub.completada
                        ? TextDecoration.lineThrough
                        : null,
                    color: sub.completada
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        sub.completada
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 20,
                        color: sub.completada
                            ? const Color(0xFF4CAF50)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: sub.completada
                          ? 'Marcar pendiente'
                          : 'Marcar completada',
                      onPressed: () => widget.onToggle(sub.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Editar',
                      onPressed: () => _showEditDialog(sub),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: 'Eliminar',
                      onPressed: () => widget.onRemove(sub.id),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        if (total == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sin subtareas. Agrega una arriba.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Ref Sub Section ──────────────────────────────────────

class _RefSubSection extends StatelessWidget {
  const _RefSubSection({
    required this.label,
    required this.icon,
    required this.refType,
    required this.ids,
    required this.onAdd,
    required this.onRemove,
  });

  final String label;
  final IconData icon;
  final RefType refType;
  final List<String> ids;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
            ),
          ],
        ),
        if (ids.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              'Sin referencias',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ids.map((id) {
              return Chip(
                avatar: Icon(icon, size: 16),
                label: ResolvedRefText(
                  id: id,
                  type: refType,
                  style: theme.textTheme.bodySmall,
                ),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => onRemove(id),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ── Search Ref Dialog ────────────────────────────────────

class _SearchRefDialog<T> extends StatefulWidget {
  const _SearchRefDialog({
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.idBuilder,
    this.searchBuilder,
    this.subtitleBuilder,
    this.leadingBuilder,
    super.key,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T) idBuilder;
  final String Function(T)? searchBuilder;
  final Widget Function(T)? subtitleBuilder;
  final Widget Function(T)? leadingBuilder;

  @override
  State<_SearchRefDialog<T>> createState() => _SearchRefDialogState<T>();
}

class _SearchRefDialogState<T> extends State<_SearchRefDialog<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((item) {
      if (_query.isEmpty) return true;
      final text = (widget.searchBuilder ?? widget.labelBuilder)(item);
      return text.toUpperCase().contains(_query.toUpperCase());
    }).toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Sin resultados',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        return ListTile(
                          leading: widget.leadingBuilder?.call(item),
                          title: Text(
                            widget.labelBuilder(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: widget.subtitleBuilder?.call(item),
                          isThreeLine: widget.subtitleBuilder != null,
                          onTap: () =>
                              Navigator.pop(ctx, widget.idBuilder(item)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

// ── Status Chip (compact label for search results) ───────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
      ),
    );
  }
}
