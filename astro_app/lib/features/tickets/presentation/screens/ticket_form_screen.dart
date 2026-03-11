import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';
import 'package:astro/core/services/storage_service.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/minutas/providers/minuta_providers.dart';
import 'package:astro/core/models/minuta.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/core/models/cita.dart';

/// Coberturas V1 disponibles.
const _coberturas = [
  'GARANTIA',
  'POLIZA DE SOPORTE',
  'PRESUPUESTO',
  'CORTESIA',
];

/// Pantalla de creación / edición de ticket.
class TicketFormScreen extends ConsumerStatefulWidget {
  const TicketFormScreen({
    required this.projectId,
    this.ticketId,
    this.returnId = false,
    super.key,
  });

  final String projectId;
  final String? ticketId;
  final bool returnId;

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

  // Campos adicionales
  double _porcentajeAvance = 0;
  int? _impacto;
  String? _cobertura;
  DateTime? _solucionProgramada;

  // Evidencias
  final List<String> _existingEvidencias = []; // URLs ya guardadas
  final List<XFile> _newFiles = []; // Archivos nuevos por subir

  // Minutas vinculadas
  final List<String> _refMinutas = [];

  // Citas vinculadas
  final List<String> _refCitas = [];

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
    final proyecto = proyectoAsync.value;
    final projectName = proyecto?.nombreProyecto ?? '';
    final empresaName = proyecto?.fkEmpresa ?? '';
    final canManage = ref.watch(canManageProjectProvider(widget.projectId));
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final isManager = canManage || isRoot;

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
          _porcentajeAvance = ticket.porcentajeAvance;
          _impacto = ticket.impacto;
          _cobertura = ticket.cobertura;
          _solucionProgramada = ticket.solucionProgramada != null
              ? DateTime.tryParse(ticket.solucionProgramada!)
              : null;
          _existingEvidencias.addAll(ticket.evidencias);
          _refMinutas.addAll(ticket.refMinutas);
          _refCitas.addAll(ticket.refCitas);
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

