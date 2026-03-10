import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/documento_proyecto.dart';
import 'package:astro/core/models/documento_version.dart';
import 'package:astro/core/models/bitacora_documento.dart';
import 'package:astro/features/documentation/providers/documento_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/core/presentation/screens/file_viewer_screen.dart';
import 'package:intl/intl.dart';

/// Pantalla de detalle de un documento formal.
class DocumentoDetailScreen extends ConsumerWidget {
  const DocumentoDetailScreen({
    required this.projectId,
    required this.documentId,
    super.key,
  });

  final String projectId;
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docAsync = ref.watch(documentoByIdProvider(documentId));
    final canManage = ref.watch(canManageDocumentsProvider(projectId));
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final uid = ref.watch(authStateProvider).value?.uid;

    return docAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('DOCUMENTO')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('DOCUMENTO')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (documento) {
        if (documento == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('DOCUMENTO')),
            body: const Center(child: Text('Documento no encontrado')),
          );
        }

        final canEdit = canManage;
        final canDelete = isRoot || documento.createdBy == uid;

        return Scaffold(
          appBar: AppBar(
            title: const Text('DOCUMENTO'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/projects/$projectId/documents'),
            ),
            actions: [
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar documento',
                  onPressed: () => context.go(
                    '/projects/$projectId/documents/$documentId/edit',
                  ),
                ),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar documento',
                  onPressed: () => _confirmDelete(context, ref, documento),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DocumentHeader(documento: documento),
                const SizedBox(height: 16),
                _DocumentInfo(documento: documento),
                const SizedBox(height: 16),
                _CurrentFile(documento: documento),
                if (documento.versiones.length > 1) ...[
                  const SizedBox(height: 16),
                  _VersionHistory(versiones: documento.versiones),
                ],
                const SizedBox(height: 16),
                _DocumentBitacora(documentId: documentId),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DocumentoProyecto documento,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: Text(
          '¿Estás seguro de eliminar "${documento.titulo}"?\n'
          'Esta acción se registrará en la bitácora.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final repo = ref.read(documentoRepositoryProvider);
    final uid = ref.read(authStateProvider).value?.uid ?? '';
    final profile = ref.read(currentUserProfileProvider).value;

    await repo.deactivate(documento.id);

    // Registrar en bitácora
    await repo.logBitacora(
      BitacoraDocumento(
        id: '',
        documentId: documento.id,
        documentFolio: documento.folio,
        documentTitulo: documento.titulo,
        projectId: projectId,
        projectName: documento.projectName,
        accion: BitacoraAccion.eliminado,
        descripcion:
            '${profile?.displayName ?? "Usuario"} eliminó el documento "${documento.titulo}"',
        userId: uid,
        userName: profile?.displayName ?? '',
        userRole: profile?.isRoot == true ? 'Root' : 'Soporte',
      ),
    );

    if (context.mounted) {
      context.go('/projects/$projectId/documents');
    }
  }
}

// ── Document Header ──────────────────────────────────────

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({required this.documento});

  final DocumentoProyecto documento;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.onSurface.withValues(
              alpha: 0.08,
            ),
            child: Icon(
              Icons.description_outlined,
              size: 36,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            documento.titulo,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              documento.folio,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Document Info Card ───────────────────────────────────

class _DocumentInfo extends StatelessWidget {
  const _DocumentInfo({required this.documento});

  final DocumentoProyecto documento;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INFORMACIÓN',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            _InfoRow(label: 'Categoría', value: documento.categoria),
            _InfoRow(label: 'Proyecto', value: documento.projectName),
            if (documento.empresaName != null)
              _InfoRow(label: 'Empresa', value: documento.empresaName!),
            _InfoRow(label: 'Subido por', value: documento.createdByName),
            _InfoRow(
              label: 'Versión actual',
              value: 'v${documento.versionActual}',
            ),
            if (documento.createdAt != null)
              _InfoRow(label: 'Creado', value: df.format(documento.createdAt!)),
            if (documento.updatedAt != null)
              _InfoRow(
                label: 'Actualizado',
                value: df.format(documento.updatedAt!),
              ),
            if (documento.descripcion != null &&
                documento.descripcion!.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'DESCRIPCIÓN',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(documento.descripcion!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Current File Card ────────────────────────────────────

class _CurrentFile extends StatelessWidget {
  const _CurrentFile({required this.documento});

  final DocumentoProyecto documento;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (documento.archivoUrl == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Sin archivo adjunto',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ARCHIVO ACTUAL',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.08,
                ),
                child: Icon(
                  _fileIcon(documento.archivoTipo),
                  color: theme.colorScheme.onSurface,
                ),
              ),
              title: Text(
                documento.archivoNombre ?? 'Archivo',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: documento.archivoSize != null
                  ? Text(_formatSize(documento.archivoSize!))
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new),
                tooltip: 'Abrir archivo',
                onPressed: () => _openFile(
                  context,
                  documento.archivoUrl!,
                  fileName: documento.archivoNombre,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _fileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file_outlined;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('image')) return Icons.image_outlined;
    if (mimeType.contains('video')) return Icons.videocam_outlined;
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description_outlined;
    }
    if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static void _openFile(BuildContext context, String url, {String? fileName}) {
    FileViewerScreen.open(context, url: url, fileName: fileName);
  }
}

// ── Version History ──────────────────────────────────────

class _VersionHistory extends StatelessWidget {
  const _VersionHistory({required this.versiones});

  final List<DocumentoVersion> versiones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final sorted = [...versiones]
      ..sort((a, b) => b.version.compareTo(a.version));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HISTORIAL DE VERSIONES',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            for (final v in sorted) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    'v${v.version}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(v.nombre),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${v.subidoPorNombre} — ${df.format(v.fecha)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (v.notas != null && v.notas!.isNotEmpty)
                      Text(
                        v.notas!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  tooltip: 'Abrir esta versión',
                  onPressed: () {
                    FileViewerScreen.open(
                      context,
                      url: v.url,
                      fileName: v.nombre,
                    );
                  },
                ),
              ),
              if (v != sorted.last) const Divider(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Document Bitacora ────────────────────────────────────

class _DocumentBitacora extends ConsumerWidget {
  const _DocumentBitacora({required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bitacoraAsync = ref.watch(bitacoraByDocProvider(documentId));
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BITÁCORA',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            bitacoraAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('Error: $e'),
              data: (entries) {
                if (entries.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Sin registros en la bitácora',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return Column(
                  children: entries.map((entry) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        _accionIcon(entry.accion),
                        size: 20,
                        color: _accionColor(entry.accion),
                      ),
                      title: Text(
                        entry.descripcion,
                        style: theme.textTheme.bodySmall,
                      ),
                      subtitle: Text(
                        entry.createdAt != null
                            ? '${entry.userName} (${entry.userRole}) — ${df.format(entry.createdAt!)}'
                            : entry.userName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static IconData _accionIcon(BitacoraAccion accion) {
    return switch (accion) {
      BitacoraAccion.creado => Icons.add_circle_outline,
      BitacoraAccion.editado => Icons.edit_outlined,
      BitacoraAccion.nuevaVersion => Icons.upload_outlined,
      BitacoraAccion.eliminado => Icons.delete_outline,
      BitacoraAccion.restaurado => Icons.restore,
    };
  }

  static Color _accionColor(BitacoraAccion accion) {
    return switch (accion) {
      BitacoraAccion.creado => Colors.green,
      BitacoraAccion.editado => Colors.blue,
      BitacoraAccion.nuevaVersion => Colors.orange,
      BitacoraAccion.eliminado => Colors.red,
      BitacoraAccion.restaurado => Colors.teal,
    };
  }
}

// ── Info Row ─────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
