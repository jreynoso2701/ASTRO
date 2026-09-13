import 'package:flutter/material.dart';

import 'package:astro/core/constants/app_typography.dart';
import 'package:astro/core/utils/progress_color.dart';

/// Barra de avance que se rellena con una animación al entrar y cada vez que
/// el porcentaje cambia.
///
/// Anima desde el valor anterior, no desde cero, para que una actualización en
/// vivo se lea como un incremento y no como un redibujado.
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    required this.percent,
    this.height = 6,
    this.duration = const Duration(milliseconds: 700),
    this.color,
    super.key,
  });

  /// Avance de 0 a 100.
  final double percent;
  final double height;
  final Duration duration;

  /// Color fijo; si se omite se usa la escala semántica de [progressColor].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = (percent / 100).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value,
          minHeight: height,
          backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
          valueColor: AlwaysStoppedAnimation(
            color ?? progressColor(value * 100),
          ),
        ),
      ),
    );
  }
}

/// Cifra que cuenta hasta su valor en lugar de aparecer de golpe.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    required this.value,
    this.style,
    this.suffix = '',
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 700),
    super.key,
  });

  final double value;
  final TextStyle? style;
  final String suffix;
  final int decimals;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text('${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}

/// Etiqueta + porcentaje + barra: el bloque de avance que comparten la tarjeta
/// de proyecto de Gestión y la del Dashboard.
class ProgressSummary extends StatelessWidget {
  const ProgressSummary({
    required this.percent,
    this.label = 'AVANCE',
    this.height = 6,
    super.key,
  });

  final double percent;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = progressColor(percent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.overline.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            AnimatedCounter(
              value: percent,
              suffix: '%',
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedProgressBar(percent: percent, height: height),
      ],
    );
  }
}
