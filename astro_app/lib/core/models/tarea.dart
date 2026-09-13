import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/subtarea.dart';
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
    this.assignedToUids = const [],
    this.assignedToNames = const [],
    this.fechaEntrega,
    this.adjuntos = const [],
    this.refTickets = const [],
    this.refRequerimientos = const [],
    this.refMinutas = const [],
    this.refCitas = const [],
    this.etiquetaIds = const [],
    this.refCompromisoNumero,
    this.subtareas = const [],
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
  /// Responsables de la tarea (múltiples). El primero se considera el
  /// responsable principal y se espeja en `assignedToUid` en Firestore
  /// para mantener compatibilidad con datos y consultas existentes.
  final List<String> assignedToUids;

  /// Nombres de los responsables, en el mismo orden que [assignedToUids].
  final List<String> assignedToNames;

  final DateTime? fechaEntrega;
  final List<String> adjuntos;

  // Referencias cruzadas (listas — admite múltiples vínculos)
  final List<String> refTickets;
  final List<String> refRequerimientos;
  final List<String> refMinutas;
  final List<String> refCitas;
  final int? refCompromisoNumero;

  // Etiquetas asignadas
  final List<String> etiquetaIds;

  // Subtareas embebidas
  final List<Subtarea> subtareas;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Helpers de responsables ──────────────────────────────

  /// Responsable principal (primero de la lista). `null` si no hay ninguno.
  String? get assignedToUid =>
      assignedToUids.isNotEmpty ? assignedToUids.first : null;

  /// Nombre del responsable principal.
  String? get assignedToName =>
      assignedToNames.isNotEmpty ? assignedToNames.first : null;

  /// Nombres de responsables separados por coma, o `null` si no hay ninguno.
  String? get assignedToLabel =>
      assignedToNames.isEmpty ? null : assignedToNames.join(', ');

  /// True si [uid] es uno de los responsables de la tarea.
  bool isAssignedTo(String? uid) =>
      uid != null && assignedToUids.contains(uid);

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
      assignedToUids: parseRefList(
        data['assignedToUids'],
        data['assignedToUid'],
      ),
      assignedToNames: parseRefList(
        data['assignedToNames'],
        data['assignedToName'],
      ),
      fechaEntrega: parseDate(data['fechaEntrega']),
      adjuntos: parseList(data['adjuntos']),
      refTickets: parseRefList(data['refTickets'], data['refTicketId']),
      refRequerimientos: parseRefList(
        data['refRequerimientos'],
        data['refRequerimientoId'],
      ),
      refMinutas: parseRefList(data['refMinutas'], data['refMinutaId']),
      refCitas: parseList(data['refCitas']),
      etiquetaIds: parseList(data['etiquetaIds']),
      refCompromisoNumero: (data['refCompromisoNumero'] as num?)?.toInt(),
      subtareas:
          (data['subtareas'] as List<dynamic>?)
              ?.map((e) => Subtarea.fromMap(e as Map<String, dynamic>))
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
      'descripcion': descripcion,
      'projectId': projectId,
      'projectName': projectName,
      'status': status.name,
      'prioridad': prioridad.name,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      if (moduleId != null) 'moduleId': moduleId,
      if (moduleName != null) 'moduleName': moduleName,
      // Listas de responsables (fuente de verdad).
      'assignedToUids': assignedToUids,
      'assignedToNames': assignedToNames,
      // Espejo del responsable principal para compatibilidad con consultas,
      // Cloud Functions y documentos históricos.
      'assignedToUid': assignedToUid,
      'assignedToName': assignedToName,
      if (fechaEntrega != null)
        'fechaEntrega': Timestamp.fromDate(fechaEntrega!),
      if (adjuntos.isNotEmpty) 'adjuntos': adjuntos,
      if (refTickets.isNotEmpty) 'refTickets': refTickets,
      if (refRequerimientos.isNotEmpty) 'refRequerimientos': refRequerimientos,
      if (refMinutas.isNotEmpty) 'refMinutas': refMinutas,
      if (refCitas.isNotEmpty) 'refCitas': refCitas,
      'etiquetaIds': etiquetaIds,
      if (refCompromisoNumero != null)
        'refCompromisoNumero': refCompromisoNumero,
      if (subtareas.isNotEmpty)
        'subtareas': subtareas.map((s) => s.toMap()).toList(),
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
    List<String>? assignedToUids,
    List<String>? assignedToNames,
    DateTime? fechaEntrega,
    List<String>? adjuntos,
    List<String>? refTickets,
    List<String>? refRequerimientos,
    List<String>? refMinutas,
    List<String>? refCitas,
    List<String>? etiquetaIds,
    int? refCompromisoNumero,
    List<Subtarea>? subtareas,
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
      assignedToUids: assignedToUids ?? this.assignedToUids,
      assignedToNames: assignedToNames ?? this.assignedToNames,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      adjuntos: adjuntos ?? this.adjuntos,
      refTickets: refTickets ?? this.refTickets,
      refRequerimientos: refRequerimientos ?? this.refRequerimientos,
      refMinutas: refMinutas ?? this.refMinutas,
      refCitas: refCitas ?? this.refCitas,
      etiquetaIds: etiquetaIds ?? this.etiquetaIds,
      refCompromisoNumero: refCompromisoNumero ?? this.refCompromisoNumero,
      subtareas: subtareas ?? this.subtareas,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
