import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/cita.dart';
import 'package:astro/core/models/cita_status.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';

/// Pantalla de listado de citas de un proyecto.
class CitaListScreen extends ConsumerWidget {
  const CitaListScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectoAsync = ref.watch(proyectoByIdProvider(projectId));

    return proyectoAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('CITAS')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('CITAS')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (proyecto) {
        if (proyecto == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('CITAS')),
            body: const Center(child: Text('Proyecto no encontrado')),
          );
        }

        final projectName = proyecto.nombreProyecto;
        final citasAsync = ref.watch(citasByProjectProvider(projectName));
        final filteredCitas = ref.watch(filteredCitasProvider(projectId));
        final searchQuery = ref.watch(citaSearchProvider);
        final statusFilter = ref.watch(citaStatusFilterProvider);

        return Scaffold(
          appBar: AppBar(
            title: Text('CITAS — $projectName'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Nueva cita',
                onPressed: () => context.push('/projects/$projectId/citas/new'),
              ),
            ],
          ),
          body: citasAsync.when(
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
                          hintText: 'Buscar cita...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => ref
                                      .read(citaSearchProvider.notifier)
                                      .clear(),
                                )
                              : null,
                          isDense: true,
                        ),
                        onChanged: (v) =>
                            ref.read(citaSearchProvider.notifier).setQuery(v),
                      ),
                    ),

                    // Filtros de estado
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _FilterChip(
                            label: 'Todas',
                            selected: statusFilter == null,
                            onSelected: (_) => ref
                                .read(citaStatusFilterProvider.notifier)
                                .clear(),
                          ),
                          for (final s in CitaStatus.values)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _FilterChip(
                                label: s.label,
                                selected: statusFilter == s,
                                onSelected: (_) => ref
                                    .read(citaStatusFilterProvider.notifier)
                                    .set(s),
                                color: _statusColor(s, context),
                              ),
                            ),
                        ],
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
                            '${filteredCitas.length} cita${filteredCitas.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    // Lista
                    Expanded(
                      child: filteredCitas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.event_outlined,
                                    size: 64,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Sin citas',
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
                              itemCount: filteredCitas.length,
                              itemBuilder: (context, index) {
                                final cita = filteredCitas[index];
                                return _CitaCard(
                                  cita: cita,
                                  onTap: () => context.push(
                                    '/projects/$projectId/citas/${cita.id}',
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

  static Color _statusColor(CitaStatus status, BuildContext context) {
    return switch (status) {
      CitaStatus.programada => Theme.of(context).colorScheme.primary,
      CitaStatus.enCurso => const Color(0xFFFFA726),
      CitaStatus.completada => const Color(0xFF4CAF50),
      CitaStatus.cancelada => Theme.of(context).colorScheme.error,
    };
  }
}

// ── Filter Chip ──────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: color?.withValues(alpha: 0.2),
      checkmarkColor: color,
      labelStyle: selected && color != null
          ? TextStyle(color: color, fontWeight: FontWeight.w600)
          : null,
    );
  }
}

// ── Cita Card ────────────────────────────────────────────

class _CitaCard extends StatelessWidget {
  const _CitaCard({required this.cita, required this.onTap});

  final Cita cita;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dateStr = cita.fecha != null
        ? DateFormat('dd/MM/yyyy').format(cita.fecha!)
        : '—';
    final timeStr = [
      cita.horaInicio,
      cita.horaFin,
    ].where((t) => t != null && t.isNotEmpty).join(' – ');

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
              // Folio + Status
              Row(
                children: [
                  Text(
                    cita.folio,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _StatusBadge(status: cita.status),
                ],
              ),
              const SizedBox(height: 8),

              // Título
              Text(
                cita.titulo,
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Fecha + hora
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: muted),
                  const SizedBox(width: 4),
                  Text(dateStr, style: theme.textTheme.bodySmall),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.schedule, size: 14, color: muted),
                    const SizedBox(width: 4),
                    Text(timeStr, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
              const SizedBox(height: 4),

              // Modalidad + participantes
              Row(
                children: [
                  Icon(
                    _modalidadIcon(cita.modalidad.label),
                    size: 16,
                    color: muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cita.modalidad.label,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  if (cita.participantes.isNotEmpty) ...[
                    const Spacer(),
                    Icon(Icons.people_outline, size: 14, color: muted),
                    const SizedBox(width: 4),
                    Text(
                      '${cita.participantes.length}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CitaStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      CitaStatus.programada => (
        Theme.of(context).colorScheme.primary,
        'Programada',
      ),
      CitaStatus.enCurso => (const Color(0xFFFFA726), 'En curso'),
      CitaStatus.completada => (const Color(0xFF4CAF50), 'Completada'),
      CitaStatus.cancelada => (
        Theme.of(context).colorScheme.error,
        'Cancelada',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
