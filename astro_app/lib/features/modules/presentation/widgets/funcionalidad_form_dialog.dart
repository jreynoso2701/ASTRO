import 'package:flutter/material.dart';
import 'package:astro/core/models/funcionalidad.dart';

/// Diálogo para crear o editar una funcionalidad.
///
/// Retorna la [Funcionalidad] creada/editada, o null si se cancela.
class FuncionalidadFormDialog extends StatefulWidget {
  const FuncionalidadFormDialog({
    this.funcionalidad,
    this.nextOrder = 0,
    super.key,
  });

  /// Si es null se crea una nueva; si tiene valor se edita.
  final Funcionalidad? funcionalidad;

  /// Orden sugerido para nuevas funcionalidades.
  final int nextOrder;

  @override
  State<FuncionalidadFormDialog> createState() =>
      _FuncionalidadFormDialogState();
}

class _FuncionalidadFormDialogState extends State<FuncionalidadFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;

  bool get _isEditing => widget.funcionalidad != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
      text: widget.funcionalidad?.nombre ?? '',
    );
    _descripcionCtrl = TextEditingController(
      text: widget.funcionalidad?.descripcion ?? '',
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar funcionalidad' : 'Nueva funcionalidad'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                hintText: 'Ej: Login con Google',
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcionCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Detalles adicionales...',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final nombre = _nombreCtrl.text.trim();
    final descripcion = _descripcionCtrl.text.trim();

    if (_isEditing) {
      final updated = widget.funcionalidad!.copyWith(
        nombre: nombre,
        descripcion: descripcion.isEmpty ? null : descripcion,
      );
      Navigator.of(context).pop(updated);
    } else {
      final created = Funcionalidad(
        id: '', // Se asignará por Firestore
        nombre: nombre,
        descripcion: descripcion.isEmpty ? null : descripcion,
        completada: false,
        estatus: true,
        orden: widget.nextOrder,
      );
      Navigator.of(context).pop(created);
    }
  }
}
