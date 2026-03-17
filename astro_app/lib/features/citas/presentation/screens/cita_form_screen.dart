import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/cita.dart';
import 'package:astro/core/models/minuta_modalidad.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de creación / edición de cita.
class CitaFormScreen extends ConsumerStatefulWidget {
  const CitaFormScreen({required this.projectId, this.citaId, super.key});

  final String projectId;
  final String? citaId;

  @override
  ConsumerState<CitaFormScreen> createState() => _CitaFormScreenState();
}

class _CitaFormScreenState extends ConsumerState<CitaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _urlController = TextEditingController();
  final _direccionController = TextEditingController();
  final _notasController = TextEditingController();

  MinutaModalidad _modalidad = MinutaModalidad.videoconferencia;
  DateTime? _fecha;
  String? _horaInicio;
  String? _horaFin;

  // Participantes
  final List<ParticipanteCita> _participantes = [];

  // Recordatorios (minutos antes)
  final List<int> _recordatorios = [15, 60];

  bool _isSaving = false;
  bool _isLoaded = false;

  bool get _isEditing => widget.citaId != null;

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _urlController.dispose();
    _direccionController.dispose();
    _notasController.dispose();
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
      final citaAsync = ref.watch(citaByIdProvider(widget.citaId!));

      citaAsync.whenData((cita) {
        if (cita != null && !_isLoaded) {
          _tituloController.text = cita.titulo;
          _descripcionController.text = cita.descripcion ?? '';
          _urlController.text = cita.urlVideoconferencia ?? '';
          _direccionController.text = cita.direccion ?? '';
          _notasController.text = cita.notas ?? '';
          _modalidad = cita.modalidad;
          _fecha = cita.fecha;
          _horaInicio = cita.horaInicio;
          _horaFin = cita.horaFin;
          _participantes.addAll(cita.participantes);
          _recordatorios
            ..clear()
            ..addAll(cita.recordatorios);
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
        title: Text(_isEditing ? 'EDITAR CITA' : 'NUEVA CITA'),
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

              // Título
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título de la cita *',
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
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              // ── Fecha y horario ───────────────────────
              _SectionHeader(label: 'FECHA Y HORARIO'),
              const SizedBox(height: 8),

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

              // URL Videoconferencia
              if (_modalidad == MinutaModalidad.videoconferencia ||
                  _modalidad == MinutaModalidad.hibrida) ...[
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

              // Dirección
              if (_modalidad == MinutaModalidad.presencial ||
                  _modalidad == MinutaModalidad.hibrida) ...[
                TextFormField(
                  controller: _direccionController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),

              // ── Participantes ─────────────────────────
              _SectionHeader(label: 'PARTICIPANTES'),
              const SizedBox(height: 8),

              ..._participantes.asMap().entries.map(
                (e) => _ParticipanteRow(
                  participante: e.value,
                  onRemove: () =>
                      setState(() => _participantes.removeAt(e.key)),
                ),
              ),

              TextButton.icon(
                onPressed: _addParticipante,
                icon: const Icon(Icons.add),
                label: const Text('Agregar participante'),
              ),
              const SizedBox(height: 24),

              // ── Recordatorios ─────────────────────────
              _SectionHeader(label: 'RECORDATORIOS'),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mins in [15, 30, 60, 120, 1440])
                    FilterChip(
                      label: Text(
                        mins >= 60
                            ? '${mins ~/ 60}h antes'
                            : '${mins}min antes',
                      ),
                      selected: _recordatorios.contains(mins),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _recordatorios.add(mins);
                          } else {
                            _recordatorios.remove(mins);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Notas ─────────────────────────────────
              _SectionHeader(label: 'NOTAS'),
              const SizedBox(height: 8),

              TextFormField(
                controller: _notasController,
                decoration: const InputDecoration(
                  labelText: 'Notas adicionales',
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
                      : Text(_isEditing ? 'Guardar cambios' : 'Crear cita'),
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
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
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

  void _addParticipante() async {
    final nombreCtrl = TextEditingController();
    final rolCtrl = TextEditingController();

    final result = await showDialog<ParticipanteCita>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo participante'),
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
              controller: rolCtrl,
              decoration: const InputDecoration(labelText: 'Rol / Puesto'),
              textCapitalization: TextCapitalization.sentences,
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
              if (nombreCtrl.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                ParticipanteCita(
                  uid: '', // Sin UID por ahora
                  nombre: nombreCtrl.text.trim(),
                  rol: rolCtrl.text.trim().isNotEmpty
                      ? rolCtrl.text.trim()
                      : null,
                ),
              );
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _participantes.add(result));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de la cita')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final proyecto = ref.read(proyectoByIdProvider(widget.projectId)).value!;
      final profile = ref.read(currentUserProfileProvider).value;
      final repo = ref.read(citaRepositoryProvider);

      final cita = Cita(
        id: widget.citaId ?? '',
        folio: '', // se genera en create
        titulo: _tituloController.text.trim(),
        projectId: widget.projectId,
        projectName: proyecto.nombreProyecto,
        empresaName: proyecto.fkEmpresa,
        createdByName: profile?.displayName ?? '',
        descripcion: _descripcionController.text.trim().isNotEmpty
            ? _descripcionController.text.trim()
            : null,
        fecha: _fecha,
        horaInicio: _horaInicio,
        horaFin: _horaFin,
        modalidad: _modalidad,
        urlVideoconferencia: _urlController.text.trim().isNotEmpty
            ? _urlController.text.trim()
            : null,
        direccion: _direccionController.text.trim().isNotEmpty
            ? _direccionController.text.trim()
            : null,
        participantes: _participantes,
        recordatorios: _recordatorios,
        notas: _notasController.text.trim().isNotEmpty
            ? _notasController.text.trim()
            : null,
        createdBy: profile?.uid,
      );

      if (_isEditing) {
        await repo.update(cita, updatedBy: profile?.uid ?? '');
        if (mounted) {
          context.pop();
        }
      } else {
        final docId = await repo.create(cita);
        if (mounted) {
          context.pushReplacement('/projects/${widget.projectId}/citas/$docId');
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

// ── Participante Row ─────────────────────────────────────

class _ParticipanteRow extends StatelessWidget {
  const _ParticipanteRow({required this.participante, required this.onRemove});

  final ParticipanteCita participante;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(participante.nombre),
        subtitle: participante.rol != null && participante.rol!.isNotEmpty
            ? Text(participante.rol!)
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
