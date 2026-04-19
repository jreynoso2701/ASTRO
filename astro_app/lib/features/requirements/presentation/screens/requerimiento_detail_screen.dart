import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/requerimiento_status.dart';
import 'package:astro/core/models/requerimiento_fase.dart';
import 'package:astro/core/models/requerimiento_comment.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/core/services/storage_service.dart';
import 'package:astro/core/presentation/widgets/storage_image.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/core/presentation/screens/file_viewer_screen.dart';
import 'package:astro/core/widgets/resolved_ref_text.dart';

/// Pantalla de detalle de un requerimiento.
class RequerimientoDetailScreen extends ConsumerStatefulWidget {
  const RequerimientoDetailScreen({
    required this.projectId,
    required this.reqId,
    super.key,
  });

  final String projectId;
  final String reqId;

  @override
  ConsumerState<RequerimientoDetailScreen> createState() =>
      _RequerimientoDetailScreenState();
}

class _RequerimientoDetailScreenState
    extends ConsumerState<RequerimientoDetailScreen> {
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
    final reqAsync = ref.watch(requerimientoByIdProvider(widget.reqId));
    final commentsAsync = ref.watch(reqCommentsProvider(widget.reqId));
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final canManage = ref.watch(canManageProjectProvider(widget.projectId));
    final isManager = canManage || isRoot;
    final canArchive = ref.watch(canArchiveReqProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('REQUERIMIENTO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isManager)
            reqAsync.whenOrNull(
                  data: (r) => r != null
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar',
                          onPressed: () => context.push(
                            '/projects/${widget.projectId}/requirements/${widget.reqId}/edit',
                          ),
                        )
                      : null,
                ) ??
                const SizedBox.shrink(),
        ],
      ),
      body: reqAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (req) {
          if (req == null) {
            return const Center(child: Text('Requerimiento no encontrado'));
          }

          final comments = commentsAsync.value ?? [];
          final width = MediaQuery.sizeOf(context).width;
          final isWide = width >= AppBreakpoints.medium;

          final infoSection = _InfoSection(
            req: req,
            projectId: widget.projectId,
            isRoot: isRoot,
            isManager: isManager,
            onStatusChange: (s) => _changeStatus(req, s),
            onFaseChange: isRoot ? (f) => _changeFase(req, f) : null,
            onAssign: isManager ? () => _showAssignDialog(req) : null,
            onToggleCriterio: isManager
                ? (criterio) => _toggleCriterio(req, criterio)
                : null,
            canArchive: canArchive,
            onArchive: canArchive ? () => _archiveReq(req) : null,
            onDelete: canArchive ? () => _deleteReq(req) : null,
          );

          final currentUserId =
              ref.watch(currentUserProfileProvider).value?.uid ?? '';

          final commentsSection = _CommentsSection(
            comments: comments,
            controller: _commentController,
            sending: _sending,
            pendingFiles: _pendingFiles,
            currentUserId: currentUserId,
            onSend: () => _sendComment(req.id),
            onPickFiles: _pickFiles,
            onRemoveFile: (i) => setState(() => _pendingFiles.removeAt(i)),
            onDeleteComment: (c) => _deleteComment(req.id, c),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 420,
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
                      ...comments.map(
                        (c) => _CommentTile(
                          comment: c,
                          currentUserId: currentUserId,
                          onDelete: () => _deleteComment(req.id, c),
                        ),
                      ),
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
              _CommentInput(
                controller: _commentController,
                sending: _sending,
                pendingFiles: _pendingFiles,
                onSend: () => _sendComment(req.id),
                onPickFiles: _pickFiles,
                onRemoveFile: (i) => setState(() => _pendingFiles.removeAt(i)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Acciones ───────────────────────────────────────────

  Future<void> _changeStatus(
    Requerimiento req,
    RequerimientoStatus newStatus,
  ) async {
    // Statuses que requieren fecha compromiso
    const requiresFecha = {
      RequerimientoStatus.enDesarrollo,
      RequerimientoStatus.implementado,
      RequerimientoStatus.completado,
    };

    // Si descartado → pedir motivo
    if (newStatus == RequerimientoStatus.descartado) {
      final motivo = await _askMotivo(newStatus.label);
      if (motivo == null) return;
      final repo = ref.read(requerimientoRepositoryProvider);
      final profile = ref.read(currentUserProfileProvider).value;
      await repo.update(
        req.copyWith(status: newStatus, motivoRechazo: motivo),
        updatedBy: profile?.uid ?? '',
      );
    } else if (requiresFecha.contains(newStatus) &&
        req.fechaCompromiso == null) {
      // Pedir fecha compromiso solo si aún no tiene una
      final fecha = await _askFechaCompromiso(null);
      if (fecha == null) return;
      final profile = ref.read(currentUserProfileProvider).value;
      await ref
          .read(requerimientoRepositoryProvider)
          .updateStatus(
            req.id,
            newStatus,
            updatedBy: profile?.uid ?? '',
            fechaCompromiso: fecha,
          );
    } else if (requiresFecha.contains(newStatus)) {
      // Ya tiene fecha compromiso, solo cambiar estado
      final profile = ref.read(currentUserProfileProvider).value;
      await ref
          .read(requerimientoRepositoryProvider)
          .updateStatus(req.id, newStatus, updatedBy: profile?.uid ?? '');
    } else {
      final profile = ref.read(currentUserProfileProvider).value;
      await ref
          .read(requerimientoRepositoryProvider)
          .updateStatus(req.id, newStatus, updatedBy: profile?.uid ?? '');
    }

    // Si pasa a completado, marcar todos los criterios de aceptación
    if (newStatus == RequerimientoStatus.completado &&
        req.criteriosAceptacion.isNotEmpty) {
      final allChecked = req.criteriosAceptacion
          .map((c) => c.copyWith(completado: true))
          .toList();
      await ref
          .read(requerimientoRepositoryProvider)
          .updateCriterios(req.id, allChecked);
    }

    // Historial
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile != null) {
      await ref
          .read(requerimientoRepositoryProvider)
          .addComment(
            req.id,
            RequerimientoComment(
              id: '',
              text:
                  'Cambió estado de "${req.status.label}" a "${newStatus.label}"',
              authorId: profile.uid,
              authorName: profile.displayName,
              type: ReqCommentType.statusChange,
            ),
          );
    }
  }

  Future<void> _changeFase(Requerimiento req, RequerimientoFase fase) async {
    final profile = ref.read(currentUserProfileProvider).value;
    await ref
        .read(requerimientoRepositoryProvider)
        .update(
          req.copyWith(faseAsignada: fase),
          updatedBy: profile?.uid ?? '',
        );
  }

  Future<void> _toggleCriterio(
    Requerimiento req,
    CriterioAceptacion criterio,
  ) async {
    final updated = req.criteriosAceptacion.map((c) {
      if (c.id == criterio.id) return c.copyWith(completado: !c.completado);
      return c;
    }).toList();
    await ref
        .read(requerimientoRepositoryProvider)
        .updateCriterios(req.id, updated);
  }

  Future<void> _sendComment(String reqId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _pendingFiles.isEmpty) return;

    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) return;

    setState(() => _sending = true);

    try {
      List<String> adjuntosUrls = [];
      if (_pendingFiles.isNotEmpty) {
        final storage = StorageService();
        for (final file in _pendingFiles) {
          final url = await storage.uploadToPath(
            'comentarios_requerimientos/$reqId',
            file,
          );
          adjuntosUrls.add(url);
        }
      }

      await ref
          .read(requerimientoRepositoryProvider)
          .addComment(
            reqId,
            RequerimientoComment(
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

  Future<void> _deleteComment(
    String reqId,
    RequerimientoComment comment,
  ) async {
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
    await ref.read(requerimientoRepositoryProvider).deleteComment(comment.id);
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

  Future<void> _showAssignDialog(Requerimiento req) async {
    final members = ref.read(projectMembersProvider(widget.projectId));
    if (!mounted) return;

    final selected = await showDialog<({String uid, String name})>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Asignar responsable'),
        children: [
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay miembros en este proyecto'),
            ),
          for (final m in members)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, (
                uid: m.assignment.userId,
                name: m.user?.displayName ?? m.assignment.userId,
              )),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text((m.user?.displayName ?? '?')[0].toUpperCase()),
                ),
                title: Text(m.user?.displayName ?? m.assignment.userId),
                subtitle: Text(
                  '${m.assignment.role.label} — ${m.user?.email ?? ''}',
                ),
              ),
            ),
        ],
      ),
    );

    if (selected != null) {
      final repo = ref.read(requerimientoRepositoryProvider);
      final profile = ref.read(currentUserProfileProvider).value;
      await repo.assign(
        req.id,
        selected.uid,
        selected.name,
        updatedBy: profile?.uid ?? '',
      );

      if (profile != null) {
        await repo.addComment(
          req.id,
          RequerimientoComment(
            id: '',
            text: 'Asignó responsable: "${selected.name}"',
            authorId: profile.uid,
            authorName: profile.displayName,
            type: ReqCommentType.assignment,
          ),
        );
      }
    }
  }

  Future<void> _archiveReq(Requerimiento req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivar requerimiento'),
        content: Text(
          '¿Archivar "${req.titulo}"? Podrás desarchivarlo después.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(requerimientoRepositoryProvider).deactivate(req.id);
    if (mounted) context.pop();
  }

  Future<void> _deleteReq(Requerimiento req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar requerimiento'),
        content: Text(
          '¿Eliminar permanentemente "${req.titulo}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(requerimientoRepositoryProvider).delete(req.id);
    if (mounted) context.pop();
  }

  Future<String?> _askMotivo(String accion) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Motivo de "$accion"'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Ingresa el motivo...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  /// Muestra un DatePicker para seleccionar la fecha compromiso.
  Future<DateTime?> _askFechaCompromiso(DateTime? current) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      helpText: 'Fecha compromiso',
    );
  }
}

