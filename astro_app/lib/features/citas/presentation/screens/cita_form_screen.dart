import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/cita.dart';
import 'package:astro/core/models/app_user.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/core/models/minuta_modalidad.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/minuta.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/minutas/providers/minuta_providers.dart';

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

  // Referencias
  final List<String> _refTickets = [];
  final List<String> _refRequerimientos = [];
  final List<String> _refMinutas = [];

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

    // Pre-calentar providers de referencias para que estén listos al buscar
    ref.watch(allTicketsByProjectProvider(projectName));
    ref.watch(allRequerimientosByProjectProvider(projectName));
    ref.watch(minutasByProjectProvider(projectName));

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
          _refTickets
            ..clear()
            ..addAll(cita.refTickets);
          _refRequerimientos
            ..clear()
            ..addAll(cita.refRequerimientos);
          _refMinutas
            ..clear()
            ..addAll(cita.refMinutas);
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

              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _addFromProject(),
                    icon: const Icon(Icons.group_outlined, size: 18),
                    label: const Text('Del proyecto'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _addExternal,
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text('Externo'),
                  ),
                ],
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

              // ── Referencias ───────────────────────────
              _SectionHeader(label: 'REFERENCIAS'),
              const SizedBox(height: 8),

              // Tickets
              _RefSubSection(
                label: 'Tickets',
                icon: Icons.confirmation_number_outlined,
                ids: _refTickets,
                onAdd: () => _searchTickets(projectName),
                onRemove: (id) => setState(() => _refTickets.remove(id)),
              ),
              const SizedBox(height: 12),

              // Requerimientos
              _RefSubSection(
                label: 'Requerimientos',
                icon: Icons.assignment_outlined,
                ids: _refRequerimientos,
                onAdd: () => _searchRequerimientos(projectName),
                onRemove: (id) => setState(() => _refRequerimientos.remove(id)),
              ),
              const SizedBox(height: 12),

              // Minutas
              _RefSubSection(
                label: 'Minutas',
                icon: Icons.description_outlined,
                ids: _refMinutas,
                onAdd: () => _searchMinutas(projectName),
                onRemove: (id) => setState(() => _refMinutas.remove(id)),
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

  void _addFromProject() {
    final members = ref.read(projectMembersProvider(widget.projectId));
    final addedUids = _participantes.map((p) => p.uid).toSet();

    // Filtrar miembros ya agregados
    final available = members.where((m) {
      final u = m.user;
      return u != null && !addedUids.contains(u.uid);
    }).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos los miembros del proyecto ya fueron agregados'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _ProjectMemberPicker(
          members: available,
          onSelected: (user, rolLabel) {
            setState(() {
              _participantes.add(
                ParticipanteCita(
                  uid: user.uid,
                  nombre: user.displayName,
                  rol: rolLabel,
                ),
              );
            });
          },
        );
      },
    );
  }

  void _addExternal() async {
    final nombreCtrl = TextEditingController();
    final rolCtrl = TextEditingController();

    final result = await showDialog<ParticipanteCita>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Participante externo'),
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
                  uid: '',
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
        refTickets: _refTickets,
        refRequerimientos: _refRequerimientos,
        refMinutas: _refMinutas,
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

  bool get _isSystemUser => participante.uid.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _isSystemUser ? Icons.person : Icons.person_outline,
          color: _isSystemUser
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(participante.nombre),
        subtitle: Row(
          children: [
            if (participante.rol != null && participante.rol!.isNotEmpty)
              Flexible(child: Text(participante.rol!)),
            if (participante.rol != null && participante.rol!.isNotEmpty)
              const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    (_isSystemUser
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant)
                        .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _isSystemUser ? 'Sistema' : 'Externo',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _isSystemUser
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
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

// ── Project Member Picker ────────────────────────────────

class _ProjectMemberPicker extends StatefulWidget {
  const _ProjectMemberPicker({required this.members, required this.onSelected});

  final List<({ProjectAssignment assignment, AppUser? user})> members;
  final void Function(AppUser user, String? rolLabel) onSelected;

  @override
  State<_ProjectMemberPicker> createState() => _ProjectMemberPickerState();
}

class _ProjectMemberPickerState extends State<_ProjectMemberPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = _search.isEmpty
        ? widget.members
        : widget.members.where((m) {
            final name = m.user?.displayName.toLowerCase() ?? '';
            return name.contains(_search.toLowerCase());
          }).toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              'Miembros del proyecto',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Sin resultados',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final m = filtered[i];
                      final user = m.user!;
                      final rolLabel = m.assignment.role.label;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(user.displayName),
                        subtitle: Text(rolLabel),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onSelected(user, rolLabel);
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Ref Sub Section ──────────────────────────────────────

class _RefSubSection extends StatelessWidget {
  const _RefSubSection({
    required this.label,
    required this.icon,
    required this.ids,
    required this.onAdd,
    required this.onRemove,
  });

  final String label;
  final IconData icon;
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
                label: Text(
                  id.length > 10 ? '${id.substring(0, 10)}…' : id,
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

  /// Optional: text used for filtering. Falls back to [labelBuilder] if null.
  final String Function(T)? searchBuilder;

  /// Optional: widget shown below the title in each list tile.
  final Widget Function(T)? subtitleBuilder;

  /// Optional: leading widget for each list tile.
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
