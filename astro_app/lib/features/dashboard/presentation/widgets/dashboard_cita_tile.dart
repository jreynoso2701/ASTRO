import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/cita.dart';
import 'package:astro/core/models/cita_status.dart';
import 'package:astro/core/models/minuta_modalidad.dart';

class DashboardCitaTile extends StatelessWidget {
  const DashboardCitaTile({super.key, required this.cita});

  final Cita cita;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _citaStatusColor(cita.status);
    final modalIcon = _citaModalidadIcon(cita.modalidad);

    // Formatear fecha
    final fecha = cita.fecha;
    if (fecha == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final citaDay = DateTime(fecha.year, fecha.month, fecha.day);
    final diff = citaDay.difference(today).inDays;

    String dateLabel;
    if (diff == 0) {
      dateLabel = 'Hoy';
    } else if (diff == 1) {
      dateLabel = 'Mañana';
    } else {
      dateLabel =
          '${fecha.day}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    }

    final timeStr = cita.horaInicio ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => GoRouter.of(
            context,
          ).push('/projects/${cita.projectId}/citas/${cita.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Status accent bar
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  modalIcon,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cita.titulo,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cita.projectName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: diff == 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
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
      ),
    );
  }

  static Color _citaStatusColor(CitaStatus status) => switch (status) {
    CitaStatus.programada => const Color(0xFF2196F3),
    CitaStatus.enCurso => const Color(0xFFFFC107),
    CitaStatus.completada => const Color(0xFF4CAF50),
    CitaStatus.cancelada => const Color(0xFFD32F2F),
  };

  static IconData _citaModalidadIcon(MinutaModalidad modalidad) =>
      switch (modalidad) {
        MinutaModalidad.videoconferencia => Icons.videocam_outlined,
        MinutaModalidad.presencial => Icons.place_outlined,
        MinutaModalidad.llamada => Icons.phone_outlined,
        MinutaModalidad.hibrida => Icons.devices_outlined,
      };
}