// ── Info Section ─────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.req,
    required this.projectId,
    required this.isRoot,
    required this.isManager,
    required this.onStatusChange,
    this.canArchive = false,
    this.onFaseChange,
    this.onAssign,
    this.onToggleCriterio,
    this.onArchive,
    this.onDelete,
  });

  final Requerimiento req;
  final String projectId;
  final bool isRoot;
  final bool isManager;
  final bool canArchive;
  final ValueChanged<RequerimientoStatus> onStatusChange;
  final ValueChanged<RequerimientoFase>? onFaseChange;
  final VoidCallback? onAssign;
  final ValueChanged<CriterioAceptacion>? onToggleCriterio;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final pct = req.porcentajeCalculado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folio + Estado
        Row(
          children: [
            Expanded(
              child: Text(
                req.folio,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ),
            _StatusBadge(status: req.status),
          ],
        ),
        const SizedBox(height: 8),

        // Título
        Text(
          req.titulo,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Descripción
        Text(req.descripcion, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),

        // Info cards
        _DetailRow(label: 'Tipo', value: req.tipo.label),
        _DetailRow(label: 'Prioridad', value: req.prioridad.label),
        if (req.moduleName != null && req.moduleName!.isNotEmpty)
          _DetailRow(label: 'Módulo', value: req.moduleName!),
        if (req.moduloPropuesto != null && req.moduloPropuesto!.isNotEmpty)
          _DetailRow(label: 'Módulo propuesto', value: req.moduloPropuesto!),
        if (req.empresaName != null && req.empresaName!.isNotEmpty)
          _DetailRow(label: 'Empresa', value: req.empresaName!),
        _DetailRow(label: 'Solicitó', value: req.createdByName),
        _DetailRow(
          label: 'Responsable',
          value: req.assignedToName ?? 'Sin asignar',
        ),
        if (req.faseAsignada != null)
          _DetailRow(label: 'Fase asignada', value: req.faseAsignada!.label),
        _DetailRow(label: 'Creado', value: _formatDate(req.createdAt)),
        _DetailRow(label: 'Actualizado', value: _formatDate(req.updatedAt)),
        if (req.fechaCompromiso != null)
          _DetailRow(
            label: 'Fecha compromiso',
            value: _formatDate(req.fechaCompromiso),
          ),

        const SizedBox(height: 16),

        // Progreso
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Progreso',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${pct.toInt()}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: progressColor(pct),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: pct / 100,
                  backgroundColor: muted.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(progressColor(pct)),
                ),
                if (req.porcentajeManual)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Ajustado manualmente',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Criterios de Aceptación
        if (req.criteriosAceptacion.isNotEmpty) ...[
          Text(
            'CRITERIOS DE ACEPTACIÓN',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final criterio in req.criteriosAceptacion)
                  CheckboxListTile(
                    value: criterio.completado,
                    title: Text(
                      criterio.texto,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: criterio.completado
                            ? TextDecoration.lineThrough
                            : null,
                        color: criterio.completado ? muted : null,
                      ),
                    ),
                    onChanged: onToggleCriterio != null
                        ? (_) => onToggleCriterio!(criterio)
                        : null,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Participantes
        if (req.participantes.isNotEmpty) ...[
          Text(
            'PARTICIPANTES',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final p in req.participantes)
                Chip(
                  avatar: CircleAvatar(child: Text(p.nombre[0].toUpperCase())),
                  label: Text(
                    p.rol != null ? '${p.nombre} (${p.rol})' : p.nombre,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Adjuntos
        if (req.adjuntos.isNotEmpty) ...[
          Text(
            'ADJUNTOS',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final url in req.adjuntos) _AdjuntoChip(url: url)],
          ),
          const SizedBox(height: 16),
        ],

        // Minutas vinculadas
        if (req.refMinutas.isNotEmpty) ...[
          Text(
            'MINUTAS VINCULADAS (${req.refMinutas.length})',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: req.refMinutas
                    .map(
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
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Observaciones Root (solo visible para Root/Soporte)
        if (isManager &&
            req.observacionesRoot != null &&
            req.observacionesRoot!.isNotEmpty) ...[
          Text(
            'OBSERVACIONES (INTERNO)',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                req.observacionesRoot!,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Motivo de descarte
        if (req.motivoRechazo != null && req.motivoRechazo!.isNotEmpty) ...[
          Text(
            'MOTIVO DE DESCARTE',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                req.motivoRechazo!,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        const Divider(),

        // Acciones de estado (Root / Supervisor: completas; Soporte: limitadas)
        if (canArchive) ...[
          Text(
            'ACCIONES',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildStatusActions(req.status),
          ),
          const SizedBox(height: 8),
        ] else if (isManager && !canArchive) ...[
          Text(
            'ACCIONES',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildSoporteActions(req.status),
          ),
          const SizedBox(height: 8),
        ],

        // Asignar responsable
        if (onAssign != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAssign,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Asignar responsable'),
            ),
          ),
        ],

        // Archivar / Eliminar  (Root / Supervisor — cualquier estado)
        if (onArchive != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onArchive,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archivar'),
            ),
          ),
        ],
        if (onDelete != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              label: Text(
                'Eliminar',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ],

        // Asignar fase (solo Root, enDesarrollo)
        if (onFaseChange != null &&
            req.status == RequerimientoStatus.enDesarrollo) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onFaseChange!(RequerimientoFase.faseActual),
                  child: const Text('Fase Actual'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onFaseChange!(RequerimientoFase.proximaFase),
                  child: const Text('Próxima Fase'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Acciones disponibles para Root según el estado actual.
  List<Widget> _buildStatusActions(RequerimientoStatus current) {
    final actions = <Widget>[];

    void add(RequerimientoStatus target, {Color? color}) {
      actions.add(
        ActionChip(
          label: Text(target.label),
          avatar: Icon(
            _statusIcon(target),
            size: 18,
            color: color ?? _statusColor(target),
          ),
          onPressed: () => onStatusChange(target),
        ),
      );
    }

    // No-lineal: Root/Supervisor puede ir a cualquier estado.
    for (final s in RequerimientoStatus.values) {
      if (s == current) continue;
      add(
        s,
        color: s == RequerimientoStatus.descartado
            ? const Color(0xFFEF5350)
            : null,
      );
    }

    return actions;
  }

  /// Acciones para Soporte (no puede descartar, archivar, eliminar).
  List<Widget> _buildSoporteActions(RequerimientoStatus current) {
    final actions = <Widget>[];

    void add(RequerimientoStatus target) {
      actions.add(
        ActionChip(
          label: Text(target.label),
          avatar: Icon(_statusIcon(target), size: 18),
          onPressed: () => onStatusChange(target),
        ),
      );
    }

    // No-lineal: Soporte puede ir a cualquier estado excepto Descartado.
    for (final s in RequerimientoStatus.values) {
      if (s == current || s == RequerimientoStatus.descartado) continue;
      add(s);
    }

    return actions;
  }
}

// ── Status helpers ───────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final RequerimientoStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Color _statusColor(RequerimientoStatus status) => switch (status) {
  RequerimientoStatus.propuesto => const Color(0xFF90A4AE),
  RequerimientoStatus.enRevision => const Color(0xFF42A5F5),
  RequerimientoStatus.enDesarrollo => const Color(0xFFFFC107),
  RequerimientoStatus.implementado => const Color(0xFF4CAF50),
  RequerimientoStatus.completado => const Color(0xFF388E3C),
  RequerimientoStatus.descartado => const Color(0xFFEF5350),
};

IconData _statusIcon(RequerimientoStatus status) => switch (status) {
  RequerimientoStatus.propuesto => Icons.fiber_new,
  RequerimientoStatus.enRevision => Icons.visibility,
  RequerimientoStatus.enDesarrollo => Icons.code,
  RequerimientoStatus.implementado => Icons.done_all,
  RequerimientoStatus.completado => Icons.check_circle,
  RequerimientoStatus.descartado => Icons.cancel_outlined,
};

// ── Detail Row ───────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Adjunto Chip ─────────────────────────────────────────

class _AdjuntoChip extends StatelessWidget {
  const _AdjuntoChip({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final isImage =
        url.contains('.jpg') ||
        url.contains('.jpeg') ||
        url.contains('.png') ||
        url.contains('.gif') ||
        url.contains('.webp');

    return ActionChip(
      avatar: Icon(
        isImage ? Icons.image_outlined : Icons.attach_file,
        size: 18,
      ),
      label: Text(
        isImage ? 'Imagen' : 'Archivo',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onPressed: () {
        FileViewerScreen.open(context, url: url);
      },
    );
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

  final List<RequerimientoComment> comments;
  final TextEditingController controller;
  final bool sending;
  final List<XFile> pendingFiles;
  final String currentUserId;
  final VoidCallback onSend;
  final VoidCallback onPickFiles;
  final ValueChanged<int> onRemoveFile;
  final ValueChanged<RequerimientoComment> onDeleteComment;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'HISTORIAL',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${comments.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lista
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: comments.length,
                  itemBuilder: (context, index) => _CommentTile(
                    comment: comments[index],
                    currentUserId: currentUserId,
                    onDelete: () => onDeleteComment(comments[index]),
                  ),
                ),
        ),

        // Input
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
  final RequerimientoComment comment;
  final String currentUserId;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSystem = comment.type != ReqCommentType.comment;

    // Comentario eliminado
    if (comment.deleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.delete_outline,
              size: 14,
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
                _formatDateTime(comment.createdAt!),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                comment.text,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            if (comment.createdAt != null)
              Text(
                _formatDateTime(comment.createdAt!),
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
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  child: Text(
                    comment.authorName.isNotEmpty
                        ? comment.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comment.authorName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (comment.createdAt != null)
                  Text(
                    _formatDateTime(comment.createdAt!),
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
              const SizedBox(height: 6),
              Text(comment.text, style: theme.textTheme.bodyMedium),
            ],
            // Adjuntos
            if (comment.adjuntos.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ReqCommentAdjuntos(adjuntos: comment.adjuntos),
            ],
          ],
        ),
      ),
    );
  }
}

/// Muestra los adjuntos de un comentario de requerimiento.
class _ReqCommentAdjuntos extends StatelessWidget {
  const _ReqCommentAdjuntos({required this.adjuntos});
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
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
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
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                ),
              ),
              IconButton(
                tooltip: 'Enviar comentario',
                icon: sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                onPressed: sending ? null : onSend,
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

// ── Helpers ──────────────────────────────────────────────

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.day}/${date.month}/${date.year}';
}

String _formatDateTime(DateTime date) {
  return '${date.day}/${date.month}/${date.year} '
      '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}
