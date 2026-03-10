import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:astro/core/models/documento_proyecto.dart';
import 'package:astro/core/models/documento_seccion.dart';
import 'package:astro/core/models/documento_version.dart';
import 'package:astro/core/models/bitacora_documento.dart';
import 'package:astro/core/services/storage_service.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/documentation/data/documento_repository.dart';
import 'package:astro/features/documentation/providers/documento_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de creación / edición de documento formal.
/// Si [documentId] es null → modo creación.
/// Si [documentId] no es null → modo edición (y subida de nueva versión).
class DocumentoFormScreen extends ConsumerStatefulWidget {
  const DocumentoFormScreen({
    required this.projectId,
    this.documentId,
    super.key,
  });

  final String projectId;
  final String? documentId;

  bool get isEdit => documentId != null;

  @override
  ConsumerState<DocumentoFormScreen> createState() =>
      _DocumentoFormScreenState();
}

class _DocumentoFormScreenState extends ConsumerState<DocumentoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _versionNotasCtrl = TextEditingController();

  String? _selectedCategoria;
  XFile? _selectedFile;
  String? _selectedFileName;
  bool _saving = false;
  bool _didLoad = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _versionNotasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proyectoAsync = ref.watch(proyectoByIdProvider(widget.projectId));
    final allCategorias = ref.watch(allCategoriasProvider(widget.projectId));

    // Si es edición, cargar datos del documento.
    DocumentoProyecto? existingDoc;
    if (widget.isEdit) {
      final docAsync = ref.watch(documentoByIdProvider(widget.documentId!));
      existingDoc = docAsync.value;

      // Llenar campos una sola vez.
      if (existingDoc != null && !_didLoad) {
        _tituloCtrl.text = existingDoc.titulo;
        _descripcionCtrl.text = existingDoc.descripcion ?? '';
        _selectedCategoria = existingDoc.categoria;
        _didLoad = true;
      }
    }

    // Default primera categoría si no hay selección.
    if (_selectedCategoria == null && allCategorias.isNotEmpty) {
      _selectedCategoria = allCategorias.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'EDITAR DOCUMENTO' : 'NUEVO DOCUMENTO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: proyectoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (proyecto) {
          if (proyecto == null) {
            return const Center(child: Text('Proyecto no encontrado'));
          }

          return AdaptiveBody(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Título
                    TextFormField(
                      controller: _tituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título del documento *',
                        hintText: 'Ej: Memoria Técnica v1.0',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 16),

                    // Categoría
                    DropdownButtonFormField<String>(
                      initialValue: allCategorias.contains(_selectedCategoria)
                          ? _selectedCategoria
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Categoría *',
                      ),
                      items: allCategorias
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategoria = v),
                      validator: (v) =>
                          v == null ? 'Selecciona categoría' : null,
                    ),
                    const SizedBox(height: 16),

                    // Descripción
                    TextFormField(
                      controller: _descripcionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        hintText: 'Descripción del contenido del documento...',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Archivo
                    Text(
                      widget.isEdit ? 'NUEVA VERSIÓN' : 'ARCHIVO',
                      style: theme.textTheme.labelLarge?.copyWith(
                        letterSpacing: 1,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (widget.isEdit && existingDoc != null) ...[
                      Text(
                        'Archivo actual: ${existingDoc.archivoNombre ?? "Sin archivo"} (v${existingDoc.versionActual})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // File picker
                    OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        _selectedFileName ??
                            (widget.isEdit
                                ? 'Subir nueva versión (opcional)'
                                : 'Seleccionar archivo *'),
                      ),
                    ),

                    if (_selectedFileName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _selectedFileName!,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Quitar archivo',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() {
                              _selectedFile = null;
                              _selectedFileName = null;
                            }),
                          ),
                        ],
                      ),
                    ],

                    if (widget.isEdit && _selectedFile != null) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _versionNotasCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Notas de la versión (opcional)',
                          hintText: 'Ej: Correcciones menores en sección 3',
                        ),
                        maxLines: 2,
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Botón guardar
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.isEdit
                                    ? 'Guardar cambios'
                                    : 'Crear documento',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _selectedFile = XFile(
          file.path ?? '',
          name: file.name,
          bytes: file.bytes,
          length: file.size,
        );
        _selectedFileName = file.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // En creación, el archivo es obligatorio.
    if (!widget.isEdit && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un archivo para el documento'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(documentoRepositoryProvider);
      final uid = ref.read(authStateProvider).value?.uid ?? '';
      final profile = ref.read(currentUserProfileProvider).value;
      final proyecto = ref.read(proyectoByIdProvider(widget.projectId)).value;
      final userName = profile?.displayName ?? '';
      final userRole = profile?.isRoot == true ? 'Root' : 'Soporte';

      if (widget.isEdit) {
        await _updateDocument(repo, uid, userName, userRole);
      } else {
        await _createDocument(
          repo,
          uid,
          userName,
          userRole,
          proyecto?.nombreProyecto ?? '',
          proyecto?.fkEmpresa,
        );
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createDocument(
    DocumentoRepository repo,
    String uid,
    String userName,
    String userRole,
    String projectName,
    String? empresaName,
  ) async {
    // Subir archivo a Storage.
    final storage = StorageService();
    final url = await storage.uploadToPath(
      'documentacion/${widget.projectId}/formales',
      _selectedFile!,
    );

    final mimeType = StorageService.contentType(_selectedFileName ?? '');
    final fileSize = await _selectedFile!.length();

    final now = DateTime.now();
    final version = DocumentoVersion(
      version: 1,
      url: url,
      nombre: _selectedFileName ?? 'archivo',
      subidoPor: uid,
      subidoPorNombre: userName,
      fecha: now,
    );

    final documento = DocumentoProyecto(
      id: '',
      folio: '', // Auto-generated by repository.
      titulo: _tituloCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      seccion: DocumentoSeccion.formal,
      categoria: _selectedCategoria!,
      projectName: projectName,
      projectId: widget.projectId,
      empresaName: empresaName,
      createdBy: uid,
      createdByName: userName,
      archivoUrl: url,
      archivoNombre: _selectedFileName,
      archivoTipo: mimeType,
      archivoSize: fileSize,
      versionActual: 1,
      versiones: [version],
      createdAt: now,
    );

    final docId = await repo.create(documento);

    // Registrar en bitácora.
    await repo.logBitacora(
      BitacoraDocumento(
        id: '',
        documentId: docId,
        documentFolio: '', // Se llenará cuando sea necesario.
        documentTitulo: _tituloCtrl.text.trim(),
        projectId: widget.projectId,
        projectName: projectName,
        accion: BitacoraAccion.creado,
        descripcion: '$userName creó el documento "${_tituloCtrl.text.trim()}"',
        userId: uid,
        userName: userName,
        userRole: userRole,
      ),
    );
  }

  Future<void> _updateDocument(
    DocumentoRepository repo,
    String uid,
    String userName,
    String userRole,
  ) async {
    final existing = ref.read(documentoByIdProvider(widget.documentId!)).value;
    if (existing == null) return;

    // Si se seleccionó un nuevo archivo → subir nueva versión.
    if (_selectedFile != null) {
      final storage = StorageService();
      final url = await storage.uploadToPath(
        'documentacion/${widget.projectId}/formales',
        _selectedFile!,
      );

      final newVersion = existing.versionActual + 1;
      final mimeType = StorageService.contentType(_selectedFileName ?? '');
      final fileSize = await _selectedFile!.length();

      final version = DocumentoVersion(
        version: newVersion,
        url: url,
        nombre: _selectedFileName ?? 'archivo',
        subidoPor: uid,
        subidoPorNombre: userName,
        fecha: DateTime.now(),
        notas: _versionNotasCtrl.text.trim().isEmpty
            ? null
            : _versionNotasCtrl.text.trim(),
        size: fileSize,
      );

      await repo.addVersion(
        widget.documentId!,
        version,
        url,
        _selectedFileName ?? 'archivo',
        mimeType,
        fileSize,
      );

      // Bitácora: nueva versión.
      await repo.logBitacora(
        BitacoraDocumento(
          id: '',
          documentId: widget.documentId!,
          documentFolio: existing.folio,
          documentTitulo: existing.titulo,
          projectId: widget.projectId,
          projectName: existing.projectName,
          accion: BitacoraAccion.nuevaVersion,
          descripcion:
              '$userName subió la versión $newVersion del documento "${existing.titulo}"',
          userId: uid,
          userName: userName,
          userRole: userRole,
          detalles: {
            'versionAnterior': existing.versionActual,
            'versionNueva': newVersion,
          },
        ),
      );
    }

    // Actualizar metadatos si cambiaron.
    final updated = existing.copyWith(
      titulo: _tituloCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      categoria: _selectedCategoria,
    );
    await repo.update(updated);

    // Bitácora: edición de metadatos (si hubo cambios).
    final tituloChanged = existing.titulo != _tituloCtrl.text.trim();
    final catChanged = existing.categoria != _selectedCategoria;
    if (tituloChanged || catChanged) {
      await repo.logBitacora(
        BitacoraDocumento(
          id: '',
          documentId: widget.documentId!,
          documentFolio: existing.folio,
          documentTitulo: _tituloCtrl.text.trim(),
          projectId: widget.projectId,
          projectName: existing.projectName,
          accion: BitacoraAccion.editado,
          descripcion: '$userName editó el documento "${existing.titulo}"',
          userId: uid,
          userName: userName,
          userRole: userRole,
          detalles: {
            if (tituloChanged) ...{
              'tituloAnterior': existing.titulo,
              'tituloNuevo': _tituloCtrl.text.trim(),
            },
            if (catChanged) ...{
              'categoriaAnterior': existing.categoria,
              'categoriaNueva': _selectedCategoria,
            },
          },
        ),
      );
    }
  }
}
