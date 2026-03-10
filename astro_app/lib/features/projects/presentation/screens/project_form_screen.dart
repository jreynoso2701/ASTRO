import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/empresa.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/core/widgets/adaptive_body.dart';

/// Pantalla de creación / edición de proyecto (solo Root).
class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({this.projectId, super.key});

  /// null = crear nuevo; si tiene valor = editar existente.
  final String? projectId;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _folioController = TextEditingController();
  final _descripcionController = TextEditingController();

  Empresa? _selectedEmpresa;
  bool _isSaving = false;
  bool _isLoaded = false;

  bool get _isEditing => widget.projectId != null;

  @override
  void dispose() {
    _nombreController.dispose();
    _folioController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empresasAsync = ref.watch(activeEmpresasProvider);

    // Si estamos editando, cargar datos del proyecto
    if (_isEditing && !_isLoaded) {
      final proyectoAsync = ref.watch(proyectoByIdProvider(widget.projectId!));
      final empresas = empresasAsync.value ?? [];

      proyectoAsync.whenData((proyecto) {
        if (proyecto != null && !_isLoaded) {
          _nombreController.text = proyecto.nombreProyecto;
          _folioController.text = proyecto.folioProyecto;
          _descripcionController.text = proyecto.descripcion ?? '';

          // Buscar empresa correspondiente
          final matchingEmpresa = empresas
              .where(
                (e) =>
                    e.nombreEmpresa.toUpperCase() ==
                    proyecto.fkEmpresa.toUpperCase(),
              )
              .firstOrNull;
          if (matchingEmpresa != null) {
            _selectedEmpresa = matchingEmpresa;
          }

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
        title: Text(_isEditing ? 'EDITAR PROYECTO' : 'NUEVO PROYECTO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: AdaptiveBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Empresa ──
                Text('Empresa:', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                empresasAsync.when(
                  data: (empresas) => DropdownButtonFormField<Empresa>(
                    initialValue: _selectedEmpresa,
                    decoration: const InputDecoration(
                      hintText: 'Seleccionar empresa...',
                    ),
                    items: empresas
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.nombreEmpresa),
                          ),
                        )
                        .toList(),
                    validator: (v) =>
                        v == null ? 'Selecciona una empresa' : null,
                    onChanged: (empresa) {
                      setState(() => _selectedEmpresa = empresa);
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),

                const SizedBox(height: 24),

                // ── Folio ──
                Text('Folio:', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _folioController,
                  decoration: const InputDecoration(
                    hintText: 'Ej: GLU-ERP, CON-AST...',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa un folio'
                      : null,
                ),

                const SizedBox(height: 24),

                // ── Nombre ──
                Text('Nombre del proyecto:', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    hintText: 'Nombre del proyecto...',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa un nombre'
                      : null,
                ),

                const SizedBox(height: 24),

                // ── Descripción ──
                Text(
                  'Descripción (opcional):',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(
                    hintText: 'Breve descripción del proyecto...',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: 32),

                // ── Botón ──
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isEditing ? Icons.save : Icons.add),
                  label: Text(
                    _isEditing ? 'Guardar cambios' : 'Crear proyecto',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmpresa == null) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(proyectoRepositoryProvider);
      final now = DateTime.now();

      if (_isEditing) {
        // Actualizar
        final proyecto = Proyecto(
          id: widget.projectId!,
          nombreProyecto: _nombreController.text.trim().toUpperCase(),
          folioProyecto: _folioController.text.trim().toUpperCase(),
          fkEmpresa: _selectedEmpresa!.nombreEmpresa,
          estatusProyecto: true,
          empresaId: _selectedEmpresa!.id,
          descripcion: _descripcionController.text.trim(),
          updatedAt: now,
        );
        await repo.updateProyecto(proyecto);

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Proyecto actualizado')));
        context.pop();
      } else {
        // Crear
        final proyecto = Proyecto(
          id: '', // se genera al crear
          nombreProyecto: _nombreController.text.trim().toUpperCase(),
          folioProyecto: _folioController.text.trim().toUpperCase(),
          fkEmpresa: _selectedEmpresa!.nombreEmpresa,
          estatusProyecto: true,
          empresaId: _selectedEmpresa!.id,
          descripcion: _descripcionController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        final newId = await repo.createProyecto(proyecto);

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Proyecto creado')));
        context.pushReplacement('/projects/$newId');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