              // Empresa (read-only, auto del proyecto)
              if (empresaName.isNotEmpty) ...[
                TextFormField(
                  initialValue: empresaName,
                  decoration: const InputDecoration(
                    labelText: 'Empresa',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  readOnly: true,
                  enabled: false,
                ),
                const SizedBox(height: 16),
              ],

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

              const SizedBox(height: 24),

              // ── Campos avanzados (Root / Soporte) ──────
              if (isManager) ...[
                Text(
                  'GESTIÓN (ROOT / SOPORTE)',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Porcentaje de avance
                Row(
                  children: [
                    Icon(
                      Icons.percent,
                      size: 20,
                      color: progressColor(_porcentajeAvance),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Porcentaje de avance: ${_porcentajeAvance.round()}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _porcentajeAvance / 100,
                            strokeWidth: 4,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            color: progressColor(_porcentajeAvance),
                          ),
                          Text(
                            '${_porcentajeAvance.round()}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: progressColor(_porcentajeAvance),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _porcentajeAvance,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_porcentajeAvance.round()}%',
                  activeColor: progressColor(_porcentajeAvance),
                  onChanged: (v) => setState(() => _porcentajeAvance = v),
                ),
                const SizedBox(height: 16),

                // Impacto (1-10)
                DropdownButtonFormField<int>(
                  initialValue: _impacto,
                  decoration: const InputDecoration(
                    labelText: 'Impacto (1-10)',
                    prefixIcon: Icon(Icons.trending_up),
                  ),
                  items: List.generate(10, (i) => i + 1).map((n) {
                    return DropdownMenuItem<int>(
                      value: n,
                      child: Text(
                        '$n${n <= 3
                            ? '  (Bajo)'
                            : n <= 6
                            ? '  (Medio)'
                            : n <= 9
                            ? '  (Alto)'
                            : '  (Crítico)'}',
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _impacto = v),
                ),
                const SizedBox(height: 16),

                // Cobertura
                DropdownButtonFormField<String>(
                  initialValue: _cobertura,
                  decoration: const InputDecoration(
                    labelText: 'Cobertura',
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                  items: _coberturas.map((c) {
                    return DropdownMenuItem<String>(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (v) => setState(() => _cobertura = v),
                ),
                const SizedBox(height: 16),

                // Fecha de solución programada
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    _solucionProgramada != null
                        ? 'Solución programada: ${_formatDate(_solucionProgramada!)}'
                        : 'Fecha de solución programada',
                  ),
                  subtitle: _solucionProgramada == null
                      ? const Text('Sin definir')
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Seleccionar fecha',
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _pickSolucionDate,
                      ),
                      if (_solucionProgramada != null)
                        IconButton(
                          tooltip: 'Limpiar fecha',
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _solucionProgramada = null),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 8),

              // ── Evidencias ─────────────────────────────
              Text(
                'EVIDENCIAS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Evidencias existentes (URLs)
              if (_existingEvidencias.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < _existingEvidencias.length; i++)
                      _EvidenceChip(
                        url: _existingEvidencias[i],
                        onDelete: () {
                          setState(() => _existingEvidencias.removeAt(i));
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Nuevos archivos seleccionados
              if (_newFiles.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < _newFiles.length; i++)
                      Chip(
                        avatar: Icon(_fileIcon(_newFiles[i].name), size: 18),
                        label: Text(
                          _newFiles[i].name.length > 20
                              ? '${_newFiles[i].name.substring(0, 20)}...'
                              : _newFiles[i].name,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onDeleted: () {
                          setState(() => _newFiles.removeAt(i));
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Botones de adjuntar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Imagen'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromCamera,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Cámara'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDocuments,
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('Archivo'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Minutas vinculadas ─────────────────────
              Text(
                'MINUTAS VINCULADAS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),

              ..._refMinutas.map(
                (id) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Chip(
                    avatar: const Icon(Icons.description_outlined, size: 16),
                    label: Text(
                      id.length > 12 ? '${id.substring(0, 12)}...' : id,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onDeleted: () => setState(() => _refMinutas.remove(id)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                ),
              ),

              TextButton.icon(
                onPressed: () => _searchMinutas(projectName),
                icon: const Icon(Icons.search),
                label: const Text('Buscar minuta'),
              ),

              const SizedBox(height: 32),

              // ── Citas vinculadas ─────────────────────────
              Text(
                'CITAS VINCULADAS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),

              ..._refCitas.map(
                (id) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Chip(
                    avatar: const Icon(Icons.event_outlined, size: 16),
                    label: Text(
                      id.length > 12 ? '${id.substring(0, 12)}...' : id,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onDeleted: () => setState(() => _refCitas.remove(id)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                ),
              ),

              TextButton.icon(
                onPressed: () => _searchCitas(projectName),
                icon: const Icon(Icons.search),
                label: const Text('Buscar cita'),
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
      ),
    );
  }

  // ── Pickers ──────────────────────────────────────────

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() => _newFiles.addAll(images));
    }
  }

  Future<void> _searchMinutas(String projectName) async {
    final minutas = ref.read(minutasByProjectProvider(projectName)).value ?? [];
    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchMinutaDialog(
        minutas: minutas.where((m) => !_refMinutas.contains(m.id)).toList(),
      ),
    );
    if (selected != null) setState(() => _refMinutas.add(selected));
  }

  Future<void> _searchCitas(String projectName) async {
    final citas = ref.read(citasByProjectProvider(projectName)).value ?? [];
    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchCitaDialog(
        citas: citas.where((c) => !_refCitas.contains(c.id)).toList(),
      ),
    );
    if (selected != null) setState(() => _refCitas.add(selected));
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() => _newFiles.add(photo));
    }
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'mp4',
        'mov',
      ],
    );
    if (result != null && result.files.isNotEmpty) {
      final xFiles = result.files
          .where((f) => f.path != null)
          .map((f) => XFile(f.path!))
          .toList();
      setState(() => _newFiles.addAll(xFiles));
    }
  }

  Future<void> _pickSolucionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _solucionProgramada ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _solucionProgramada = picked);
    }
  }

  // ── Guardar ──────────────────────────────────────────

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

      final empresaName = proyecto.fkEmpresa;
      final solucionStr = _solucionProgramada != null
          ? '${_solucionProgramada!.year}/${_solucionProgramada!.month}/${_solucionProgramada!.day}'
          : null;

      if (_isEditing) {
        final existing = ref.read(ticketByIdProvider(widget.ticketId!)).value;
        if (existing == null) return;

        // Subir nuevos archivos a Firebase Storage
        List<String> allEvidencias = [..._existingEvidencias];
        if (_newFiles.isNotEmpty) {
          final storageService = StorageService();
          final newUrls = await storageService.uploadMultipleEvidence(
            widget.ticketId!,
            _newFiles,
          );
          allEvidencias.addAll(newUrls);
        }

        await repo.update(
          existing.copyWith(
            titulo: _tituloController.text.trim(),
            descripcion: _descripcionController.text.trim(),
            moduleId: _selectedModuleId,
            moduleName: _selectedModuleName,
            priority: _priority,
            empresaName: empresaName,
            porcentajeAvance: _porcentajeAvance,
            impacto: _impacto,
            cobertura: _cobertura,
            solucionProgramada: solucionStr,
            evidencias: allEvidencias,
            refMinutas: _refMinutas,
            refCitas: _refCitas,
          ),
        );

        // Sincronización bidireccional: cada minuta vinculada debe saber de este ticket
        final minutaRepo = ref.read(minutaRepositoryProvider);
        for (final minutaId in _refMinutas) {
          await minutaRepo.addRefTicket(minutaId, widget.ticketId!);
        }

        if (mounted) {
          context.pop();
        }
      } else {
        // Crear ticket primero para obtener el ID
        final ticket = Ticket(
          id: '',
          folio: '',
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
          empresaName: empresaName,
          porcentajeAvance: _porcentajeAvance,
          impacto: _impacto,
          cobertura: _cobertura,
          solucionProgramada: solucionStr,
          refMinutas: _refMinutas,
          refCitas: _refCitas,
        );

        final ticketId = await repo.create(ticket);

        // Subir evidencias con el ID del ticket creado
        if (_newFiles.isNotEmpty) {
          final storageService = StorageService();
          final urls = await storageService.uploadMultipleEvidence(
            ticketId,
            _newFiles,
          );
          await repo.updateEvidencias(ticketId, urls);
        }

        // Sincronización bidireccional
        final minutaRepo = ref.read(minutaRepositoryProvider);
        for (final minutaId in _refMinutas) {
          await minutaRepo.addRefTicket(minutaId, ticketId);
        }

        // Sincronización citas vinculadas
        for (final citaId in _refCitas) {
          await repo.addRefCita(ticketId, citaId);
        }

        if (mounted) {
          if (widget.returnId) {
            context.pop(ticketId);
          } else {
            context.pop();
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

// ── Helpers de UI ──────────────────────────────────────

Color _priorityColor(TicketPriority priority) {
  return switch (priority) {
    TicketPriority.baja => const Color(0xFF4CAF50),
    TicketPriority.media => const Color(0xFF2196F3),
    TicketPriority.alta => const Color(0xFFFFC107),
    TicketPriority.critica => const Color(0xFFD71921),
  };
}

IconData _fileIcon(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => Icons.image_outlined,
    'mp4' || 'mov' => Icons.videocam_outlined,
    'pdf' => Icons.picture_as_pdf_outlined,
    'doc' || 'docx' => Icons.description_outlined,
    'xls' || 'xlsx' => Icons.table_chart_outlined,
    _ => Icons.insert_drive_file_outlined,
  };
}

class _EvidenceChip extends StatelessWidget {
  const _EvidenceChip({required this.url, required this.onDelete});

  final String url;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isImage = _isImageUrl(url);
    return Chip(
      avatar: isImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                url,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 18),
              ),
            )
          : const Icon(Icons.attach_file, size: 18),
      label: Text(_fileName(url), style: Theme.of(context).textTheme.bodySmall),
      onDeleted: onDelete,
    );
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.gif') ||
        lower.contains('.webp');
  }

  String _fileName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final name = Uri.decodeComponent(segments.last);
        return name.length > 25 ? '${name.substring(0, 25)}...' : name;
      }
    } catch (_) {
      // ignore
    }
    return 'Archivo';
  }
}

// ── Search Minuta Dialog ─────────────────────────────────

class _SearchMinutaDialog extends StatefulWidget {
  const _SearchMinutaDialog({required this.minutas});

  final List<Minuta> minutas;

  @override
  State<_SearchMinutaDialog> createState() => _SearchMinutaDialogState();
}

class _SearchMinutaDialogState extends State<_SearchMinutaDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.minutas.where((m) {
      if (_query.isEmpty) return true;
      final upper = _query.toUpperCase();
      return m.folio.toUpperCase().contains(upper) ||
          m.objetivo.toUpperCase().contains(upper);
    }).toList();

    return AlertDialog(
      title: const Text('Buscar minuta'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por folio u objetivo...',
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
                        final m = filtered[i];
                        return ListTile(
                          title: Text(
                            '${m.folio} — ${m.objetivo}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(ctx, m.id),
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

class _SearchCitaDialog extends StatefulWidget {
  const _SearchCitaDialog({required this.citas});

  final List<Cita> citas;

  @override
  State<_SearchCitaDialog> createState() => _SearchCitaDialogState();
}

class _SearchCitaDialogState extends State<_SearchCitaDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.citas.where((c) {
      if (_query.isEmpty) return true;
      final upper = _query.toUpperCase();
      return c.folio.toUpperCase().contains(upper) ||
          c.titulo.toUpperCase().contains(upper);
    }).toList();

    return AlertDialog(
      title: const Text('Buscar cita'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por folio o título...',
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
                        final c = filtered[i];
                        return ListTile(
                          leading: const Icon(Icons.event_outlined),
                          title: Text(
                            '${c.folio} — ${c.titulo}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(ctx, c.id),
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
