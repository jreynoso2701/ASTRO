import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:markdown/markdown.dart' as md;

/// Nivel de toolbar para el editor de texto enriquecido.
enum RichTextToolbarLevel {
  /// Toolbar completo para formularios (bold, italic, underline, headers,
  /// listas, code, blockquote, link, color, alignment).
  full,

  /// Toolbar mínimo para comentarios (bold, italic, underline, listas, link).
  mini,
}

/// Editor de texto enriquecido reutilizable basado en flutter_quill.
///
/// Almacena y retorna contenido en formato Markdown.
/// Soporta texto enriquecido intermedio: bold, italic, underline, headers,
/// listas, links, code blocks, blockquotes, colores de texto, alineación.
class RichTextEditor extends StatefulWidget {
  const RichTextEditor({
    this.initialMarkdown = '',
    this.toolbarLevel = RichTextToolbarLevel.full,
    this.placeholder = 'Escribe aquí...',
    this.minHeight = 150,
    this.maxHeight = 400,
    this.onChanged,
    this.focusNode,
    this.autoFocus = false,
    super.key,
  });

  /// Contenido Markdown inicial (puede ser texto plano para retrocompatibilidad).
  final String initialMarkdown;

  /// Nivel de toolbar a mostrar.
  final RichTextToolbarLevel toolbarLevel;

  /// Placeholder cuando el editor está vacío.
  final String placeholder;

  /// Altura mínima del editor.
  final double minHeight;

  /// Altura máxima del editor (scrolleable después de esta altura).
  final double maxHeight;

  /// Callback cuando el contenido cambia.
  final ValueChanged<String>? onChanged;

  /// FocusNode opcional.
  final FocusNode? focusNode;

  /// Si debe auto-enfocar al mostrarse.
  final bool autoFocus;

  @override
  State<RichTextEditor> createState() => RichTextEditorState();
}

class RichTextEditorState extends State<RichTextEditor>
    with AutomaticKeepAliveClientMixin {
  late QuillController _controller;
  late FocusNode _focusNode;
  bool _ownFocusNode = false;

  /// Obtiene el contenido actual como JSON Delta (formato nativo de Quill).
  /// Se almacena como JSON para roundtrip sin pérdidas.
  String get markdown {
    final delta = _controller.document.toDelta();
    return jsonEncode(delta.toJson());
  }

  /// Obtiene el texto plano del editor.
  String get plainText => _controller.document.toPlainText().trim();

  /// Indica si el editor está vacío.
  bool get isEmpty => plainText.isEmpty;

  /// Establece nuevo contenido (auto-detecta JSON Delta, Markdown o texto plano).
  void setMarkdown(String text) {
    final delta = _parseToDelta(text);
    _controller.document = Document.fromDelta(delta);
  }

  /// Limpia el contenido del editor.
  void clear() {
    _controller.clear();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ownFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();

    final delta = _parseToDelta(widget.initialMarkdown);
    _controller = QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _controller.document.changes.listen((_) {
      widget.onChanged?.call(markdown);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              theme.inputDecorationTheme.enabledBorder?.borderSide.color ??
              theme.dividerColor,
        ),
        color:
            theme.inputDecorationTheme.fillColor ??
            (isDark
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surface),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Toolbar ───────────────────────────────
          _buildToolbar(theme),
          Divider(height: 1, color: theme.dividerColor),
          // ── Editor ────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.minHeight,
              maxHeight: widget.maxHeight,
            ),
            child: QuillEditor(
              controller: _controller,
              focusNode: _focusNode,
              scrollController: ScrollController(),
              config: QuillEditorConfig(
                autoFocus: widget.autoFocus,
                expands: false,
                scrollable: true,
                placeholder: widget.placeholder,
                padding: const EdgeInsets.all(12),
                customStyles: _buildCustomStyles(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    if (widget.toolbarLevel == RichTextToolbarLevel.mini) {
      return QuillSimpleToolbar(
        controller: _controller,
        config: QuillSimpleToolbarConfig(
          multiRowsDisplay: false,
          showAlignmentButtons: false,
          showBackgroundColorButton: false,
          showCenterAlignment: false,
          showClearFormat: false,
          showCodeBlock: false,
          showColorButton: false,
          showDirection: false,
          showDividers: false,
          showFontFamily: false,
          showFontSize: false,
          showHeaderStyle: false,
          showIndent: false,
          showInlineCode: false,
          showJustifyAlignment: false,
          showLeftAlignment: false,
          showQuote: false,
          showRightAlignment: false,
          showSearchButton: false,
          showSmallButton: false,
          showStrikeThrough: true,
          showSubscript: false,
          showSuperscript: false,
          showUndo: false,
          showRedo: false,
          showClipboardCut: false,
          showClipboardCopy: false,
          showClipboardPaste: false,
          // Mantener: bold, italic, underline, strikethrough, lists, link
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: true,
          showListBullets: true,
          showListNumbers: true,
          showLink: true,
          showListCheck: false,
          toolbarIconAlignment: WrapAlignment.start,
          toolbarSize: 36,
        ),
      );
    }

    // Toolbar completo
    return QuillSimpleToolbar(
      controller: _controller,
      config: QuillSimpleToolbarConfig(
        multiRowsDisplay: false,
        showDividers: true,
        showSmallButton: false,
        showSubscript: false,
        showSuperscript: false,
        showFontFamily: false,
        showFontSize: false,
        showSearchButton: false,
        showClipboardCut: false,
        showClipboardCopy: false,
        showClipboardPaste: false,
        showListCheck: false,
        showDirection: false,
        showIndent: true,
        // Format buttons
        showBoldButton: true,
        showItalicButton: true,
        showUnderLineButton: true,
        showStrikeThrough: true,
        showInlineCode: true,
        // Structure
        showHeaderStyle: true,
        showListBullets: true,
        showListNumbers: true,
        showQuote: true,
        showCodeBlock: true,
        // Alignment
        showAlignmentButtons: true,
        showLeftAlignment: true,
        showCenterAlignment: true,
        showRightAlignment: true,
        showJustifyAlignment: false,
        // Rich
        showLink: true,
        showColorButton: true,
        showBackgroundColorButton: false,
        showClearFormat: true,
        // Undo/redo
        showUndo: true,
        showRedo: true,
        toolbarIconAlignment: WrapAlignment.start,
        toolbarSize: 40,
      ),
    );
  }

  DefaultStyles _buildCustomStyles(ThemeData theme) {
    final baseStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: 14,
      height: 1.5,
    );

    return DefaultStyles(
      paragraph: DefaultTextBlockStyle(
        baseStyle,
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(4, 4),
        const VerticalSpacing(0, 0),
        null,
      ),
      h1: DefaultTextBlockStyle(
        baseStyle.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(8, 8),
        const VerticalSpacing(0, 0),
        null,
      ),
      h2: DefaultTextBlockStyle(
        baseStyle.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(6, 6),
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
      placeHolder: DefaultTextBlockStyle(
        baseStyle.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
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
  static Delta _parseToDelta(String text) {
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
