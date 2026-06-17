import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/modules/providers/module_providers.dart';

// ── Project Card ─────────────────────────────────────────

class DashboardProjectCard extends StatelessWidget {
  const DashboardProjectCard({
    super.key,
    required this.proyecto,
    required this.ref,
    required this.onTap,
  });

  final Proyecto proyecto;
  final WidgetRef ref;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ref.watch(
      projectProgressProvider(proyecto.nombreProyecto),
    );
    final baseProgress = ref.watch(
      projectBaseProgressProvider(proyecto.nombreProyecto),
    );
    final openTickets = ref.watch(openTicketCountProvider(proyecto.id));
    final pendingReqs = ref.watch(pendingReqCountProvider(proyecto.id));
    final members = ref.watch(projectMembersProvider(proyecto.id));
    final penalty = baseProgress - progress;
    final hasPenalty = penalty > 0.5;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre y folio
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.08,
                    ),
                    child: Text(
                      proyecto.folioProyecto.isNotEmpty
                          ? proyecto.folioProyecto.substring(
                              0,
                              proyecto.folioProyecto.length.clamp(0, 2),
                            )
                          : '?',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proyecto.nombreProyecto,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          proyecto.fkEmpresa,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Progress bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 100) / 100,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: progressColor(progress),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${progress.round()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: progressColor(progress),
                    ),
                  ),
                ],
              ),

              // Penalty indicator (only when tickets are dragging progress down)
              if (hasPenalty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: const Color(0xFFFF9800),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Base: ${baseProgress.round()}%  ▼${penalty.toStringAsFixed(1)}% por tickets',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFFF9800),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Footer: tickets + reqs + miembros
              Row(
                children: [
                  Icon(
                    Icons.confirmation_num_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$openTickets',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.task_alt_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$pendingReqs',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.people_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${members.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
