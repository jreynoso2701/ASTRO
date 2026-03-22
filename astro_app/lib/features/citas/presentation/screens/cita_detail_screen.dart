import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:astro/core/models/cita.dart';
import 'package:astro/core/models/cita_comment.dart';
import 'package:astro/core/models/cita_status.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';

/// Pantalla de detalle de una cita.
class CitaDetailScreen extends ConsumerWidget {
  const CitaDetailScreen({
    required this.projectId,
    required this.citaId,
    super.key,
  });

  final String projectId;
  final String citaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citaAsync = ref.watch(citaByIdProvider(citaId));
    final canManage = ref.watch(canManageProjectProvider(projectId));
    final isRoot = ref.watch(isCurrentUserRootProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CITA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (canManage || isRoot)
            citaAsync.whenOrNull(
                  data: (c) => c != null
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar cita',
                          onPressed: () => context.push(
                            '/projects/$projectId/citas/$citaId/edit',
                          ),
                        )
                      : null,
                ) ??
                const SizedBox.shrink(),
        ],
      ),
      body: citaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cita) {
          if (cita == null) {
            return const Center(child: Text('Cita no encontrada'));
          }

          final width = MediaQuery.sizeOf(context).width;
          final isWide = width >= AppBreakpoints.medium;

          final infoSection = _CitaInfoSection(
            cita: cita,
            projectId: projectId,
          );
          final actionsSection = _ActionsSection(
            cita: cita,
            canManage: canManage || isRoot,
            onStatusChange: (status) =>
                _changeStatus(context, ref, cita, status),
          );
          final commentsSection = _CommentsSection(
            citaId: citaId,
            canComment: canManage || isRoot,
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        actionsSection,
                        const SizedBox(height: 24),
                        commentsSection,
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoSection,
                const SizedBox(height: 24),
                actionsSection,
                const SizedBox(height: 24),
                commentsSection,
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    Cita cita,
    CitaStatus newStatus,
  ) async {
    final repo = ref.read(citaRepositoryProvider);
    final uid = ref.read(authStateProvider).value?.uid ?? '';

    // ── Modal de completar ─────────────────────────────────
    if (newStatus == CitaStatus.completada) {
      final projectId = GoRouterState.of(context).pathParameters['id'] ?? '';
      final result = await showDialog<_CompletionResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _CompletionDialog(citaId: cita.id, projectId: projectId),
      );
      if (result == null) return; // canceló

      await repo.updateStatus(cita.id, newStatus, updatedBy: uid);

      // Actualizar refTickets / refRequerimientos de la cita con los creados
      if (result.createdTicketIds.isNotEmpty ||
          result.createdReqIds.isNotEmpty) {
        final citaRepo = ref.read(citaRepositoryProvider);
        for (final ticketId in result.createdTicketIds) {
          await citaRepo.addRefTicket(cita.id, ticketId);
        }
        for (final reqId in result.createdReqIds) {
          await citaRepo.addRefRequerimiento(cita.id, reqId);
        }
      }

      if (result.comment.isNotEmpty) {
        final profile = ref.read(currentUserProfileProvider).value;
        await repo.addComment(
          cita.id,
          CitaComment(
            id: '',
            text: result.comment,
            authorId: uid,
            authorName: profile?.displayName ?? '',
            citaId: cita.id,
            type: CitaCommentType.completion,
          ),
        );
      }

      if (!context.mounted) return;
      if (result.generateMinuta) {
        context.push('/projects/$projectId/minutas/new?refCitaId=${cita.id}');
      }
      return;
    }

    await repo.updateStatus(cita.id, newStatus, updatedBy: uid);
  }
}

// ── Completion Dialog ────────────────────────────────────

class _CompletionResult {
  const _CompletionResult({
    required this.comment,
    this.generateMinuta = false,
    this.createdTicketIds = const [],
    this.createdReqIds = const [],
  });
  final String comment;
  final bool generateMinuta;
  final List<String> createdTicketIds;
  final List<String> createdReqIds;
}

