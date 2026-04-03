import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/aviso.dart';
import 'package:astro/core/models/aviso_prioridad.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/avisos/providers/aviso_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';

/// Pantalla de detalle de un aviso con sistema de read receipts.
class AvisoDetailScreen extends ConsumerStatefulWidget {
  const AvisoDetailScreen({
    required this.projectId,
    required this.avisoId,
    super.key,
  });

  final String projectId;
  final String avisoId;

  @override
  ConsumerState<AvisoDetailScreen> createState() => _AvisoDetailScreenState();
}

class _AvisoDetailScreenState extends ConsumerState<AvisoDetailScreen> {
  bool _markedAsRead = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final avisoAsync = ref.watch(avisoByIdProvider(widget.avisoId));
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AVISO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isRoot)
            avisoAsync.whenOrNull(
                  data: (aviso) => aviso != null
                      ? PopupMenuButton<String>(
                          onSelected: (action) => _handleAction(action, aviso),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Editar'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline),
                                title: Text('Eliminar'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        )
                      : null,
                ) ??
                const SizedBox.shrink(),
        ],
      ),
      body: avisoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (aviso) {
          if (aviso == null) {
            return const Center(child: Text('Aviso no encontrado'));
          }

          // Mark as read on first view
          if (uid != null && !_markedAsRead) {
            final lectura = aviso.lecturas[uid];
            if (lectura == null || !lectura.leido) {
              _markedAsRead = true;
              Future.microtask(() {
                ref
                    .read(avisoRepositoryProvider)
                    .markAsRead(widget.avisoId, uid);
              });
            } else {
              _markedAsRead = true;
            }
          }

          final prioridadColor = switch (aviso.prioridad) {
            AvisoPrioridad.informativo => colors.primary,
            AvisoPrioridad.importante => Colors.orange,
            AvisoPrioridad.urgente => colors.error,
          };

          final prioridadIcon = switch (aviso.prioridad) {
            AvisoPrioridad.informativo => Icons.info_outline,
            AvisoPrioridad.importante => Icons.warning_amber_outlined,
            AvisoPrioridad.urgente => Icons.error_outline,
          };

          return SafeArea(
            top: false,
            child: AdaptiveBody(
              maxWidth: 720,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Priority banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: prioridadColor.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: prioridadColor.withValues(alpha: .3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(prioridadIcon, color: prioridadColor),
                        const SizedBox(width: 12),
                        Text(
                          aviso.prioridad.label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: prioridadColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (aviso.isExpired) ...[
                          const Spacer(),
                          Chip(
                            label: const Text('Expirado'),
                            backgroundColor: colors.error.withValues(
                              alpha: .15,
                            ),
                            labelStyle: theme.textTheme.labelSmall?.copyWith(
                              color: colors.error,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    aviso.titulo,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Meta info
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: colors.onSurface.withValues(alpha: .5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        aviso.createdByName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: .6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: colors.onSurface.withValues(alpha: .5),
                      ),
                      const SizedBox(width: 4),
                      if (aviso.createdAt != null)
                        Text(
                          DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(aviso.createdAt!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: .6),
                          ),
                        ),
                    ],
                  ),

                  if (aviso.expiresAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 16,
                          color: colors.onSurface.withValues(alpha: .5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Expira: ${DateFormat('dd/MM/yyyy').format(aviso.expiresAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: aviso.isExpired
                                ? colors.error
                                : colors.onSurface.withValues(alpha: .6),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const Divider(height: 32),

                  // Message body
                  Text(
                    aviso.mensaje,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),

                  const SizedBox(height: 24),

                  // Audience chip
                  Row(
                    children: [
                      Icon(
                        aviso.todosLosUsuarios
                            ? Icons.groups_outlined
                            : Icons.person_outline,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        aviso.todosLosUsuarios
                            ? 'Enviado a todos los miembros del proyecto'
                            : 'Enviado a ${aviso.destinatarios.length} usuario${aviso.destinatarios.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  // ── Read Receipts (Root only) ──────────
                  if (isRoot && aviso.lecturas.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _ReadReceiptsSection(aviso: aviso),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleAction(String action, Aviso aviso) {
    switch (action) {
      case 'edit':
        context.push(
          '/projects/${widget.projectId}/avisos/${widget.avisoId}/edit',
        );
      case 'delete':
        _confirmDelete(aviso);
    }
  }

  Future<void> _confirmDelete(Aviso aviso) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar aviso'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este aviso? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(avisoRepositoryProvider).deactivate(widget.avisoId);
      if (mounted) context.pop();
    }
  }
}

/// Sección de read receipts tipo WhatsApp.
class _ReadReceiptsSection extends ConsumerWidget {
  const _ReadReceiptsSection({required this.aviso});

  final Aviso aviso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final allUsers = ref.watch(allUsersProvider).value ?? [];
    final userMap = {for (final u in allUsers) u.uid: u};

    // Sort: unread first, then by name
    final entries = aviso.lecturas.entries.toList()
      ..sort((a, b) {
        if (a.value.leido != b.value.leido) {
          return a.value.leido ? 1 : -1; // unread first
        }
        final nameA = userMap[a.key]?.displayName ?? a.key;
        final nameB = userMap[b.key]?.displayName ?? b.key;
        return nameA.compareTo(nameB);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with summary
            Row(
              children: [
                Text(
                  'ESTADO DE LECTURA',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Icon(
                  aviso.todosLeyeron ? Icons.done_all : Icons.done_all,
                  size: 18,
                  color: aviso.todosLeyeron
                      ? Colors.blue
                      : colors.onSurface.withValues(alpha: .4),
                ),
                const SizedBox(width: 4),
                Text(
                  '${aviso.leidoCount}/${aviso.totalDestinatarios}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: aviso.todosLeyeron
                        ? Colors.blue
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: aviso.totalDestinatarios > 0
                    ? aviso.leidoCount / aviso.totalDestinatarios
                    : 0,
                minHeight: 6,
                backgroundColor: colors.onSurface.withValues(alpha: .1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),

            const SizedBox(height: 16),

            // User list
            ...entries.map((entry) {
              final lectura = entry.value;
              final user = userMap[entry.key];
              final name = user?.displayName ?? entry.key;

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: lectura.leido
                      ? Colors.blue.withValues(alpha: .15)
                      : colors.surfaceContainerHighest,
                  child: Icon(
                    lectura.leido ? Icons.done_all : Icons.done,
                    size: 16,
                    color: lectura.leido
                        ? Colors.blue
                        : colors.onSurface.withValues(alpha: .4),
                  ),
                ),
                title: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: lectura.leido
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                ),
                subtitle: lectura.leido && lectura.leidoAt != null
                    ? Text(
                        'Leído ${DateFormat('dd/MM/yyyy HH:mm').format(lectura.leidoAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.withValues(alpha: .8),
                        ),
                      )
                    : Text(
                        'No leído',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: .4),
                        ),
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
