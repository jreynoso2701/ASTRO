import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/aviso.dart';
import 'package:astro/core/models/aviso_prioridad.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/avisos/providers/aviso_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';

/// Pantalla de listado de avisos de un proyecto.
class AvisoListScreen extends ConsumerWidget {
  const AvisoListScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectoAsync = ref.watch(proyectoByIdProvider(projectId));
    final isRoot = ref.watch(isCurrentUserRootProvider);

    return proyectoAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('AVISOS')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('AVISOS')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (proyecto) {
        if (proyecto == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('AVISOS')),
            body: const Center(child: Text('Proyecto no encontrado')),
          );
        }

        final projectName = proyecto.nombreProyecto;
        final avisosAsync = ref.watch(avisosByProjectProvider(projectId));
        final filteredAvisos = ref.watch(filteredAvisosProvider(projectId));
        final searchQuery = ref.watch(avisoSearchProvider);
        final uid = ref.watch(authStateProvider).value?.uid;

        return Scaffold(
          appBar: AppBar(
            title: Text('AVISOS — $projectName'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (isRoot)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Nuevo aviso',
                  onPressed: () =>
                      context.push('/projects/$projectId/avisos/new'),
                ),
            ],
          ),
          body: avisosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (_) {
              return SafeArea(
                top: false,
                child: AdaptiveBody(
                  maxWidth: 960,
                  child: Column(
                    children: [
                      // Barra de búsqueda
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar aviso...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => ref
                                        .read(avisoSearchProvider.notifier)
                                        .clear(),
                                  )
                                : null,
                            isDense: true,
                          ),
                          onChanged: (v) => ref
                              .read(avisoSearchProvider.notifier)
                              .setQuery(v),
                        ),
                      ),

                      // Contador
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${filteredAvisos.length} aviso${filteredAvisos.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),

                      // Lista
                      Expanded(
                        child: filteredAvisos.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.campaign_outlined,
                                      size: 64,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: .3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Sin avisos',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: .5),
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  24,
                                ),
                                itemCount: filteredAvisos.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (ctx, i) => _AvisoCard(
                                  aviso: filteredAvisos[i],
                                  projectId: projectId,
                                  isRoot: isRoot,
                                  currentUid: uid,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AvisoCard extends StatelessWidget {
  const _AvisoCard({
    required this.aviso,
    required this.projectId,
    required this.isRoot,
    this.currentUid,
  });

  final Aviso aviso;
  final String projectId;
  final bool isRoot;
  final String? currentUid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Read receipt status for current user
    final isRead =
        currentUid != null && (aviso.lecturas[currentUid]?.leido ?? false);

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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/projects/$projectId/avisos/${aviso.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top color strip for priority
            Container(height: 4, color: prioridadColor),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: priority icon + title + read indicator
                  Row(
                    children: [
                      Icon(prioridadIcon, size: 20, color: prioridadColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          aviso.titulo,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Message preview
                  Text(
                    aviso.mensaje,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: .7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Footer: date + read receipts (Root only) + audience
                  Row(
                    children: [
                      // Audience chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          aviso.todosLosUsuarios
                              ? 'Todos'
                              : '${aviso.destinatarios.length} usuario${aviso.destinatarios.length == 1 ? '' : 's'}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Priority label
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: prioridadColor.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          aviso.prioridad.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: prioridadColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Read receipts (Root only)
                      if (isRoot && aviso.totalDestinatarios > 0) ...[
                        Icon(
                          aviso.todosLeyeron ? Icons.done_all : Icons.done_all,
                          size: 16,
                          color: aviso.todosLeyeron
                              ? Colors.blue
                              : colors.onSurface.withValues(alpha: .4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${aviso.leidoCount}/${aviso.totalDestinatarios}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: .5),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Date
                      if (aviso.createdAt != null)
                        Text(
                          DateFormat('dd/MM/yy').format(aviso.createdAt!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: .4),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
