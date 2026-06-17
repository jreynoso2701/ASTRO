import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:astro/core/models/modulo.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_priority.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/services/storage_service.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

void showQuickTicketSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) =>
          _QuickTicketSheet(scrollController: scrollController),
    ),
  );
}

class _QuickTicketSheet extends ConsumerStatefulWidget {
  const _QuickTicketSheet({required this.scrollController});
  final ScrollController scrollController;

  @override
  ConsumerState<_QuickTicketSheet> createState() => _QuickTicketSheetState();
}

class _QuickTicketSheetState extends ConsumerState<_QuickTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  Proyecto? _project;
  Modulo? _module;
  TicketPriority _priority = TicketPriority.media;
  bool _urlNoAplica = false;
  bool _isSaving = false;

  final List<XFile> _newFiles = [];

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  // ── Pickers ──

  Future<void> _pickImages() async {
    final images = await ImagePicker().pickMultiImage();
    if (images.isNotEmpty) setState(() => _newFiles.addAll(images));
  }

  Future<void> _pickFromCamera() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    if (photo != null) setState(() => _newFiles.add(photo));
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx',
        'jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov',
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

  // ── Submit ──

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_project == null || _module == null) return;

    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      final profile = ref.read(currentUserProfileProvider).value;
      if (uid == null || profile == null) return;

      final repo = ref.read(ticketRepositoryProvider);

      final ticket = Ticket(
        id: '',
        folio: '',
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descCtrl.text.trim(),
        projectName: _project!.nombreProyecto,
        moduleName: _module!.nombreModulo,
        status: TicketStatus.pendiente,
        priority: _priority,
        createdByName: profile.displayName,
        projectId: _project!.id,
        moduleId: _module!.id,
        createdBy: uid,
        empresaName: _project!.fkEmpresa,
        urlReferencia: _urlNoAplica ? null : _urlCtrl.text.trim(),
      );

      final ticketId = await repo.create(ticket);

      // Subir evidencias si hay archivos seleccionados
      if (_newFiles.isNotEmpty) {
        final urls = await StorageService().uploadMultipleEvidence(
          ticketId,
          _newFiles,
        );
        if (urls.isNotEmpty) {
          await repo.updateEvidencias(ticketId, urls);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket creado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear ticket: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allProjects = ref.watch(myProjectsProvider);

    final modulesAsync = _project != null
        ? ref.watch(activeModulosByProjectProvider(_project!.nombreProyecto))
        : null;
    final modules = modulesAsync?.value ?? <Modulo>[];
    final modulesLoading = modulesAsync?.isLoading ?? false;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Column(
        children: [
          // ── Drag handle ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 20),
                const SizedBox(width: 10),
                Text(
                  'NUEVO TICKET',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Form ──
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Proyecto
                    DropdownButtonFormField<Proyecto>(
                      value: _project,
                      decoration: const InputDecoration(
                        labelText: 'Proyecto *',
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                      items: allProjects
                          .map(
                            (p) => DropdownMenuItem<Proyecto>(
                              value: p,
                              child: Text(
                                p.nombreProyecto,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (p) => setState(() {
                        _project = p;
                        _module = null;
                      }),
                      validator: (v) =>
                          v == null ? 'Selecciona un proyecto' : null,
                    ),
                    const SizedBox(height: 16),

                    // 2. Módulo
                    DropdownButtonFormField<Modulo>(
                      value: _module,
                      decoration: InputDecoration(
                        labelText: 'Módulo *',
                        prefixIcon: const Icon(Icons.view_module_outlined),
                        hintText: _project == null
                            ? 'Selecciona un proyecto primero'
                            : modulesLoading
                            ? 'Cargando módulos…'
                            : modules.isEmpty
                            ? 'Sin módulos activos'
                            : null,
                      ),
                      items: modules
                          .map(
                            (m) => DropdownMenuItem<Modulo>(
                              value: m,
                              child: Text(
                                m.nombreModulo,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _project == null || modules.isEmpty
                          ? null
                          : (m) => setState(() => _module = m),
                      validator: (v) =>
                          v == null ? 'Selecciona un módulo' : null,
                    ),
                    const SizedBox(height: 16),

                    // 3. Título
                    TextFormField(
                      controller: _tituloCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        prefixIcon: Icon(Icons.title_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'El título es obligatorio'
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // 4. Prioridad
                    DropdownButtonFormField<TicketPriority>(
                      value: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Prioridad',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: TicketPriority.values
                          .map(
                            (p) => DropdownMenuItem<TicketPriority>(
                              value: p,
                              child: Text(p.label),
                            ),
                          )
                          .toList(),
                      onChanged: (p) {
                        if (p != null) setState(() => _priority = p);
                      },
                    ),
                    const SizedBox(height: 16),

                    // 5. URL + "No aplica"
                    _UrlField(
                      controller: _urlCtrl,
                      noAplica: _urlNoAplica,
                      onNoAplicaChanged: (v) =>
                          setState(() => _urlNoAplica = v ?? false),
                    ),
                    const SizedBox(height: 16),

                    // 6. Descripción (opcional)
                    TextField(
                      controller: _descCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 7. Evidencias
                    _EvidenceSection(
                      files: _newFiles,
                      onPickImages: _pickImages,
                      onPickCamera: _pickFromCamera,
                      onPickDocuments: _pickDocuments,
                      onRemove: (i) => setState(() => _newFiles.removeAt(i)),
                    ),
                    const SizedBox(height: 24),

                    // 8. Botón crear
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isSaving ? 'Creando…' : 'Crear Ticket'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sección de evidencias ─────────────────────────────────────────────────────

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({
    required this.files,
    required this.onPickImages,
    required this.onPickCamera,
    required this.onPickDocuments,
    required this.onRemove,
  });

  final List<XFile> files;
  final VoidCallback onPickImages;
  final VoidCallback onPickCamera;
  final VoidCallback onPickDocuments;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Icon(
              Icons.attach_file,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Evidencias',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (files.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${files.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // Botones de selección
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _PickerButton(
              icon: Icons.photo_library_outlined,
              label: 'Galería',
              onTap: onPickImages,
            ),
            _PickerButton(
              icon: Icons.camera_alt_outlined,
              label: 'Cámara',
              onTap: onPickCamera,
            ),
            _PickerButton(
              icon: Icons.folder_open_outlined,
              label: 'Archivo',
              onTap: onPickDocuments,
            ),
          ],
        ),

        // Archivos seleccionados
        if (files.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < files.length; i++)
                Chip(
                  label: Text(
                    _fileName(files[i].path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => onRemove(i),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _fileName(String path) {
    final name = path.split('/').last.split('\\').last;
    return name.length > 28 ? '${name.substring(0, 25)}…' : name;
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        textStyle: const TextStyle(fontSize: 13),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onTap,
    );
  }
}

// ── Campo URL ─────────────────────────────────────────────────────────────────

class _UrlField extends StatelessWidget {
  const _UrlField({
    required this.controller,
    required this.noAplica,
    required this.onNoAplicaChanged,
  });

  final TextEditingController controller;
  final bool noAplica;
  final ValueChanged<bool?> onNoAplicaChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!noAplica)
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'URL de referencia *',
              prefixIcon: Icon(Icons.link_outlined),
              hintText: 'https://…',
            ),
            validator: (v) {
              if (noAplica) return null;
              if (v == null || v.trim().isEmpty) {
                return 'Ingresa una URL o marca "No aplica"';
              }
              final uri = Uri.tryParse(v.trim());
              if (uri == null || !uri.hasScheme) return 'URL no válida';
              return null;
            },
          ),
        Row(
          children: [
            Checkbox(
              value: noAplica,
              onChanged: onNoAplicaChanged,
              visualDensity: VisualDensity.compact,
            ),
            const Text('No aplica (sin URL de referencia)'),
          ],
        ),
      ],
    );
  }
}
