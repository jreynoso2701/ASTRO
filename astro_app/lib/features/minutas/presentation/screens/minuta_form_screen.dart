import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:astro/core/models/minuta.dart';
import 'package:astro/core/models/minuta_modalidad.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/documento_proyecto.dart';
import 'package:astro/core/models/documento_seccion.dart';
import 'package:astro/core/services/minuta_pdf_service.dart';
import 'package:astro/core/services/places_service.dart';
import 'package:astro/core/services/storage_service.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/minutas/providers/minuta_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/documentation/providers/documento_providers.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/core/models/tarea.dart';
import 'package:astro/core/models/tarea_status.dart';
import 'package:astro/core/models/tarea_prioridad.dart';
import 'package:astro/features/tareas/data/tarea_repository.dart';

/// Pantalla de creación / edición de minuta.
class MinutaFormScreen extends ConsumerStatefulWidget {
  const MinutaFormScreen({
    required this.projectId,
    this.minutaId,
    this.citaId,
    super.key,
  });

  final String projectId;
  final String? minutaId;
  final String? citaId;

  @override
  ConsumerState<MinutaFormScreen> createState() => _MinutaFormScreenState();
}

class _MinutaFormScreenState extends ConsumerState<MinutaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _objetivoController = TextEditingController();
  final _lugarController = TextEditingController();
  final _urlController = TextEditingController();
  final _direccionController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _versionController = TextEditingController(text: '1.0.0');

  MinutaModalidad _modalidad = MinutaModalidad.videoconferencia;
  DateTime? _fecha;
  String? _horaInicio;
  String? _horaFin;

  final List<AsistenteMinuta> _asistentes = [];
  final List<AsuntoTratado> _asuntos = [];
  final List<CompromisoMinuta> _compromisos = [];
  final List<String> _adjuntos = [];
  final List<XFile> _pendingFiles = [];
  final List<String> _refTickets = [];
  final List<String> _refRequerimientos = [];

  bool _isSaving = false;
  bool _isLoaded = false;
  bool _citaPreloaded = false;

  bool get _isEditing => widget.minutaId != null;

  bool get _showLugar =>
      _modalidad == MinutaModalidad.presencial ||
      _modalidad == MinutaModalidad.hibrida;

  bool get _showUrl =>
      _modalidad == MinutaModalidad.videoconferencia ||
      _modalidad == MinutaModalidad.hibrida;

  bool get _showDireccion =>
      _modalidad == MinutaModalidad.presencial ||
      _modalidad == MinutaModalidad.hibrida;

  @override
  void dispose() {
    _objetivoController.dispose();
    _lugarController.dispose();
    _urlController.dispose();
    _direccionController.dispose();
    _observacionesController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proyectoAsync = ref.watch(proyectoByIdProvider(widget.projectId));
    final proyecto = proyectoAsync.value;
    final projectName = proyecto?.nombreProyecto ?? '';
    final empresaName = proyecto?.fkEmpresa ?? '';

    if (projectName.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('CARGANDO...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Si estamos editando, cargar datos
    if (_isEditing && !_isLoaded) {
      final minutaAsync = ref.watch(minutaByIdProvider(widget.minutaId!));

      minutaAsync.whenData((minuta) {
        if (minuta != null && !_isLoaded) {
          _objetivoController.text = minuta.objetivo;
          _lugarController.text = minuta.lugar ?? '';
          _urlController.text = minuta.urlVideoconferencia ?? '';
          _direccionController.text = minuta.direccion ?? '';
          _observacionesController.text = minuta.observaciones ?? '';
          _versionController.text = minuta.version;
          _modalidad = minuta.modalidad;
          _fecha = minuta.fecha;
          _horaInicio = minuta.horaInicio;
          _horaFin = minuta.horaFin;
          _asistentes.addAll(minuta.asistentes);
          _asuntos.addAll(minuta.asuntosTratados);
          _compromisos.addAll(minuta.compromisos);
          _adjuntos.addAll(minuta.adjuntos);
          _refTickets.addAll(minuta.refTickets);
          _refRequerimientos.addAll(minuta.refRequerimientos);
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

    // Pre-poblar desde cita (solo al crear)
    if (widget.citaId != null && !_isEditing && !_citaPreloaded) {
      final citaAsync = ref.watch(citaByIdProvider(widget.citaId!));
      citaAsync.whenData((cita) {
        if (cita != null && !_citaPreloaded) {
          _fecha = cita.fecha;
          _horaInicio = cita.horaInicio;
          _horaFin = cita.horaFin;
          _modalidad = cita.modalidad;
          if (cita.urlVideoconferencia != null) {
            _urlController.text = cita.urlVideoconferencia!;
          }
          if (cita.direccion != null) {
            _direccionController.text = cita.direccion!;
          }
          for (final p in cita.participantes) {
            _asistentes.add(
              AsistenteMinuta(
                uid: p.uid.isNotEmpty ? p.uid : null,
                nombre: p.nombre,
                puesto: p.rol ?? '',
              ),
            );
          }
          _objetivoController.text = cita.titulo;
          _citaPreloaded = true;
          if (mounted) setState(() {});
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'EDITAR MINUTA' : 'NUEVA MINUTA'),
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
              // ── Información general ───────────────────
              _SectionHeader(label: 'INFORMACIÓN GENERAL'),
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

              // Versión
              TextFormField(
                controller: _versionController,
                decoration: const InputDecoration(
                  labelText: 'Versión minuta',
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 16),

              // Objetivo
              TextFormField(
                controller: _objetivoController,
                decoration: const InputDecoration(
                  labelText: 'Objetivo de la reunión *',
                  prefixIcon: Icon(Icons.flag_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El objetivo es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Fecha y horario ───────────────────────
              _SectionHeader(label: 'FECHA Y HORARIO'),
              const SizedBox(height: 8),

              // Fecha
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _fecha != null
                      ? DateFormat('dd/MM/yyyy').format(_fecha!)
                      : 'Seleccionar fecha *',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),

              // Horas
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(_horaInicio ?? 'Hora inicio'),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(_horaFin ?? 'Hora fin'),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Modalidad
              DropdownButtonFormField<MinutaModalidad>(
                initialValue: _modalidad,
                decoration: const InputDecoration(
                  labelText: 'Modalidad',
                  prefixIcon: Icon(Icons.videocam_outlined),
                ),
                items: MinutaModalidad.values.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m.label));
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _modalidad = value);
                },
              ),
              const SizedBox(height: 16),

              // URL Videoconferencia (videoconferencia / híbrida)
              if (_showUrl) ...[
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL Videoconferencia',
                    prefixIcon: Icon(Icons.link),
                    hintText: 'Zoom / Teams / Meet',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
              ],

              // Dirección — editable + búsqueda Google Maps (presencial / híbrida)
              if (_showDireccion) ...[
                TextFormField(
                  controller: _direccionController,
                  decoration: InputDecoration(
                    labelText: 'Dirección',
                    prefixIcon: const Icon(Icons.map_outlined),
                    hintText: 'Escribe o busca una dirección...',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_direccionController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setState(() => _direccionController.clear()),
                          ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          tooltip: 'Buscar en Google Maps',
                          onPressed: _showPlacesSearch,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Lugar / Referencia (presencial / híbrida)
              if (_showLugar) ...[
                TextFormField(
                  controller: _lugarController,
                  decoration: const InputDecoration(
                    labelText: 'Lugar / Referencia',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    hintText: 'Ej: Segundo piso, sala de juntas',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 8),

              // ── Asistentes ────────────────────────────
              _SectionHeader(label: 'ASISTENTES'),
              const SizedBox(height: 8),

              ..._asistentes.asMap().entries.map(
                (e) => _AsistenteRow(
                  asistente: e.value,
                  onRemove: () => setState(() => _asistentes.removeAt(e.key)),
                  onEdit: (updated) =>
                      setState(() => _asistentes[e.key] = updated),
                ),
              ),

              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _addAsistenteFromProject,
                    icon: const Icon(Icons.person_search),
                    label: const Text('Buscar del proyecto'),
                  ),
                  TextButton.icon(
                    onPressed: _addAsistenteExterno,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Agregar externo'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Asuntos tratados ──────────────────────
              _SectionHeader(label: 'ASUNTOS TRATADOS'),
              const SizedBox(height: 8),

              ..._asuntos.asMap().entries.map(
                (e) => _AsuntoRow(
                  asunto: e.value,
                  onRemove: () => setState(() => _asuntos.removeAt(e.key)),
                ),
              ),

              TextButton.icon(
                onPressed: _addAsunto,
                icon: const Icon(Icons.add),
                label: const Text('Agregar asunto'),
              ),
              const SizedBox(height: 24),

              // ── Compromisos ───────────────────────────
              _SectionHeader(label: 'COMPROMISOS ASUMIDOS'),
              const SizedBox(height: 8),

              ..._compromisos.asMap().entries.map(
                (e) => _CompromisoRow(
                  compromiso: e.value,
                  onRemove: () => setState(() => _compromisos.removeAt(e.key)),
                ),
              ),

              TextButton.icon(
                onPressed: _addCompromiso,
                icon: const Icon(Icons.add),
                label: const Text('Agregar compromiso'),
              ),
              const SizedBox(height: 24),

              // ── Adjuntos ──────────────────────────────
              _SectionHeader(label: 'ADJUNTOS'),
              const SizedBox(height: 8),

              ..._adjuntos.asMap().entries.map(
                (e) => _AdjuntoRow(
                  url: e.value,
                  onRemove: () => setState(() => _adjuntos.removeAt(e.key)),
                ),
              ),
              ..._pendingFiles.asMap().entries.map(
                (e) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: Text(e.value.name, overflow: TextOverflow.ellipsis),
                    subtitle: const Text('Pendiente de subir'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _pendingFiles.removeAt(e.key)),
                    ),
                  ),
                ),
              ),

              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Archivo'),
                  ),
                  TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Imagen'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Tickets vinculados ────────────────────
              _SectionHeader(label: 'TICKETS VINCULADOS'),
              const SizedBox(height: 8),

              ..._refTickets.map(
                (id) => _RefChip(
                  id: id,
                  icon: Icons.confirmation_num_outlined,
                  onRemove: () => setState(() => _refTickets.remove(id)),
                ),
              ),

              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _searchTickets(projectName),
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar ticket'),
                  ),
                  TextButton.icon(
                    onPressed: () => _navigateNewTicket(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo ticket'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Requerimientos vinculados ──────────────
              _SectionHeader(label: 'REQUERIMIENTOS VINCULADOS'),
              const SizedBox(height: 8),

              ..._refRequerimientos.map(
                (id) => _RefChip(
                  id: id,
                  icon: Icons.assignment_outlined,
                  onRemove: () => setState(() => _refRequerimientos.remove(id)),
                ),
              ),

              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _searchRequerimientos(projectName),
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar requerimiento'),
                  ),
                  TextButton.icon(
                    onPressed: () => _navigateNewRequerimiento(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo requerimiento'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Observaciones ─────────────────────────
              _SectionHeader(label: 'OBSERVACIONES'),
              const SizedBox(height: 8),

              TextFormField(
                controller: _observacionesController,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
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
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Guardar cambios' : 'Crear minuta'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      final formatted = picked.format(context);
      setState(() {
        if (isStart) {
          _horaInicio = formatted;
        } else {
          _horaFin = formatted;
        }
      });
    }
  }

  // ─── Google Places ──────────────────────────────────

  Future<void> _showPlacesSearch() async {
    final placesService = ref.read(placesServiceProvider);
    if (placesService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Búsqueda de direcciones no disponible. '
              'Escribe la dirección manualmente.',
            ),
          ),
        );
      }
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _PlacesSearchDialog(placesService: placesService),
    );
    if (result != null) {
      setState(() => _direccionController.text = result);
    }
  }

  // ─── Asistentes ───────────────────────────────────────

  void _addAsistenteFromProject() async {
    final members = ref.read(projectMembersProvider(widget.projectId));
    final existingUids = _asistentes
        .where((a) => a.uid != null)
        .map((a) => a.uid!)
        .toSet();

    final available = members
        .where((m) => m.user != null && !existingUids.contains(m.user!.uid))
        .toList();

    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todos los miembros del proyecto ya están agregados'),
          ),
        );
      }
      return;
    }

    // Mapear a items simples para el diálogo
    final items = available.map((m) {
      return (
        uid: m.user!.uid,
        name: m.user!.displayName,
        role: m.assignment.role.label,
      );
    }).toList();

    final selected = await showDialog<List<AsistenteMinuta>>(
      context: context,
      builder: (ctx) => _ProjectMembersDialog(items: items),
    );

    if (selected != null && selected.isNotEmpty) {
      setState(() => _asistentes.addAll(selected));
    }
  }

  void _addAsistenteExterno() async {
    final result = await _showAsistenteDialog();
    if (result != null) {
      setState(() => _asistentes.add(result));
    }
  }

  Future<AsistenteMinuta?> _showAsistenteDialog({
    AsistenteMinuta? initial,
  }) async {
    final nombreCtrl = TextEditingController(text: initial?.nombre ?? '');
    final puestoCtrl = TextEditingController(text: initial?.puesto ?? '');
    bool asistencia = initial?.asistencia ?? true;

    return showDialog<AsistenteMinuta>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            initial != null ? 'Editar asistente' : 'Asistente externo',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: puestoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Puesto / Empresa *',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Asistencia'),
                value: asistencia,
                onChanged: (v) => setDlgState(() => asistencia = v),
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
                if (nombreCtrl.text.trim().isEmpty ||
                    puestoCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  ctx,
                  AsistenteMinuta(
                    nombre: nombreCtrl.text.trim(),
                    puesto: puestoCtrl.text.trim(),
                    asistencia: asistencia,
                  ),
                );
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Adjuntos ─────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      final xFiles = result.files
          .where((f) => f.path != null)
          .map((f) => XFile(f.path!, name: f.name))
          .toList();
      if (xFiles.isNotEmpty) setState(() => _pendingFiles.addAll(xFiles));
    }
  }

  Future<void> _pickImage() async {
    final images = await ImagePicker().pickMultiImage();
    if (images.isNotEmpty) setState(() => _pendingFiles.addAll(images));
  }

  // ─── Tickets search / quick-create ────────────────────

  Future<void> _searchTickets(String projectName) async {
    final tickets = ref.read(ticketsByProjectProvider(projectName)).value ?? [];
    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchRefDialog<Ticket>(
        title: 'Buscar ticket',
        items: tickets.where((t) => !_refTickets.contains(t.id)).toList(),
        labelBuilder: (t) => '${t.folio} — ${t.titulo}',
        idBuilder: (t) => t.id,
      ),
    );
    if (selected != null) setState(() => _refTickets.add(selected));
  }

  Future<void> _navigateNewTicket() async {
    final createdId = await context.push<String>(
      '/projects/${widget.projectId}/tickets/new',
      extra: {'returnId': true},
    );
    if (createdId != null && mounted) {
      setState(() => _refTickets.add(createdId));
    }
  }

  // ─── Requerimientos search / quick-create ─────────────

  Future<void> _searchRequerimientos(String projectName) async {
    final reqs =
        ref.read(requerimientosByProjectProvider(projectName)).value ?? [];
    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchRefDialog<Requerimiento>(
        title: 'Buscar requerimiento',
        items: reqs.where((r) => !_refRequerimientos.contains(r.id)).toList(),
        labelBuilder: (r) => '${r.folio} — ${r.titulo}',
        idBuilder: (r) => r.id,
      ),
    );
    if (selected != null) setState(() => _refRequerimientos.add(selected));
  }

  Future<void> _navigateNewRequerimiento() async {
    final createdId = await context.push<String>(
      '/projects/${widget.projectId}/requirements/new',
      extra: {'returnId': true},
    );
    if (createdId != null && mounted) {
      setState(() => _refRequerimientos.add(createdId));
    }
  }

  void _addAsunto() async {
    final textoCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo asunto'),
        content: TextField(
          controller: textoCtrl,
          decoration: const InputDecoration(labelText: 'Descripción *'),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (textoCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, textoCtrl.text.trim());
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        _asuntos.add(AsuntoTratado(numero: _asuntos.length + 1, texto: result));
      });
    }
  }

  void _addCompromiso() async {
    final tareaCtrl = TextEditingController();
    final responsableCtrl = TextEditingController();
    DateTime? fechaEntrega;
    String? selectedUid;

    // Obtener miembros del proyecto para sugerencias
    final members = ref.read(projectMembersProvider(widget.projectId));
    final memberItems = members
        .where((m) => m.user != null)
        .map((m) => (uid: m.user!.uid, nombre: m.user!.displayName))
        .toList();

    final result = await showDialog<CompromisoMinuta>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Nuevo compromiso'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tareaCtrl,
                  decoration: const InputDecoration(labelText: 'Tarea *'),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                // Autocomplete: permite seleccionar un miembro o escribir nombre externo
                Autocomplete<({String uid, String nombre})>(
                  displayStringForOption: (opt) => opt.nombre,
                  optionsBuilder: (textEditingValue) {
                    final text = textEditingValue.text.toLowerCase();
                    if (text.isEmpty) return memberItems;
                    return memberItems.where(
                      (m) => m.nombre.toLowerCase().contains(text),
                    );
                  },
                  onSelected: (opt) {
                    setDlgState(() {
                      selectedUid = opt.uid;
                      responsableCtrl.text = opt.nombre;
                    });
                  },
                  fieldViewBuilder: (ctx, textCtrl, focusNode, onFieldSubmitted) {
                    // Sincronizar con nuestro controller
                    textCtrl.addListener(() {
                      responsableCtrl.text = textCtrl.text;
                      // Si el texto ya no coincide con un miembro, limpiar UID
                      final match = memberItems.where(
                        (m) => m.nombre == textCtrl.text,
                      );
                      if (match.isEmpty) {
                        selectedUid = null;
                      }
                    });
                    return TextField(
                      controller: textCtrl,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Responsable *',
                        hintText: 'Escribe o selecciona un miembro',
                      ),
                      textCapitalization: TextCapitalization.words,
                    );
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    fechaEntrega != null
                        ? DateFormat('dd/MM/yyyy').format(fechaEntrega!)
                        : 'Fecha de entrega',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDlgState(() => fechaEntrega = picked);
                    }
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
              onPressed: () {
                if (tareaCtrl.text.trim().isEmpty ||
                    responsableCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  ctx,
                  CompromisoMinuta(
                    numero: _compromisos.length + 1,
                    tarea: tareaCtrl.text.trim(),
                    responsable: responsableCtrl.text.trim(),
                    responsableUid: selectedUid, // null si es externo
                    fechaEntrega: fechaEntrega,
                  ),
                );
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() => _compromisos.add(result));
    }
  }

  /// Genera el PDF de la minuta y lo guarda como documento formal.
  Future<void> _generatePdfDocumento({
    required String minutaId,
    required dynamic proyecto,
    required dynamic profile,
  }) async {
    try {
      // Leer la minuta guardada (con folio generado)
      final snap = await FirebaseFirestore.instance
          .collection('Minutas')
          .doc(minutaId)
          .get();
      if (!snap.exists) return;

      final savedMinuta = Minuta.fromFirestore(snap);

      // Generar PDF
      final pdfDoc = await MinutaPdfService.generate(savedMinuta);
      final pdfBytes = await pdfDoc.save();

      // Subir a Storage
      final storage = StorageService();
      final fileName = 'Minuta_${savedMinuta.folio}.pdf';
      final pdfUrl = await storage.uploadBytes(
        'documentacion/${widget.projectId}/formales',
        Uint8List.fromList(pdfBytes),
        fileName,
        mimeType: 'application/pdf',
      );

      // Crear documento formal
      final docRepo = ref.read(documentoRepositoryProvider);
      await docRepo.create(
        DocumentoProyecto(
          id: '',
          folio: '',
          titulo: 'Minuta — ${savedMinuta.folio}',
          seccion: DocumentoSeccion.formal,
          categoria: 'Minuta',
          projectName: proyecto.nombreProyecto,
          projectId: widget.projectId,
          empresaName: proyecto.fkEmpresa,
          createdBy: profile?.uid ?? '',
          createdByName: profile?.displayName ?? '',
          archivoUrl: pdfUrl,
          archivoNombre: fileName,
          archivoTipo: 'application/pdf',
          archivoSize: pdfBytes.length,
        ),
      );
    } catch (_) {
      // PDF generation is best-effort; don't block minuta save
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de la reunión')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final proyecto = ref.read(proyectoByIdProvider(widget.projectId)).value!;
      final profile = ref.read(currentUserProfileProvider).value;
      final repo = ref.read(minutaRepositoryProvider);

      // Subir archivos pendientes
      if (_pendingFiles.isNotEmpty) {
        final storage = StorageService();
        for (final file in _pendingFiles) {
          final url = await storage.uploadToPath(
            'minutas/${widget.projectId}',
            file,
          );
          _adjuntos.add(url);
        }
        _pendingFiles.clear();
      }

      // Construir participantUids desnormalizado
      final participantUids = <String>{};
      for (final a in _asistentes) {
        if (a.uid != null) participantUids.add(a.uid!);
      }
      for (final c in _compromisos) {
        if (c.responsableUid != null) participantUids.add(c.responsableUid!);
      }

      final minuta = Minuta(
        id: widget.minutaId ?? '',
        folio: '',
        version: _versionController.text.trim(),
        projectId: widget.projectId,
        projectName: proyecto.nombreProyecto,
        empresaName: proyecto.fkEmpresa,
        objetivo: _objetivoController.text.trim(),
        fecha: _fecha,
        horaInicio: _horaInicio,
        horaFin: _horaFin,
        lugar: _lugarController.text.trim().isNotEmpty
            ? _lugarController.text.trim()
            : null,
        modalidad: _modalidad,
        urlVideoconferencia: _urlController.text.trim().isNotEmpty
            ? _urlController.text.trim()
            : null,
        direccion: _direccionController.text.trim().isNotEmpty
            ? _direccionController.text.trim()
            : null,
        asistentes: _asistentes,
        asuntosTratados: _asuntos,
        compromisos: _compromisos,
        adjuntos: _adjuntos,
        refTickets: _refTickets,
        refRequerimientos: _refRequerimientos,
        refCita: widget.citaId,
        participantUids: participantUids.toList(),
        observaciones: _observacionesController.text.trim().isNotEmpty
            ? _observacionesController.text.trim()
            : null,
        createdBy: profile?.uid,
        createdByName: profile?.displayName ?? '',
      );

      if (_isEditing) {
        await repo.update(minuta);

        // Sincronización bidireccional
        final ticketRepo = ref.read(ticketRepositoryProvider);
        final reqRepo = ref.read(requerimientoRepositoryProvider);
        for (final ticketId in _refTickets) {
          await ticketRepo.addRefMinuta(ticketId, widget.minutaId!);
        }
        for (final reqId in _refRequerimientos) {
          await reqRepo.addRefMinuta(reqId, widget.minutaId!);
        }

        // Auto-generar PDF como documento formal
        await _generatePdfDocumento(
          minutaId: widget.minutaId!,
          proyecto: proyecto,
          profile: profile,
        );

        // Auto-crear tareas para compromisos con responsable asignado
        await _autoCreateTareasFromCompromisos(
          minutaId: widget.minutaId!,
          proyecto: proyecto,
          profile: profile,
        );

        if (mounted) {
          context.pop();
        }
      } else {
        final docId = await repo.create(minuta);

        // Vincular cita → minuta generada
        if (widget.citaId != null) {
          final citaRepo = ref.read(citaRepositoryProvider);
          await citaRepo.setRefMinuta(widget.citaId!, docId);
        }

        // Sincronización bidireccional
        final ticketRepo = ref.read(ticketRepositoryProvider);
        final reqRepo = ref.read(requerimientoRepositoryProvider);
        for (final ticketId in _refTickets) {
          await ticketRepo.addRefMinuta(ticketId, docId);
        }
        for (final reqId in _refRequerimientos) {
          await reqRepo.addRefMinuta(reqId, docId);
        }

        // Auto-generar PDF como documento formal
        await _generatePdfDocumento(
          minutaId: docId,
          proyecto: proyecto,
          profile: profile,
        );

        // Auto-crear tareas para compromisos con responsable asignado
        await _autoCreateTareasFromCompromisos(
          minutaId: docId,
          proyecto: proyecto,
          profile: profile,
        );

        if (mounted) {
          context.pushReplacement(
            '/projects/${widget.projectId}/minutas/$docId',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Auto-crea tareas para compromisos que tengan responsableUid definido.
  /// Evita duplicados verificando si ya existe una tarea con la misma
  /// combinación de minutaId + compromisoNumero.
  Future<void> _autoCreateTareasFromCompromisos({
    required String minutaId,
    required dynamic proyecto,
    required dynamic profile,
  }) async {
    try {
      final tareaRepo = TareaRepository();
      final db = FirebaseFirestore.instance;

      for (final c in _compromisos) {
        if (c.responsableUid == null) continue;

        // Verificar si ya existe una tarea para este compromiso
        final existing = await db
            .collection('Tareas')
            .where('refMinutaId', isEqualTo: minutaId)
            .where('refCompromisoNumero', isEqualTo: c.numero)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) continue;

        final tarea = Tarea(
          id: '',
          folio: '',
          titulo: c.tarea,
          descripcion: 'Compromiso de minuta: ${c.tarea}',
          projectId: widget.projectId,
          projectName: proyecto.nombreProyecto,
          status: TareaStatus.pendiente,
          prioridad: TareaPrioridad.media,
          createdByUid: profile?.uid ?? '',
          createdByName: profile?.displayName ?? '',
          assignedToUid: c.responsableUid,
          assignedToName: c.responsable,
          fechaEntrega: c.fechaEntrega,
          refMinutas: [minutaId],
          refCompromisoNumero: c.numero,
        );

        await tareaRepo.create(tarea);
      }
    } catch (_) {
      // Best-effort: no bloquear el guardado de la minuta.
    }
  }
}

// ── Section Header ───────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            letterSpacing: 1,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Divider(),
      ],
    );
  }
}

