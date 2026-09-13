import 'package:flutter/material.dart';
import 'package:astro/core/constants/app_colors.dart';
import 'package:astro/core/constants/app_typography.dart';

// ── Stats Summary (solo Root) ────────────────────────────

/// Sección de estadística de alto nivel. Solo visible para Root.
class DashboardStatsSummary extends StatelessWidget {
  const DashboardStatsSummary({super.key, required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return DashboardStatCard(
      icon: Icons.folder_outlined,
      label: 'Proyectos activos',
      value: '$activeCount',
      color: AppColors.info,
    );
  }
}

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Cifra enorme arriba, etiqueta diminuta en mayúsculas debajo: la métrica
    // es el objeto de la tarjeta y el icono queda como marca tenue al margen.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    label.toUpperCase(),
                    style: AppTypography.overline.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: theme.textTheme.displaySmall?.copyWith(color: color),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
