import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';
import 'package:astro/core/models/ticket_comment.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de detalle de un ticket con hilo de comentarios.
class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({
    required this.projectId,
    required this.ticketId,
    super.key,
  });

  final String projectId;
  final String ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(ticketByIdProvider(widget.ticketId));
    final commentsAsync = ref.watch(ticketCommentsProvider(widget.ticketId));
    final canManage = ref.watch(canManageProjectProvider(widget.projectId));
    final isRoot = ref.watch(isCurrentUserRootProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TICKET'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/projects/${widget.projectId}/tickets'),
        ),
        actions: [
          if (canManage || isRoot)
            ticketAsync.whenOrNull(
                  data: (t) => t != null
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar ticket',
                          onPressed: () => context.go(
                            '/projects/${widget.projectId}/tickets/${widget.ticketId}/edit',
                          ),
                        )
                      : null,
                ) ??
                const SizedBox.shrink(),
        ],
      ),
      body: ticketAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ticket) {
          if (ticket == null) {
            return const Center(child: Text('Ticket no encontrado'));
          }

          final comments = commentsAsync.value ?? [];
          final width = MediaQuery.sizeOf(context).width;
          final isWide = width >= AppBreakpoints.medium;

          final infoSection = _TicketInfoSection(
            ticket: ticket,
            canManage: canManage || isRoot,
            onStatusChange: (status) => _changeStatus(ticket, status),
            onAssign: canManage || isRoot
                ? () => _showAssignDialog(ticket)
                : null,
          );

          final commentsSection = _CommentsSection(
            comments: comments,
            controller: _commentController,
            sending: _sending,
            onSend: () => _sendComment(ticket.id),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: infoSection,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: commentsSection),
              ],
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      infoSection,
                      const SizedBox(height: 16),
                      Text(
                        'COMENTARIOS',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          letterSpacing: 1,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Divider(),
                      ...commentsAsync
                              .whenOrNull(
                                data: (list) =>
                                    list.map((c) => _CommentTile(comment: c)),
                              )
                              ?.toList() ??
                          [],
                      if (comments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Sin comentarios aún',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Input de comentario
              _CommentInput(
                controller: _commentController,
                sending: _sending,
                onSend: () => _sendComment(ticket.id),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changeStatus(Ticket ticket, TicketStatus newStatus) async {
    final repo = ref.read(ticketRepositoryProvider);
    await repo.updateStatus(ticket.id, newStatus);

    // Agregar entrada de historial
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile != null) {
      await repo.addComment(
        ticket.id,
        TicketComment(
          id: '',
          text:
              'Cambió estado de "${ticket.status.label}" a "${newStatus.label}"',
          authorId: profile.uid,
          authorName: profile.displayName,
          type: CommentType.statusChange,
        ),
      );
    }
  }

  Future<void> _sendComment(String ticketId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) return;

    setState(() => _sending = true);

    try {
      await ref
          .read(ticketRepositoryProvider)
          .addComment(
            ticketId,
            TicketComment(
              id: '',
              text: text,
              authorId: profile.uid,
              authorName: profile.displayName,
            ),
          );
      _commentController.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showAssignDialog(Ticket ticket) async {
    // Obtener usuarios con rol Soporte en este proyecto
    final assignments = ref.read(projectMembersProvider(widget.projectId));

    final soporteMembers = assignments
        .where((m) => m.assignment.role.name == 'soporte')
        .toList();

    if (!mounted) return;

    final selected = await showDialog<({String uid, String name})>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Asignar a Soporte'),
        children: [
          if (soporteMembers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay usuarios Soporte en este proyecto'),
            ),
          for (final m in soporteMembers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, (
                uid: m.assignment.userId,
                name: m.user?.displayName ?? m.assignment.userId,
              )),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.support_agent)),
                title: Text(m.user?.displayName ?? m.assignment.userId),
                subtitle: Text(m.user?.email ?? ''),
              ),
            ),
        ],
      ),
    );

    if (selected != null) {
      final repo = ref.read(ticketRepositoryProvider);
      await repo.assign(ticket.id, selected.uid, selected.name);

      // Entrada de historial
      final profile = ref.read(currentUserProfileProvider).value;
      if (profile != null) {
        await repo.addComment(
          ticket.id,
          TicketComment(
            id: '',
            text: 'Asignó ticket a "${selected.name}"',
            authorId: profile.uid,
            authorName: profile.displayName,
            type: CommentType.assignment,
          ),
        );
      }
    }
  }
}