// ── Asistente Row ────────────────────────────────────────

class _AsistenteRow extends StatelessWidget {
  const _AsistenteRow({
    required this.asistente,
    required this.onRemove,
    required this.onEdit,
  });

  final AsistenteMinuta asistente;
  final VoidCallback onRemove;
  final ValueChanged<AsistenteMinuta> onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          asistente.asistencia
              ? Icons.check_circle_outline
              : Icons.cancel_outlined,
          color: asistente.asistencia
              ? const Color(0xFF4CAF50)
              : Theme.of(context).colorScheme.error,
        ),
        title: Text(asistente.nombre),
        subtitle: Row(
          children: [
            Expanded(child: Text(asistente.puesto)),
            if (asistente.uid != null)
              Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

// ── Asunto Row ───────────────────────────────────────────

class _AsuntoRow extends StatelessWidget {
  const _AsuntoRow({required this.asunto, required this.onRemove});

  final AsuntoTratado asunto;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 14,
          child: Text('${asunto.numero}', style: const TextStyle(fontSize: 12)),
        ),
        title: Text(asunto.texto),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

// ── Compromiso Row ───────────────────────────────────────

class _CompromisoRow extends StatelessWidget {
  const _CompromisoRow({required this.compromiso, required this.onRemove});

  final CompromisoMinuta compromiso;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fechaStr = compromiso.fechaEntrega != null
        ? DateFormat('dd/MM/yyyy').format(compromiso.fechaEntrega!)
        : 'Sin fecha';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              child: Text(
                '${compromiso.numero}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(compromiso.tarea, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${compromiso.responsable} • $fechaStr',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
          ],
        ),
      ),
    );
  }
}

