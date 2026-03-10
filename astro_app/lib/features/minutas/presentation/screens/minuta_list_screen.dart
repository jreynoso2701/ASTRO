import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/minuta.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/minutas/providers/minuta_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';

/// Pantalla de listado de minutas de un proyecto.
class MinutaListScreen extends ConsumerWidget {
  const MinutaListScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectoAsync = ref.watch(proyectoByIdProvider(projectId));

    return proyectoAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('MINUTAS')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('MINUTAS')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (proyecto) {
        if (proyecto == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('MINUTAS')),
            body: const Center(child: Text('Proyecto no encontrado')),
          );
        }

        final projectName = proyecto.nombreProyecto;
        final minutasAsync = ref.watch(minutasByProjectProvider(projectName));
        final filteredMinutas = ref.watch(filteredMinutasProvider(projectId));
        final searchQuery = ref.watch(minutaSearchProvider);
        final canCreate = ref.watch(canCreateMinutaProvider(projectId));

        return Scaffold(
          appBar: AppBar(
            title: Text('MINUTAS — $projectName'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (canCreate)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Nueva minuta',
                  onPressed: () =>
                      context.push('/projects/$projectId/minutas/new'),
                ),
            ],
          ),
          body: minutasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (_) {
              return AdaptiveBody(
                maxWidth: 960,
                child: Column(
                  children: [
                    // Barra de búsqueda
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar minuta...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => ref
                                      .read(minutaSearchProvider.notifier)
                                      .clear(),
                                )
                              : null,
                          isDense: true,
                        ),
                        onChanged: (v) =>
                            ref.read(minutaSearchProvider.notifier).setQuery(v),
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
                            '${filteredMinutas.length} minuta${filteredMinutas.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    // Lista
                    Expanded(
                      child: filteredMinutas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 64,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Sin minutas',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filteredMinutas.length,
                              itemBuilder: (context, index) {
                                final minuta = filteredMinutas[index];
                                return _MinutaCard(
                                  minuta: minuta,
                                  onTap: () => context.push(
                                    '/projects/$projectId/minutas/${minuta.id}',
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Minuta Card ──────────────────────────────────────────

class _MinutaCard extends StatelessWidget {
  const _MinutaCard({required this.minuta, required this.onTap});

  final Minuta minuta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dateStr = minuta.fecha != null
        ? DateFormat('dd/MM/yyyy').format(minuta.fecha!)
        : '—';
    final pendientes = minuta.compromisosPendientes;
    final vencidos = minuta.compromisosVencidos;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Folio + Fecha
              Row(
                children: [
                  Text(
                    minuta.folio,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today, size: 14, color: muted),
                  const SizedBox(width: 4),
                  Text(dateStr, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),

              // Objetivo
              Text(
                minuta.objetivo,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Modalidad + Compromisos
              Row(
                children: [
                  Icon(
                    _modalidadIcon(minuta.modalidad.label),
                    size: 16,
                    color: muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    minuta.modalidad.label,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const Spacer(),
                  if (vencidos > 0)
                    _CompromisoBadge(
                      count: vencidos,
                      label: 'vencido${vencidos == 1 ? '' : 's'}',
                      color: theme.colorScheme.error,
                    ),
                  if (vencidos > 0 && pendientes > 0) const SizedBox(width: 8),
                  if (pendientes > 0)
                    _CompromisoBadge(
                      count: pendientes,
                      label: 'pendiente${pendientes == 1 ? '' : 's'}',
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),

              // Asistentes
              if (minuta.asistentes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people_outline, size: 14, color: muted),
                    const SizedBox(width: 4),
                    Text(
                      '${minuta.asistentes.length} asistente${minuta.asistentes.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static IconData _modalidadIcon(String modalidad) {
    switch (modalidad.toLowerCase()) {
      case 'videoconferencia':
        return Icons.videocam_outlined;
      case 'presencial':
        return Icons.location_on_outlined;
      case 'llamada':
        return Icons.phone_outlined;
      case 'híbrida':
        return Icons.devices_outlined;
      default:
        return Icons.event_outlined;
    }
  }
}

class _CompromisoBadge extends StatelessWidget {
  const _CompromisoBadge({
    required this.count,
    required this.label,
    required this.color,
  });

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count $label',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
