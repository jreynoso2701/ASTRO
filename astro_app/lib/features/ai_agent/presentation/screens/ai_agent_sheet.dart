import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/ai_chat_message.dart';
import 'package:astro/features/ai_agent/providers/ai_agent_providers.dart';

/// Bottom sheet modal del Agente IA ASTRO.
///
/// Se invoca desde el FAB del Dashboard. Muestra el historial de chat
/// con soporte para mensajes de texto, cards interactivas y voz.
class AiAgentSheet extends ConsumerStatefulWidget {
  const AiAgentSheet({super.key});

  @override
  ConsumerState<AiAgentSheet> createState() => _AiAgentSheetState();
}

class _AiAgentSheetState extends ConsumerState<AiAgentSheet> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(aiChatNotifierProvider.notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = ref.watch(aiChatMessagesProvider);
    final chatState = ref.watch(aiChatNotifierProvider);

    // Scroll al fondo cuando llegan mensajes nuevos
    messages.whenData((_) => _scrollToBottom());

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle + Header ──
              _Header(
                autoSpeak: chatState.autoSpeak,
                onToggleAutoSpeak: () {
                  ref.read(aiChatNotifierProvider.notifier).toggleAutoSpeak();
                },
              ),

              const Divider(height: 1),

              // ── Messages list ──
              Expanded(
                child: messages.when(
                  data: (msgs) {
                    if (msgs.isEmpty) {
                      return _EmptyState();
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: msgs.length + (chatState.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == msgs.length && chatState.isLoading) {
                          return const _TypingIndicator();
                        }
                        return _MessageBubble(
                          message: msgs[index],
                          onSpeak: () {
                            ref
                                .read(aiChatNotifierProvider.notifier)
                                .speakMessage(msgs[index]);
                          },
                          onNavigate: (type, id) =>
                              _navigateToItem(context, type, id),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Error al cargar mensajes: $e')),
                ),
              ),

              // ── Error banner ──
              if (chatState.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: theme.colorScheme.errorContainer,
                  child: Text(
                    chatState.error!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ),

              // ── Input bar ──
              _InputBar(
                controller: _textController,
                isLoading: chatState.isLoading,
                isListening: chatState.isListening,
                isSpeaking: chatState.isSpeaking,
                onSend: _send,
                onMicPressed: () {
                  final notifier = ref.read(aiChatNotifierProvider.notifier);
                  if (chatState.isListening) {
                    notifier.stopListening();
                  } else {
                    notifier.startListening();
                  }
                },
                onStopSpeaking: () {
                  ref.read(aiChatNotifierProvider.notifier).stopSpeaking();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToItem(BuildContext context, AiContentType type, String id) {
    Navigator.pop(context); // Cerrar el sheet
    switch (type) {
      case AiContentType.tickets:
        context.push('/projects/_/tickets/$id');
      case AiContentType.minutas:
        context.push('/projects/_/minutas/$id');
      case AiContentType.requerimientos:
        context.push('/projects/_/requirements/$id');
      case AiContentType.citas:
        context.push('/projects/_/citas/$id');
      default:
        break;
    }
  }
}

// ── Header ────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.autoSpeak, required this.onToggleAutoSpeak});

  final bool autoSpeak;
  final VoidCallback onToggleAutoSpeak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ASTRO AI',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Asistente de proyecto',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: autoSpeak
                      ? 'Respuesta por voz activada'
                      : 'Respuesta por voz desactivada',
                  child: IconButton(
                    icon: Icon(
                      autoSpeak ? Icons.volume_up : Icons.volume_off,
                      color: autoSpeak
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onToggleAutoSpeak,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text('¡Hola! Soy ASTRO AI', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Pregúntame sobre tus proyectos, tickets, minutas, requerimientos o citas.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(label: '¿Cómo va mi proyecto?'),
                _SuggestionChip(label: 'Tickets críticos'),
                _SuggestionChip(label: 'Próximas citas'),
                _SuggestionChip(label: 'Resumen general'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends ConsumerWidget {
  const _SuggestionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ActionChip(
      label: Text(label),
      labelStyle: theme.textTheme.bodySmall,
      onPressed: () {
        ref.read(aiChatNotifierProvider.notifier).sendMessage(label);
      },
    );
  }
}

// ── Message bubble ────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onSpeak,
    required this.onNavigate,
  });

  final AiChatMessage message;
  final VoidCallback onSpeak;
  final void Function(AiContentType type, String id) onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == AiMessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.auto_awesome,
                size: 14,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Bloques de contenido
                for (final block in message.content) ...[
                  _buildContentBlock(context, block, isUser),
                  const SizedBox(height: 4),
                ],
                // Botón de voz (solo para mensajes del asistente)
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: InkWell(
                      onTap: onSpeak,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.volume_up_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Escuchar',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildContentBlock(
    BuildContext context,
    AiContentBlock block,
    bool isUser,
  ) {
    final theme = Theme.of(context);

    switch (block.type) {
      case AiContentType.text:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isUser
                  ? const Radius.circular(16)
                  : const Radius.circular(4),
              bottomRight: isUser
                  ? const Radius.circular(4)
                  : const Radius.circular(16),
            ),
          ),
          child: Text(
            block.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isUser
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        );

      case AiContentType.tickets:
      case AiContentType.minutas:
      case AiContentType.requerimientos:
      case AiContentType.citas:
        return _DataCardsBlock(
          block: block,
          onTap: (id) => onNavigate(block.type, id),
        );

      case AiContentType.progress:
        return _ProgressBlock(block: block);

      case AiContentType.actionConfirm:
        return _ActionConfirmBlock(block: block);
    }
  }
}

// ── Data cards block (tickets, minutas, reqs, citas) ──

class _DataCardsBlock extends StatelessWidget {
  const _DataCardsBlock({required this.block, required this.onTap});

  final AiContentBlock block;
  final void Function(String id) onTap;

  IconData get _icon => switch (block.type) {
    AiContentType.tickets => Icons.bug_report_outlined,
    AiContentType.minutas => Icons.description_outlined,
    AiContentType.requerimientos => Icons.checklist_outlined,
    AiContentType.citas => Icons.calendar_today_outlined,
    _ => Icons.article_outlined,
  };

  String get _typeLabel => switch (block.type) {
    AiContentType.tickets => 'tickets',
    AiContentType.minutas => 'minutas',
    AiContentType.requerimientos => 'requerimientos',
    AiContentType.citas => 'citas',
    _ => 'items',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = block.items;
    final ids = block.data ?? [];
    final count = items?.length ?? ids.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: icono + conteo ──
          Row(
            children: [
              Icon(_icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '$count $_typeLabel',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (count > 0) ...[
            const SizedBox(height: 8),
            // Usar mini-cards cuando hay datos enriquecidos
            if (items != null && items.isNotEmpty)
              ...items
                  .take(5)
                  .map(
                    (item) => _MiniCard(
                      item: item,
                      type: block.type,
                      onTap: () => onTap(item['id'] as String? ?? ''),
                    ),
                  )
            else
              // Fallback: IDs planos (mensajes anteriores sin items)
              ...ids
                  .take(5)
                  .map(
                    (id) => _MiniCardFallback(id: id, onTap: () => onTap(id)),
                  ),
            if (count > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${count - 5} más',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Mini-card con datos enriquecidos ──

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.item,
    required this.type,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final AiContentType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    final folio = item['folio'] as String? ?? '';
    final titulo = item['titulo'] as String? ?? '';
    final status = item['status'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Fila 1: Folio + badge de estado ──
                Row(
                  children: [
                    if (folio.isNotEmpty)
                      Text(
                        folio,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                    const Spacer(),
                    if (status.isNotEmpty)
                      _AiStatusBadge(
                        status: status,
                        color: _statusColorForType(type, status),
                      ),
                  ],
                ),
                if (titulo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  // ── Fila 2: Título ──
                  Text(
                    titulo,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                // ── Fila 3: Metadata según tipo ──
                _buildMetadata(context, muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, Color muted) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: muted);

    return switch (type) {
      AiContentType.tickets => _buildTicketMeta(style, muted),
      AiContentType.minutas => _buildMinutaMeta(style, muted),
      AiContentType.citas => _buildCitaMeta(style, muted),
      _ => const SizedBox.shrink(), // requerimientos: no extra metadata
    };
  }

  Widget _buildTicketMeta(TextStyle? style, Color muted) {
    final prioridad = item['prioridad'] as String? ?? '';
    if (prioridad.isEmpty) return const SizedBox.shrink();

    final prioColor = _priorityColor(prioridad);
    return Row(
      children: [
        Icon(Icons.flag_outlined, size: 12, color: prioColor),
        const SizedBox(width: 4),
        Text(prioridad, style: style?.copyWith(color: prioColor)),
        const Spacer(),
        Icon(Icons.chevron_right, size: 14, color: muted),
      ],
    );
  }

  Widget _buildMinutaMeta(TextStyle? style, Color muted) {
    final fecha = _formatIsoDate(item['fecha'] as String? ?? '');
    final modalidad = item['modalidad'] as String? ?? '';
    return Row(
      children: [
        if (fecha.isNotEmpty) ...[
          Icon(Icons.calendar_today, size: 12, color: muted),
          const SizedBox(width: 4),
          Text(fecha, style: style),
        ],
        if (modalidad.isNotEmpty) ...[
          const SizedBox(width: 10),
          Icon(_modalidadIcon(modalidad), size: 12, color: muted),
          const SizedBox(width: 4),
          Text(modalidad, style: style),
        ],
        const Spacer(),
        Icon(Icons.chevron_right, size: 14, color: muted),
      ],
    );
  }

  Widget _buildCitaMeta(TextStyle? style, Color muted) {
    final fecha = _formatIsoDate(item['fecha'] as String? ?? '');
    return Row(
      children: [
        if (fecha.isNotEmpty) ...[
          Icon(Icons.calendar_today, size: 12, color: muted),
          const SizedBox(width: 4),
          Text(fecha, style: style),
        ],
        const Spacer(),
        Icon(Icons.chevron_right, size: 14, color: muted),
      ],
    );
  }
}

// ── Fallback para mensajes viejos sin items ──

class _MiniCardFallback extends StatelessWidget {
  const _MiniCardFallback({required this.id, required this.onTap});

  final String id;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.open_in_new,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  id,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge de estado compacto ──

class _AiStatusBadge extends StatelessWidget {
  const _AiStatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }
}

// ── Helpers de color ──

Color _statusColorForType(AiContentType type, String status) {
  final upper = status.toUpperCase().trim();
  return switch (type) {
    AiContentType.tickets => _ticketStatusColor(upper),
    AiContentType.requerimientos => _reqStatusColor(status),
    AiContentType.citas => _citaStatusColor(status),
    _ => const Color(0xFF90A4AE),
  };
}

Color _ticketStatusColor(String upper) => switch (upper) {
  'PENDIENTE' => const Color(0xFF2196F3),
  'EN DESARROLLO' => const Color(0xFF00BCD4),
  'PRUEBAS INTERNAS' => const Color(0xFFFF9800),
  'PRUEBAS CLIENTE' => const Color(0xFFFFC107),
  'BUGS' => const Color(0xFFD71921),
  'RESUELTO' => const Color(0xFF4CAF50),
  'ARCHIVADO' => const Color(0xFF9E9E9E),
  _ => const Color(0xFF90A4AE),
};

Color _reqStatusColor(String status) {
  final lower = status.toLowerCase().trim();
  if (lower.contains('propuesto')) return const Color(0xFF90A4AE);
  if (lower.contains('revisión') || lower.contains('revision')) {
    return const Color(0xFF42A5F5);
  }
  if (lower.contains('aprobado')) return const Color(0xFF66BB6A);
  if (lower.contains('diferido')) return const Color(0xFFFFB74D);
  if (lower.contains('rechazado')) return const Color(0xFFEF5350);
  if (lower.contains('desarrollo')) return const Color(0xFFFFC107);
  if (lower.contains('implementado')) return const Color(0xFF4CAF50);
  if (lower.contains('cerrado')) return const Color(0xFF388E3C);
  return const Color(0xFF90A4AE);
}

Color _citaStatusColor(String status) {
  final lower = status.toLowerCase().trim();
  if (lower.contains('programada')) return const Color(0xFF42A5F5);
  if (lower.contains('curso')) return const Color(0xFFFFA726);
  if (lower.contains('completada')) return const Color(0xFF4CAF50);
  if (lower.contains('cancelada')) return const Color(0xFFEF5350);
  return const Color(0xFF90A4AE);
}

Color _priorityColor(String prioridad) {
  final upper = prioridad.toUpperCase().trim();
  return switch (upper) {
    'BAJA' => const Color(0xFF4CAF50),
    'NORMAL' => const Color(0xFF2196F3),
    'ALTA' => const Color(0xFFFFC107),
    'CRITICA' || 'CRÍTICA' => const Color(0xFFD71921),
    _ => const Color(0xFF90A4AE),
  };
}

String _formatIsoDate(String iso) {
  if (iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

IconData _modalidadIcon(String modalidad) {
  final lower = modalidad.toLowerCase();
  if (lower.contains('video')) return Icons.videocam_outlined;
  if (lower.contains('presencial')) return Icons.location_on_outlined;
  if (lower.contains('llamada')) return Icons.phone_outlined;
  if (lower.contains('híbrida') || lower.contains('hibrida')) {
    return Icons.devices_outlined;
  }
  return Icons.event_outlined;
}

// ── Progress block ────────────────────────────────────

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.block});

  final AiContentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              block.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action confirm block ──────────────────────────────

class _ActionConfirmBlock extends StatelessWidget {
  const _ActionConfirmBlock({required this.block});

  final AiContentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.text, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonal(
                onPressed: () {
                  // TODO: Implementar confirmación de acción
                },
                child: const Text('Sí'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  // TODO: Implementar cancelación de acción
                },
                child: const Text('No'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.auto_awesome,
              size: 14,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 200),
                const SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});

  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// ── Input bar ─────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.isListening,
    required this.isSpeaking,
    required this.onSend,
    required this.onMicPressed,
    required this.onStopSpeaking,
  });

  final TextEditingController controller;
  final bool isLoading;
  final bool isListening;
  final bool isSpeaking;
  final VoidCallback onSend;
  final VoidCallback onMicPressed;
  final VoidCallback onStopSpeaking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Botón de micrófono
          Tooltip(
            message: isListening ? 'Detener escucha' : 'Hablar',
            child: IconButton(
              icon: Icon(
                isListening ? Icons.mic : Icons.mic_none,
                color: isListening
                    ? const Color(0xFFD71921)
                    : theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: isLoading ? null : onMicPressed,
            ),
          ),

          // Campo de texto
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isLoading && !isListening,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: isListening
                    ? 'Escuchando...'
                    : 'Escribe tu pregunta...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ),

          const SizedBox(width: 4),

          // Botón enviar / detener voz
          if (isSpeaking)
            Tooltip(
              message: 'Detener voz',
              child: IconButton(
                icon: Icon(
                  Icons.stop_circle_outlined,
                  color: theme.colorScheme.primary,
                ),
                onPressed: onStopSpeaking,
              ),
            )
          else
            Tooltip(
              message: 'Enviar',
              child: IconButton(
                icon: Icon(
                  Icons.send,
                  color: isLoading
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
                onPressed: isLoading ? null : onSend,
              ),
            ),
        ],
      ),
    );
  }
}
