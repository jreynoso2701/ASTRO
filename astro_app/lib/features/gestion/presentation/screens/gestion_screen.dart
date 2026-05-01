import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/core/router/app_router.dart';

/// Pantalla hub de Gestión — agrupa Proyectos, Usuarios y Empresas.
class GestionScreen extends ConsumerWidget {
  const GestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final projects = ref.watch(myProjectsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= AppBreakpoints.medium ? 3 : 1;

    final items = <_GestionItem>[
      _GestionItem(
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder,
        title: 'Proyectos',
        subtitle:
            '${projects.length} proyecto${projects.length != 1 ? 's' : ''} asignado${projects.length != 1 ? 's' : ''}',
        color: const Color(0xFF2196F3),
        path: '/projects',
      ),
      if (isRoot) ...[
        _GestionItem(
          icon: Icons.person_add_outlined,
          selectedIcon: Icons.person_add,
          title: 'Solicitudes',
          subtitle: _pendingSubtitle(ref),
          color: const Color(0xFFE91E63),
          path: '/gestion/requests',
          badgeCount: ref.watch(pendingUsersCountProvider),
        ),
        _GestionItem(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          title: 'Usuarios',
          subtitle: 'Gestión de cuentas y roles',
          color: const Color(0xFF00BCD4),
          path: '/users',
        ),
        _GestionItem(
          icon: Icons.business_outlined,
          selectedIcon: Icons.business,
          title: 'Empresas',
          subtitle: 'Administración de empresas',
          color: const Color(0xFFFF9800),
          path: '/empresas',
        ),
        _GestionItem(
          icon: Icons.label_outlined,
          selectedIcon: Icons.label,
          title: 'Etiquetas',
          subtitle: 'Etiquetas globales del sistema',
          color: const Color(0xFF9C27B0),
          path: AppRoutes.globalEtiquetas,
        ),
      ],
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Text('GESTIÓN', style: theme.textTheme.displaySmall),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 96,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _GestionTile(item: items[index]),
                  childCount: items.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  String _pendingSubtitle(WidgetRef ref) {
    final count = ref.watch(pendingUsersCountProvider);
    if (count == 0) return 'Sin solicitudes pendientes';
    return '$count solicitud${count != 1 ? 'es' : ''} pendiente${count != 1 ? 's' : ''}';
  }
}

class _GestionItem {
  const _GestionItem({
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.path,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final String subtitle;
  final Color color;
  final String path;
  final int badgeCount;
}

class _GestionTile extends StatelessWidget {
  const _GestionTile({required this.item});

  final _GestionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(item.path),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Badge(
                  isLabelVisible: item.badgeCount > 0,
                  label: Text('${item.badgeCount}'),
                  child: Icon(item.icon, color: item.color, size: 26),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
