import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/modulo.dart';
import 'package:astro/features/modules/providers/module_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/core/widgets/adaptive_body.dart';

/// Pantalla de creación / edición de módulo (Root y Soporte).
class ModuleFormScreen extends ConsumerStatefulWidget {
  const ModuleFormScreen({required this.projectId, this.moduleId, super.key});

  final String projectId;

  /// null = crear nuevo; si tiene valor = editar existente.
  final String? moduleId;

  @override
  ConsumerState<ModuleFormScreen> createState() => _ModuleFormScreenState();
}

class _ModuleFormScreenState extends ConsumerState<ModuleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _folioController = TextEditingController();
  final _descripcionController = TextEditingController();

  bool _isSaving = false;
  bool _isLoaded = false;

  bool get _isEditing => widget.moduleId != null;

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
    final proyectoAsync = ref.watch(proyectoByIdProvider(widget.projectId));
    final projectName = proyectoAsync.value?.nombreProyecto ?? '';

    // Esperar a que cargue el proyecto
    if (projectName.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('CARGANDO...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Si estamos editando, cargar datos del módulo
    if (_isEditing && !_isLoaded) {
      final moduloAsync = ref.watch(moduloByIdProvider(widget.moduleId!));

      moduloAsync.whenData((modulo) {
        if (modulo != null && !_isLoaded) {
          _nombreController.text = modulo.nombreModulo;
          _folioController.text = modulo.folioModulo;
          _descripcionController.text = modulo.descripcion ?? '';
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
        title: Text(_isEditing ? 'EDITAR MÓDULO' : 'NUEVO MÓDULO'),
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
                // ── Proyecto (solo lectura) ──
                Text('Proyecto:', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(projectName, style: theme.textTheme.bodyLarge),
                ),

                const SizedBox(height: 24),

                // ── Folio ──
                Text('Folio:', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _folioController,
                  decoration: const InputDecoration(
                    hintText: 'Ej: GLU-ERP-COT, CON-AST-AUTH...',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa un folio'
                      : null,
                ),

                const SizedBox(height: 24),

                // ── Nombre ──
                Text('Nombre del módulo:', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    hintText: 'Nombre del módulo...',
                    prefixIcon: Icon(Icons.view_module_outlined),
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
                    hintText: 'Breve descripción del módulo...',
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
                  label: Text(_isEditing ? 'Guardar cambios' : 'Crear módulo'),
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

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(moduloRepositoryProvider);
      final folio = _folioController.text.trim().toUpperCase();

      // ── Validar unicidad del folio ──
      final taken = await repo.isFolioTaken(
        folio,
        excludeId: _isEditing ? widget.moduleId : null,
      );
      if (taken) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El folio ya existe en otro módulo. Usa uno diferente.',
            ),
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      final now = DateTime.now();
      final projectName =
          ref
              .read(proyectoByIdProvider(widget.projectId))
              .value
              ?.nombreProyecto ??
          '';

      if (_isEditing) {
        final modulo = Modulo(
          id: widget.moduleId!,
          nombreModulo: _nombreController.text.trim().toUpperCase(),
          folioModulo: folio,
          fkProyecto: projectName,
          estatusModulo: true,
          projectId: widget.projectId,
          descripcion: _descripcionController.text.trim(),
          updatedAt: now,
        );
        await repo.updateModulo(modulo);

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Módulo actualizado')));
        context.pop();
      } else {
        final modulo = Modulo(
          id: '',
          nombreModulo: _nombreController.text.trim().toUpperCase(),
          folioModulo: folio,
          fkProyecto: projectName,
          estatusModulo: true,
          projectId: widget.projectId,
          descripcion: _descripcionController.text.trim(),
          porcentCompletaModulo: 0,
          createdAt: now,
          updatedAt: now,
        );
        final newId = await repo.createModulo(modulo);

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Módulo creado')));
        context.pushReplacement('/projects/${widget.projectId}/modules/$newId');
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