// ── Adjunto Row ──────────────────────────────────────────

class _AdjuntoRow extends StatelessWidget {
  const _AdjuntoRow({required this.url, required this.onRemove});

  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final decodedUrl = Uri.decodeFull(url);
    final fileName = decodedUrl.split('/').last.split('?').first;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.attachment),
        title: Text(fileName, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

// ── Reference Chip ───────────────────────────────────────

class _RefChip extends StatelessWidget {
  const _RefChip({
    required this.id,
    required this.icon,
    required this.onRemove,
  });

  final String id;
  final IconData icon;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Chip(
        avatar: Icon(icon, size: 16),
        label: Text(
          id.length > 12 ? '${id.substring(0, 12)}...' : id,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onDeleted: onRemove,
        deleteIcon: const Icon(Icons.close, size: 16),
      ),
    );
  }
}

// ── Project Members Dialog (multi-select) ────────────────

class _ProjectMembersDialog extends StatefulWidget {
  const _ProjectMembersDialog({required this.items});

  final List<({String uid, String name, String role})> items;

  @override
  State<_ProjectMembersDialog> createState() => _ProjectMembersDialogState();
}

class _ProjectMembersDialogState extends State<_ProjectMembersDialog> {
  final _selected = <int>{};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.asMap().entries.where((e) {
      if (_search.isEmpty) return true;
      return e.value.name.toUpperCase().contains(_search.toUpperCase());
    }).toList();

