import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/requerimiento_status.dart';
import 'package:astro/core/models/requerimiento_fase.dart';
import 'package:astro/core/models/requerimiento_comment.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/utils/progress_color.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/core/presentation/screens/file_viewer_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('REQUERIMIENTO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.go('/projects/${widget.projectId}/requirements'),
        ),
        actions: [
          if (isManager)
            reqAsync.whenOrNull(
                  data: (r) => r != null
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar',
                          onPressed: () => context.go(
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
            isRoot: isRoot,
            isManager: isManager,
            onStatusChange: (s) => _changeStatus(req, s),
            onFaseChange: isRoot ? (f) => _changeFase(req, f) : null,
            onAssign: isManager ? () => _showAssignDialog(req) : null,
            onToggleCriterio: isManager
                ? (criterio) => _toggleCriterio(req, criterio)
                : null,
          );

          final commentsSection = _CommentsSection(
            comments: comments,
            controller: _commentController,
            sending: _sending,
            onSend: () => _sendComment(req.id),
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
                      ...comments.map((c) => _CommentTile(comment: c)),
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
                onSend: () => _sendComment(req.id),
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
    // Si rechazado/diferido → pedir motivo
    if (newStatus == RequerimientoStatus.rechazado ||
        newStatus == RequerimientoStatus.diferido) {
      final motivo = await _askMotivo(newStatus.label);
      if (motivo == null) return;
      final repo = ref.read(requerimientoRepositoryProvider);
      await repo.update(req.copyWith(status: newStatus, motivoRechazo: motivo));
    } else {
      await ref
          .read(requerimientoRepositoryProvider)
          .updateStatus(req.id, newStatus);
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
    await ref
        .read(requerimientoRepositoryProvider)
        .update(req.copyWith(faseAsignada: fase));
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
    if (text.isEmpty) return;

    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) return;

    setState(() => _sending = true);

    try {
      await ref
          .read(requerimientoRepositoryProvider)
          .addComment(
            reqId,
            RequerimientoComment(
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
      await repo.assign(req.id, selected.uid, selected.name);

      final profile = ref.read(currentUserProfileProvider).value;
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
}

// ── Info Section ─────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.req,
    required this.isRoot,
    required this.isManager,
    required this.onStatusChange,
    this.onFaseChange,
    this.onAssign,
    this.onToggleCriterio,
  });

  final Requerimiento req;
  final bool isRoot;
  final bool isManager;
  final ValueChanged<RequerimientoStatus> onStatusChange;
  final ValueChanged<RequerimientoFase>? onFaseChange;
  final VoidCallback? onAssign;
  final ValueChanged<CriterioAceptacion>? onToggleCriterio;

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

        // Motivo de rechazo
        if (req.motivoRechazo != null && req.motivoRechazo!.isNotEmpty) ...[
          Text(
            'MOTIVO DE ${req.status == RequerimientoStatus.diferido ? "DIFERIMIENTO" : "RECHAZO"}',
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

        // Acciones de estado
        if (isRoot) ...[
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
        ] else if (isManager) ...[
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

        // Asignar fase (solo Root, solo para aprobados sin fase)
        if (onFaseChange != null &&
            (req.status == RequerimientoStatus.aprobado ||
                req.status == RequerimientoStatus.enDesarrollo)) ...[
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

    switch (current) {
      case RequerimientoStatus.propuesto:
        add(RequerimientoStatus.enRevision);
        add(RequerimientoStatus.rechazado, color: const Color(0xFFEF5350));
      case RequerimientoStatus.enRevision:
        add(RequerimientoStatus.aprobado);
        add(RequerimientoStatus.diferido);
        add(RequerimientoStatus.rechazado, color: const Color(0xFFEF5350));
      case RequerimientoStatus.aprobado:
        add(RequerimientoStatus.enDesarrollo);
        add(RequerimientoStatus.diferido);
      case RequerimientoStatus.diferido:
        add(RequerimientoStatus.enRevision);
        add(RequerimientoStatus.aprobado);
      case RequerimientoStatus.enDesarrollo:
        add(RequerimientoStatus.implementado);
      case RequerimientoStatus.implementado:
        add(RequerimientoStatus.cerrado);
        add(RequerimientoStatus.enDesarrollo);
      case RequerimientoStatus.cerrado:
      case RequerimientoStatus.rechazado:
        add(RequerimientoStatus.propuesto); // Reabrir
    }

    return actions;
  }

  /// Acciones para Soporte (más limitadas).
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

    switch (current) {
      case RequerimientoStatus.aprobado:
        add(RequerimientoStatus.enDesarrollo);
      case RequerimientoStatus.enDesarrollo:
        add(RequerimientoStatus.implementado);
      case RequerimientoStatus.implementado:
        add(RequerimientoStatus.enDesarrollo);
      default:
        break;
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
  RequerimientoStatus.aprobado => const Color(0xFF66BB6A),
  RequerimientoStatus.diferido => const Color(0xFFFFB74D),
  RequerimientoStatus.rechazado => const Color(0xFFEF5350),
  RequerimientoStatus.enDesarrollo => const Color(0xFFFFC107),
  RequerimientoStatus.implementado => const Color(0xFF4CAF50),
  RequerimientoStatus.cerrado => const Color(0xFF388E3C),
};

IconData _statusIcon(RequerimientoStatus status) => switch (status) {
  RequerimientoStatus.propuesto => Icons.fiber_new,
  RequerimientoStatus.enRevision => Icons.visibility,
  RequerimientoStatus.aprobado => Icons.check_circle_outline,
  RequerimientoStatus.diferido => Icons.pause_circle_outline,
  RequerimientoStatus.rechazado => Icons.cancel_outlined,
  RequerimientoStatus.enDesarrollo => Icons.code,
  RequerimientoStatus.implementado => Icons.done_all,
  RequerimientoStatus.cerrado => Icons.lock_outline,
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
    required this.onSend,
  });

  final List<RequerimientoComment> comments;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

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
                  itemBuilder: (context, index) =>
                      _CommentTile(comment: comments[index]),
                ),
        ),

        // Input
        _CommentInput(controller: controller, sending: sending, onSend: onSend),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final RequerimientoComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSystem = comment.type != ReqCommentType.comment;

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
              ],
            ),
            const SizedBox(height: 6),
            Text(comment.text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
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
    );
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
