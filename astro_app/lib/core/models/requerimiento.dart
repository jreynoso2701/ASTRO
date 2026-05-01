import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/requerimiento_status.dart';
import 'package:astro/core/models/requerimiento_tipo.dart';
import 'package:astro/core/models/requerimiento_fase.dart';
import 'package:astro/core/models/ticket_priority.dart';

/// Criterio de aceptación de un requerimiento.
class CriterioAceptacion {
  const CriterioAceptacion({
    required this.id,
    required this.texto,
    this.completado = false,
    this.orden = 0,
  });

  final String id;
  final String texto;
  final bool completado;
  final int orden;

  factory CriterioAceptacion.fromMap(Map<String, dynamic> data) {
    return CriterioAceptacion(
      id: data['id'] as String? ?? '',
      texto: data['texto'] as String? ?? '',
      completado: data['completado'] as bool? ?? false,
      orden: (data['orden'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'texto': texto,
    'completado': completado,
    'orden': orden,
  };

  CriterioAceptacion copyWith({String? texto, bool? completado, int? orden}) {
    return CriterioAceptacion(
      id: id,
      texto: texto ?? this.texto,
      completado: completado ?? this.completado,
      orden: orden ?? this.orden,
    );
  }
}

/// Participante de un levantamiento de requerimiento.
class Participante {
  const Participante({required this.uid, required this.nombre, this.rol});

  final String uid;
  final String nombre;
  final String? rol; // Rol en el levantamiento, no del sistema

  factory Participante.fromMap(Map<String, dynamic> data) {
    return Participante(
      uid: data['uid'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      rol: data['rol'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'nombre': nombre,
    if (rol != null) 'rol': rol,
  };
}

/// Modelo de Requerimiento.
///
/// Colección Firestore: `Requerimientos/{docId}` (nueva — sin V1 legacy).
class Requerimiento {
  const Requerimiento({
    required this.id,
    required this.folio,
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.prioridad,
    required this.status,
    required this.projectName,
    required this.createdByName,
    this.moduleName,
    this.moduloPropuesto,
    this.faseAsignada,
    this.projectId,
    this.moduleId,
    this.createdBy,
    this.empresaName,
    this.assignedTo,
    this.assignedToName,
    this.porcentajeAvance = 0,
    this.porcentajeManual = false,
    this.criteriosAceptacion = const [],
    this.participantes = const [],
    this.adjuntos = const [],
    this.refMinutas = const [],
    this.refCitas = const [],
    this.etiquetaIds = const [],
    this.fechaCompromiso,
    this.motivoRechazo,
    this.observacionesRoot,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String folio;
  final String titulo;
  final String descripcion;
  final RequerimientoTipo tipo;
  final TicketPriority prioridad;
  final RequerimientoStatus status;
  final String projectName;
  final String createdByName;

  // Módulo
  final String? moduleName; // Módulo existente
  final String? moduloPropuesto; // Módulo propuesto (nuevo)
  final RequerimientoFase? faseAsignada; // Solo Root asigna

  // IDs (para navegación directa)
  final String? projectId;
  final String? moduleId;
  final String? createdBy; // UID
  final String? empresaName;

  // Responsable de implementación
  final String? assignedTo; // UID
  final String? assignedToName;

  // Progreso
  final double porcentajeAvance; // 0–100, auto-cálculo o manual
  final bool porcentajeManual; // true = override manual

  // Criterios de aceptación (checklist)
  final List<CriterioAceptacion> criteriosAceptacion;

  // Participantes del levantamiento
  final List<Participante> participantes;

  // Adjuntos (URLs a Storage)
  final List<String> adjuntos;

  // Vínculos futuros (Fase 2)
  final List<String> refMinutas;
  final List<String> refCitas;

  // Etiquetas asignadas
  final List<String> etiquetaIds;

  // Fecha compromiso (obligatoria para En Desarrollo, Implementado, Completado)
  final DateTime? fechaCompromiso;

  // Disposición Root
  final String? motivoRechazo;
  final String? observacionesRoot; // Solo visible para Root/Soporte

  // Control
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Porcentaje calculado: si es manual, usa el campo; si no, calcula desde criterios.
  double get porcentajeCalculado {
    if (porcentajeManual) return porcentajeAvance;
    if (criteriosAceptacion.isEmpty) return porcentajeAvance;
    final completados = criteriosAceptacion.where((c) => c.completado).length;
    return (completados / criteriosAceptacion.length) * 100;
  }

  factory Requerimiento.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    List<String> parseStrList(dynamic value) {
      if (value is List) return value.whereType<String>().toList();
      return [];
    }

    List<CriterioAceptacion> parseCriterios(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map(CriterioAceptacion.fromMap)
            .toList();
      }
      return [];
    }

    List<Participante> parseParticipantes(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map(Participante.fromMap)
            .toList();
      }
      return [];
    }

    return Requerimiento(
      id: doc.id,
      folio: data['folio'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      tipo: RequerimientoTipo.fromString(data['tipo'] as String? ?? ''),
      prioridad: TicketPriority.fromString(
        data['prioridad'] as String? ?? 'NORMAL',
      ),
      status: RequerimientoStatus.fromString(data['status'] as String? ?? ''),
      projectName: data['projectName'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      moduleName: data['moduleName'] as String?,
      moduloPropuesto: data['moduloPropuesto'] as String?,
      faseAsignada: RequerimientoFase.fromString(
        data['faseAsignada'] as String?,
      ),
      projectId: data['projectId'] as String?,
      moduleId: data['moduleId'] as String?,
      createdBy: data['createdBy'] as String?,
      empresaName: data['empresaName'] as String?,
      assignedTo: data['assignedTo'] as String?,
      assignedToName: data['assignedToName'] as String?,
      porcentajeAvance: _parseDouble(data['porcentajeAvance']) ?? 0,
      porcentajeManual: data['porcentajeManual'] as bool? ?? false,
      criteriosAceptacion: parseCriterios(data['criteriosAceptacion']),
      participantes: parseParticipantes(data['participantes']),
      adjuntos: parseStrList(data['adjuntos']),
      refMinutas: parseStrList(data['refMinutas']),
      refCitas: parseStrList(data['refCitas']),
      etiquetaIds: parseStrList(data['etiquetaIds']),
      fechaCompromiso: parseDate(data['fechaCompromiso']),
      motivoRechazo: data['motivoRechazo'] as String?,
      observacionesRoot: data['observacionesRoot'] as String?,
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
      'tipo': tipo.label,
      'prioridad': prioridad.label,
      'status': status.label,
      'projectName': projectName,
      'createdByName': createdByName,
      if (moduleName != null) 'moduleName': moduleName,
      if (moduloPropuesto != null) 'moduloPropuesto': moduloPropuesto,
      if (faseAsignada != null) 'faseAsignada': faseAsignada!.label,
      if (projectId != null) 'projectId': projectId,
      if (moduleId != null) 'moduleId': moduleId,
      if (createdBy != null) 'createdBy': createdBy,
      if (empresaName != null) 'empresaName': empresaName,
      if (assignedTo != null) 'assignedTo': assignedTo,
      if (assignedToName != null) 'assignedToName': assignedToName,
      'porcentajeAvance': porcentajeAvance,
      'porcentajeManual': porcentajeManual,
      'criteriosAceptacion': criteriosAceptacion.map((c) => c.toMap()).toList(),
      'participantes': participantes.map((p) => p.toMap()).toList(),
      if (adjuntos.isNotEmpty) 'adjuntos': adjuntos,
      if (refMinutas.isNotEmpty) 'refMinutas': refMinutas,
      if (refCitas.isNotEmpty) 'refCitas': refCitas,
      if (etiquetaIds.isNotEmpty) 'etiquetaIds': etiquetaIds,
      if (fechaCompromiso != null)
        'fechaCompromiso': Timestamp.fromDate(fechaCompromiso!),
      if (motivoRechazo != null) 'motivoRechazo': motivoRechazo,
      if (observacionesRoot != null) 'observacionesRoot': observacionesRoot,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  Requerimiento copyWith({
    String? folio,
    String? titulo,
    String? descripcion,
    RequerimientoTipo? tipo,
    TicketPriority? prioridad,
    RequerimientoStatus? status,
    String? projectName,
    String? createdByName,
    String? moduleName,
    String? moduloPropuesto,
    RequerimientoFase? faseAsignada,
    String? projectId,
    String? moduleId,
    String? createdBy,
    String? empresaName,
    String? assignedTo,
    String? assignedToName,
    double? porcentajeAvance,
    bool? porcentajeManual,
    List<CriterioAceptacion>? criteriosAceptacion,
    List<Participante>? participantes,
    List<String>? adjuntos,
    List<String>? refMinutas,
    List<String>? refCitas,
    List<String>? etiquetaIds,
    DateTime? fechaCompromiso,
    String? motivoRechazo,
    String? observacionesRoot,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Requerimiento(
      id: id,
      folio: folio ?? this.folio,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      tipo: tipo ?? this.tipo,
      prioridad: prioridad ?? this.prioridad,
      status: status ?? this.status,
      projectName: projectName ?? this.projectName,
      createdByName: createdByName ?? this.createdByName,
      moduleName: moduleName ?? this.moduleName,
      moduloPropuesto: moduloPropuesto ?? this.moduloPropuesto,
      faseAsignada: faseAsignada ?? this.faseAsignada,
      projectId: projectId ?? this.projectId,
      moduleId: moduleId ?? this.moduleId,
      createdBy: createdBy ?? this.createdBy,
      empresaName: empresaName ?? this.empresaName,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      porcentajeAvance: porcentajeAvance ?? this.porcentajeAvance,
      porcentajeManual: porcentajeManual ?? this.porcentajeManual,
      criteriosAceptacion: criteriosAceptacion ?? this.criteriosAceptacion,
      participantes: participantes ?? this.participantes,
      adjuntos: adjuntos ?? this.adjuntos,
      refMinutas: refMinutas ?? this.refMinutas,
      refCitas: refCitas ?? this.refCitas,
      etiquetaIds: etiquetaIds ?? this.etiquetaIds,
      fechaCompromiso: fechaCompromiso ?? this.fechaCompromiso,
      motivoRechazo: motivoRechazo ?? this.motivoRechazo,
      observacionesRoot: observacionesRoot ?? this.observacionesRoot,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return null;
  }
}
