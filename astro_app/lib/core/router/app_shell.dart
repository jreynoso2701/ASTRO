import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/notifications/providers/notification_providers.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/features/tareas/providers/tarea_providers.dart';

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

/// Todos los destinos de navegación.
const List<AppDestination> _allDestinations = [
  AppDestination(
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard,
    path: '/',
  ),
  AppDestination(
    label: 'Tareas',
    icon: Icons.task_outlined,
    selectedIcon: Icons.task,
    path: '/tareas',
  ),
  AppDestination(
    label: 'Calendario',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
    path: '/calendar',
  ),
  AppDestination(
    label: 'Notificaciones',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    path: '/notifications',
  ),
  AppDestination(
    label: 'Gestión',
    icon: Icons.widgets_outlined,
    selectedIcon: Icons.widgets,
    path: '/gestion',
  ),
];

/// Rutas que forman parte del grupo "Gestión" y deben resaltar ese tab.
const _gestionPaths = ['/gestion', '/projects', '/users', '/empresas'];

/// Shell adaptativo: NavigationBar (móvil) / NavigationRail (tablet/web).
/// Muestra destinos según el rol del usuario autenticado.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  List<AppDestination> _visibleDestinations(bool isRoot) {
    // Todos los destinos son visibles para cualquier rol.
    return List.unmodifiable(_allDestinations);
  }

  int _currentIndex(BuildContext context, List<AppDestination> destinations) {
    final location = GoRouterState.of(context).uri.path;

    // Rutas del grupo Gestión → índice del tab Gestión.
    final gestionIndex = destinations.indexWhere((d) => d.path == '/gestion');
    if (gestionIndex >= 0 &&
        _gestionPaths.any((p) => p != '/' && location.startsWith(p))) {
      return gestionIndex;
    }

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
    final unreadCount = ref.watch(unreadCountProvider);
    final upcomingCitas = ref.watch(upcomingCitasCountProvider);
    final pendingTareas = ref.watch(myPendingTareasProvider).length;

    Widget badgeIcon(
      IconData icon,
      bool isBell, {
      bool isCalendar = false,
      bool isTareas = false,
    }) {
      if (isTareas && pendingTareas > 0) {
        return Badge.count(count: pendingTareas, child: Icon(icon));
      }
      if (isCalendar && upcomingCitas > 0) {
        return Badge.count(count: upcomingCitas, child: Icon(icon));
      }
      if (!isBell || unreadCount == 0) return Icon(icon);
      return Badge.count(count: unreadCount, child: Icon(icon));
    }

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
              destinations: destinations.map((d) {
                final isBell = d.path == '/notifications';
                final isCal = d.path == '/calendar';
                final isTar = d.path == '/tareas';
                return NavigationRailDestination(
                  icon: badgeIcon(
                    d.icon,
                    isBell,
                    isCalendar: isCal,
                    isTareas: isTar,
                  ),
                  selectedIcon: badgeIcon(
                    d.selectedIcon,
                    isBell,
                    isCalendar: isCal,
                    isTareas: isTar,
                  ),
                  label: Text(d.label),
                );
              }).toList(),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // ── Compact → NavigationBar (móvil)
    return Scaffold(
      body: child,
      bottomNavigationBar: destinations.length >= 2
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) =>
                  _onDestinationSelected(context, i, destinations),
              destinations: destinations.map((d) {
                final isBell = d.path == '/notifications';
                final isCal = d.path == '/calendar';
                final isTar = d.path == '/tareas';
                return NavigationDestination(
                  icon: badgeIcon(
                    d.icon,
                    isBell,
                    isCalendar: isCal,
                    isTareas: isTar,
                  ),
                  selectedIcon: badgeIcon(
                    d.selectedIcon,
                    isBell,
                    isCalendar: isCal,
                    isTareas: isTar,
                  ),
                  label: d.label,
                );
              }).toList(),
            )
          : null,
    );
  }
}
