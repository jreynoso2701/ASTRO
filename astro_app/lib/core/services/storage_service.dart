import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

/// Servicio para subir archivos a Firebase Storage.
///
/// Ruta de almacenamiento: `incidentes/{ticketId}/evidencias/{filename}`.
class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Sube un archivo [XFile] y retorna la URL de descarga.
  Future<String> uploadEvidence(String ticketId, XFile file) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final name = file.name.isNotEmpty ? file.name : 'evidencia_$timestamp';
    final ref = _storage.ref('incidentes/$ticketId/evidencias/$name');

    final SettableMetadata metadata = SettableMetadata(
      contentType: _contentType(name),
    );

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await ref.putData(bytes, metadata);
    } else {
      await ref.putFile(File(file.path), metadata);
    }

    return ref.getDownloadURL();
  }

  /// Sube múltiples archivos y retorna lista de URLs.
  Future<List<String>> uploadMultipleEvidence(
    String ticketId,
    List<XFile> files,
  ) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadEvidence(ticketId, file);
      urls.add(url);
    }
    return urls;
  }

  /// Elimina un archivo por su URL de descarga.
  Future<void> deleteByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } on FirebaseException {
      // El archivo puede no existir; ignorar.
    }
  }

  static String _contentType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => 'application/octet-stream',
    };
  }
}