class _CompletionDialog extends StatefulWidget {
  const _CompletionDialog({required this.citaId, required this.projectId});
  final String citaId;
  final String projectId;

  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog> {
  final _commentCtrl = TextEditingController();
  final List<String> _createdTicketIds = [];
  final List<String> _createdReqIds = [];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _createTicket() async {
    final ticketId = await context.push<String>(
      '/projects/${widget.projectId}/tickets/new',
      extra: {'returnId': true, 'refCitaId': widget.citaId},
    );
    if (ticketId != null && ticketId.isNotEmpty && mounted) {
      setState(() => _createdTicketIds.add(ticketId));
    }
  }

  Future<void> _createRequerimiento() async {
    final reqId = await context.push<String>(
      '/projects/${widget.projectId}/requirements/new',
      extra: {'returnId': true, 'refCitaId': widget.citaId},
    );
    if (reqId != null && reqId.isNotEmpty && mounted) {
      setState(() => _createdReqIds.add(reqId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Completar cita'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Puedes añadir un comentario de cierre y, '
                'opcionalmente, generar una minuta a partir de esta cita.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Comentario de cierre (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Crear ticket / requerimiento ──
              Text(
                'Crear a partir de esta cita:',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _createTicket,
                      icon: const Icon(
                        Icons.confirmation_number_outlined,
                        size: 18,
                      ),
                      label: const Text('Ticket'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _createRequerimiento,
                      icon: const Icon(Icons.assignment_outlined, size: 18),
                      label: const Text('Requerimiento'),
                    ),
                  ),
                ],
              ),

              // Mostrar items creados
              if (_createdTicketIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _createdTicketIds
                      .map(
                        (id) => Chip(
                          avatar: const Icon(
                            Icons.confirmation_number_outlined,
                            size: 14,
                          ),
                          label: Text(
                            'Ticket creado',
                            style: theme.textTheme.bodySmall,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
              if (_createdReqIds.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _createdReqIds
                      .map(
                        (id) => Chip(
                          avatar: const Icon(
                            Icons.assignment_outlined,
                            size: 14,
                          ),
                          label: Text(
                            'Requerimiento creado',
                            style: theme.textTheme.bodySmall,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(
            context,
            _CompletionResult(
              comment: _commentCtrl.text.trim(),
              generateMinuta: true,
              createdTicketIds: _createdTicketIds,
              createdReqIds: _createdReqIds,
            ),
          ),
          child: const Text('Completar y generar minuta'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _CompletionResult(
              comment: _commentCtrl.text.trim(),
              createdTicketIds: _createdTicketIds,
              createdReqIds: _createdReqIds,
            ),
          ),
          child: const Text('Completar'),
        ),
      ],
    );
  }
}

// ── Info Section ─────────────────────────────────────────

class _CitaInfoSection extends StatelessWidget {
  const _CitaInfoSection({required this.cita, required this.projectId});

  final Cita cita;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = cita.fecha != null
        ? DateFormat('dd/MM/yyyy').format(cita.fecha!)
        : '—';

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
                child: const Icon(Icons.event_outlined, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                cita.titulo,
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
                  cita.folio,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _StatusBadge(status: cita.status),
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
                _InfoRow(label: 'Fecha', value: dateStr),
                _InfoRow(
                  label: 'Hora',
                  value: '${cita.horaInicio ?? '—'} – ${cita.horaFin ?? '—'}',
                ),
                _InfoRow(label: 'Modalidad', value: cita.modalidad.label),
                if (cita.urlVideoconferencia != null &&
                    cita.urlVideoconferencia!.isNotEmpty)
                  _UrlRow(url: cita.urlVideoconferencia!),
                if (cita.direccion != null && cita.direccion!.isNotEmpty)
                  _InfoRow(label: 'Dirección', value: cita.direccion!),
                _InfoRow(label: 'Empresa', value: cita.empresaName),
                _InfoRow(label: 'Creado por', value: cita.createdByName),
              ],
            ),
          ),
        ),

        // Descripción
        if (cita.descripcion != null && cita.descripcion!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DESCRIPCIÓN',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  Text(cita.descripcion!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Participantes
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PARTICIPANTES',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),
                if (cita.participantes.isEmpty)
                  Text(
                    'Sin participantes registrados',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...cita.participantes.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            p.uid.isNotEmpty
                                ? Icons.person
                                : Icons.person_outline,
                            size: 18,
                            color: p.uid.isNotEmpty
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.nombre,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (p.rol != null && p.rol!.isNotEmpty)
                                  Text(
                                    p.rol!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Recordatorios
        if (cita.recordatorios.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RECORDATORIOS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 8,
                    children: cita.recordatorios.map((mins) {
                      final label = mins >= 60
                          ? '${mins ~/ 60}h antes'
                          : '${mins}min antes';
                      return Chip(
                        label: Text(label),
                        avatar: const Icon(
                          Icons.notifications_outlined,
                          size: 16,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Notas
        if (cita.notas != null && cita.notas!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NOTAS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  Text(cita.notas!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],

        // ── Minuta generada ─────────────────────────────────
        if (cita.refMinuta != null && cita.refMinuta!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MINUTA GENERADA',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Ver minuta'),
                    trailing: const Icon(Icons.chevron_right),
                    contentPadding: EdgeInsets.zero,
                    onTap: () => context.push(
                      '/projects/$projectId/minutas/${cita.refMinuta}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // ── Referencias ─────────────────────────────────────
        if (cita.refMinutas.isNotEmpty ||
            cita.refTickets.isNotEmpty ||
            cita.refRequerimientos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REFERENCIAS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  if (cita.refTickets.isNotEmpty) ...[
                    Text(
                      'Tickets',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: cita.refTickets.map((id) {
                        return ActionChip(
                          avatar: const Icon(
                            Icons.confirmation_number_outlined,
                            size: 16,
                          ),
                          label: Text(
                            id.length > 8 ? '${id.substring(0, 8)}…' : id,
                          ),
                          onPressed: () =>
                              context.push('/projects/$projectId/tickets/$id'),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (cita.refRequerimientos.isNotEmpty) ...[
                    Text(
                      'Requerimientos',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: cita.refRequerimientos.map((id) {
                        return ActionChip(
                          avatar: const Icon(
                            Icons.assignment_outlined,
                            size: 16,
                          ),
                          label: Text(
                            id.length > 8 ? '${id.substring(0, 8)}…' : id,
                          ),
                          onPressed: () => context.push(
                            '/projects/$projectId/requirements/$id',
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (cita.refMinutas.isNotEmpty) ...[
                    Text(
                      'Minutas',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: cita.refMinutas.map((id) {
                        return ActionChip(
                          avatar: const Icon(
                            Icons.description_outlined,
                            size: 16,
                          ),
                          label: Text(
                            id.length > 8 ? '${id.substring(0, 8)}…' : id,
                          ),
                          onPressed: () =>
                              context.push('/projects/$projectId/minutas/$id'),
                        );
                      }).toList(),
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
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

class _UrlRow extends StatelessWidget {
  const _UrlRow({required this.url});

  final String url;

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No se pudo abrir la URL')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              'URL',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _openUrl(context),
              child: Text(
                url,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _openUrl(context),
            child: Icon(
              Icons.open_in_new,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CitaStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      CitaStatus.programada => (
        Theme.of(context).colorScheme.primary,
        'Programada',
      ),
      CitaStatus.enCurso => (const Color(0xFFFFA726), 'En curso'),
      CitaStatus.completada => (const Color(0xFF4CAF50), 'Completada'),
      CitaStatus.cancelada => (
        Theme.of(context).colorScheme.error,
        'Cancelada',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Actions Section ──────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.cita,
    required this.canManage,
    required this.onStatusChange,
  });

  final Cita cita;
  final bool canManage;
  final ValueChanged<CitaStatus> onStatusChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!canManage) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCIONES',
          style: theme.textTheme.labelLarge?.copyWith(
            letterSpacing: 1,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Divider(),
        const SizedBox(height: 8),

        Text(
          'Cambiar estado:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CitaStatus.values
              .where((s) => s != cita.status)
              .map(
                (s) => OutlinedButton(
                  onPressed: () => onStatusChange(s),
                  child: Text(s.label),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ── Comments Section ─────────────────────────────────────

class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({required this.citaId, required this.canComment});

  final String citaId;
  final bool canComment;

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final repo = ref.read(citaRepositoryProvider);
      final profile = ref.read(currentUserProfileProvider).value;
      await repo.addComment(
        widget.citaId,
        CitaComment(
          id: '',
          text: text,
          authorId: profile?.uid ?? '',
          authorName: profile?.displayName ?? '',
          citaId: widget.citaId,
        ),
      );
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commentsAsync = ref.watch(citaCommentsProvider(widget.citaId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COMENTARIOS',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            commentsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('Error: $e'),
              data: (comments) {
                if (comments.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Sin comentarios',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: comments.map((c) {
                    final isCompletion = c.type == CitaCommentType.completion;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isCompletion
                                ? Icons.check_circle_outline
                                : Icons.chat_bubble_outline,
                            size: 18,
                            color: isCompletion
                                ? const Color(0xFF4CAF50)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      c.authorName,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const Spacer(),
                                    if (c.createdAt != null)
                                      Text(
                                        DateFormat(
                                          'dd/MM/yy HH:mm',
                                        ).format(c.createdAt!),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(c.text, style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            if (widget.canComment) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Añadir comentario…',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      maxLines: 2,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 20),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
