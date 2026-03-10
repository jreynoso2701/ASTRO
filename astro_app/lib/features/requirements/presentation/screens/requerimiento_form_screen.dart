import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/requerimiento_status.dart';
import 'package:astro/core/models/requerimiento_tipo.dart';
import 'package:astro/core/models/requerimiento_fase.dart';
import 'package:astro/core/models/ticket_priority.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/core/services/storage_service.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Genera un ID corto para cada criterio de aceptación.
String _shortId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

/// Pantalla de creación / edición de requerimiento.
class RequerimientoFormScreen extends ConsumerStatefulWidget {
  const RequerimientoFormScreen({
    required this.projectId,
    this.reqId,
    super.key,
  });

  final String projectId;
  final String? reqId;

  @override
  ConsumerState<RequerimientoFormScreen> createState() =>
      _RequerimientoFormScreenState();
}

class _RequerimientoFormScreenState
    extends ConsumerState<RequerimientoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _moduloPropuestoController = TextEditingController();
  final _observacionesController = TextEditingController();

  RequerimientoTipo _tipo = RequerimientoTipo.funcional;
  TicketPriority _prioridad = TicketPriority.media;
  RequerimientoFase? _faseAsignada;

  String? _selectedModuleId;
  String _selectedModuleName = '';
  bool _usarModuloPropuesto = false;

  // Criterios de aceptación
  final List<_CriterioEntry> _criterios = [];

  // Adjuntos
  final List<String> _existingAdjuntos = [];
  final List<XFile> _newFiles = [];

  // Porcentaje manual
  double _porcentajeAvance = 0;
  bool _porcentajeManual = false;

  bool _isSaving = false;
  bool _isLoaded = false;

  bool get _isEditing => widget.reqId != null;

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _moduloPropuestoController.dispose();
    _observacionesController.dispose();
    for (final c in _criterios) {
      c.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proyectoAsync = ref.watch(proyectoByIdProvider(widget.projectId));
    final proyecto = proyectoAsync.value;
    final projectName = proyecto?.nombreProyecto ?? '';
    final empresaName = proyecto?.fkEmpresa ?? '';
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final canManage = ref.watch(canManageProjectProvider(widget.projectId));
    final isManager = canManage || isRoot;

    if (projectName.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('CARGANDO...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Cargar datos si estamos editando
    if (_isEditing && !_isLoaded) {
      final reqAsync = ref.watch(requerimientoByIdProvider(widget.reqId!));
      reqAsync.whenData((req) {
        if (req != null && !_isLoaded) {
          _loadReq(req);
        }
      });

      if (!_isLoaded) {
        return Scaffold(
          appBar: AppBar(title: const Text('CARGANDO...')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
    }

    // Módulos del proyecto
    final modulesAsync = ref.watch(activeModulosByProjectProvider(projectName));
    final modules = modulesAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'EDITAR REQUERIMIENTO' : 'NUEVO REQUERIMIENTO',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isEditing) {
              context.go(
                '/projects/${widget.projectId}/requirements/${widget.reqId}',
              );
            } else {
              context.go('/projects/${widget.projectId}/requirements');
            }
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: AdaptiveBody(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Título ──
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // ── Descripción ──
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción *',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // ── Tipo ──
              DropdownButtonFormField<RequerimientoTipo>(
                initialValue: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: RequerimientoTipo.values
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _tipo = v);
                },
              ),
              const SizedBox(height: 16),

              // ── Prioridad ──
              DropdownButtonFormField<TicketPriority>(
                initialValue: _prioridad,
                decoration: const InputDecoration(
                  labelText: 'Prioridad *',
                  prefixIcon: Icon(Icons.priority_high),
                ),
                items: TicketPriority.values
                    .map(
                      (p) => DropdownMenuItem(value: p, child: Text(p.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _prioridad = v);
                },
              ),
              const SizedBox(height: 16),

              // ── Módulo ──
              SwitchListTile(
                title: const Text('¿Módulo nuevo / propuesto?'),
                subtitle: const Text('Activar si el módulo aún no existe'),
                value: _usarModuloPropuesto,
                onChanged: (v) => setState(() {
                  _usarModuloPropuesto = v;
                  if (v) {
                    _selectedModuleId = null;
                    _selectedModuleName = '';
                  } else {
                    _moduloPropuestoController.clear();
                  }
                }),
              ),
              const SizedBox(height: 8),

              if (!_usarModuloPropuesto) ...[
                DropdownButtonFormField<String>(
                  initialValue:
                      _selectedModuleId != null && _selectedModuleId!.isNotEmpty
                      ? _selectedModuleId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Módulo existente',
                    prefixIcon: Icon(Icons.view_module_outlined),
                  ),
                  items: modules
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.nombreModulo),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    final mod = modules.firstWhere((m) => m.id == v);
                    setState(() {
                      _selectedModuleId = v;
                      _selectedModuleName = mod.nombreModulo;
                    });
                  },
                ),
              ] else ...[
                TextFormField(
                  controller: _moduloPropuestoController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del módulo propuesto',
                    prefixIcon: Icon(Icons.add_box_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // ── Criterios de Aceptación ──
              _buildCriteriosSection(),
              const SizedBox(height: 24),

              // ── Adjuntos ──
              _buildAdjuntosSection(),
              const SizedBox(height: 24),

              // ── Campos Root/Soporte ──
              if (isManager) ...[
                const Divider(),
                Text(
                  'GESTIÓN (Root/Soporte)',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                // Porcentaje manual
                SwitchListTile(
                  title: const Text('Porcentaje manual'),
                  subtitle: Text(
                    _porcentajeManual
                        ? 'Ajustar manualmente'
                        : 'Auto-cálculo desde criterios',
                  ),
                  value: _porcentajeManual,
                  onChanged: (v) => setState(() => _porcentajeManual = v),
                ),
                if (_porcentajeManual) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _porcentajeAvance,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '${_porcentajeAvance.toInt()}%',
                          onChanged: (v) =>
                              setState(() => _porcentajeAvance = v),
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${_porcentajeAvance.toInt()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: progressColor(_porcentajeAvance),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Fase asignada (solo Root)
                if (isRoot)
                  DropdownButtonFormField<RequerimientoFase>(
                    initialValue: _faseAsignada,
                    decoration: const InputDecoration(
                      labelText: 'Fase asignada',
                      prefixIcon: Icon(Icons.timeline),
                    ),
                    items: RequerimientoFase.values
                        .map(
                          (f) =>
                              DropdownMenuItem(value: f, child: Text(f.label)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _faseAsignada = v),
                  ),
                const SizedBox(height: 12),

                // Observaciones internas
                if (isRoot)
                  TextFormField(
                    controller: _observacionesController,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones internas (Root)',
                      prefixIcon: Icon(Icons.lock_outline),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                const SizedBox(height: 16),
              ],

              // Botón guardar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _save(projectName, empresaName),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isEditing ? 'Guardar cambios' : 'Crear requerimiento',
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Criterios Section ──────────────────────────────────

  Widget _buildCriteriosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'CRITERIOS DE ACEPTACIÓN',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Agregar criterio',
              onPressed: () {
                setState(() {
                  _criterios.add(
                    _CriterioEntry(
                      id: _shortId(),
                      controller: TextEditingController(),
                      completado: false,
                    ),
                  );
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_criterios.isEmpty)
          Text(
            'Sin criterios agregados. Tap "+" para agregar.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        for (var i = 0; i < _criterios.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _criterios[i].controller,
                    decoration: InputDecoration(
                      hintText: 'Criterio ${i + 1}',
                      isDense: true,
                      prefixIcon: const Icon(
                        Icons.check_box_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar criterio',
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () {
                    setState(() {
                      _criterios[i].controller.dispose();
                      _criterios.removeAt(i);
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Adjuntos Section ───────────────────────────────────

  Widget _buildAdjuntosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADJUNTOS',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            letterSpacing: 1,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),

        // Existing
        if (_existingAdjuntos.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final url in _existingAdjuntos)
                Chip(
                  avatar: const Icon(Icons.attach_file, size: 16),
                  label: const Text('Archivo'),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () =>
                      setState(() => _existingAdjuntos.remove(url)),
                ),
            ],
          ),

        // New
        if (_newFiles.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _newFiles.length; i++)
                Chip(
                  avatar: const Icon(Icons.upload_file, size: 16),
                  label: Text(
                    _newFiles[i].name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _newFiles.removeAt(i)),
                ),
            ],
          ),

        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Galería'),
              onPressed: _pickFromGallery,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('Archivos'),
              onPressed: _pickFiles,
            ),
          ],
        ),
      ],
    );
  }

  // ── File Picking ───────────────────────────────────────

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 80);
    if (images.isNotEmpty) {
      setState(() => _newFiles.addAll(images));
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result != null) {
      setState(() {
        _newFiles.addAll(
          result.files.where((f) => f.path != null).map((f) => XFile(f.path!)),
        );
      });
    }
  }

  // ── Load existing data ─────────────────────────────────

  void _loadReq(Requerimiento req) {
    _tituloController.text = req.titulo;
    _descripcionController.text = req.descripcion;
    _tipo = req.tipo;
    _prioridad = req.prioridad;
    _selectedModuleId = req.moduleId;
    _selectedModuleName = req.moduleName ?? '';
    _usarModuloPropuesto =
        req.moduloPropuesto != null && req.moduloPropuesto!.isNotEmpty;
    _moduloPropuestoController.text = req.moduloPropuesto ?? '';
    _faseAsignada = req.faseAsignada;
    _porcentajeAvance = req.porcentajeAvance;
    _porcentajeManual = req.porcentajeManual;
    _observacionesController.text = req.observacionesRoot ?? '';
    _existingAdjuntos.addAll(req.adjuntos);

    for (final c in req.criteriosAceptacion) {
      _criterios.add(
        _CriterioEntry(
          id: c.id,
          controller: TextEditingController(text: c.texto),
          completado: c.completado,
        ),
      );
    }

    _isLoaded = true;
  }

  // ── Save ───────────────────────────────────────────────

  Future<void> _save(String projectName, String empresaName) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final profile = ref.read(currentUserProfileProvider).value;
      if (profile == null) return;

      // Upload new files
      final newUrls = <String>[];
      if (_newFiles.isNotEmpty) {
        final storage = StorageService();
        for (final file in _newFiles) {
          final url = await storage.uploadToPath(
            'requerimientos/${widget.projectId}',
            file,
          );
          newUrls.add(url);
        }
      }

      final allAdjuntos = [..._existingAdjuntos, ...newUrls];

      // Build criterios
      final criterios = <CriterioAceptacion>[];
      for (var i = 0; i < _criterios.length; i++) {
        final texto = _criterios[i].controller.text.trim();
        if (texto.isNotEmpty) {
          criterios.add(
            CriterioAceptacion(
              id: _criterios[i].id,
              texto: texto,
              completado: _criterios[i].completado,
              orden: i,
            ),
          );
        }
      }

      // Auto-calc porcentaje if not manual
      double pct = _porcentajeAvance;
      if (!_porcentajeManual && criterios.isNotEmpty) {
        final done = criterios.where((c) => c.completado).length;
        pct = (done / criterios.length) * 100;
      }

      final repo = ref.read(requerimientoRepositoryProvider);

      if (_isEditing) {
        final existing = ref
            .read(requerimientoByIdProvider(widget.reqId!))
            .value;
        if (existing == null) return;

        await repo.update(
          existing.copyWith(
            titulo: _tituloController.text.trim(),
            descripcion: _descripcionController.text.trim(),
            tipo: _tipo,
            prioridad: _prioridad,
            moduleName: _usarModuloPropuesto ? null : _selectedModuleName,
            moduleId: _usarModuloPropuesto ? null : _selectedModuleId,
            moduloPropuesto: _usarModuloPropuesto
                ? _moduloPropuestoController.text.trim()
                : null,
            faseAsignada: _faseAsignada,
            criteriosAceptacion: criterios,
            adjuntos: allAdjuntos,
            porcentajeAvance: pct,
            porcentajeManual: _porcentajeManual,
            observacionesRoot: _observacionesController.text.trim().isNotEmpty
                ? _observacionesController.text.trim()
                : null,
          ),
        );

        if (mounted) {
          context.go(
            '/projects/${widget.projectId}/requirements/${widget.reqId}',
          );
        }
      } else {
        final newReq = Requerimiento(
          id: '',
          folio: '', // Se genera en el repo
          titulo: _tituloController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          tipo: _tipo,
          prioridad: _prioridad,
          status: RequerimientoStatus.propuesto,
          projectName: projectName,
          createdByName: profile.displayName,
          createdBy: profile.uid,
          projectId: widget.projectId,
          empresaName: empresaName,
          moduleName: _usarModuloPropuesto ? null : _selectedModuleName,
          moduleId: _usarModuloPropuesto ? null : _selectedModuleId,
          moduloPropuesto: _usarModuloPropuesto
              ? _moduloPropuestoController.text.trim()
              : null,
          faseAsignada: _faseAsignada,
          criteriosAceptacion: criterios,
          adjuntos: allAdjuntos,
          porcentajeAvance: pct,
          porcentajeManual: _porcentajeManual,
          observacionesRoot: _observacionesController.text.trim().isNotEmpty
              ? _observacionesController.text.trim()
              : null,
          createdAt: DateTime.now(),
        );

        final docId = await repo.create(newReq);

        if (mounted) {
          context.go('/projects/${widget.projectId}/requirements/$docId');
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

/// Entrada temporal de criterio durante edición del formulario.
class _CriterioEntry {
  _CriterioEntry({
    required this.id,
    required this.controller,
    required this.completado,
  });

  final String id;
  final TextEditingController controller;
  final bool completado;
}
