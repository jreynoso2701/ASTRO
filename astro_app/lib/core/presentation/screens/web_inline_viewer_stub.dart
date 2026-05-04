// Stub para plataformas no-web. Nunca se invoca cuando kIsWeb es false.
import 'package:flutter/material.dart';

/// Embebe un PDF/imagen vía iframe HTML (solo web).
///
/// En no-web devuelve un placeholder que indica que no aplica.
class WebInlineViewer extends StatelessWidget {
  const WebInlineViewer({required this.url, this.fileName, super.key});

  final String url;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Vista inline solo disponible en web',
        style: TextStyle(color: Colors.white54),
      ),
    );
  }
}
