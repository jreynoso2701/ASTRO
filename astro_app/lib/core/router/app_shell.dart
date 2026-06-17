import 'dart:math' show max;
import 'dart:ui';
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
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      return Scaffold(
        body: Row(
          children: [
            // Liquid Glass NavigationRail
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.55),
                    border: Border(
                      right: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  child: NavigationRail(
                    backgroundColor: Colors.transparent,
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
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    // ── Compact → Liquid Glass NavigationBar flotante (móvil)
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: destinations.length >= 2
          ? _LiquidGlassNavBar(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) =>
                  _onDestinationSelected(context, i, destinations),
              badgeIcon: badgeIcon,
              unreadCount: unreadCount,
              upcomingCitas: upcomingCitas,
              pendingTareas: pendingTareas,
            )
          : null,
    );
  }
}

// ── Liquid Glass NavigationBar flotante ──────────────────────────────────────

typedef _BadgeIconBuilder = Widget Function(
  IconData icon,
  bool isBell, {
  bool isCalendar,
  bool isTareas,
});

class _LiquidGlassNavBar extends StatelessWidget {
  const _LiquidGlassNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.badgeIcon,
    required this.unreadCount,
    required this.upcomingCitas,
    required this.pendingTareas,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final _BadgeIconBuilder badgeIcon;
  final int unreadCount;
  final int upcomingCitas;
  final int pendingTareas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, max(bottomPadding + 8, 16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.13)
                    : Colors.white.withValues(alpha: 0.80),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(destinations.length, (i) {
                final dest = destinations[i];
                final isSelected = i == selectedIndex;
                final isBell = dest.path == '/notifications';
                final isCal = dest.path == '/calendar';
                final isTar = dest.path == '/tareas';

                final iconWidget = badgeIcon(
                  isSelected ? dest.selectedIcon : dest.icon,
                  isBell,
                  isCalendar: isCal,
                  isTareas: isTar,
                );

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onDestinationSelected(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor.withValues(alpha: isDark ? 0.18 : 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.10 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: IconTheme(
                              data: IconThemeData(
                                color: isSelected
                                    ? primaryColor
                                    : (isDark
                                        ? Colors.white60
                                        : Colors.black54),
                                size: 24,
                              ),
                              child: iconWidget,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? primaryColor
                                  : (isDark
                                      ? Colors.white60
                                      : Colors.black54),
                              letterSpacing: 0.2,
                            ),
                            child: Text(
                              dest.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
