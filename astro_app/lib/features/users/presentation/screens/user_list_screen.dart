import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/app_user.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de gestión de usuarios — accesible solo para Root.
class UserListScreen extends ConsumerWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final searchQuery = ref.watch(userSearchProvider);
    final filteredUsers = ref.watch(filteredUsersProvider);

    return SafeArea(
      child: Column(
        children: [
          // ── Header + Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'USUARIOS',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                ref.read(userSearchProvider.notifier).clear(),
                          )
                        : null,
                  ),
                  onChanged: (v) =>
                      ref.read(userSearchProvider.notifier).setQuery(v),
                ),
              ],
            ),
          ),

          // ── User count ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: usersAsync.when(
                data: (all) => Text(
                  '${filteredUsers.length} de ${all.length} usuarios',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── List / Grid ──
          Expanded(
            child: usersAsync.when(
              data: (_) => _UserListContent(users: filteredUsers),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error al cargar usuarios: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserListContent extends StatelessWidget {
  const _UserListContent({required this.users});

  final List<AppUser> users;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text('No se encontraron usuarios'));
    }

    final width = MediaQuery.sizeOf(context).width;

    // En pantallas amplias usar grid de 2-3 columnas
    if (width >= AppBreakpoints.medium) {
      final crossAxisCount = adaptiveGridColumns(width);
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 100,
        ),
        itemCount: users.length,
        itemBuilder: (context, index) => _UserCard(user: users[index]),
      );
    }

    // En móvil: lista vertical
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _UserCard(user: users[index]),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = user.isRoot
        ? UserRole.root
        : UserRole.fromString(user.legacyRolUsuario ?? 'Usuario');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/users/${user.uid}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: _roleColor(role).withValues(alpha: 0.15),
                child: Text(
                  _initials(user.displayName),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _roleColor(role),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.displayName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _RoleBadge(role: role),
                        if (user.legacyDeEmpresa != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              user.legacyDeEmpresa!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Status indicator
              Icon(
                user.isActive ? Icons.circle : Icons.circle_outlined,
                size: 10,
                color: user.isActive
                    ? const Color(0xFF4CAF50)
                    : theme.colorScheme.onSurfaceVariant,
              ),

              const SizedBox(width: 4),
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

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0];
    return '?';
  }

  static Color _roleColor(UserRole role) {
    return switch (role) {
      UserRole.root => const Color(0xFFD71921),
      UserRole.supervisor => const Color(0xFF2196F3),
      UserRole.soporte => const Color(0xFFFFC107),
      UserRole.usuario => const Color(0xFF4CAF50),
    };
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = _UserCard._roleColor(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
