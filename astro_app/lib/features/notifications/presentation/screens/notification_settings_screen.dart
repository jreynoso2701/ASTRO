import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/notification_config.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/notifications/providers/notification_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';

/// Pantalla para que Root gestione las notificaciones de cada miembro del proyecto.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(projectMembersProvider(widget.projectId));
    final configsAsync = ref.watch(
      projectNotifConfigsProvider(widget.projectId),
    );
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Mapa de configs existentes indexado por userId
    final configMap = <String, NotificationConfig>{};
    final configs = configsAsync.value ?? [];
    for (final c in configs) {
      configMap[c.userId] = c;
    }

    // Filtrar miembros por búsqueda
    final filteredMembers = _query.isEmpty
        ? members
        : members.where((m) {
            final user = m.user;
            if (user == null) return false;
            final q = _query.toLowerCase();
            return user.displayName.toLowerCase().contains(q) ||
                user.email.toLowerCase().contains(q) ||
                m.assignment.role.label.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('NOTIFICACIONES DEL PROYECTO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Buscador ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar miembro...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
          ),
          // ── Lista ──
          Expanded(
            child: filteredMembers.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'Sin miembros asignados'
                          : 'Sin resultados para "$_query"',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface.withValues(alpha: .5),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredMembers.length,
                    itemBuilder: (context, i) {
                      final member = filteredMembers[i];
                      final user = member.user;
                      final assignment = member.assignment;
                      if (user == null) return const SizedBox.shrink();

                      final existingConfig = configMap[user.uid];
                      final effectiveConfig =
                          existingConfig ??
                          NotificationConfig.defaultForRole(
                            projectId: widget.projectId,
                            userId: user.uid,
                            role: assignment.role,
                          );

                      return _MemberNotifCard(
                        projectId: widget.projectId,
                        userId: user.uid,
                        displayName: user.displayName,
                        email: user.email,
                        role: assignment.role,
                        config: effectiveConfig,
                        hasOverride: existingConfig != null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemberNotifCard extends ConsumerWidget {
  const _MemberNotifCard({
    required this.projectId,
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.config,
    required this.hasOverride,
  });

  final String projectId;
  final String userId;
  final String displayName;
  final String email;
  final UserRole role;
  final NotificationConfig config;
  final bool hasOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: nombre, email, rol ──
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: .6),
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(role.label, style: theme.textTheme.labelSmall),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (hasOverride)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Configuración personalizada',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.tertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const Divider(height: 24),

            // ── Master toggle ──
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notificaciones activas'),
              subtitle: const Text(
                'Toggle general para este usuario en el proyecto',
              ),
              value: config.pushEnabled,
              onChanged: (val) => _save(ref, config.copyWith(pushEnabled: val)),
            ),

            if (config.pushEnabled) ...[
              const SizedBox(height: 8),

              // ── Tickets ──
              Text(
                'TICKETS',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Recibir notificaciones de tickets'),
                value: config.recibirTickets,
                onChanged: (val) =>
                    _save(ref, config.copyWith(recibirTickets: val)),
              ),
              if (config.recibirTickets)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _ScopeSelector(
                    label: 'Alcance de tickets',
                    currentScope: config.scopeTickets,
                    defaultScope: NotificationScope.defaultForRole(role),
                    onChanged: (scope) =>
                        _save(ref, config.copyWith(scopeTickets: scope)),
                  ),
                ),

              const SizedBox(height: 12),

              // ── Requerimientos ──
              Text(
                'REQUERIMIENTOS',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Recibir notificaciones de requerimientos'),
                value: config.recibirRequerimientos,
                onChanged: (val) =>
                    _save(ref, config.copyWith(recibirRequerimientos: val)),
              ),
              if (config.recibirRequerimientos)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _ScopeSelector(
                    label: 'Alcance de requerimientos',
                    currentScope: config.scopeRequerimientos,
                    defaultScope: NotificationScope.defaultForRole(role),
                    onChanged: (scope) =>
                        _save(ref, config.copyWith(scopeRequerimientos: scope)),
                  ),
                ),

              const SizedBox(height: 12),

              // ── Tareas ──
              Text(
                'TAREAS',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Recibir notificaciones de tareas'),
                value: config.recibirTareas,
                onChanged: (val) =>
                    _save(ref, config.copyWith(recibirTareas: val)),
              ),
              if (config.recibirTareas)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _ScopeSelector(
                    label: 'Alcance de tareas',
                    currentScope: config.scopeTareas,
                    defaultScope: NotificationScope.defaultForRole(role),
                    onChanged: (scope) =>
                        _save(ref, config.copyWith(scopeTareas: scope)),
                  ),
                ),

              const SizedBox(height: 12),

              // ── Citas ──
              Text(
                'CITAS',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Recibir notificaciones de citas'),
                value: config.recibirCitas,
                onChanged: (val) =>
                    _save(ref, config.copyWith(recibirCitas: val)),
              ),
              if (config.recibirCitas)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _ScopeSelector(
                    label: 'Alcance de citas',
                    currentScope: config.scopeCitas,
                    defaultScope: NotificationScope.defaultForRole(role),
                    onChanged: (scope) =>
                        _save(ref, config.copyWith(scopeCitas: scope)),
                  ),
                ),
            ],

            // ── Reset a defaults ──
            if (hasOverride)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _reset(ref),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Restaurar defaults del rol'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _save(WidgetRef ref, NotificationConfig updated) {
    final myUid = ref.read(authStateProvider).value?.uid ?? '';
    ref
        .read(notificationConfigRepoProvider)
        .save(updated.copyWith(updatedBy: myUid));
  }

  void _reset(WidgetRef ref) {
    ref.read(notificationConfigRepoProvider).delete(projectId, userId);
  }
}

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({
    required this.label,
    required this.currentScope,
    required this.defaultScope,
    required this.onChanged,
  });

  final String label;
  final NotificationScope currentScope;
  final NotificationScope defaultScope;
  final ValueChanged<NotificationScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: .6),
          ),
        ),
        const SizedBox(height: 4),
        SegmentedButton<NotificationScope>(
          segments: [
            ButtonSegment(
              value: NotificationScope.participante,
              label: const Text('Solo propios'),
              icon: const Icon(Icons.person_outline, size: 16),
            ),
            ButtonSegment(
              value: NotificationScope.proyecto,
              label: const Text('Proyecto'),
              icon: const Icon(Icons.folder_outlined, size: 16),
            ),
            ButtonSegment(
              value: NotificationScope.todos,
              label: const Text('Todos'),
              icon: const Icon(Icons.public, size: 16),
            ),
          ],
          selected: {currentScope},
          onSelectionChanged: (sel) => onChanged(sel.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(theme.textTheme.labelSmall),
          ),
        ),
        if (currentScope != defaultScope)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Default del rol: ${_scopeLabel(defaultScope)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  String _scopeLabel(NotificationScope scope) {
    return switch (scope) {
      NotificationScope.participante => 'Solo propios',
      NotificationScope.proyecto => 'Proyecto',
      NotificationScope.todos => 'Todos',
    };
  }
}
