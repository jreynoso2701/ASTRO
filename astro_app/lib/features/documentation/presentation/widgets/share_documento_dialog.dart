import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astro/core/models/bitacora_documento.dart';
import 'package:astro/core/models/documento_proyecto.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/documentation/providers/documento_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Dialog tipo "Compartir" estilo Google Drive.
///
/// Permite a Root y Lider Proyecto agregar/quitar acceso de solo lectura
/// a otros proyectos para un documento formal.
class ShareDocumentoDialog extends ConsumerStatefulWidget {
  const ShareDocumentoDialog({required this.documento, super.key});

  final DocumentoProyecto documento;

  static Future<void> show(
    BuildContext context, {
    required DocumentoProyecto documento,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ShareDocumentoDialog(documento: documento),
    );
  }

  @override
  ConsumerState<ShareDocumentoDialog> createState() =>
      _ShareDocumentoDialogState();
}

class _ShareDocumentoDialogState extends ConsumerState<ShareDocumentoDialog> {
  late Set<String> _selectedIds;
  late Map<String, String> _idToName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.documento.sharedWithProjectIds.toSet();
    _idToName = {
      for (var i = 0; i < widget.documento.sharedWithProjectIds.length; i++)
        widget.documento.sharedWithProjectIds[i]:
            i < widget.documento.sharedWithProjectNames.length
            ? widget.documento.sharedWithProjectNames[i]
            : widget.documento.sharedWithProjectIds[i],
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(documentoRepositoryProvider);
      final uid = ref.read(authStateProvider).value?.uid ?? '';
      final profile = ref.read(currentUserProfileProvider).value;
      final isRoot = ref.read(isCurrentUserRootProvider);

      final idsList = _selectedIds.toList();
      final namesList = idsList.map((id) => _idToName[id] ?? id).toList();

      final previousIds = widget.documento.sharedWithProjectIds.toSet();
      final added = _selectedIds.difference(previousIds);
      final removed = previousIds.difference(_selectedIds);

      await repo.updateSharedProjects(
        widget.documento.id,
        projectIds: idsList,
        projectNames: namesList,
        sharedBy: uid,
        sharedByName: profile?.displayName ?? '',
      );

      // Bitácora — registrar cada cambio (no crítico).
      for (final id in added) {
        try {
          await repo.logBitacora(
            BitacoraDocumento(
              id: '',
              documentId: widget.documento.id,
              documentFolio: widget.documento.folio,
              documentTitulo: widget.documento.titulo,
              projectId: widget.documento.projectId,
              projectName: widget.documento.projectName,
              accion: BitacoraAccion.compartido,
              descripcion:
                  '${profile?.displayName ?? "Usuario"} compartió el documento con el proyecto "${_idToName[id] ?? id}"',
              userId: uid,
              userName: profile?.displayName ?? '',
              userRole: isRoot ? 'Root' : 'Lider Proyecto',
              detalles: {'projectId': id, 'projectName': _idToName[id] ?? id},
            ),
          );
        } catch (_) {
          // No crítico.
        }
      }
      for (final id in removed) {
        final originalIndex = widget.documento.sharedWithProjectIds.indexOf(id);
        final originalName =
            originalIndex >= 0 &&
                originalIndex < widget.documento.sharedWithProjectNames.length
            ? widget.documento.sharedWithProjectNames[originalIndex]
            : id;
        try {
          await repo.logBitacora(
            BitacoraDocumento(
              id: '',
              documentId: widget.documento.id,
              documentFolio: widget.documento.folio,
              documentTitulo: widget.documento.titulo,
              projectId: widget.documento.projectId,
              projectName: widget.documento.projectName,
              accion: BitacoraAccion.descompartido,
              descripcion:
                  '${profile?.displayName ?? "Usuario"} retiró el acceso del proyecto "$originalName"',
              userId: uid,
              userName: profile?.displayName ?? '',
              userRole: isRoot ? 'Root' : 'Lider Proyecto',
              detalles: {'projectId': id, 'projectName': originalName},
            ),
          );
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Compartición actualizada')));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al compartir: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shareable = ref.watch(shareableProjectsProvider(widget.documento.id));

    // Proyectos previamente compartidos pero a los que el usuario actual ya
    // no tiene acceso (Lider que perdió asignación). Se muestran read-only.
    final shareableIds = shareable.map((p) => p.id).toSet();
    final orphanIds = widget.documento.sharedWithProjectIds
        .where((id) => !shareableIds.contains(id))
        .toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.share_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Compartir documento',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info del documento
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.documento.titulo,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Dueño: ${widget.documento.projectName}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Acceso de solo lectura para usuarios que pertenecen tanto al proyecto dueño como al proyecto destino.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'PROYECTOS DISPONIBLES',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: shareable.isEmpty && orphanIds.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No tienes proyectos disponibles para compartir.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final p in shareable)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                value: _selectedIds.contains(p.id),
                                onChanged: _saving
                                    ? null
                                    : (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedIds.add(p.id);
                                            _idToName[p.id] = p.name;
                                          } else {
                                            _selectedIds.remove(p.id);
                                          }
                                        });
                                      },
                                title: Text(p.name),
                                secondary: const Icon(Icons.folder_outlined),
                              ),
                            if (orphanIds.isNotEmpty) ...[
                              const Divider(),
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 4,
                                ),
                                child: Text(
                                  'Otros proyectos con acceso',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              for (final id in orphanIds)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: const Icon(Icons.folder_outlined),
                                  title: Text(_idToName[id] ?? id),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    tooltip: 'Quitar acceso',
                                    onPressed: _saving
                                        ? null
                                        : () => setState(
                                            () => _selectedIds.remove(id),
                                          ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}
