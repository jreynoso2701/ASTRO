/// Adjunto compartido agregado de tickets o requerimientos.
///
/// No se almacena en Firestore — se genera en tiempo real
/// al consultar los adjuntos de tickets y requerimientos.
class AdjuntoCompartido {
  const AdjuntoCompartido({
    required this.url,
    required this.origen,
    required this.origenId,
    required this.origenFolio,
    required this.origenTitulo,
    required this.projectName,
    this.nombre,
    this.uploadedAt,
    this.autorNombre,
    this.moduleName,
    this.origenStatus,
    this.origenPrioridad,
    this.createdAt,
  });

  final String url;

  /// 'ticket' o 'requerimiento'.
  final String origen;
  final String origenId;
  final String origenFolio;
  final String origenTitulo;
  final String projectName;
  final String? nombre;
  final DateTime? uploadedAt;

  /// Datos adicionales del origen.
  final String? autorNombre;
  final String? moduleName;
  final String? origenStatus;
  final String? origenPrioridad;
  final DateTime? createdAt;

  /// Etiqueta legible del origen.
  String get origenLabel => origen == 'ticket' ? 'Ticket' : 'Requerimiento';

  /// Extrae el nombre del archivo de la URL de Firebase Storage.
  String get displayName {
    if (nombre != null && nombre!.isNotEmpty) return nombre!;
    try {
      final uri = Uri.parse(url);
      // Firebase Storage URLs: /.../o/path%2Fto%2Ffile.jpg?alt=media&token=...
      // The last path segment before query is the encoded path.
      final fullPath = Uri.decodeComponent(uri.pathSegments.last);
      // Extract just the filename (after last /).
      final fileName = fullPath.contains('/')
          ? fullPath.split('/').last
          : fullPath;
      // Remove query if still attached.
      return fileName.split('?').first;
    } catch (_) {
      return 'Archivo adjunto';
    }
  }

  /// Detecta el tipo de archivo por extensión.
  String get tipoArchivo {
    final ext = displayName.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => 'imagen',
      'mp4' || 'mov' || 'avi' => 'video',
      'pdf' => 'pdf',
      'doc' || 'docx' => 'word',
      'xls' || 'xlsx' => 'excel',
      _ => 'archivo',
    };
  }
}
