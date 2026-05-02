import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/documento_seccion.dart';
import 'package:astro/core/models/documento_version.dart';

/// Modelo de documento de proyecto.
///
/// Colección Firestore: `DocumentosProyecto/{docId}`.
/// Documentos formales con versionado (memorias técnicas, contratos, etc.).
class DocumentoProyecto {
  const DocumentoProyecto({
    required this.id,
    required this.folio,
    required this.titulo,
    required this.seccion,
    required this.categoria,
    required this.projectName,
    required this.projectId,
    required this.createdBy,
    required this.createdByName,
    this.descripcion,
    this.empresaName,
    this.archivoUrl,
    this.archivoNombre,
    this.archivoTipo,
    this.archivoSize,
    this.versionActual = 1,
    this.versiones = const [],
    this.etiquetaIds = const [],
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String folio;
  final String titulo;
  final String? descripcion;
  final DocumentoSeccion seccion;
  final String categoria; // Puede ser default o personalizada
  final String projectName;
  final String projectId;
  final String? empresaName;
  final String createdBy;
  final String createdByName;

  // Archivo actual (última versión)
  final String? archivoUrl;
  final String? archivoNombre;
  final String? archivoTipo;
  final int? archivoSize;

  // Versionado
  final int versionActual;
  final List<DocumentoVersion> versiones;

  // Etiquetas
  final List<String> etiquetaIds;

  // Control
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DocumentoProyecto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    List<DocumentoVersion> parseVersiones(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map(DocumentoVersion.fromMap)
            .toList();
      }
      return [];
    }

    return DocumentoProyecto(
      id: doc.id,
      folio: data['folio'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String?,
      seccion: DocumentoSeccion.fromString(
        data['seccion'] as String? ?? 'Formal',
      ),
      categoria: data['categoria'] as String? ?? 'Otro',
      projectName: data['projectName'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      empresaName: data['empresaName'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      archivoUrl: data['archivoUrl'] as String?,
      archivoNombre: data['archivoNombre'] as String?,
      archivoTipo: data['archivoTipo'] as String?,
      archivoSize: (data['archivoSize'] as num?)?.toInt(),
      versionActual: (data['versionActual'] as num?)?.toInt() ?? 1,
      versiones: parseVersiones(data['versiones']),
      etiquetaIds:
          (data['etiquetaIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [],
      isActive: data['isActive'] as bool? ?? true,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final now = DateTime.now();
    return {
      'folio': folio,
      'titulo': titulo,
      if (descripcion != null) 'descripcion': descripcion,
      'seccion': seccion.label,
      'categoria': categoria,
      'projectName': projectName,
      'projectId': projectId,
      if (empresaName != null) 'empresaName': empresaName,
      'createdBy': createdBy,
      'createdByName': createdByName,
      if (archivoUrl != null) 'archivoUrl': archivoUrl,
      if (archivoNombre != null) 'archivoNombre': archivoNombre,
      if (archivoTipo != null) 'archivoTipo': archivoTipo,
      if (archivoSize != null) 'archivoSize': archivoSize,
      'versionActual': versionActual,
      'versiones': versiones.map((v) => v.toMap()).toList(),
      'etiquetaIds': etiquetaIds,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  DocumentoProyecto copyWith({
    String? folio,
    String? titulo,
    String? descripcion,
    DocumentoSeccion? seccion,
    String? categoria,
    String? projectName,
    String? projectId,
    String? empresaName,
    String? createdBy,
    String? createdByName,
    String? archivoUrl,
    String? archivoNombre,
    String? archivoTipo,
    int? archivoSize,
    int? versionActual,
    List<DocumentoVersion>? versiones,
    List<String>? etiquetaIds,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentoProyecto(
      id: id,
      folio: folio ?? this.folio,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      seccion: seccion ?? this.seccion,
      categoria: categoria ?? this.categoria,
      projectName: projectName ?? this.projectName,
      projectId: projectId ?? this.projectId,
      empresaName: empresaName ?? this.empresaName,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      archivoUrl: archivoUrl ?? this.archivoUrl,
      archivoNombre: archivoNombre ?? this.archivoNombre,
      archivoTipo: archivoTipo ?? this.archivoTipo,
      archivoSize: archivoSize ?? this.archivoSize,
      versionActual: versionActual ?? this.versionActual,
      versiones: versiones ?? this.versiones,
      etiquetaIds: etiquetaIds ?? this.etiquetaIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
