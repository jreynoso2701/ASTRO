import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/features/dashboard/providers/dashboard_providers.dart';

// ── Project Sort Button ──────────────────────────────────

class DashboardProjectSortButton extends ConsumerWidget {
  const DashboardProjectSortButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(projectSortProvider);
    return PopupMenuButton<ProjectSortOption>(
      tooltip: 'Ordenar proyectos',
      icon: Icon(
        Icons.sort,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onSelected: (option) =>
          ref.read(projectSortProvider.notifier).set(option),
      itemBuilder: (_) => ProjectSortOption.values
          .map(
            (o) => PopupMenuItem(
              value: o,
              child: Row(
                children: [
                  if (o == current)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.primary,
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(o.label),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
