import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';
import 'package:astro/core/models/ticket_comment.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/core/presentation/screens/file_viewer_screen.dart';

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
                backgroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.08,
                ),
                child: Icon(
                  Icons.confirmation_num_outlined,
                  size: 32,
                  color: theme.colorScheme.onSurface,
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ticket.folio,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
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
                if (ticket.empresaName != null &&
                    ticket.empresaName!.isNotEmpty)
                  _InfoRow(label: 'Empresa', value: ticket.empresaName!),
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

        // Progreso y datos de gestión
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROGRESO Y GESTIÓN',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),

                // Porcentaje de avance
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: ticket.porcentajeAvance / 100,
                            strokeWidth: 5,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            color: progressColor(ticket.porcentajeAvance),
                          ),
                          Text(
                            '${ticket.porcentajeAvance.round()}%',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: progressColor(ticket.porcentajeAvance),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Avance del ticket',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ticket.porcentajeAvance / 100,
                              minHeight: 8,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              color: progressColor(ticket.porcentajeAvance),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (ticket.impacto != null)
                  _InfoRow(label: 'Impacto', value: '${ticket.impacto}/10'),
                if (ticket.cobertura != null && ticket.cobertura!.isNotEmpty)
                  _InfoRow(label: 'Cobertura', value: ticket.cobertura!),
                if (ticket.solucionProgramada != null &&
                    ticket.solucionProgramada!.isNotEmpty)
                  _InfoRow(
                    label: 'Solución programada',
                    value: ticket.solucionProgramada!,
                  ),
                if (ticket.updatedAt != null)
                  _InfoRow(
                    label: 'Última actualización',
                    value: _formatDateTime(ticket.updatedAt!),
                  ),
              ],
            ),
          ),
        ),

        // Evidencias
        if (ticket.evidencias.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EVIDENCIAS (${ticket.evidencias.length})',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ticket.evidencias.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final url = ticket.evidencias[i];
                        final isImg = _isImageUrl(url);
                        return GestureDetector(
                          onTap: () => _showEvidenceDialog(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: isImg
                                ? Image.network(
                                    url,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 120,
                                      height: 120,
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 32,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _fileIcon(url),
                                          size: 32,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            _fileName(url),
                                            style: theme.textTheme.labelSmall,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Minutas vinculadas
        if (ticket.refMinutas.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MINUTAS VINCULADAS (${ticket.refMinutas.length})',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  ...ticket.refMinutas.map(
                    (id) => ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        id.length > 20 ? '${id.substring(0, 20)}...' : id,
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

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

  void _showEvidenceDialog(BuildContext context, String url) {
    FileViewerScreen.open(context, url: url);
  }

  static bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.gif') ||
        lower.contains('.webp');
  }

  static IconData _fileIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.contains('.doc')) return Icons.description_outlined;
    if (lower.contains('.xls')) return Icons.table_chart_outlined;
    if (lower.contains('.mp4') || lower.contains('.mov')) {
      return Icons.videocam_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  static String _fileName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final name = Uri.decodeComponent(segments.last);
        return name.length > 30 ? '${name.substring(0, 30)}...' : name;
      }
    } catch (_) {
      // ignore
    }
    return 'Archivo';
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
                  backgroundColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.08,
                  ),
                  child: Text(
                    _initials(comment.authorName),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
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
            tooltip: 'Enviar comentario',
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
