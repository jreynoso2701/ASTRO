import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';

/// Pantalla de lista de chats (comentarios de tickets) agrupada por proyecto.
/// Se muestra como el tab "CHATS" dentro del Dashboard.
class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key});

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projects = ref.watch(myProjectsProvider);
    final uid = ref.watch(authStateProvider).value?.uid ?? '';

    final ticketsAsync = ref.watch(ticketsWithCommentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar chats...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
        ),

        ticketsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Error: $e')),
          ),
          data: (tickets) {
            final filtered = _search.isEmpty
                ? tickets
                : tickets.where((t) {
                    return t.titulo.toLowerCase().contains(_search) ||
                        t.folio.toLowerCase().contains(_search) ||
                        t.projectName.toLowerCase().contains(_search) ||
                        (t.lastCommentPreview?.toLowerCase().contains(_search) ?? false);
                  }).toList();

            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _search.isEmpty
                            ? 'Aún no hay conversaciones\nen tus tickets'
                            : 'Sin resultados para "$_search"',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (_search.isNotEmpty) {
              return Column(
                children: [
                  const Divider(height: 1),
                  ...filtered.map(
                    (t) => _ChatListTile(ticket: t, uid: uid, showProjectBadge: true),
                  ),
                ],
              );
            }

            // Grouped by project
            final grouped = _groupByProject(filtered, projects);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final group in grouped) ...[
                  _ProjectChatHeader(projectName: group.projectName, color: group.color),
                  ...group.tickets.map(
                    (t) => _ChatListTile(ticket: t, uid: uid, showProjectBadge: false),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ],
    );
  }

  List<_ProjectGroup> _groupByProject(
    List<Ticket> tickets,
    List<dynamic> projects,
  ) {
    final map = <String, List<Ticket>>{};
    for (final t in tickets) {
      map.putIfAbsent(t.projectName, () => []).add(t);
    }

    final groups = map.entries.map((e) {
      final color = _projectColor(e.key);
      // Find project id for navigation
      final proj = projects.where((p) => p.nombreProyecto == e.key || p.id == e.value.first.projectId).firstOrNull;
      final projectId = e.value.first.projectId ?? proj?.id ?? '';
      return _ProjectGroup(
        projectName: e.key,
        projectId: projectId,
        color: color,
        tickets: e.value,
        latestActivity: e.value.first.lastCommentAt ?? DateTime(2000),
      );
    }).toList();

    // Sort groups by most recent activity
    groups.sort((a, b) => b.latestActivity.compareTo(a.latestActivity));
    return groups;
  }

  static Color _projectColor(String name) {
    const palette = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFF14B8A6),
      Color(0xFFF97316),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
    ];
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }
}

class _ProjectGroup {
  const _ProjectGroup({
    required this.projectName,
    required this.projectId,
    required this.color,
    required this.tickets,
    required this.latestActivity,
  });
  final String projectName;
  final String projectId;
  final Color color;
  final List<Ticket> tickets;
  final DateTime latestActivity;
}

// ── Widgets ───────────────────────────────────────────────

class _ProjectChatHeader extends StatelessWidget {
  const _ProjectChatHeader({required this.projectName, required this.color});
  final String projectName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            projectName.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatListTile extends ConsumerWidget {
  const _ChatListTile({
    required this.ticket,
    required this.uid,
    required this.showProjectBadge,
  });

  final Ticket ticket;
  final String uid;
  final bool showProjectBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Watch last read for this ticket
    final chatReadAsync = uid.isNotEmpty
        ? ref.watch(chatReadProvider((uid: uid, ticketId: ticket.id)))
        : const AsyncData<DateTime?>(null);
    final lastRead = chatReadAsync.value;
    final lastCommentAt = ticket.lastCommentAt;
    final hasUnread = lastCommentAt != null &&
        ticket.lastCommentAuthorId != uid &&
        (lastRead == null || lastCommentAt.isAfter(lastRead));

    final timeAgo = lastCommentAt != null ? _timeAgo(lastCommentAt) : '';
    final preview = ticket.lastCommentPreview ?? '';

    return InkWell(
      onTap: () {
        if (ticket.projectId != null) {
          context.push('/projects/${ticket.projectId}/tickets/${ticket.id}/chat');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status dot
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: _statusColor(ticket.status).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: _statusColor(ticket.status),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#${ticket.folio} · ${ticket.titulo}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: hasUnread
                              ? primary
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  if (showProjectBadge) ...[
                    const SizedBox(height: 2),
                    Text(
                      ticket.projectName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview.isNotEmpty ? '"$preview"' : 'Sin mensajes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(TicketStatus status) {
    return switch (status) {
      TicketStatus.pendiente => const Color(0xFF6366F1),
      TicketStatus.enDesarrollo => const Color(0xFFF59E0B),
      TicketStatus.pruebasInternas => const Color(0xFF3B82F6),
      TicketStatus.pruebasCliente => const Color(0xFF8B5CF6),
      TicketStatus.bugs => const Color(0xFFEF4444),
      TicketStatus.resuelto => const Color(0xFF10B981),
      TicketStatus.archivado => const Color(0xFF6B7280),
    };
  }

  static String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('dd/MM').format(date);
  }
}
