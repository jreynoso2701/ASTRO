import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/tarea_status.dart';
import 'package:astro/core/models/tarea_prioridad.dart';

/// Modelo de Tarea.
///
/// Colección Firestore: `Tareas/{docId}`.
class Tarea {
  const Tarea({
    required this.id,
    required this.folio,
    required this.titulo,
    required this.descripcion,
    required this.projectId,
    required this.projectName,
    required this.status,
    required this.prioridad,
    required this.createdByUid,
    required this.createdByName,
    this.moduleId,
    this.moduleName,
    this.assignedToUid,
    this.assignedToName,
    this.fechaEntrega,
    this.adjuntos = const [],
    this.refTicketId,
    this.refRequerimientoId,
    this.refMinutaId,
    this.refCompromisoNumero,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String folio;
  final String titulo;
  final String descripcion;
  final String projectId;
  final String projectName;
  final TareaStatus status;
  final TareaPrioridad prioridad;
  final String createdByUid;
  final String createdByName;

  // Opcionales
  final String? moduleId;
  final String? moduleName;
  final String? assignedToUid;
  final String? assignedToName;
  final DateTime? fechaEntrega;
  final List<String> adjuntos;

  // Referencias cruzadas
  final String? refTicketId;
  final String? refRequerimientoId;
  final String? refMinutaId;
  final int? refCompromisoNumero;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Tarea.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    List<String> parseList(dynamic value) {
      if (value is List) return value.whereType<String>().toList();
      return [];
    }

    return Tarea(
      id: doc.id,
      folio: data['folio'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      projectName: data['projectName'] as String? ?? '',
      status: TareaStatus.fromString(data['status'] as String?),
      prioridad: TareaPrioridad.fromString(data['prioridad'] as String?),
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      moduleId: data['moduleId'] as String?,
      moduleName: data['moduleName'] as String?,
      assignedToUid: data['assignedToUid'] as String?,
      assignedToName: data['assignedToName'] as String?,
      fechaEntrega: parseDate(data['fechaEntrega']),
      adjuntos: parseList(data['adjuntos']),
      refTicketId: data['refTicketId'] as String?,
      refRequerimientoId: data['refRequerimientoId'] as String?,
      refMinutaId: data['refMinutaId'] as String?,
      refCompromisoNumero: (data['refCompromisoNumero'] as num?)?.toInt(),
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
      'descripcion': descripcion,
      'projectId': projectId,
      'projectName': projectName,
      'status': status.name,
      'prioridad': prioridad.name,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      if (moduleId != null) 'moduleId': moduleId,
      if (moduleName != null) 'moduleName': moduleName,
      if (assignedToUid != null) 'assignedToUid': assignedToUid,
      if (assignedToName != null) 'assignedToName': assignedToName,
      if (fechaEntrega != null)
        'fechaEntrega': Timestamp.fromDate(fechaEntrega!),
      if (adjuntos.isNotEmpty) 'adjuntos': adjuntos,
      if (refTicketId != null) 'refTicketId': refTicketId,
      if (refRequerimientoId != null) 'refRequerimientoId': refRequerimientoId,
      if (refMinutaId != null) 'refMinutaId': refMinutaId,
      if (refCompromisoNumero != null)
        'refCompromisoNumero': refCompromisoNumero,
      'isActive': isActive,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  Tarea copyWith({
    String? folio,
    String? titulo,
    String? descripcion,
    String? projectId,
    String? projectName,
    TareaStatus? status,
    TareaPrioridad? prioridad,
    String? createdByUid,
    String? createdByName,
    String? moduleId,
    String? moduleName,
    String? assignedToUid,
    String? assignedToName,
    DateTime? fechaEntrega,
    List<String>? adjuntos,
    String? refTicketId,
    String? refRequerimientoId,
    String? refMinutaId,
    int? refCompromisoNumero,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tarea(
      id: id,
      folio: folio ?? this.folio,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      status: status ?? this.status,
      prioridad: prioridad ?? this.prioridad,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      moduleId: moduleId ?? this.moduleId,
      moduleName: moduleName ?? this.moduleName,
      assignedToUid: assignedToUid ?? this.assignedToUid,
      assignedToName: assignedToName ?? this.assignedToName,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      adjuntos: adjuntos ?? this.adjuntos,
      refTicketId: refTicketId ?? this.refTicketId,
      refRequerimientoId: refRequerimientoId ?? this.refRequerimientoId,
      refMinutaId: refMinutaId ?? this.refMinutaId,
      refCompromisoNumero: refCompromisoNumero ?? this.refCompromisoNumero,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
