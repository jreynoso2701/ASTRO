import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/constants/app_colors.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/core/widgets/animated_progress_bar.dart';
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
    final leads = ref.watch(projectLeadNamesProvider(proyecto.id));
    final penalty = baseProgress - progress;
    final hasPenalty = penalty > 0.5;
    // Carga de tickets sin diluir: es lo que de verdad queda por resolver,
    // frente a la resta que el promedio de modulos deja casi invisible.
    final pendingWeight = ref.watch(
      projectPendingWeightProvider(proyecto.nombreProyecto),
    );
    final hasPending = pendingWeight >= 1;
    // Sin módulos no hay avance que medir: mostrar 0% haría parecer parado un
    // proyecto que solo está sin desglosar.
    final hasModules = ref.watch(
      projectHasModulesProvider(proyecto.nombreProyecto),
    );

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

              // Responsables principales
              if (leads.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        leads.join(' · '),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const Spacer(),

              // Progress bar
              if (!hasModules)
                Text(
                  'Sin módulos',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(child: AnimatedProgressBar(percent: progress)),
                    const SizedBox(width: 8),
                    AnimatedCounter(
                      value: progress,
                      suffix: '%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: progressColor(progress),
                      ),
                    ),
                  ],
                ),

              // Lo pendiente por tickets. Se muestra con el peso en crudo
              // porque la resta al porcentaje queda diluida entre modulos.
              if (hasModules && hasPending) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        hasPenalty
                            ? 'Pendiente ${pendingWeight.toStringAsFixed(0)} pts · ▼${penalty.toStringAsFixed(1)}%'
                            : 'Pendiente ${pendingWeight.toStringAsFixed(0)} pts por tickets',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
