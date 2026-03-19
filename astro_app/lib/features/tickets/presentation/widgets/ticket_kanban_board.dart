import 'package:flutter/material.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/utils/ticket_colors.dart';
import 'package:astro/core/utils/progress_color.dart';

// ── Criterios de ordenamiento ────────────────────────────

enum KanbanSortCriteria {
  reciente('Más reciente', Icons.schedule),
  antiguo('Más antiguo', Icons.history),
  prioridadDesc('Prioridad ↑', Icons.arrow_upward),
  prioridadAsc('Prioridad ↓', Icons.arrow_downward),
  reporto('Quién reporta', Icons.person_outline),
  soporte('Soporte asignado', Icons.headset_mic_outlined),
  avance('% Avance', Icons.trending_up),
  impacto('Impacto', Icons.warning_amber_rounded);

  const KanbanSortCriteria(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Tablero Kanban que agrupa tickets por estado en columnas horizontales.
/// Soporta drag & drop entre columnas y ordenamiento por columna.
class TicketKanbanBoard extends StatefulWidget {
  const TicketKanbanBoard({
    required this.tickets,
    required this.onTicketTap,
    required this.onStatusChange,
    this.showDeadline = false,
    this.canManage = false,
    this.onBulkArchive,
    super.key,
  });

  final List<Ticket> tickets;
  final ValueChanged<Ticket> onTicketTap;
  final void Function(Ticket ticket, TicketStatus newStatus) onStatusChange;
  final bool showDeadline;
  final bool canManage;
  final Future<void> Function(List<Ticket> tickets)? onBulkArchive;

  @override
  State<TicketKanbanBoard> createState() => _TicketKanbanBoardState();
}

class _TicketKanbanBoardState extends State<TicketKanbanBoard> {
  /// Ordenamiento global (aplica a todas las columnas).
  KanbanSortCriteria _sort = KanbanSortCriteria.reciente;

  List<Ticket> _sortTickets(List<Ticket> tickets) {
    final sorted = List<Ticket>.of(tickets);
    switch (_sort) {
      case KanbanSortCriteria.reciente:
        sorted.sort(
          (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
            a.createdAt ?? DateTime(2000),
          ),
        );
      case KanbanSortCriteria.antiguo:
        sorted.sort(
          (a, b) => (a.createdAt ?? DateTime(2000)).compareTo(
            b.createdAt ?? DateTime(2000),
          ),
        );
      case KanbanSortCriteria.prioridadDesc:
        sorted.sort((a, b) => b.priority.index.compareTo(a.priority.index));
      case KanbanSortCriteria.prioridadAsc:
        sorted.sort((a, b) => a.priority.index.compareTo(b.priority.index));
      case KanbanSortCriteria.reporto:
        sorted.sort(
          (a, b) => a.createdByName.toLowerCase().compareTo(
            b.createdByName.toLowerCase(),
          ),
        );
      case KanbanSortCriteria.soporte:
        sorted.sort(
          (a, b) => (a.assignedToName ?? 'zzz').toLowerCase().compareTo(
            (b.assignedToName ?? 'zzz').toLowerCase(),
          ),
        );
      case KanbanSortCriteria.avance:
        sorted.sort((a, b) => b.porcentajeAvance.compareTo(a.porcentajeAvance));
      case KanbanSortCriteria.impacto:
        sorted.sort((a, b) => (b.impacto ?? 0).compareTo(a.impacto ?? 0));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final columns = TicketStatus.kanbanValues;
    final theme = Theme.of(context);

    return Column(
      children: [
        // ── Sort bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.sort,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Ordenar:',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final criteria in KanbanSortCriteria.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: FilterChip(
                            avatar: Icon(criteria.icon, size: 14),
                            label: Text(criteria.label),
                            selected: _sort == criteria,
                            onSelected: (_) => setState(() => _sort = criteria),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            labelStyle: theme.textTheme.labelSmall,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Board ──
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const minColumnWidth = 230.0;
              final availableWidth = constraints.maxWidth;
              final fitsAll = availableWidth >= columns.length * minColumnWidth;
              final columnWidth = fitsAll
                  ? availableWidth / columns.length
                  : minColumnWidth;

              final child = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final status in columns)
                    SizedBox(
                      width: columnWidth,
                      child: _KanbanColumn(
                        status: status,
                        tickets: _sortTickets(
                          widget.tickets
                              .where((t) => t.status == status)
                              .toList(),
                        ),
                        onTicketTap: widget.onTicketTap,
                        onStatusChange: widget.onStatusChange,
                        showDeadline: widget.showDeadline,
                        canManage: widget.canManage,
                        onBulkArchive: widget.onBulkArchive,
                      ),
                    ),
                ],
              );

              if (fitsAll) return child;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: child,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Columna Kanban ───────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.status,
    required this.tickets,
    required this.onTicketTap,
    required this.onStatusChange,
    this.showDeadline = false,
    this.canManage = false,
    this.onBulkArchive,
  });

  final TicketStatus status;
  final List<Ticket> tickets;
  final ValueChanged<Ticket> onTicketTap;
  final void Function(Ticket ticket, TicketStatus newStatus) onStatusChange;
  final bool showDeadline;
  final bool canManage;
  final Future<void> Function(List<Ticket> tickets)? onBulkArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ticketStatusColor(status);

    return DragTarget<Ticket>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) => onStatusChange(details.data, status),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isHovering
                ? color.withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering
                  ? color.withValues(alpha: 0.5)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isHovering ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              // ── Header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${tickets.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // ── Botón archivar masivo (solo Resuelto, Root/Soporte) ──
                    if (status == TicketStatus.resuelto &&
                        canManage &&
                        tickets.isNotEmpty &&
                        onBulkArchive != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _BulkArchiveButton(
                          ticketCount: tickets.length,
                          onConfirmed: () => onBulkArchive!(tickets),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Cards ──
              Expanded(
                child: tickets.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Sin tickets',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(6),
                        itemCount: tickets.length,
                        itemBuilder: (context, index) {
                          final ticket = tickets[index];
                          return LongPressDraggable<Ticket>(
                            data: ticket,
                            delay: const Duration(milliseconds: 200),
                            hapticFeedbackOnStart: true,
                            feedback: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 210,
                                child: _KanbanCard(
                                  ticket: ticket,
                                  isDragging: true,
                                  showDeadline: showDeadline,
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _KanbanCard(
                                ticket: ticket,
                                showDeadline: showDeadline,
                              ),
                            ),
                            child: GestureDetector(
                              onTap: () => onTicketTap(ticket),
                              onSecondaryTapDown: (details) {
                                _showStatusMenu(
                                  context,
                                  details.globalPosition,
                                  ticket,
                                  status,
                                  onStatusChange,
                                );
                              },
                              child: _KanbanCard(
                                ticket: ticket,
                                showDeadline: showDeadline,
                                onMovePressed: () {
                                  final box =
                                      context.findRenderObject() as RenderBox;
                                  final offset = box.localToGlobal(Offset.zero);
                                  _showStatusMenu(
                                    context,
                                    offset,
                                    ticket,
                                    status,
                                    onStatusChange,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStatusMenu(
    BuildContext context,
    Offset position,
    Ticket ticket,
    TicketStatus currentStatus,
    void Function(Ticket, TicketStatus) onStatusChange,
  ) {
    final targets = TicketStatus.kanbanValues
        .where((s) => s != currentStatus)
        .toList();

    showMenu<TicketStatus>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        for (final s in targets)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: ticketStatusColor(s),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(s.label),
              ],
            ),
          ),
      ],
    ).then((newStatus) {
      if (newStatus != null) {
        onStatusChange(ticket, newStatus);
      }
    });
  }
}

// ── Tarjeta Kanban Compacta ──────────────────────────────

class _KanbanCard extends StatelessWidget {
  const _KanbanCard({
    required this.ticket,
    this.isDragging = false,
    this.showDeadline = false,
    this.onMovePressed,
  });

  final Ticket ticket;
  final bool isDragging;
  final bool showDeadline;
  final VoidCallback? onMovePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final pct = ticket.porcentajeAvance;
    final priorityColor = ticketPriorityColor(ticket.priority);

    return Card(
      elevation: isDragging ? 6 : 1,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Folio + Priority badge + Move ──
            Row(
              children: [
                Text(
                  ticket.folio,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (onMovePressed != null)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 14,
                      tooltip: 'Mover a…',
                      onPressed: onMovePressed,
                      icon: Icon(Icons.swap_horiz_rounded, color: muted),
                    ),
                  ),
                if (onMovePressed != null) const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: priorityColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    ticket.priority.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: priorityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── Título (2 lines) ──
            Text(
              ticket.titulo,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // ── Módulo ──
            _CardInfoRow(icon: Icons.widgets_outlined, text: ticket.moduleName),

            // ── Reportó ──
            _CardInfoRow(
              icon: Icons.person_outline,
              text: ticket.createdByName,
            ),

            // ── Soporte ──
            _CardInfoRow(
              icon: Icons.headset_mic_outlined,
              text: ticket.assignedToName ?? 'Sin asignar',
            ),

            // ── Fecha reporte ──
            if (ticket.createdAt != null)
              _CardInfoRow(
                icon: Icons.calendar_today_outlined,
                text: _shortDate(ticket.createdAt!),
              ),

            // ── Impacto badge ──
            if (ticket.impacto != null)
              _CardInfoRow(
                icon: Icons.warning_amber_rounded,
                text: 'Impacto: ${ticket.impacto}/10',
                color: ticket.impacto! <= 3
                    ? const Color(0xFF4CAF50)
                    : ticket.impacto! <= 6
                    ? const Color(0xFFFFC107)
                    : ticket.impacto! <= 9
                    ? const Color(0xFFFF9800)
                    : const Color(0xFFF44336),
              ),

            // ── Deadline semaphore (Root / Soporte) ──
            if (showDeadline) _DeadlineRow(solucion: ticket.solucionProgramada),

            const SizedBox(height: 6),

            // ── Indicadores: adjuntos + comentarios ──
            if (ticket.evidencias.isNotEmpty || ticket.commentCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    if (ticket.evidencias.isNotEmpty) ...[
                      Icon(Icons.attach_file, size: 12, color: muted),
                      const SizedBox(width: 2),
                      Text(
                        '${ticket.evidencias.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (ticket.commentCount > 0) ...[
                      Icon(Icons.chat_bubble_outline, size: 11, color: muted),
                      const SizedBox(width: 2),
                      Text(
                        '${ticket.commentCount}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // ── Progress bar + percentage ──
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 4,
                      backgroundColor: muted.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(progressColor(pct)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${pct.toInt()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    color: progressColor(pct),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _shortDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

// ── Botón de archivado masivo ─────────────────────────────

class _BulkArchiveButton extends StatefulWidget {
  const _BulkArchiveButton({
    required this.ticketCount,
    required this.onConfirmed,
  });

  final int ticketCount;
  final VoidCallback onConfirmed;

  @override
  State<_BulkArchiveButton> createState() => _BulkArchiveButtonState();
}

class _BulkArchiveButtonState extends State<_BulkArchiveButton> {
  bool _loading = false;

  Future<void> _handleTap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.archive_rounded, size: 36),
        title: const Text('Archivar tickets resueltos'),
        content: Text(
          '¿Archivar los ${widget.ticketCount} ticket(s) de la columna Resuelto?\n\n'
          'Se asignará la justificación "Archivado masivo desde Kanban" '
          'a cada ticket.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.archive_rounded, size: 18),
            label: Text('Archivar ${widget.ticketCount}'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      widget.onConfirmed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(4),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              tooltip: 'Archivar todos',
              onPressed: _handleTap,
              icon: Icon(
                Icons.archive_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

/// Row compacto de ícono + texto para las tarjetas Kanban.
class _CardInfoRow extends StatelessWidget {
  const _CardInfoRow({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: c, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Semáforo de deadline compacto para tarjetas Kanban.
class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({required this.solucion});
  final String? solucion;

  @override
  Widget build(BuildContext context) {
    final info = deadlineInfo(solucion);
    return _CardInfoRow(
      icon: Icons.schedule,
      text: info.label,
      color: info.color,
    );
  }
}

/// Parsea una fecha almacenada como String en múltiples formatos posibles:
/// - ISO 8601: "2026-03-15", "2026-03-15T00:00:00.000Z"
/// - V1 con hora: "2026/3/15 11:12"
/// - V2 sin hora: "2026/3/15"
DateTime? parseDeadlineDate(String? solucion) {
  if (solucion == null || solucion.isEmpty) return null;

  // 1. ISO 8601 directo (con guiones)
  final iso = DateTime.tryParse(solucion);
  if (iso != null) return iso;

  // 2. Formato "año/mes/día" o "año/mes/día hora:min"
  final dateTimeParts = solucion.split(' ');
  final datePart = dateTimeParts[0];
  final parts = datePart.split('/');
  if (parts.length == 3) {
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  return null;
}

/// Calcula color y etiqueta del semáforo de deadline.
({Color color, String label}) deadlineInfo(String? solucion) {
  if (solucion == null || solucion.isEmpty) {
    return (color: const Color(0xFF9E9E9E), label: 'Sin fecha límite');
  }

  final target = parseDeadlineDate(solucion);

  if (target == null) {
    return (color: const Color(0xFF9E9E9E), label: 'Fecha inválida');
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final deadline = DateTime(target.year, target.month, target.day);
  final days = deadline.difference(today).inDays;

  if (days < 0) {
    return (color: const Color(0xFFD32F2F), label: 'Vencido (${-days}d)');
  } else if (days <= 1) {
    return (
      color: const Color(0xFFFF9800),
      label: days == 0 ? 'Vence hoy' : 'Vence mañana',
    );
  } else if (days <= 5) {
    return (color: const Color(0xFFFFC107), label: 'Vence en ${days}d');
  } else {
    return (color: const Color(0xFF4CAF50), label: 'Vence en ${days}d');
  }
}
