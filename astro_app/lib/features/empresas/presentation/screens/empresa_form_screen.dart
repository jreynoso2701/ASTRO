import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:astro/core/models/empresa.dart';
import 'package:astro/core/services/storage_service.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de formulario para crear / editar una empresa.
class EmpresaFormScreen extends ConsumerStatefulWidget {
  const EmpresaFormScreen({this.empresaId, super.key});

  /// Si es null → modo crear; si tiene valor → modo editar.
  final String? empresaId;

  @override
  ConsumerState<EmpresaFormScreen> createState() => _EmpresaFormScreenState();
}

class _EmpresaFormScreenState extends ConsumerState<EmpresaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _contactoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  String? _logoUrl;
  bool _loaded = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _rfcCtrl.dispose();
    _contactoCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _isEditing = widget.empresaId != null;

    // Cargar datos en modo edición.
    if (_isEditing && !_loaded) {
      final empresaAsync = ref.watch(empresaByIdProvider(widget.empresaId!));
      return Scaffold(
        appBar: AppBar(
          title: const Text('Editar empresa'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: empresaAsync.when(
          data: (empresa) {
            if (empresa == null) {
              return const Center(child: Text('Empresa no encontrada'));
            }
            _populateFields(empresa);
            return _buildForm(theme);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar empresa' : 'Nueva empresa'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildForm(theme),
    );
  }

  void _populateFields(Empresa empresa) {
    if (_loaded) return;
    _loaded = true;
    _nombreCtrl.text = empresa.nombreEmpresa;
    _rfcCtrl.text = empresa.rfc ?? '';
    _contactoCtrl.text = empresa.contacto ?? '';
    _emailCtrl.text = empresa.email ?? '';
    _telefonoCtrl.text = empresa.telefono ?? '';
    _direccionCtrl.text = empresa.direccion ?? '';
    _logoUrl = empresa.logoUrl;
  }

  Widget _buildForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Logo ──
            Center(
              child: GestureDetector(
                onTap: _isUploadingLogo ? null : _pickLogo,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: _logoUrl != null
                          ? NetworkImage(_logoUrl!)
                          : null,
                      child: _logoUrl == null
                          ? const Icon(Icons.business, size: 36)
                          : null,
                    ),
                    if (_isUploadingLogo)
                      const Positioned.fill(
                        child: CircleAvatar(
                          backgroundColor: Colors.black45,
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Toca para cambiar logo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Nombre ──
            TextFormField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre de la empresa *',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),

            // ── RFC ──
            TextFormField(
              controller: _rfcCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'RFC',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // ── Contacto ──
            TextFormField(
              controller: _contactoCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre de contacto',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),

            // ── Email ──
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // ── Teléfono ──
            TextFormField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // ── Dirección ──
            TextFormField(
              controller: _direccionCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                prefixIcon: Icon(Icons.location_on_outlined),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 32),

            // ── Botón guardar ──
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Guardar cambios' : 'Crear empresa'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final storagePath = widget.empresaId != null
          ? 'empresas/${widget.empresaId}/logo'
          : 'empresas/temp_${DateTime.now().millisecondsSinceEpoch}/logo';
      final url = await StorageService().uploadToPath(storagePath, image);
      setState(() => _logoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al subir logo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(empresaRepositoryProvider);

      String? nonEmpty(String text) => text.trim().isEmpty ? null : text.trim();

      if (_isEditing) {
        // Actualizar
        final fields = <String, dynamic>{
          'nombreEmpresa': _nombreCtrl.text.trim(),
        };
        final rfc = nonEmpty(_rfcCtrl.text);
        final contacto = nonEmpty(_contactoCtrl.text);
        final email = nonEmpty(_emailCtrl.text);
        final telefono = nonEmpty(_telefonoCtrl.text);
        final direccion = nonEmpty(_direccionCtrl.text);

        if (rfc != null) fields['rfc'] = rfc;
        if (contacto != null) fields['contacto'] = contacto;
        if (email != null) fields['email'] = email;
        if (telefono != null) fields['telefono'] = telefono;
        if (direccion != null) fields['direccion'] = direccion;
        if (_logoUrl != null) fields['logoUrl'] = _logoUrl;

        await repo.updateEmpresa(widget.empresaId!, fields);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Empresa actualizada')));
          context.pop();
        }
      } else {
        // Crear
        final empresa = Empresa(
          id: '',
          nombreEmpresa: _nombreCtrl.text.trim(),
          isActive: true,
          logoUrl: _logoUrl,
          rfc: nonEmpty(_rfcCtrl.text),
          contacto: nonEmpty(_contactoCtrl.text),
          email: nonEmpty(_emailCtrl.text),
          telefono: nonEmpty(_telefonoCtrl.text),
          direccion: nonEmpty(_direccionCtrl.text),
        );

        final newId = await repo.createEmpresa(empresa);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Empresa creada')));
          context.pushReplacement('/empresas/$newId');
        }
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
