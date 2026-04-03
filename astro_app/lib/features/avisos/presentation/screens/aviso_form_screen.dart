import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/aviso.dart';
import 'package:astro/core/models/aviso_prioridad.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/avisos/data/aviso_repository.dart';
import 'package:astro/features/avisos/providers/aviso_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';

/// Pantalla para crear o editar un aviso.
class AvisoFormScreen extends ConsumerStatefulWidget {
  const AvisoFormScreen({required this.projectId, this.avisoId, super.key});

  final String projectId;
  final String? avisoId;

  @override
  ConsumerState<AvisoFormScreen> createState() => _AvisoFormScreenState();
}

class _AvisoFormScreenState extends ConsumerState<AvisoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();

  AvisoPrioridad _prioridad = AvisoPrioridad.informativo;
  bool _todosLosUsuarios = true;
  List<String> _destinatarios = [];
  DateTime? _expiresAt;
  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.avisoId != null) {
      _isEditing = true;
      // Carga posterior en didChangeDependencies vía provider.
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proyectoAsync = ref.watch(proyectoByIdProvider(widget.projectId));
    final members = ref.watch(projectMembersProvider(widget.projectId));

    // Load existing aviso data if editing
    if (_isEditing && !_loaded) {
      final avisoAsync = ref.watch(avisoByIdProvider(widget.avisoId!));
      avisoAsync.whenData((aviso) {
        if (aviso != null && !_loaded) {
          _loaded = true;
          _tituloCtrl.text = aviso.titulo;
          _mensajeCtrl.text = aviso.mensaje;
          _prioridad = aviso.prioridad;
          _todosLosUsuarios = aviso.todosLosUsuarios;
          _destinatarios = List.from(aviso.destinatarios);
          _expiresAt = aviso.expiresAt;
          if (mounted) setState(() {});
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'EDITAR AVISO' : 'NUEVO AVISO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: AdaptiveBody(
          maxWidth: 720,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Título ───────────────────────────────
                TextFormField(
                  controller: _tituloCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título del aviso *',
                    hintText: 'Ej: Mantenimiento programado',
                    prefixIcon: Icon(Icons.title),
                  ),
                  maxLength: 120,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),

                const SizedBox(height: 16),

                // ── Mensaje ──────────────────────────────
                TextFormField(
                  controller: _mensajeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje *',
                    hintText: 'Describe el aviso...',
                    prefixIcon: Icon(Icons.message_outlined),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  minLines: 3,
                  maxLength: 1000,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),

                const SizedBox(height: 16),

                // ── Prioridad ────────────────────────────
                Text(
                  'PRIORIDAD',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<AvisoPrioridad>(
                  segments: AvisoPrioridad.values.map((p) {
                    final icon = switch (p) {
                      AvisoPrioridad.informativo => Icons.info_outline,
                      AvisoPrioridad.importante => Icons.warning_amber_outlined,
                      AvisoPrioridad.urgente => Icons.error_outline,
                    };
                    return ButtonSegment(
                      value: p,
                      label: Text(p.label),
                      icon: Icon(icon),
                    );
                  }).toList(),
                  selected: {_prioridad},
                  onSelectionChanged: (s) =>
                      setState(() => _prioridad = s.first),
                ),

                const SizedBox(height: 24),

                // ── Destinatarios ────────────────────────
                Text(
                  'DESTINATARIOS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),

                SwitchListTile(
                  title: const Text('Enviar a todos los miembros'),
                  subtitle: Text(
                    'El aviso se enviará a todos los usuarios del proyecto',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: _todosLosUsuarios,
                  onChanged: (v) => setState(() {
                    _todosLosUsuarios = v;
                    if (v) _destinatarios.clear();
                  }),
                ),

                if (!_todosLosUsuarios) ...[
                  const SizedBox(height: 8),
                  // Member selection list
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seleccionar usuarios (${_destinatarios.length})',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Divider(),
                          if (members.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Sin miembros asignados'),
                            )
                          else
                            ...members.map((m) {
                              final uid = m.assignment.userId;
                              final name = m.user?.displayName ?? uid;
                              final role = m.assignment.role.label;
                              final selected = _destinatarios.contains(uid);

                              return CheckboxListTile(
                                value: selected,
                                title: Text(name),
                                subtitle: Text(role),
                                dense: true,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _destinatarios.add(uid);
                                    } else {
                                      _destinatarios.remove(uid);
                                    }
                                  });
                                },
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Fecha de expiración ──────────────────
                Text(
                  'EXPIRACIÓN (OPCIONAL)',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),

                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    _expiresAt != null
                        ? DateFormat('dd/MM/yyyy').format(_expiresAt!)
                        : 'Sin fecha de expiración',
                  ),
                  subtitle: _expiresAt != null
                      ? const Text('El aviso dejará de mostrarse después')
                      : const Text('El aviso será permanente'),
                  trailing: _expiresAt != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _expiresAt = null),
                        )
                      : null,
                  onTap: _pickExpirationDate,
                ),

                const SizedBox(height: 32),

                // ── Botón enviar ─────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _submit,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(_isEditing ? Icons.save : Icons.send),
                        label: Text(
                          _isEditing ? 'Guardar cambios' : 'Enviar aviso',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_todosLosUsuarios && _destinatarios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un destinatario')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(avisoRepositoryProvider);
      final proyecto = ref.read(proyectoByIdProvider(widget.projectId)).value;
      final profile = ref.read(currentUserProfileProvider).value;
      final members = ref.read(projectMembersProvider(widget.projectId));

      if (proyecto == null || profile == null) {
        throw Exception('Datos de proyecto o usuario no disponibles');
      }

      // Determine actual recipient UIDs for read receipt tracking
      final recipientUids = _todosLosUsuarios
          ? members.map((m) => m.assignment.userId).toList()
          : List<String>.from(_destinatarios);

      // Initialize lecturas map
      final lecturas = <String, AvisoLectura>{};
      for (final uid in recipientUids) {
        lecturas[uid] = AvisoLectura(uid: uid);
      }

      if (_isEditing) {
        final existing = ref.read(avisoByIdProvider(widget.avisoId!)).value;
        if (existing == null) throw Exception('Aviso no encontrado');

        await repo.update(
          existing.copyWith(
            titulo: _tituloCtrl.text.trim(),
            mensaje: _mensajeCtrl.text.trim(),
            prioridad: _prioridad,
            todosLosUsuarios: _todosLosUsuarios,
            destinatarios: _todosLosUsuarios ? [] : _destinatarios,
            expiresAt: _expiresAt,
          ),
        );
      } else {
        final aviso = Aviso(
          id: '',
          titulo: _tituloCtrl.text.trim(),
          mensaje: _mensajeCtrl.text.trim(),
          prioridad: _prioridad,
          projectId: widget.projectId,
          projectName: proyecto.nombreProyecto,
          createdBy: profile.uid,
          createdByName: profile.displayName,
          destinatarios: _todosLosUsuarios ? [] : _destinatarios,
          todosLosUsuarios: _todosLosUsuarios,
          lecturas: lecturas,
          expiresAt: _expiresAt,
        );

        await repo.create(aviso);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Aviso actualizado' : 'Aviso enviado'),
          ),
        );
        context.pop();
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
