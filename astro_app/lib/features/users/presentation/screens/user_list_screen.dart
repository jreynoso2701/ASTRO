import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/app_user.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/core/models/registration_status.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de gestión de usuarios — accesible solo para Root.
class UserListScreen extends ConsumerWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final searchQuery = ref.watch(userSearchProvider);
    final filteredUsers = ref.watch(filteredUsersProvider);
    final deactivatedUsers = ref.watch(deactivatedUsersProvider);
    final deactivatedCount = deactivatedUsers.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/gestion');
      },
      child: SafeArea(
        child: Column(
          children: [
            // ── Header + Search ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.go('/gestion'),
                        tooltip: 'Volver a Gestión',
                      ),
                      Text(
                        'USUARIOS',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      if (deactivatedCount > 0)
                        Badge(
                          label: Text('$deactivatedCount'),
                          child: IconButton(
                            icon: const Icon(Icons.person_off_outlined),
                            tooltip: 'Usuarios desactivados',
                            onPressed: () => _showDeactivatedSheet(context),
                          ),
                        ),
                    ],
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
                  data: (all) {
                    final activeApprovedCount = all
                        .where(
                          (u) =>
                              u.registrationStatus ==
                                  RegistrationStatus.approved &&
                              u.isActive,
                        )
                        .length;
                    return Text(
                      '${filteredUsers.length} de $activeApprovedCount usuarios',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
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
      ),
    );
  }

  void _showDeactivatedSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) =>
            _DeactivatedUsersSheet(scrollController: scrollController),
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
          mainAxisExtent: 112,
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
    final role = user.globalRole;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/users/${user.uid}'),
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
                    _RoleBadge(role: role),
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

// ── Bottom Sheet de usuarios desactivados ────────────────

class _DeactivatedUsersSheet extends ConsumerStatefulWidget {
  const _DeactivatedUsersSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_DeactivatedUsersSheet> createState() =>
      _DeactivatedUsersSheetState();
}

class _DeactivatedUsersSheetState
    extends ConsumerState<_DeactivatedUsersSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deactivatedColor = theme.colorScheme.onSurfaceVariant;

    var users = ref.watch(deactivatedUsersProvider);

    if (_search.isNotEmpty) {
      final q = _search.toUpperCase();
      users = users
          .where(
            (u) =>
                u.displayName.toUpperCase().contains(q) ||
                u.email.toUpperCase().contains(q),
          )
          .toList();
    }

    return Column(
      children: [
        // ── Drag handle ──
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // ── Header ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.person_off_outlined,
                color: deactivatedColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Usuarios Desactivados',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: deactivatedColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${users.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: deactivatedColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Búsqueda ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o email...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _search = ''),
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),

        const SizedBox(height: 8),
        const Divider(height: 1),

        // ── Lista ──
        Expanded(
          child: users.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _search.isNotEmpty
                              ? 'No se encontraron coincidencias'
                              : 'No hay usuarios desactivados',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _DeactivatedUserTile(user: user);
                  },
                ),
        ),
      ],
    );
  }
}

class _DeactivatedUserTile extends ConsumerWidget {
  const _DeactivatedUserTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.onSurfaceVariant.withValues(
            alpha: 0.15,
          ),
          child: Text(
            _initials(user.displayName),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          user.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.person, color: Color(0xFF4CAF50)),
              tooltip: 'Reactivar usuario',
              onPressed: () => _confirmReactivate(context, ref),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          context.push('/users/${user.uid}');
        },
      ),
    );
  }

  void _confirmReactivate(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivar usuario'),
        content: Text(
          '¿Reactivar la cuenta de ${user.displayName}?\n\n'
          'El usuario podrá volver a iniciar sesión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(userRepositoryProvider).activateUser(user.uid);
            },
            child: const Text('Reactivar'),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0];
    return '?';
  }
}
