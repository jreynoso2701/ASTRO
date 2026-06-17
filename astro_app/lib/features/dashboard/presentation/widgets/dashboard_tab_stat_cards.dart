import 'package:flutter/material.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/core/models/cita.dart';
import 'package:astro/features/dashboard/presentation/widgets/dashboard_stats_summary.dart';
import 'package:astro/features/dashboard/presentation/widgets/dashboard_cita_tile.dart';

// ── Tab Stat Cards: Progreso general + Próximas citas ────

/// Tarjetas de progreso y próximas citas dentro de cada pestaña del dashboard.
/// Los datos reflejan únicamente los proyectos seleccionados en el filtro.
class DashboardTabStatCards extends StatelessWidget {
  const DashboardTabStatCards({
    super.key,
    required this.avgProgress,
    required this.avgBaseProgress,
    required this.upcomingCitas,
  });

  final double avgProgress;
  final double avgBaseProgress;
  final List<Cita> upcomingCitas;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBreakpoints.medium;
    final hasPenalty = avgBaseProgress > avgProgress;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: isWide ? null : double.infinity,
          child: DashboardStatCard(
            icon: Icons.trending_up,
            label: 'Progreso general',
            value: '${avgProgress.round()}%',
            color: progressColor(avgProgress),
            subtitle: hasPenalty
                ? 'Base: ${avgBaseProgress.round()}%  (-${(avgBaseProgress - avgProgress).toStringAsFixed(1)}%)'
                : null,
          ),
        ),
        SizedBox(
          width: isWide ? null : double.infinity,
          child: DashboardStatCard(
            icon: Icons.calendar_today_outlined,
            label: 'Próximas citas',
            value: '${upcomingCitas.length}',
            color: const Color(0xFF2196F3),
            onTap: upcomingCitas.isNotEmpty
                ? () => _showUpcomingCitasSheet(context, upcomingCitas)
                : null,
          ),
        ),
      ],
    );
  }
}

// ── Bottom Sheet: próximas citas ─────────────────────────

void _showUpcomingCitasSheet(BuildContext context, List<Cita> citas) {
  final theme = Theme.of(context);
  const color = Color(0xFF2196F3);

  // Ordenar cronológicamente
  final sorted = [...citas]
    ..sort((a, b) {
      final af = a.fecha ?? DateTime(9999);
      final bf = b.fecha ?? DateTime(9999);
      return af.compareTo(bf);
    });

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // ─ Handle ─
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ─ Header ─
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Próximas citas',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${sorted.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ─ Lista de citas ─
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: sorted.length,
              itemBuilder: (ctx, i) => DashboardCitaTile(cita: sorted[i]),
            ),
          ),
        ],
      ),
    ),
  );
}
