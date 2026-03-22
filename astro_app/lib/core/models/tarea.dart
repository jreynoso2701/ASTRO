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
    this.refTickets = const [],
    this.refRequerimientos = const [],
    this.refMinutas = const [],
    this.refCitas = const [],
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

  // Referencias cruzadas (listas — admite múltiples vínculos)
  final List<String> refTickets;
  final List<String> refRequerimientos;
  final List<String> refMinutas;
  final List<String> refCitas;
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

    /// Migración: si existe la lista nueva la usa; si no, hereda el campo viejo.
    List<String> parseRefList(dynamic listVal, dynamic singleVal) {
      final list = parseList(listVal);
      if (list.isNotEmpty) return list;
      if (singleVal is String && singleVal.isNotEmpty) return [singleVal];
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
      refTickets: parseRefList(data['refTickets'], data['refTicketId']),
      refRequerimientos: parseRefList(
        data['refRequerimientos'],
        data['refRequerimientoId'],
      ),
      refMinutas: parseRefList(data['refMinutas'], data['refMinutaId']),
      refCitas: parseList(data['refCitas']),
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
      if (refTickets.isNotEmpty) 'refTickets': refTickets,
      if (refRequerimientos.isNotEmpty) 'refRequerimientos': refRequerimientos,
      if (refMinutas.isNotEmpty) 'refMinutas': refMinutas,
      if (refCitas.isNotEmpty) 'refCitas': refCitas,
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
    List<String>? refTickets,
    List<String>? refRequerimientos,
    List<String>? refMinutas,
    List<String>? refCitas,
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
      refTickets: refTickets ?? this.refTickets,
      refRequerimientos: refRequerimientos ?? this.refRequerimientos,
      refMinutas: refMinutas ?? this.refMinutas,
      refCitas: refCitas ?? this.refCitas,
      refCompromisoNumero: refCompromisoNumero ?? this.refCompromisoNumero,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
