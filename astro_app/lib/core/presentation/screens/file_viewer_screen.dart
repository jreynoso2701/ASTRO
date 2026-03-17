import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:astro/core/services/download_service.dart';

/// Visor universal de archivos.
///
/// Soporta:
/// - **Imágenes** (jpg, png, gif, webp): pinch-to-zoom con [InteractiveViewer].
/// - **Videos** (mp4, mov): reproductor nativo con controles.
/// - **PDFs**: visor scrollable con [PdfViewPinch].
/// - **Otros**: ícono + nombre + botones de abrir externo / descargar.
///
/// Uso:
/// ```dart
/// FileViewerScreen.open(context, url: '...', fileName: 'doc.pdf');
/// ```
class FileViewerScreen extends StatefulWidget {
  const FileViewerScreen({
    required this.url,
    this.fileName,
    this.heroTag,
    super.key,
  });

  final String url;
  final String? fileName;
  final String? heroTag;

  /// Atajo para navegar al visor.
  static void open(
    BuildContext context, {
    required String url,
    String? fileName,
    String? heroTag,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            FileViewerScreen(url: url, fileName: fileName, heroTag: heroTag),
      ),
    );
  }

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  late final FileCategory _category;
  late final String _displayName;

  bool _downloading = false;
  String? _downloadResult;

  @override
  void initState() {
    super.initState();
    _category = DownloadService.categorize(widget.url);
    _displayName = widget.fileName ?? DownloadService.fileName(widget.url);
  }

  // ── Descarga ───────────────────────────────────────────

  Future<void> _download() async {
    if (kIsWeb) {
      // En web, abrir en nueva pestaña.
      final uri = Uri.tryParse(widget.url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    setState(() {
      _downloading = true;
      _downloadResult = null;
    });

    try {
      final service = DownloadService();
      final result = await service.download(
        widget.url,
        customFileName: _displayName,
      );
      if (!mounted) return;

      setState(() {
        _downloading = false;
        _downloadResult = result;
      });

      final msg = result == 'galería'
          ? 'Guardado en galería (álbum ASTRO)'
          : 'Guardado en: $result';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al descargar: $e')));
    }
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Regresar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _displayName,
          style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_downloading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Descargar',
              onPressed: _download,
            ),
          if (_category == FileCategory.other)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Abrir externo',
              onPressed: _openExternal,
            ),
        ],
      ),
      body: SafeArea(
        child: switch (_category) {
          FileCategory.image => _ImageViewer(
            url: widget.url,
            heroTag: widget.heroTag,
          ),
          FileCategory.video => _VideoViewer(url: widget.url),
          FileCategory.pdf => _PdfViewer(url: widget.url),
          FileCategory.other => _OtherFileViewer(
            url: widget.url,
            fileName: _displayName,
            onDownload: _download,
            onOpenExternal: _openExternal,
            downloading: _downloading,
            downloadResult: _downloadResult,
          ),
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// IMAGE VIEWER — InteractiveViewer con zoom y pan
// ═══════════════════════════════════════════════════════════

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url, this.heroTag});
  final String url;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    Widget image = InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            final percent = progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null;
            return Center(
              child: CircularProgressIndicator(
                value: percent,
                color: Colors.white,
              ),
            );
          },
          errorBuilder: (_, __, ___) => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, size: 64, color: Colors.white54),
                SizedBox(height: 8),
                Text(
                  'No se pudo cargar la imagen',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    return image;
  }
}

// ═══════════════════════════════════════════════════════════
// VIDEO VIEWER — VideoPlayer con controles nativos
// ═══════════════════════════════════════════════════════════

class _VideoViewer extends StatefulWidget {
  const _VideoViewer({required this.url});
  final String url;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _initialized = true);
              _controller.play();
            }
          })
          .catchError((e) {
            if (mounted) setState(() => _error = e.toString());
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white54),
            const SizedBox(height: 8),
            Text(
              'Error al reproducir video',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
        // Controles.
        _VideoControls(controller: _controller),
      ],
    );
  }
}

class _VideoControls extends StatefulWidget {
  const _VideoControls({required this.controller});
  final VideoPlayerController controller;

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  late VideoPlayerController _c;

  @override
  void initState() {
    super.initState();
    _c = widget.controller;
    _c.addListener(_listener);
  }

  @override
  void dispose() {
    _c.removeListener(_listener);
    super.dispose();
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final pos = _c.value.position;
    final dur = _c.value.duration;

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.white,
              thumbColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: dur.inMilliseconds > 0
                  ? pos.inMilliseconds / dur.inMilliseconds
                  : 0,
              onChanged: (v) {
                _c.seekTo(
                  Duration(milliseconds: (v * dur.inMilliseconds).round()),
                );
              },
            ),
          ),
          Row(
            children: [
              Text(
                _fmt(pos),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                tooltip: _c.value.isPlaying ? 'Pausar' : 'Reproducir',
                icon: Icon(
                  _c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  _c.value.isPlaying ? _c.pause() : _c.play();
                },
              ),
              const Spacer(),
              Text(
                _fmt(dur),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// PDF VIEWER — PdfViewPinch con scroll y zoom
// ═══════════════════════════════════════════════════════════

class _PdfViewer extends StatefulWidget {
  const _PdfViewer({required this.url});
  final String url;

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  PdfControllerPinch? _pdfController;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final service = DownloadService();
      final bytes = await service.downloadBytes(widget.url);
      if (!mounted) return;

      final document = PdfDocument.openData(bytes);
      _pdfController = PdfControllerPinch(document: document);
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(widget.url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // On web, if pdfx fails, show fallback to open in browser.
    if (_error != null || _pdfController == null) {
      if (kIsWeb) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'El PDF no se puede mostrar aquí',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ábrelo directamente en tu navegador',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir PDF'),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white54),
            const SizedBox(height: 8),
            const Text(
              'No se pudo cargar el PDF',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return PdfViewPinch(
      controller: _pdfController!,
      padding: 8,
      scrollDirection: Axis.vertical,
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        pageLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorBuilder: (_, error) => Center(
          child: Text(
            error.toString(),
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// OTHER FILE VIEWER — Ícono + nombre + acciones
// ═══════════════════════════════════════════════════════════

class _OtherFileViewer extends StatelessWidget {
  const _OtherFileViewer({
    required this.url,
    required this.fileName,
    required this.onDownload,
    required this.onOpenExternal,
    required this.downloading,
    this.downloadResult,
  });

  final String url;
  final String fileName;
  final VoidCallback onDownload;
  final VoidCallback onOpenExternal;
  final bool downloading;
  final String? downloadResult;

  IconData _iconForFile() {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return Icons.table_chart_outlined;
    }
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
      return Icons.slideshow_outlined;
    }
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForFile(), size: 80, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              fileName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Este tipo de archivo no tiene vista previa',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: downloading ? null : onDownload,
                  icon: downloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: const Text('Descargar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onOpenExternal,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir externo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                ),
              ],
            ),
            if (downloadResult != null) ...[
              const SizedBox(height: 16),
              Text(
                '✓ Descargado',
                style: const TextStyle(color: Colors.green, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
