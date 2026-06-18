import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:astro/core/models/ticket_comment.dart';
import 'package:astro/core/services/storage_service.dart';
import 'package:astro/core/presentation/widgets/storage_image.dart';
import 'package:astro/core/presentation/screens/file_viewer_screen.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de chat para los comentarios de un ticket.
/// Estilo WhatsApp: burbujas izquierda/derecha, input plano, separadores de fecha.
class TicketChatScreen extends ConsumerStatefulWidget {
  const TicketChatScreen({
    required this.projectId,
    required this.ticketId,
    super.key,
  });

  final String projectId;
  final String ticketId;

  @override
  ConsumerState<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends ConsumerState<TicketChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  List<XFile> _pendingFiles = [];

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markAsRead() {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    ref
        .read(ticketRepositoryProvider)
        .markChatAsRead(uid, widget.ticketId)
        .catchError((_) {});
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
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
            'comentarios_tickets/${widget.ticketId}',
            file,
          );
          adjuntosUrls.add(url);
        }
      }
      await ref.read(ticketRepositoryProvider).addComment(
        widget.ticketId,
        TicketComment(
          id: '',
          text: text,
          authorId: profile.uid,
          authorName: profile.displayName,
          adjuntos: adjuntosUrls,
        ),
      );
      _textController.clear();
      setState(() => _pendingFiles = []);
      _markAsRead(); // best-effort, error handled internally
      _scrollToBottom(animated: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickFiles() async {
    final totalAllowed = 10 - _pendingFiles.length;
    if (totalAllowed <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo 10 archivos por mensaje')),
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
            if (!kIsWeb)
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
    setState(() => _pendingFiles = [..._pendingFiles, ...picked.take(canAdd)]);
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(ticketByIdProvider(widget.ticketId));
    final commentsAsync = ref.watch(ticketCommentsProvider(widget.ticketId));
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final ticket = ticketAsync.value;
    final title = ticket != null ? '${ticket.folio} · ${ticket.titulo}' : 'Chat';

    // Auto-scroll when new messages arrive
    commentsAsync.whenData((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (ticket != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Ver ticket',
              onPressed: () => context.push(
                '/projects/${widget.projectId}/tickets/${widget.ticketId}',
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: commentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (comments) {
                if (comments.isEmpty) {
                  return Center(
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
                          'Sin mensajes aún\nSé el primero en escribir',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Build list items with date separators
                final items = _buildChatItems(comments);

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    if (item is _DateSeparatorItem) {
                      return _ChatDateSeparator(label: item.label);
                    }
                    final comment = item as TicketComment;
                    if (comment.type != CommentType.comment) {
                      return _ChatSystemMessage(comment: comment);
                    }
                    final isMe = comment.authorId == uid;
                    // Determine if we should show avatar (first of a sequence)
                    final prevIdx = items.indexOf(comment) - 1;
                    final showAvatar = !isMe && (prevIdx < 0 ||
                        items[prevIdx] is _DateSeparatorItem ||
                        (items[prevIdx] is TicketComment &&
                            (items[prevIdx] as TicketComment).authorId != comment.authorId));
                    return _ChatBubble(
                      comment: comment,
                      isMe: isMe,
                      showAvatar: showAvatar,
                    );
                  },
                );
              },
            ),
          ),

          // Pending files preview
          if (_pendingFiles.isNotEmpty)
            _PendingFilesStrip(
              files: _pendingFiles,
              onRemove: (i) => setState(() => _pendingFiles.removeAt(i)),
            ),

          // Input bar
          _ChatInputBar(
            controller: _textController,
            sending: _sending,
            onAttach: _pickFiles,
            onSend: _sendMessage,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  List<Object> _buildChatItems(List<TicketComment> comments) {
    final items = <Object>[];
    DateTime? lastDate;
    for (final c in comments) {
      if (c.deleted) continue;
      final date = c.createdAt;
      if (date != null) {
        final day = DateTime(date.year, date.month, date.day);
        if (lastDate == null || day.isAfter(lastDate)) {
          items.add(_DateSeparatorItem(_formatDate(day)));
          lastDate = day;
        }
      }
      items.add(c);
    }
    return items;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'Hoy';
    if (date == yesterday) return 'Ayer';
    return DateFormat('EEEE d \'de\' MMMM', 'es').format(date);
  }
}

class _DateSeparatorItem {
  const _DateSeparatorItem(this.label);
  final String label;
}

// ── Widgets ───────────────────────────────────────────────

class _ChatDateSeparator extends StatelessWidget {
  const _ChatDateSeparator({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _ChatSystemMessage extends StatelessWidget {
  const _ChatSystemMessage({required this.comment});
  final TicketComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (comment.type) {
      CommentType.statusChange => Icons.swap_horiz,
      CommentType.assignment => Icons.person_add_outlined,
      CommentType.priorityChange => Icons.flag_outlined,
      _ => Icons.info_outline,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  comment.text,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.comment,
    required this.isMe,
    required this.showAvatar,
  });

  final TicketComment comment;
  final bool isMe;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final bubbleColor = isMe
        ? primary.withValues(alpha: isDark ? 0.75 : 0.85)
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isMe
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final metaColor = isMe
        ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
        : theme.colorScheme.onSurfaceVariant;

    final timeStr = comment.createdAt != null
        ? DateFormat('HH:mm').format(comment.createdAt!)
        : '';

    final initials = comment.authorName.isNotEmpty
        ? comment.authorName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';

    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        bottom: 2,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            if (showAvatar)
              CircleAvatar(
                radius: 14,
                backgroundColor: primary.withValues(alpha: 0.15),
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      comment.authorName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (comment.text.isNotEmpty)
                        Text(
                          comment.text,
                          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                        ),
                      if (comment.adjuntos.isNotEmpty) ...[
                        if (comment.text.isNotEmpty) const SizedBox(height: 6),
                        _BubbleAttachments(
                          adjuntos: comment.adjuntos,
                          isMe: isMe,
                        ),
                      ],
                      const SizedBox(height: 3),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          timeStr,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: metaColor,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleAttachments extends StatelessWidget {
  const _BubbleAttachments({required this.adjuntos, required this.isMe});
  final List<String> adjuntos;
  final bool isMe;

  static const _imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};

  bool _isImage(String url) {
    final lower = url.toLowerCase().split('?').first;
    return _imageExts.any(lower.endsWith);
  }

  @override
  Widget build(BuildContext context) {
    final images = adjuntos.where(_isImage).toList();
    final files = adjuntos.where((u) => !_isImage(u)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: images
                .map(
                  (url) => GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FileViewerScreen(url: url),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: StorageImage(
                        url: url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        if (files.isNotEmpty)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: files
                .map(
                  (url) => ActionChip(
                    avatar: const Icon(Icons.attach_file, size: 14),
                    label: Text(
                      url.split('/').last.split('?').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FileViewerScreen(url: url),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.sending,
    required this.onAttach,
    required this.onSend,
    required this.isDark,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.75),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.07),
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomPad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: sending ? null : onAttach,
                tooltip: 'Adjuntar',
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final hasContent = controller.text.trim().isNotEmpty;
                  return IconButton.filled(
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    onPressed: (hasContent && !sending) ? onSend : null,
                    tooltip: 'Enviar',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingFilesStrip extends StatelessWidget {
  const _PendingFilesStrip({required this.files, required this.onRemove});
  final List<XFile> files;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 80,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: files.length,
        itemBuilder: (context, i) {
          final file = files[i];
          final ext = file.name.split('.').last.toLowerCase();
          final isImage = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext);
          return Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: isImage && !kIsWeb
                    ? Image.file(File(file.path), fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          ext.toUpperCase(),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
              ),
              Positioned(
                top: 0,
                right: 6,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
