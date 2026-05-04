// Implementación web del visor inline para PDFs e imágenes.
// Usa HtmlElementView + iframe nativo del navegador (renderiza PDFs sin
// depender de PDF.js worker o pdfx).
//
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WebInlineViewer extends StatefulWidget {
  const WebInlineViewer({required this.url, this.fileName, super.key});

  final String url;
  final String? fileName;

  @override
  State<WebInlineViewer> createState() => _WebInlineViewerState();
}

class _WebInlineViewerState extends State<WebInlineViewer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'astro-inline-${widget.url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';

    try {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final iframe = html.IFrameElement()
          ..src = widget.url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true;
        return iframe;
      });
    } catch (e) {
      // Si la fábrica ya estaba registrada (hot reload), ignoramos.
      if (kDebugMode) {
        debugPrint('WebInlineViewer registerViewFactory error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
