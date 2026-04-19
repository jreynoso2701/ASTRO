import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:astro/core/services/storage_service.dart';

/// Widget que carga imágenes desde Firebase Storage usando el SDK autenticado.
///
/// Resuelve el problema de tokens de descarga invalidados (error 403)
/// al usar [StorageService.getBytesFromUrl] en lugar de URLs directas.
///
/// Uso:
/// ```dart
/// StorageImage(url: firebaseUrl, width: 80, height: 80)
/// ```
class StorageImage extends StatefulWidget {
  const StorageImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  static final Map<String, Uint8List> _cache = {};

  Uint8List? _bytes;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(StorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    // Revisar caché en memoria.
    final cached = _cache[widget.url];
    if (cached != null) {
      if (mounted)
        setState(() {
          _bytes = cached;
          _loading = false;
        });
      return;
    }

    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final storage = StorageService();
      final bytes = await storage.getBytesFromUrl(widget.url);
      _cache[widget.url] = bytes;
      if (mounted)
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _hasError = true;
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_loading) {
      child =
          widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
    } else if (_hasError || _bytes == null) {
      child =
          widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image,
              size: 24,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
    } else {
      child = Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
      );
    }

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    return child;
  }
}
