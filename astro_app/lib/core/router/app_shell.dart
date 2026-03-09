import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Destino de navegación compartido entre NavigationBar y NavigationRail.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

/// Todos los destinos posibles. Se filtran según el rol del usuario.
const List<AppDestination> _allDestinations = [
  AppDestination(
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard,
    path: '/',
  ),
  AppDestination(
    label: 'Proyectos',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder,
    path: '/projects',
  ),
  AppDestination(
    label: 'Usuarios',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    path: '/users',
  ),
];

/// Shell adaptativo: NavigationBar (móvil) / NavigationRail (tablet/web).
/// Muestra destinos según el rol del usuario autenticado.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  List<AppDestination> _visibleDestinations(bool isRoot) {
    return [
      _allDestinations[0], // Dashboard — siempre visible
      _allDestinations[1], // Proyectos — siempre visible
      if (isRoot) _allDestinations[2], // Usuarios — solo Root
    ];
  }

  int _currentIndex(BuildContext context, List<AppDestination> destinations) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = destinations.length - 1; i >= 0; i--) {
      final path = destinations[i].path;
      if (path != '/' && location.startsWith(path)) return i;
    }
    return 0;
  }

  void _onDestinationSelected(
    BuildContext context,
    int index,
    List<AppDestination> destinations,
  ) {
    context.go(destinations[index].path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final destinations = _visibleDestinations(isRoot);
    final width = MediaQuery.sizeOf(context).width;
    final selectedIndex = _currentIndex(context, destinations);

    // ── Expanded / Large → NavigationRail (tablet, desktop, web)
    if (width >= AppBreakpoints.compact && destinations.length >= 2) {
      final bool extended = width >= AppBreakpoints.medium;

      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: extended,
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) =>
                  _onDestinationSelected(context, i, destinations),
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // ── Compact → NavigationBar (móvil)
    // NavigationBar requiere mínimo 2 destinos; si solo hay 1, omitirlo.
    return Scaffold(
      body: child,
      bottomNavigationBar: destinations.length >= 2
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) =>
                  _onDestinationSelected(context, i, destinations),
              destinations: destinations
                  .map(
                    (d) => NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }
}
