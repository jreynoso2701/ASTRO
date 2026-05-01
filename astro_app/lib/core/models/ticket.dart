import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';

/// Modelo de Ticket / Incidente.
///
/// Colección Firestore: `Incidentes/{docId}` (V1 compat).
class Ticket {
  const Ticket({
    required this.id,
    required this.folio,
    required this.titulo,
    required this.descripcion,
    required this.projectName,
    required this.moduleName,
    required this.status,
    required this.priority,
    required this.createdByName,
    this.projectId,
    this.moduleId,
    this.createdBy,
    this.assignedTo,
    this.assignedToName,
    this.empresaName,
    this.cobertura,
    this.impacto,
    this.evidencias = const [],
    this.refMinutas = const [],
    this.refCitas = const [],
    this.etiquetaIds = const [],
    this.solucionProgramada,
    this.porcentajeAvance = 0,
    this.isActive = true,
    this.commentCount = 0,
    this.archiveReason,
    this.archivedByName,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
  });

  final String id;
  final String folio; // V1: folioIncidente
  final String titulo; // V1: tituloIncidente
  final String descripcion; // V1: explicacionIncidente
  final String projectName; // V1: fkxProyecto
  final String moduleName; // V1: fkxModulo
  final TicketStatus status; // V1: estatusIncidente
  final TicketPriority priority; // V1: prioridadIncidente
  final String createdByName; // V1: fkxUsuarioReporta

  // Campos opcionales (V2 o complementarios)
  final String? projectId;
  final String? moduleId;
  final String? createdBy; // UID (V2)
  final String? assignedTo; // UID de Soporte (V2)
  final String? assignedToName; // V1: fkxSoporte
  final String? empresaName; // V1: fkxEmpresa
  final String? cobertura; // V1: fkxCobertura
  final int? impacto; // V1: impacto
  final List<String> evidencias; // V1: evidenciasIncidente
  final List<String> refMinutas; // IDs de minutas vinculadas
  final List<String> refCitas; // IDs de citas vinculadas
  final List<String> etiquetaIds; // IDs de etiquetas asignadas
  final String? solucionProgramada; // V1: fhCompromisoSol
  final double porcentajeAvance; // V1: porcentajeAvance (0-100)
  final bool isActive;
  final int commentCount; // Contador desnormalizado de comentarios
  final String? archiveReason; // Justificación de archivado
  final String? archivedByName; // Quién archivó
  final DateTime? createdAt; // V1: fhRegistro (string)
  final DateTime? updatedAt; // V1: fhActualizacion (string)
  final DateTime? closedAt;

