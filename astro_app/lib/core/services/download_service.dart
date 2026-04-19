import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import 'package:astro/core/services/storage_service.dart';

/// Servicio para descargar archivos desde URLs de Firebase Storage.
///
/// - **Imágenes/videos:** se guardan en la galería del dispositivo.
/// - **Otros archivos:** se guardan en la carpeta de descargas.
/// - **Web:** no soporta descarga directa (usar url_launcher como fallback).
///
/// Usa Firebase Storage SDK (autenticado) como método primario para evitar
/// errores 403 por tokens de descarga invalidados.
class DownloadService {
  DownloadService({Dio? dio, StorageService? storageService})
    : _dio = dio ?? Dio(),
      _storageService = storageService ?? StorageService();

  final Dio _dio;
  final StorageService _storageService;

  /// Tipo de archivo derivado de la URL.
  static FileCategory categorize(String url) {
    final lower = _cleanUrl(url).toLowerCase();
    if (_imageExts.any((e) => lower.endsWith(e))) return FileCategory.image;
    if (_videoExts.any((e) => lower.endsWith(e))) return FileCategory.video;
    if (lower.endsWith('.pdf')) return FileCategory.pdf;
    return FileCategory.other;
  }

  /// Extrae el nombre del archivo desde una URL de Firebase Storage.
  static String fileName(String url) {
    try {
      final uri = Uri.parse(url);
      final path = Uri.decodeComponent(uri.pathSegments.last);
      final clean = path.split('?').first;
      // Firebase Storage URLs: encoded path may contain folder separators.
      return clean.contains('/') ? clean.split('/').last : clean;
    } catch (_) {
      return 'archivo';
    }
  }

  /// Descarga un archivo y lo guarda en la ubicación adecuada.
  ///
  /// Retorna la ruta local del archivo guardado.
  /// En web, retorna `null` (no soportado).
  Future<String?> download(
    String url, {
    String? customFileName,
    void Function(int received, int total)? onProgress,
  }) async {
    if (kIsWeb) return null;

    final name = customFileName ?? fileName(url);
    final category = categorize(url);

    // Descargar a directorio temporal.
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/$name';

    // Intentar con Firebase Storage SDK primero (autenticado).
    if (isFirebaseStorageUrl(url)) {
      try {
        final bytes = await _storageService.getBytesFromUrl(url);
        await File(tempPath).writeAsBytes(bytes);
      } catch (_) {
        // Fallback a Dio.
        await _dio.download(url, tempPath, onReceiveProgress: onProgress);
      }
    } else {
      await _dio.download(url, tempPath, onReceiveProgress: onProgress);
    }

    // Guardar según tipo.
    if (category == FileCategory.image || category == FileCategory.video) {
      await Gal.putImage(tempPath, album: 'ASTRO');
      // Limpiar temp.
      try {
        await File(tempPath).delete();
      } catch (_) {}
      return 'galería';
    }

    // Para PDFs y otros — mover a descargas.
    final downloadsDir = await _getDownloadsDirectory();
    final finalPath = '${downloadsDir.path}/$name';
    await File(tempPath).copy(finalPath);
    try {
      await File(tempPath).delete();
    } catch (_) {}
    return finalPath;
  }

  /// Descarga los bytes de un archivo.
  ///
  /// Usa Firebase Storage SDK (autenticado) como método primario.
  /// Si falla, intenta descarga directa con Dio como fallback.
  Future<Uint8List> downloadBytes(String url) async {
    // Intentar con Firebase Storage SDK (autenticado, sin depender de tokens).
    if (isFirebaseStorageUrl(url)) {
      try {
        return await _storageService.getBytesFromUrl(url);
      } catch (_) {
        // Fallback a Dio si el SDK falla.
      }
    }

    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  /// Verifica si una URL es de Firebase Storage.
  static bool isFirebaseStorageUrl(String url) {
    return url.contains('firebasestorage.googleapis.com') ||
        url.contains('firebasestorage.app') ||
        url.contains('storage.googleapis.com');
  }

  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // En Android, usar directorio de descargas externo.
      final dirs = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (dirs != null && dirs.isNotEmpty) return dirs.first;
    }
    // Fallback: directorio de aplicación.
    return getApplicationDocumentsDirectory();
  }

  static String _cleanUrl(String url) {
    // Remove query params (Firebase Storage URLs have token params).
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final path = uri.path;
    return path.split('?').first;
  }

  static const _imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  static const _videoExts = ['.mp4', '.mov', '.avi', '.mkv'];
}

/// Categoría de archivo para determinar el visor adecuado.
enum FileCategory { image, video, pdf, other }