// ── Info Section ─────────────────────────────────────────

class _TicketInfoSection extends StatelessWidget {
  const _TicketInfoSection({
    required this.ticket,
    required this.canManage,
    required this.onStatusChange,
    this.onAssign,
  });

  final Ticket ticket;
  final bool canManage;
  final ValueChanged<TicketStatus> onStatusChange;
  final VoidCallback? onAssign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(
                  0xFFD71921,
                ).withValues(alpha: 0.15),
                child: Icon(
                  Icons.confirmation_num_outlined,
                  size: 32,
                  color: const Color(0xFFD71921),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ticket.titulo,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD71921).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ticket.folio,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFFD71921),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INFORMACIÓN',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),
                _InfoRow(label: 'Proyecto', value: ticket.projectName),
                _InfoRow(label: 'Módulo', value: ticket.moduleName),
                _InfoRow(label: 'Creado por', value: ticket.createdByName),
                _InfoRow(
                  label: 'Asignado a',
                  value: ticket.assignedToName ?? 'Sin asignar',
                ),
                if (ticket.createdAt != null)
                  _InfoRow(
                    label: 'Fecha',
                    value: _formatDateTime(ticket.createdAt!),
                  ),
                if (ticket.descripcion.isNotEmpty)
                  _InfoRow(label: 'Descripción', value: ticket.descripcion),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Estado + Prioridad
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESTADO Y PRIORIDAD',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    _StatusChip(status: ticket.status),
                    const SizedBox(width: 8),
                    _PriorityChip(priority: ticket.priority),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Acciones
        if (canManage) ...[
          // Cambiar estado
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACCIONES',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in TicketStatus.values)
                        if (s != ticket.status)
                          OutlinedButton(
                            onPressed: () => onStatusChange(s),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _statusColor(s),
                              side: BorderSide(
                                color: _statusColor(s).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(s.label),
                          ),
                    ],
                  ),
                  if (onAssign != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onAssign,
                        icon: const Icon(Icons.support_agent),
                        label: const Text('Asignar a Soporte'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// ── Badges ───────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Chip(
      label: Text(status.label),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});
  final TicketPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);
    return Chip(
      label: Text(priority.label),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }
}

// ── Comments Section ─────────────────────────────────────

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.comments,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final List<TicketComment> comments;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'COMENTARIOS (${comments.length})',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: comments.isEmpty
              ? Center(
                  child: Text(
                    'Sin comentarios aún',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: comments.length,
                  itemBuilder: (context, i) =>
                      _CommentTile(comment: comments[i]),
                ),
        ),
        _CommentInput(controller: controller, sending: sending, onSend: onSend),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final TicketComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSystem = comment.type != CommentType.comment;

    if (isSystem) {
      // Entrada de historial (cambio de estado, asignación, etc.)
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: [
            Icon(
              _systemIcon(comment.type),
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  children: [
                    TextSpan(
                      text: comment.authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' ${comment.text}'),
                  ],
                ),
              ),
            ),
            if (comment.createdAt != null)
              Text(
                _formatTime(comment.createdAt!),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(
                    0xFFD71921,
                  ).withValues(alpha: 0.15),
                  child: Text(
                    _initials(comment.authorName),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFD71921),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comment.authorName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (comment.createdAt != null)
                  Text(
                    _formatTime(comment.createdAt!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(comment.text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  IconData _systemIcon(CommentType type) {
    return switch (type) {
      CommentType.statusChange => Icons.swap_horiz,
      CommentType.assignment => Icons.person_add_outlined,
      CommentType.priorityChange => Icons.flag_outlined,
      CommentType.comment => Icons.chat_bubble_outline,
    };
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0];
    return '?';
  }

  String _formatTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Escribe un comentario...',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

// ── Color helpers ────────────────────────────────────────

Color _statusColor(TicketStatus status) {
  return switch (status) {
    TicketStatus.abierto => const Color(0xFF2196F3),
    TicketStatus.enProgreso => const Color(0xFFFFC107),
    TicketStatus.resuelto => const Color(0xFF4CAF50),
    TicketStatus.cerrado => Colors.grey,
  };
}

Color _priorityColor(TicketPriority priority) {
  return switch (priority) {
    TicketPriority.baja => const Color(0xFF4CAF50),
    TicketPriority.media => const Color(0xFF2196F3),
    TicketPriority.alta => const Color(0xFFFFC107),
    TicketPriority.critica => const Color(0xFFD71921),
  };
}
