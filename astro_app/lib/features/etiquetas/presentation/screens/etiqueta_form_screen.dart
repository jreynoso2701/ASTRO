import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/etiqueta.dart';
import 'package:astro/features/etiquetas/providers/etiqueta_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de creación / edición de una etiqueta.
///
/// Parámetros:
/// - [etiqueta]: si se pasa, entra en modo edición.
/// - [etiquetaId]: si se pasa (desde router), carga la etiqueta por ID.
/// - [projectId]: si se pasa, crea etiqueta de proyecto; si es null, crea global.
class EtiquetaFormScreen extends ConsumerStatefulWidget {
  const EtiquetaFormScreen({
    this.etiqueta,
    this.etiquetaId,
    this.projectId,
    this.projectName,
    super.key,
  });

  final Etiqueta? etiqueta;
  final String? etiquetaId;
  final String? projectId;
  final String? projectName;

  @override
  ConsumerState<EtiquetaFormScreen> createState() => _EtiquetaFormScreenState();
}

class _EtiquetaFormScreenState extends ConsumerState<EtiquetaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  String _colorHex = '#4CAF50';
  String? _icono;
  bool _saving = false;
  Etiqueta? _loadedEtiqueta;

  bool get _isEditing => widget.etiqueta != null || widget.etiquetaId != null;

  @override
  void initState() {
    super.initState();
    if (widget.etiqueta != null) {
      _nombreController.text = widget.etiqueta!.nombre;
      _colorHex = widget.etiqueta!.colorHex;
      _icono = widget.etiqueta!.icono;
    } else if (widget.etiquetaId != null) {
      // Load from repository asynchronously
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final repo = ref.read(etiquetaRepositoryProvider);
        final etiqueta = await repo.getById(widget.etiquetaId!);
        if (etiqueta != null && mounted) {
          setState(() {
            _loadedEtiqueta = etiqueta;
            _nombreController.text = etiqueta.nombre;
            _colorHex = etiqueta.colorHex;
            _icono = etiqueta.icono;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGlobal = widget.projectId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'EDITAR ETIQUETA' : 'NUEVA ETIQUETA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Guardar',
              icon: const Icon(Icons.check),
              onPressed: _submit,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview
              Center(child: _buildPreview(theme)),
              const SizedBox(height: 24),

              // Nombre
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  hintText: 'ej. Backend, Frontend, Urgente…',
                  prefixIcon: Icon(Icons.label),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (v.trim().length > 40) {
                    return 'Máximo 40 caracteres';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // Color
              Text(
                'COLOR',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kEtiquetaPresetColors.map((hex) {
                  final color = Etiqueta(
                    id: '',
                    nombre: '',
                    colorHex: hex,
                    createdByUid: '',
                    createdByName: '',
                    esGlobal: false,
                  ).color;
                  final isSelected = _colorHex == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 18,
                              color: color.computeLuminance() > 0.4
                                  ? Colors.black87
                                  : Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Ícono
              Text(
                'ÍCONO (OPCIONAL)',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Opción sin ícono
                  GestureDetector(
                    onTap: () => setState(() => _icono = null),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _icono == null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          width: _icono == null ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('—', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                  ...kEtiquetaPresetIcons.map((name) {
                    final icon = _iconForName(name);
                    final isSelected = _icono == name;
                    return GestureDetector(
                      onTap: () => setState(() => _icono = name),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                )
                              : null,
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 22),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 24),

              // Info de tipo
              if (!_isEditing)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isGlobal ? Icons.public : Icons.folder_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isGlobal
                              ? 'Etiqueta GLOBAL — visible en todos los proyectos'
                              : 'Etiqueta de PROYECTO — solo visible en ${widget.projectName ?? "este proyecto"}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final previewEtiqueta = Etiqueta(
      id: '',
      nombre: _nombreController.text.isEmpty
          ? 'Vista previa'
          : _nombreController.text.trim(),
      colorHex: _colorHex,
      icono: _icono,
      esGlobal: widget.projectId == null,
      createdByUid: '',
      createdByName: '',
    );
    return Column(
      children: [
        Text(
          'Vista previa',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: _EtiquetaChipPreview(etiqueta: previewEtiqueta),
        ),
      ],
    );
  }

  IconData _iconForName(String name) {
    const map = <String, IconData>{
      'label': Icons.label,
      'bug_report': Icons.bug_report,
      'code': Icons.code,
      'design_services': Icons.design_services,
      'storage': Icons.storage,
      'cloud': Icons.cloud,
      'phone_android': Icons.phone_android,
      'web': Icons.web,
      'security': Icons.security,
      'speed': Icons.speed,
      'build': Icons.build,
      'star': Icons.star,
      'priority_high': Icons.priority_high,
      'flag': Icons.flag,
      'bookmark': Icons.bookmark,
      'tag': Icons.tag,
      'work': Icons.work,
      'school': Icons.school,
      'science': Icons.science,
      'auto_awesome': Icons.auto_awesome,
    };
    return map[name] ?? Icons.label;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(etiquetaRepositoryProvider);
      final authUser = ref.read(authStateProvider).value;
      final profile = ref.read(currentUserProfileProvider).value;
      final byUid = authUser?.uid ?? '';
      final byName = profile?.displayName ?? authUser?.email ?? '';

      if (_isEditing) {
        final editId =
            widget.etiqueta?.id ?? _loadedEtiqueta?.id ?? widget.etiquetaId!;
        await repo.update(
          editId,
          nombre: _nombreController.text.trim(),
          colorHex: _colorHex,
          icono: _icono,
          clearIcono: _icono == null,
        );
      } else {
        final etiqueta = Etiqueta(
          id: '',
          nombre: _nombreController.text.trim(),
          colorHex: _colorHex,
          icono: _icono,
          esGlobal: widget.projectId == null,
          projectId: widget.projectId,
          projectName: widget.projectName,
          createdByUid: byUid,
          createdByName: byName,
          isActive: true,
        );
        await repo.create(etiqueta);
      }

      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

/// Preview del chip dentro del formulario.
class _EtiquetaChipPreview extends StatelessWidget {
  const _EtiquetaChipPreview({required this.etiqueta});
  final Etiqueta etiqueta;

  @override
  Widget build(BuildContext context) {
    final color = etiqueta.color;
    final iconMap = <String, IconData>{
      'label': Icons.label,
      'bug_report': Icons.bug_report,
      'code': Icons.code,
      'design_services': Icons.design_services,
      'storage': Icons.storage,
      'cloud': Icons.cloud,
      'phone_android': Icons.phone_android,
      'web': Icons.web,
      'security': Icons.security,
      'speed': Icons.speed,
      'build': Icons.build,
      'star': Icons.star,
      'priority_high': Icons.priority_high,
      'flag': Icons.flag,
      'bookmark': Icons.bookmark,
      'tag': Icons.tag,
      'work': Icons.work,
      'school': Icons.school,
      'science': Icons.science,
      'auto_awesome': Icons.auto_awesome,
    };
    final iconData = etiqueta.icono != null ? iconMap[etiqueta.icono] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconData != null) ...[
            Icon(iconData, size: 16, color: color),
            const SizedBox(width: 6),
          ] else ...[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            etiqueta.nombre,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (etiqueta.esGlobal) ...[
            const SizedBox(width: 4),
            Icon(Icons.public, size: 12, color: color.withValues(alpha: 0.7)),
          ],
        ],
      ),
    );
  }
}
