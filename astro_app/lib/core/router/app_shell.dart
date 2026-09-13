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

      return Scaffold(
        body: Row(
          children: [
            // Rail plano: fondo sólido y una línea fina de separación.
            Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  right: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: NavigationRail(
                backgroundColor: Colors.transparent,
                extended: extended,
                selectedIndex: selectedIndex,
                onDestinationSelected: (i) =>
                    _onDestinationSelected(context, i, destinations),
                // Trazo vertical sobre el destino activo, en lugar de píldora.
                indicatorShape: const Border(left: BorderSide(width: 3)),
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
                    label: Text(d.label.toUpperCase()),
                  );
                }).toList(),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    // ── Compact → barra de navegación inferior (móvil)
    return Scaffold(
      body: child,
      bottomNavigationBar: destinations.length >= 2
          ? _NikeNavBar(
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

// ── Barra de navegación inferior ────────────────────────────────────────────

typedef _BadgeIconBuilder =
    Widget Function(
      IconData icon,
      bool isBell, {
      bool isCalendar,
      bool isTareas,
    });

/// Barra de navegación plana, al estilo de las apps de Nike.
///
/// Sin cristal, sin sombra y sin píldora de selección: fondo sólido, una
/// línea fina de separación arriba y un trazo grueso sobre el destino activo.
/// La jerarquía la marcan el peso del icono y el contraste del texto.
class _NikeNavBar extends StatelessWidget {
  const _NikeNavBar({
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
    final scheme = theme.colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      // El padding inferior respeta la barra de gestos (edge-to-edge).
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SizedBox(
        height: 64,
        child: Row(
          children: List.generate(destinations.length, (i) {
            final dest = destinations[i];
            final isSelected = i == selectedIndex;
            final color = isSelected
                ? scheme.onSurface
                : scheme.onSurfaceVariant;

            final iconWidget = badgeIcon(
              isSelected ? dest.selectedIcon : dest.icon,
              dest.path == '/notifications',
              isCalendar: dest.path == '/calendar',
              isTareas: dest.path == '/tareas',
            );

            return Expanded(
              child: GestureDetector(
                onTap: () => onDestinationSelected(i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Trazo superior del destino activo.
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      height: 3,
                      width: isSelected ? 28 : 0,
                      decoration: BoxDecoration(
                        color: scheme.onSurface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Spacer(),
                    IconTheme(
                      data: IconThemeData(color: color, size: 24),
                      child: iconWidget,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dest.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