  factory Ticket.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) {
        final iso = DateTime.tryParse(value);
        if (iso != null) return iso;
        return _parseV1Date(value);
      }
      return null;
    }

    List<String> parseList(dynamic value) {
      if (value is List) return value.whereType<String>().toList();
      return [];
    }

    return Ticket(
      id: doc.id,
      folio:
          data['folioIncidente'] as String? ?? data['folio'] as String? ?? '',
      titulo:
          data['tituloIncidente'] as String? ?? data['titulo'] as String? ?? '',
      descripcion:
          data['explicacionIncidente'] as String? ??
          data['descripcion'] as String? ??
          '',
      projectName:
          data['fkxProyecto'] as String? ??
          data['projectName'] as String? ??
          '',
      moduleName:
          data['fkxModulo'] as String? ?? data['moduleName'] as String? ?? '',
      status: TicketStatus.fromString(
        data['estatusIncidente'] as String? ??
            data['status'] as String? ??
            'PENDIENTE',
      ),
      priority: TicketPriority.fromString(
        data['prioridadIncidente'] as String? ??
            data['priority'] as String? ??
            'NORMAL',
      ),
      createdByName:
          data['fkxUsuarioReporta'] as String? ??
          data['createdByName'] as String? ??
          '',
      projectId: data['projectId'] as String?,
      moduleId: data['moduleId'] as String?,
      createdBy: data['createdBy'] as String?,
      assignedTo: data['assignedTo'] as String?,
      assignedToName:
          data['fkxSoporte'] as String? ?? data['assignedToName'] as String?,
      empresaName: data['fkxEmpresa'] as String?,
      cobertura: data['fkxCobertura'] as String?,
      impacto: data['impacto'] is int
          ? data['impacto'] as int
          : (data['impacto'] is num ? (data['impacto'] as num).toInt() : null),
      evidencias: parseList(data['evidenciasIncidente']),
      refMinutas: parseList(data['refMinutas']),
      refCitas: parseList(data['refCitas']),
      etiquetaIds: parseList(data['etiquetaIds']),
      solucionProgramada: _parseDateString(data['fhCompromisoSol']),
      porcentajeAvance: _parseDouble(data['porcentajeAvance']) ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      archiveReason: data['archiveReason'] as String?,
      archivedByName: data['archivedByName'] as String?,
      createdAt: parseDate(data['fhRegistro'] ?? data['createdAt']),
      updatedAt: parseDate(data['fhActualizacion'] ?? data['updatedAt']),
      closedAt: parseDate(data['closedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final now = DateTime.now();
    return {
      // V1 fields
      'folioIncidente': folio,
      'tituloIncidente': titulo,
      'explicacionIncidente': descripcion,
      'fkxProyecto': projectName,
      'fkxModulo': moduleName,
      'estatusIncidente': status.v1Label,
      'prioridadIncidente': priority.v1Label,
      'fkxUsuarioReporta': createdByName,
      if (assignedToName != null) 'fkxSoporte': assignedToName,
      if (empresaName != null) 'fkxEmpresa': empresaName,
      if (cobertura != null) 'fkxCobertura': cobertura,
      if (impacto != null) 'impacto': impacto,
      if (evidencias.isNotEmpty) 'evidenciasIncidente': evidencias,
      if (refMinutas.isNotEmpty) 'refMinutas': refMinutas,
      if (refCitas.isNotEmpty) 'refCitas': refCitas,
      if (etiquetaIds.isNotEmpty) 'etiquetaIds': etiquetaIds,
      if (solucionProgramada != null) 'fhCompromisoSol': solucionProgramada,
      'porcentajeAvance': porcentajeAvance,
      'isActive': isActive,
      'commentCount': commentCount,
      if (archiveReason != null) 'archiveReason': archiveReason,
      if (archivedByName != null) 'archivedByName': archivedByName,
      'fhRegistro': createdAt != null
          ? _toV1DateString(createdAt!)
          : _toV1DateString(now),
      'fhActualizacion': _toV1DateString(now),
      // V2 fields
      if (projectId != null) 'projectId': projectId,
      if (moduleId != null) 'moduleId': moduleId,
      if (createdBy != null) 'createdBy': createdBy,
      if (assignedTo != null) 'assignedTo': assignedTo,
      if (assignedToName != null) 'assignedToName': assignedToName,
      'createdByName': createdByName,
      'projectName': projectName,
      'moduleName': moduleName,
      'status': status.label,
      'priority': priority.label,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': Timestamp.fromDate(now),
      if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
    };
  }

  Ticket copyWith({
    String? folio,
    String? titulo,
    String? descripcion,
    String? projectName,
    String? moduleName,
    String? projectId,
    String? moduleId,
    TicketStatus? status,
    TicketPriority? priority,
    String? createdByName,
    String? createdBy,
    String? assignedTo,
    String? assignedToName,
    String? empresaName,
    String? cobertura,
    int? impacto,
    List<String>? evidencias,
    List<String>? refMinutas,
    List<String>? refCitas,
    List<String>? etiquetaIds,
    String? solucionProgramada,
    double? porcentajeAvance,
    bool? isActive,
    int? commentCount,
    String? archiveReason,
    String? archivedByName,
    DateTime? updatedAt,
    DateTime? closedAt,
  }) {
    return Ticket(
      id: id,
      folio: folio ?? this.folio,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      projectName: projectName ?? this.projectName,
      moduleName: moduleName ?? this.moduleName,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdByName: createdByName ?? this.createdByName,
      projectId: projectId ?? this.projectId,
      moduleId: moduleId ?? this.moduleId,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      empresaName: empresaName ?? this.empresaName,
      cobertura: cobertura ?? this.cobertura,
      impacto: impacto ?? this.impacto,
      evidencias: evidencias ?? this.evidencias,
      refMinutas: refMinutas ?? this.refMinutas,
      refCitas: refCitas ?? this.refCitas,
      etiquetaIds: etiquetaIds ?? this.etiquetaIds,
      solucionProgramada: solucionProgramada ?? this.solucionProgramada,
      porcentajeAvance: porcentajeAvance ?? this.porcentajeAvance,
      isActive: isActive ?? this.isActive,
      commentCount: commentCount ?? this.commentCount,
      archiveReason: archiveReason ?? this.archiveReason,
      archivedByName: archivedByName ?? this.archivedByName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Convierte un campo Firestore (Timestamp, String, etc.) a String de fecha.
  /// Normaliza al formato "año/mes/día" para compatibilidad.
  static String? _parseDateString(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      final dt = value.toDate();
      return '${dt.year}/${dt.month}/${dt.day}';
    }
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  /// Parse V1 date string: "2025/7/18 11:12"
  static DateTime? _parseV1Date(String value) {
    try {
      final parts = value.split(' ');
      final dateParts = parts[0].split('/');
      if (dateParts.length < 3) return null;
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      if (parts.length > 1 && parts[1].contains(':')) {
        final timeParts = parts[1].split(':');
        return DateTime(
          year,
          month,
          day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
      }
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Format DateTime to V1 string: "2025/7/18 11:12"
  static String _toV1DateString(DateTime dt) {
    return '${dt.year}/${dt.month}/${dt.day} '
        '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