    return AlertDialog(
      title: const Text('Agregar del proyecto'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar miembro...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final entry = filtered[i];
                  final item = entry.value;
                  final idx = entry.key;
                  final isSelected = _selected.contains(idx);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(idx);
                        } else {
                          _selected.remove(idx);
                        }
                      });
                    },
                    title: Text(item.name),
                    subtitle: Text(item.role),
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
        FilledButton(
          onPressed: () {
            final result = _selected.map((idx) {
              final item = widget.items[idx];
              return AsistenteMinuta(
                uid: item.uid,
                nombre: item.name,
                puesto: item.role,
              );
            }).toList();
            Navigator.pop(context, result);
          },
          child: Text('Agregar (${_selected.length})'),
        ),
      ],
    );
  }
}

// ── Places Search Dialog ─────────────────────────────────

class _PlacesSearchDialog extends StatefulWidget {
  const _PlacesSearchDialog({required this.placesService});

  final PlacesService placesService;

  @override
  State<_PlacesSearchDialog> createState() => _PlacesSearchDialogState();
}

class _PlacesSearchDialogState extends State<_PlacesSearchDialog> {
  final _searchCtrl = TextEditingController();
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 3) {
      setState(() => _predictions = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await widget.placesService.autocomplete(
        query,
        country: 'mx',
      );
      if (mounted) {
        setState(() {
          _predictions = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar dirección'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Escribe una dirección...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: _search,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _predictions.isEmpty
                  ? Center(
                      child: Text(
                        _searchCtrl.text.length < 3
                            ? 'Escribe al menos 3 caracteres'
                            : 'Sin resultados',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _predictions.length,
                      itemBuilder: (ctx, i) {
                        final p = _predictions[i];
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(
                            p.mainText ?? p.description,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: p.secondaryText != null
                              ? Text(
                                  p.secondaryText!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () => Navigator.pop(ctx, p.description),
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

// ── Search Reference Dialog (generic) ────────────────────

class _SearchRefDialog<T> extends StatefulWidget {
  const _SearchRefDialog({
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.idBuilder,
    super.key,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T) idBuilder;

  @override
  State<_SearchRefDialog<T>> createState() => _SearchRefDialogState<T>();
}

class _SearchRefDialogState<T> extends State<_SearchRefDialog<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((item) {
      if (_query.isEmpty) return true;
      return widget
          .labelBuilder(item)
          .toUpperCase()
          .contains(_query.toUpperCase());
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
                          title: Text(
                            widget.labelBuilder(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
