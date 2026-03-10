import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/bitacora_documento.dart';
import 'package:astro/features/documentation/providers/documento_providers.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/widgets/adaptive_body.dart';

/// Pantalla de bitácora de documentos formales del proyecto.
/// Solo accesible para Root.
class BitacoraScreen extends ConsumerWidget {
  const BitacoraScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bitacoraAsync = ref.watch(bitacoraByProjectProvider(projectId));
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('BITÁCORA DE DOCUMENTOS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: bitacoraAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sin registros en la bitácora',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return AdaptiveBody(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: _accionColor(
                        entry.accion,
                      ).withValues(alpha: 0.15),
                      child: Icon(
                        _accionIcon(entry.accion),
                        size: 18,
                        color: _accionColor(entry.accion),
                      ),
                    ),
                    title: Text(
                      entry.descripcion,
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          '${entry.userName} (${entry.userRole})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          entry.createdAt != null
                              ? df.format(entry.createdAt!)
                              : '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (entry.documentFolio.isNotEmpty)
                          Text(
                            entry.documentFolio,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              letterSpacing: 0.5,
                            ),
                          ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          );
        },
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
