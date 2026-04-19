import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';
import 'package:astro/core/models/ticket_comment.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/core/utils/ticket_colors.dart';
import 'package:astro/core/services/storage_service.dart';
import 'package:astro/core/presentation/widgets/storage_image.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/core/presentation/screens/file_viewer_screen.dart';
import 'package:astro/core/widgets/resolved_ref_text.dart';

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
  List<XFile> _pendingFiles = [];

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
          onPressed: () => context.pop(),
        ),
        actions: [
          if (canManage || isRoot)
            ticketAsync.whenOrNull(
                  data: (t) => t != null
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar ticket',
                          onPressed: () => context.push(
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
            projectId: widget.projectId,
            canManage: canManage || isRoot,
            isRoot: isRoot,
            systemComments: comments
                .where((c) => c.type != CommentType.comment)
                .toList(),
            onStatusChange: (status) => _changeStatus(ticket, status),
            onArchive: () => _showArchiveDialog(ticket),
            onAssign: canManage || isRoot
                ? () => _showAssignDialog(ticket)
                : null,
          );

          final currentUserId =
              ref.watch(currentUserProfileProvider).value?.uid ?? '';

          final commentsSection = _CommentsSection(
            comments: comments,
            controller: _commentController,
            sending: _sending,
            pendingFiles: _pendingFiles,
            currentUserId: currentUserId,
            onSend: () => _sendComment(ticket.id),
            onPickFiles: _pickFiles,
            onRemoveFile: (i) => setState(() => _pendingFiles.removeAt(i)),
            onDeleteComment: (c) => _deleteComment(ticket.id, c),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                data: (list) => list.map(
                                  (c) => _CommentTile(
                                    comment: c,
                                    currentUserId: currentUserId,
                                    onDelete: () =>
                                        _deleteComment(ticket.id, c),
                                  ),
                                ),
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
                pendingFiles: _pendingFiles,
                onSend: () => _sendComment(ticket.id),
                onPickFiles: _pickFiles,
                onRemoveFile: (i) => setState(() => _pendingFiles.removeAt(i)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changeStatus(Ticket ticket, TicketStatus newStatus) async {
    final repo = ref.read(ticketRepositoryProvider);
    final profile = ref.read(currentUserProfileProvider).value;
    await repo.updateStatus(
      ticket.id,
      newStatus,
      updatedBy: profile?.uid ?? '',
    );

    // Agregar entrada de historial
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

  Future<void> _showArchiveDialog(Ticket ticket) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.inventory_2_outlined,
          color: ticketStatusColor(TicketStatus.archivado),
          size: 32,
        ),
        title: const Text('Archivar ticket'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estás a punto de archivar el ticket "${ticket.folio}".',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Justificación *',
                  hintText: 'Explica por qué se archiva este ticket...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'La justificación es obligatoria';
                  }
                  if (v.trim().length < 10) {
                    return 'Mínimo 10 caracteres';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Archivar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();

    final repo = ref.read(ticketRepositoryProvider);
    final profile = ref.read(currentUserProfileProvider).value;
    final archivedBy = profile?.displayName ?? 'Desconocido';

    await repo.archiveTicket(
      ticket.id,
      reason: reason,
      archivedByName: archivedBy,
      updatedBy: profile?.uid ?? '',
    );

    // Entrada de historial
    if (profile != null) {
      await repo.addComment(
        ticket.id,
        TicketComment(
          id: '',
          text: 'Archivó el ticket. Justificación: "$reason"',
          authorId: profile.uid,
          authorName: profile.displayName,
          type: CommentType.statusChange,
        ),
      );
    }
  }

  Future<void> _sendComment(String ticketId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _pendingFiles.isEmpty) return;

    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) return;

    setState(() => _sending = true);

    try {
      // Subir archivos pendientes
      List<String> adjuntosUrls = [];
      if (_pendingFiles.isNotEmpty) {
        final storage = StorageService();
        for (final file in _pendingFiles) {
          final url = await storage.uploadToPath(
            'comentarios_tickets/$ticketId',
            file,
          );
          adjuntosUrls.add(url);
        }
      }

      await ref
          .read(ticketRepositoryProvider)
          .addComment(
            ticketId,
            TicketComment(
              id: '',
              text: text,
              authorId: profile.uid,
              authorName: profile.displayName,
              adjuntos: adjuntosUrls,
            ),
          );
      _commentController.clear();
      setState(() => _pendingFiles = []);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(String ticketId, TicketComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar comentario'),
        content: const Text(
          '¿Estás seguro de eliminar este comentario? '
          'Se mostrará como "Comentario eliminado".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(ticketRepositoryProvider).deleteComment(comment.id);
  }

  Future<void> _pickFiles() async {
    final totalAllowed = 10 - _pendingFiles.length;
    if (totalAllowed <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo 10 archivos por comentario')),
        );
      }
      return;
    }

    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería de fotos'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Seleccionar archivos'),
              onTap: () => Navigator.pop(ctx, 'files'),
            ),
          ],
        ),
      ),
    );

    if (option == null || !mounted) return;

    List<XFile> picked = [];
    switch (option) {
      case 'camera':
        final img = await ImagePicker().pickImage(source: ImageSource.camera);
        if (img != null) picked = [img];
        break;
      case 'gallery':
        picked = await ImagePicker().pickMultiImage();
        break;
      case 'files':
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.any,
        );
        if (result != null) {
          picked = result.files
              .where((f) => f.path != null)
              .map((f) => XFile(f.path!))
              .toList();
        }
        break;
    }

    if (picked.isEmpty || !mounted) return;

    // Respetar el límite de 10
    final canAdd = 10 - _pendingFiles.length;
    final toAdd = picked.take(canAdd).toList();
    setState(() => _pendingFiles = [..._pendingFiles, ...toAdd]);

    if (picked.length > canAdd) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Solo se agregaron $canAdd de ${picked.length} archivos (máximo 10)',
          ),
        ),
      );
    }
  }

  Future<void> _showAssignDialog(Ticket ticket) async {
    // Obtener usuarios con rol Soporte en este proyecto
    final assignments = ref.read(projectMembersProvider(widget.projectId));

    final soporteMembers = assignments
        .where(
          (m) =>
              m.assignment.role.name == 'soporte' ||
              m.assignment.role.name == 'liderProyecto',
        )
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
              child: Text(
                'No hay usuarios Soporte o Líder Proyecto en este proyecto',
              ),
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
      final profile = ref.read(currentUserProfileProvider).value;
      await repo.assign(
        ticket.id,
        selected.uid,
        selected.name,
        updatedBy: profile?.uid ?? '',
      );

      // Entrada de historial
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
    required this.projectId,
    required this.canManage,
    required this.isRoot,
    required this.systemComments,
    required this.onStatusChange,
    required this.onArchive,
    this.onAssign,
  });

  final Ticket ticket;
  final String projectId;
  final bool canManage;
  final bool isRoot;
  final List<TicketComment> systemComments;
  final ValueChanged<TicketStatus> onStatusChange;
  final VoidCallback onArchive;
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

                // ── Impacto visual ──
                if (ticket.impacto != null) ...[
                  _ImpactIndicator(ticket: ticket),
                  const SizedBox(height: 8),
                ],
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

        // Razón de archivado (si aplica)
        if (ticket.status == TicketStatus.archivado &&
            ticket.archiveReason != null &&
            ticket.archiveReason!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: ticketStatusColor(
              TicketStatus.archivado,
            ).withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: ticketStatusColor(TicketStatus.archivado),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RAZÓN DE ARCHIVADO',
                        style: theme.textTheme.labelLarge?.copyWith(
                          letterSpacing: 1,
                          color: ticketStatusColor(TicketStatus.archivado),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    ticket.archiveReason!,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (ticket.archivedByName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Archivado por: ${ticket.archivedByName}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],

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
                          child: isImg
                              ? StorageImage(
                                  url: url,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(8),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                      title: ResolvedRefText(
                        id: id,
                        type: RefType.minuta,
                        showTitle: true,
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onTap: () =>
                          context.push('/projects/$projectId/minutas/$id'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Citas vinculadas
        if (ticket.refCitas.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CITAS VINCULADAS (${ticket.refCitas.length})',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  ...ticket.refCitas.map(
                    (id) => ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: ResolvedRefText(
                        id: id,
                        type: RefType.cita,
                        showTitle: true,
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onTap: () =>
                          context.push('/projects/$projectId/citas/$id'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Bitácora de movimientos
        _BitacoraCard(entries: systemComments),

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
                        if (s != ticket.status && s != TicketStatus.archivado)
                          OutlinedButton(
                            onPressed: () => onStatusChange(s),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ticketStatusColor(s),
                              side: BorderSide(
                                color: ticketStatusColor(
                                  s,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(s.label),
                          ),
                      // Botón Archivar separado (Root + Soporte)
                      if (ticket.status != TicketStatus.archivado)
                        OutlinedButton.icon(
                          onPressed: onArchive,
                          icon: const Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                          ),
                          label: const Text('Archivar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ticketStatusColor(
                              TicketStatus.archivado,
                            ),
                            side: BorderSide(
                              color: ticketStatusColor(
                                TicketStatus.archivado,
                              ).withValues(alpha: 0.5),
                            ),
                          ),
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

// ── Indicador visual de impacto ──────────────────────────

class _ImpactIndicator extends StatelessWidget {
  const _ImpactIndicator({required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final impacto = ticket.impacto ?? 0;
    final priorityWeight = ticket.priority.penaltyWeight;

    // Calcular penalización de este ticket
    final impactoFactor = impacto / 10.0;
    final avanceFactor = 1.0 - (ticket.porcentajeAvance / 100.0);
    final penalty = priorityWeight * impactoFactor * avanceFactor;

    // Color según nivel de impacto
    final Color impactColor;
    if (impacto <= 3) {
      impactColor = const Color(0xFF4CAF50); // Verde
    } else if (impacto <= 6) {
      impactColor = const Color(0xFFFFC107); // Amarillo
    } else if (impacto <= 9) {
      impactColor = const Color(0xFFFF9800); // Naranja
    } else {
      impactColor = const Color(0xFFF44336); // Rojo
    }

    final isOpen =
        ticket.status != TicketStatus.resuelto &&
        ticket.status != TicketStatus.archivado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, size: 16, color: impactColor),
            const SizedBox(width: 6),
            Text(
              'Impacto: $impacto/10',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: impactColor,
              ),
            ),
            const Spacer(),
            Text(
              impacto <= 3
                  ? 'Bajo'
                  : impacto <= 6
                  ? 'Medio'
                  : impacto <= 9
                  ? 'Alto'
                  : 'Crítico',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: impactColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: impacto / 10.0,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: impactColor,
          ),
        ),
        if (isOpen && penalty > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Penalización al módulo: -${penalty.toStringAsFixed(1)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFFFF5252),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
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
    final color = ticketStatusColor(status);
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
    final color = ticketPriorityColor(priority);
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

// ── Bitácora de Movimientos ──────────────────────────────

class _BitacoraCard extends StatelessWidget {
  const _BitacoraCard({required this.entries});
  final List<TicketComment> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    // Ordenar de más reciente a más antiguo
    final sorted = [...entries]
      ..sort(
        (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
          a.createdAt ?? DateTime(2000),
        ),
      );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 18, color: muted),
                const SizedBox(width: 8),
                Text(
                  'BITÁCORA (${sorted.length})',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: muted,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sin movimientos registrados',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              )
            else
              // Mostrar máximo 10 más recientes, con opción de expandir
              _BitacoraList(entries: sorted),
          ],
        ),
      ),
    );
  }
}

class _BitacoraList extends StatefulWidget {
  const _BitacoraList({required this.entries});
  final List<TicketComment> entries;

  @override
  State<_BitacoraList> createState() => _BitacoraListState();
}

class _BitacoraListState extends State<_BitacoraList> {
  static const _initialLimit = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final entries = widget.entries;
    final visible = _expanded ? entries : entries.take(_initialLimit).toList();

    return Column(
      children: [
        for (final entry in visible) _BitacoraEntry(entry: entry),
        if (entries.length > _initialLimit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _expanded ? 'Ver menos' : 'Ver todos (${entries.length})',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BitacoraEntry extends StatelessWidget {
  const _BitacoraEntry({required this.entry});
  final TicketComment entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final color = _typeColor(entry.type, theme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono de tipo
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(_typeIcon(entry.type), size: 14, color: color),
          ),
          const SizedBox(width: 10),
          // Contenido
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodySmall,
                    children: [
                      TextSpan(
                        text: entry.authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: ' — ${_typeLabel(entry.type)}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.text,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Fecha
          if (entry.createdAt != null)
            Text(
              _formatDateTime(entry.createdAt!),
              style: theme.textTheme.labelSmall?.copyWith(
                color: muted,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  IconData _typeIcon(CommentType type) {
    return switch (type) {
      CommentType.statusChange => Icons.swap_horiz,
      CommentType.assignment => Icons.person_add_outlined,
      CommentType.priorityChange => Icons.flag_outlined,
      CommentType.comment => Icons.chat_bubble_outline,
    };
  }

  Color _typeColor(CommentType type, ThemeData theme) {
    return switch (type) {
      CommentType.statusChange => const Color(0xFF2196F3),
      CommentType.assignment => const Color(0xFF4CAF50),
      CommentType.priorityChange => const Color(0xFFFFC107),
      CommentType.comment => theme.colorScheme.onSurfaceVariant,
    };
  }

  String _typeLabel(CommentType type) {
    return switch (type) {
      CommentType.statusChange => 'Cambio de estado',
      CommentType.assignment => 'Asignación',
      CommentType.priorityChange => 'Cambio de prioridad',
      CommentType.comment => 'Comentario',
    };
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Comments Section ─────────────────────────────────────

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.comments,
    required this.controller,
    required this.sending,
    required this.pendingFiles,
    required this.currentUserId,
    required this.onSend,
    required this.onPickFiles,
    required this.onRemoveFile,
    required this.onDeleteComment,
  });

  final List<TicketComment> comments;
  final TextEditingController controller;
  final bool sending;
  final List<XFile> pendingFiles;
  final String currentUserId;
  final VoidCallback onSend;
  final VoidCallback onPickFiles;
  final ValueChanged<int> onRemoveFile;
  final ValueChanged<TicketComment> onDeleteComment;

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
                  itemBuilder: (context, i) => _CommentTile(
                    comment: comments[i],
                    currentUserId: currentUserId,
                    onDelete: () => onDeleteComment(comments[i]),
                  ),
                ),
        ),
        _CommentInput(
          controller: controller,
          sending: sending,
          pendingFiles: pendingFiles,
          onSend: onSend,
          onPickFiles: onPickFiles,
          onRemoveFile: onRemoveFile,
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    this.currentUserId = '',
    this.onDelete,
  });
  final TicketComment comment;
  final String currentUserId;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSystem = comment.type != CommentType.comment;

    // Comentario eliminado
    if (comment.deleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: [
            Icon(
              Icons.delete_outline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Comentario eliminado',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            if (comment.createdAt != null)
              Text(
                _formatTime(comment.createdAt!),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (isSystem) {
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

    final isOwner = comment.authorId == currentUserId;

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
                if (isOwner && onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Eliminar comentario',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onDelete,
                    color: theme.colorScheme.error,
                  ),
              ],
            ),
            if (comment.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(comment.text, style: theme.textTheme.bodyMedium),
            ],
            // Adjuntos
            if (comment.adjuntos.isNotEmpty) ...[
              const SizedBox(height: 8),
              _CommentAdjuntos(adjuntos: comment.adjuntos),
            ],
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

/// Muestra los adjuntos de un comentario: imágenes como thumbnails, archivos como chips.
class _CommentAdjuntos extends StatelessWidget {
  const _CommentAdjuntos({required this.adjuntos});
  final List<String> adjuntos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final images = <String>[];
    final files = <String>[];

    for (final url in adjuntos) {
      if (_isImage(url)) {
        images.add(url);
      } else {
        files.add(url);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: images
                .map(
                  (url) => GestureDetector(
                    onTap: () => FileViewerScreen.open(context, url: url),
                    child: StorageImage(
                      url: url,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )
                .toList(),
          ),
        if (files.isNotEmpty) ...[
          if (images.isNotEmpty) const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: files
                .map(
                  (url) => ActionChip(
                    avatar: Icon(
                      _fileIcon(url),
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(
                      _fileName(url),
                      style: theme.textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => FileViewerScreen.open(context, url: url),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  bool _isImage(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.gif') ||
        lower.contains('.webp') ||
        lower.contains('.bmp');
  }

  IconData _fileIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.pdf')) return Icons.picture_as_pdf;
    if (lower.contains('.doc') || lower.contains('.docx')) {
      return Icons.description;
    }
    if (lower.contains('.xls') || lower.contains('.xlsx')) {
      return Icons.table_chart;
    }
    if (lower.contains('.mp4') || lower.contains('.mov')) {
      return Icons.videocam;
    }
    if (lower.contains('.mp3') || lower.contains('.wav')) {
      return Icons.audiotrack;
    }
    return Icons.insert_drive_file;
  }

  String _fileName(String url) {
    try {
      final decoded = Uri.decodeFull(url);
      final segments = decoded.split('/');
      final last = segments.last;
      // Quitar query params (?alt=media&token=...)
      final name = last.split('?').first;
      return name.length > 30 ? '${name.substring(0, 27)}...' : name;
    } catch (_) {
      return 'Archivo';
    }
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.sending,
    required this.pendingFiles,
    required this.onSend,
    required this.onPickFiles,
    required this.onRemoveFile,
  });

  final TextEditingController controller;
  final bool sending;
  final List<XFile> pendingFiles;
  final VoidCallback onSend;
  final VoidCallback onPickFiles;
  final ValueChanged<int> onRemoveFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Vista previa de archivos pendientes
          if (pendingFiles.isNotEmpty) ...[
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pendingFiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final file = pendingFiles[i];
                  final isImg = _isImageFile(file.name);
                  return Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: isImg
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  file.path,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Icon(
                                      Icons.image,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.insert_drive_file,
                                      size: 24,
                                      color: theme.colorScheme.primary,
                                    ),
                                    Text(
                                      _ext(file.name),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(fontSize: 9),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: GestureDetector(
                          onTap: () => onRemoveFile(i),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: theme.colorScheme.onError,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Barra de input
          Row(
            children: [
              IconButton(
                tooltip: 'Adjuntar archivo',
                icon: Badge(
                  isLabelVisible: pendingFiles.isNotEmpty,
                  label: Text('${pendingFiles.length}'),
                  child: const Icon(Icons.attach_file),
                ),
                onPressed: sending ? null : onPickFiles,
              ),
              const SizedBox(width: 4),
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
        ],
      ),
    );
  }

  bool _isImageFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  String _ext(String name) {
    final parts = name.split('.');
    return parts.length > 1 ? '.${parts.last}' : '';
  }
}

// ── Color helpers ────────────────────────────────────────
// Use shared helpers from ticket_colors.dart:
// ticketStatusColor() and ticketPriorityColor()
