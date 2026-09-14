import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:astro/core/constants/app_colors.dart';
import 'package:astro/core/constants/app_typography.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/utils/ticket_colors.dart';
import 'package:astro/core/widgets/animated_progress_bar.dart';
import 'package:astro/features/dashboard/providers/chart_providers.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';

// ── Envoltorio comun ─────────────────────────────────────

/// Tarjeta con titulo, subtitulo opcional y el grafico dentro.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.overline.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Mensaje para cuando un grafico se queda sin datos que pintar.
class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 140,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── 1. Tickets por estatus ───────────────────────────────

/// Reparto de los tickets abiertos por estado, como anillo.
///
/// El total va en el centro en vez de en una etiqueta aparte: es el dato que
/// se busca primero y el anillo deja ese hueco libre de todas formas.
class TicketStatusChart extends ConsumerStatefulWidget {
  const TicketStatusChart({super.key});

  @override
  ConsumerState<TicketStatusChart> createState() => _TicketStatusChartState();
}

class _TicketStatusChartState extends ConsumerState<TicketStatusChart> {
  /// Sector bajo el dedo o el cursor; -1 cuando no hay ninguno.
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = ref.watch(globalTicketCountsByStatusProvider);

    final entries = [
      for (final status in TicketStatus.kanbanValues)
        if ((counts[status] ?? 0) > 0) (status: status, count: counts[status]!),
    ];
    final total = entries.fold<int>(0, (sum, e) => sum + e.count);

    if (total == 0) {
      return const _ChartCard(
        title: 'TICKETS POR ESTATUS',
        child: _ChartEmpty(message: 'Sin tickets en tus proyectos'),
      );
    }

    return _ChartCard(
      title: 'TICKETS POR ESTATUS',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 38,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          _touched = event.isInterestedForInteractions
                              ? response?.touchedSection?.touchedSectionIndex ??
                                    -1
                              : -1;
                        });
                      },
                    ),
                    sections: [
                      for (var i = 0; i < entries.length; i++)
                        PieChartSectionData(
                          value: entries[i].count.toDouble(),
                          color: ticketStatusColor(entries[i].status),
                          // El sector activo crece un poco en vez de cambiar
                          // de color: el color ya significa el estado.
                          radius: i == _touched ? 26 : 22,
                          showTitle: false,
                        ),
                    ],
                  ),
                  // Deja que el anillo se dibuje al entrar en vez de aparecer.
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedCounter(
                      value: _touched >= 0 && _touched < entries.length
                          ? entries[_touched].count.toDouble()
                          : total.toDouble(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _touched >= 0 && _touched < entries.length
                          ? entries[_touched].status.label
                          : 'tickets',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: ticketStatusColor(entries[i].status),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            entries[i].status.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: i == _touched
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${entries[i].count}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. Altas vs. cierres por mes ─────────────────────────

/// Entradas y salidas de tickets mes a mes, en barras enfrentadas.
class TicketFlowChart extends ConsumerWidget {
  const TicketFlowChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final flow = ref.watch(ticketFlowByMonthProvider);
    final hasData = flow.any((f) => f.opened > 0 || f.closed > 0);

    if (!hasData) {
      return const _ChartCard(
        title: 'ALTAS VS. CIERRES',
        child: _ChartEmpty(message: 'Sin movimiento en los ultimos 12 meses'),
      );
    }

    final maxY = flow
        .map((f) => f.opened > f.closed ? f.opened : f.closed)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    // El neto del periodo completo es el titular: dice si se acumula trabajo.
    final netoTotal = flow.fold<int>(0, (sum, f) => sum + f.net);
    final netoColor = netoTotal > 0 ? AppColors.warning : AppColors.success;

    return _ChartCard(
      title: 'ALTAS VS. CIERRES',
      subtitle:
          'Ultimos 12 meses · fecha de cierre aproximada en los tickets '
          'antiguos sin registro de cierre',
      trailing: Text(
        netoTotal > 0 ? '+$netoTotal acumulados' : '$netoTotal acumulados',
        style: theme.textTheme.labelSmall?.copyWith(
          color: netoColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY == 0 ? 1 : maxY * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final f = flow[group.x];
                      return BarTooltipItem(
                        '${DateFormat('MMM yyyy', 'es').format(f.month)}\n'
                        '${f.opened} altas · ${f.closed} cierres',
                        TextStyle(
                          color: theme.colorScheme.onInverseSurface,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      // Solo se rotulan los extremos: en 12 meses el eje se
                      // satura enseguida y las barras son el dato.
                      interval: maxY <= 4 ? 1 : (maxY / 3).ceilToDouble(),
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= flow.length) {
                          return const SizedBox.shrink();
                        }
                        // Con 12 columnas no caben todas las etiquetas, asi
                        // que se rotula un mes de cada dos.
                        if (flow.length > 6 && i.isOdd) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('MMM', 'es').format(flow[i].month),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < flow.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 2,
                      barRods: [
                        BarChartRodData(
                          toY: flow[i].opened.toDouble(),
                          color: AppColors.info,
                          width: 6,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                        BarChartRodData(
                          toY: flow[i].closed.toDouble(),
                          color: AppColors.success,
                          width: 6,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FlowLegend(color: AppColors.info, label: 'Altas'),
              const SizedBox(width: 18),
              _FlowLegend(color: AppColors.success, label: 'Cierres'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowLegend extends StatelessWidget {
  const _FlowLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
