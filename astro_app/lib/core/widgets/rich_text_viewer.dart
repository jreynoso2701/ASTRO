import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:markdown/markdown.dart' as md;

/// Visor de texto enriquecido en modo solo lectura.
///
/// Recibe contenido Markdown y lo muestra con formato usando QuillEditor
/// en modo readOnly. Compatible con texto plano existente (retrocompat).
class RichTextViewer extends StatefulWidget {
  const RichTextViewer({
    required this.markdown,
    this.padding = const EdgeInsets.all(0),
    this.maxLines,
    super.key,
  });

  /// Contenido Markdown (o texto plano) a renderizar.
  final String markdown;

  /// Padding interno del visor.
  final EdgeInsetsGeometry padding;

  /// Máximo de líneas antes de truncar (null = sin límite).
  final int? maxLines;

  @override
  State<RichTextViewer> createState() => _RichTextViewerState();
}

class _RichTextViewerState extends State<RichTextViewer> {
  late QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.markdown);
  }

  @override
  void didUpdateWidget(covariant RichTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdown != widget.markdown) {
      _controller.dispose();
      _controller = _buildController(widget.markdown);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  QuillController _buildController(String markdownText) {
    final delta = _markdownToDelta(markdownText);
    return QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.markdown.trim().isEmpty) {
      return Padding(
        padding: widget.padding,
        child: Text(
          'Sin contenido',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return QuillEditor(
      controller: _controller,
      focusNode: FocusNode(canRequestFocus: false),
      scrollController: ScrollController(),
      config: QuillEditorConfig(
        autoFocus: false,
        expands: false,
        scrollable: false,
        showCursor: false,
        enableInteractiveSelection: true,
        padding: widget.padding,
        customStyles: _buildStyles(theme),
      ),
    );
  }

  DefaultStyles _buildStyles(ThemeData theme) {
    final baseStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: 14,
      height: 1.5,
    );

    return DefaultStyles(
      paragraph: DefaultTextBlockStyle(
        baseStyle,
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(2, 2),
        const VerticalSpacing(0, 0),
        null,
      ),
      h1: DefaultTextBlockStyle(
        baseStyle.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(6, 6),
        const VerticalSpacing(0, 0),
        null,
      ),
      h2: DefaultTextBlockStyle(
        baseStyle.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(4, 4),
        const VerticalSpacing(0, 0),
        null,
      ),
      h3: DefaultTextBlockStyle(
        baseStyle.copyWith(fontSize: 17, fontWeight: FontWeight.bold),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(4, 4),
        const VerticalSpacing(0, 0),
        null,
      ),
    );
  }

  /// Parsea contenido a Delta. Auto-detecta formato:
  /// 1. JSON Delta (lossless roundtrip)
  /// 2. Markdown
  /// 3. Texto plano (fallback)
  static Delta _markdownToDelta(String text) {
    if (text.trim().isEmpty) {
      return Delta()..insert('\n');
    }

    // 1. Intentar JSON Delta
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return Delta.fromJson(decoded);
      }
    } catch (_) {}

    // 2. Intentar Markdown
    try {
      final mdDocument = md.Document(
        encodeHtml: false,
        extensionSet: md.ExtensionSet.gitHubFlavored,
      );
      final converter = MarkdownToDelta(markdownDocument: mdDocument);
      return converter.convert(text);
    } catch (_) {}

    // 3. Fallback: texto plano
    return Delta()
      ..insert(text)
      ..insert('\n');
  }
}
