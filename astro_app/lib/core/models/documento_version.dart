import 'package:cloud_firestore/cloud_firestore.dart';

/// Versión de un documento formal.
class DocumentoVersion {
  const DocumentoVersion({
    required this.version,
    required this.url,
    required this.nombre,
    required this.subidoPor,
    required this.subidoPorNombre,
    required this.fecha,
    this.notas,
    this.size,
  });

  final int version;
  final String url;
  final String nombre;
  final String subidoPor;
  final String subidoPorNombre;
  final DateTime fecha;
  final String? notas;
  final int? size;

  factory DocumentoVersion.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return DocumentoVersion(
      version: (data['version'] as num?)?.toInt() ?? 1,
      url: data['url'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      subidoPor: data['subidoPor'] as String? ?? '',
      subidoPorNombre: data['subidoPorNombre'] as String? ?? '',
      fecha: parseDate(data['fecha']) ?? DateTime.now(),
      notas: data['notas'] as String?,
      size: (data['size'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'version': version,
    'url': url,
    'nombre': nombre,
    'subidoPor': subidoPor,
    'subidoPorNombre': subidoPorNombre,
    'fecha': Timestamp.fromDate(fecha),
    if (notas != null) 'notas': notas,
    if (size != null) 'size': size,
  };
}
