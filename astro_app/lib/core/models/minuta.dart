import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/compromiso_status.dart';
import 'package:astro/core/models/minuta_modalidad.dart';

/// Asistente de una minuta de reunión.
class AsistenteMinuta {
  const AsistenteMinuta({
    required this.nombre,
    required this.puesto,
    this.uid,
    this.asistencia = true,
    this.firmaMotivo,
  });

  final String? uid; // null para personas externas no registradas
  final String nombre;
  final String puesto; // Empresa u organización
  final bool asistencia;
  final String? firmaMotivo;

  factory AsistenteMinuta.fromMap(Map<String, dynamic> data) {
    return AsistenteMinuta(
      uid: data['uid'] as String?,
      nombre: data['nombre'] as String? ?? '',
      puesto: data['puesto'] as String? ?? '',
      asistencia: data['asistencia'] as bool? ?? true,
      firmaMotivo: data['firmaMotivo'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    if (uid != null) 'uid': uid,
    'nombre': nombre,
    'puesto': puesto,
    'asistencia': asistencia,
    if (firmaMotivo != null) 'firmaMotivo': firmaMotivo,
  };

  AsistenteMinuta copyWith({
    String? uid,
    String? nombre,
    String? puesto,
    bool? asistencia,
    String? firmaMotivo,
  }) {
    return AsistenteMinuta(
      uid: uid ?? this.uid,
      nombre: nombre ?? this.nombre,
      puesto: puesto ?? this.puesto,
      asistencia: asistencia ?? this.asistencia,
      firmaMotivo: firmaMotivo ?? this.firmaMotivo,
    );
  }
}

/// Asunto tratado en la reunión.
class AsuntoTratado {
  const AsuntoTratado({
    required this.numero,
    required this.texto,
    this.subitems = const [],
  });

  final int numero;
  final String texto;
  final List<String> subitems;

  factory AsuntoTratado.fromMap(Map<String, dynamic> data) {
    return AsuntoTratado(
      numero: (data['numero'] as num?)?.toInt() ?? 0,
      texto: data['texto'] as String? ?? '',
      subitems: (data['subitems'] is List)
          ? (data['subitems'] as List).whereType<String>().toList()
          : [],
    );
  }

  Map<String, dynamic> toMap() => {
    'numero': numero,
    'texto': texto,
    'subitems': subitems,
  };

  AsuntoTratado copyWith({int? numero, String? texto, List<String>? subitems}) {
    return AsuntoTratado(
      numero: numero ?? this.numero,
      texto: texto ?? this.texto,
      subitems: subitems ?? this.subitems,
    );
  }
}

/// Compromiso asumido en la minuta con seguimiento de estado.
class CompromisoMinuta {
  const CompromisoMinuta({
    required this.numero,
    required this.tarea,
    required this.responsable,
    this.fechaEntrega,
    this.status = CompromisoStatus.pendiente,
  });

  final int numero;
  final String tarea;
  final String responsable;
  final DateTime? fechaEntrega;
  final CompromisoStatus status;

  factory CompromisoMinuta.fromMap(Map<String, dynamic> data) {
    return CompromisoMinuta(
      numero: (data['numero'] as num?)?.toInt() ?? 0,
      tarea: data['tarea'] as String? ?? '',
      responsable: data['responsable'] as String? ?? '',
      fechaEntrega: _parseDate(data['fechaEntrega']),
      status: CompromisoStatus.fromString(data['status'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'numero': numero,
    'tarea': tarea,
    'responsable': responsable,
    if (fechaEntrega != null) 'fechaEntrega': Timestamp.fromDate(fechaEntrega!),
    'status': status.name,
  };

  CompromisoMinuta copyWith({
    int? numero,
    String? tarea,
    String? responsable,
    DateTime? fechaEntrega,
    CompromisoStatus? status,
  }) {
    return CompromisoMinuta(
      numero: numero ?? this.numero,
      tarea: tarea ?? this.tarea,
      responsable: responsable ?? this.responsable,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      status: status ?? this.status,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}

/// Modelo de Minuta de reunión.
///
/// Colección Firestore: `Minutas/{docId}`.
class Minuta {
  const Minuta({
    required this.id,
    required this.folio,
    required this.projectId,
    required this.projectName,
    required this.empresaName,
    required this.objetivo,
    required this.createdByName,
    this.version = '1.0.0',
    this.fecha,
    this.horaInicio,
    this.horaFin,
    this.lugar,
    this.modalidad = MinutaModalidad.videoconferencia,
    this.urlVideoconferencia,
    this.direccion,
    this.asistentes = const [],
    this.asuntosTratados = const [],
    this.compromisos = const [],
    this.adjuntos = const [],
    this.refTickets = const [],
    this.refRequerimientos = const [],
    this.refCita,
    this.participantUids = const [],
    this.resumenIA,
    this.observaciones,
    this.createdBy,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String folio;
  final String version;
  final String projectId;
  final String projectName;
  final String empresaName;
  final String objetivo;

  // Fecha y hora
  final DateTime? fecha;
  final String? horaInicio;
  final String? horaFin;
  final String? lugar;
  final MinutaModalidad modalidad;
  final String? urlVideoconferencia;
  final String? direccion;

  // Participantes y contenido
  final List<AsistenteMinuta> asistentes;
  final List<AsuntoTratado> asuntosTratados;
  final List<CompromisoMinuta> compromisos;
  final List<String> adjuntos;

  // Vínculos
  final List<String> refTickets;
  final List<String> refRequerimientos;
  final String? refCita;

  // UIDs desnormalizados para queries de visibilidad (asistentes + responsables compromisos)
  final List<String> participantUids;

  // IA y observaciones
  final String? resumenIA;
  final String? observaciones;

  // Control
  final String? createdBy;
  final String createdByName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Número de compromisos pendientes.
  int get compromisosPendientes =>
      compromisos.where((c) => c.status == CompromisoStatus.pendiente).length;

  /// Número de compromisos vencidos.
  int get compromisosVencidos =>
      compromisos.where((c) => c.status == CompromisoStatus.vencido).length;

  factory Minuta.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
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

    List<AsistenteMinuta> parseAsistentes(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map(AsistenteMinuta.fromMap)
            .toList();
      }
      return [];
    }

    List<AsuntoTratado> parseAsuntos(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map(AsuntoTratado.fromMap)
            .toList();
      }
      return [];
    }

    List<CompromisoMinuta> parseCompromisos(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map(CompromisoMinuta.fromMap)
            .toList();
      }
      return [];
    }

    return Minuta(
      id: doc.id,
      folio: data['folio'] as String? ?? '',
      version: data['version'] as String? ?? '1.0.0',
      projectId: data['projectId'] as String? ?? '',
      projectName: data['projectName'] as String? ?? '',
      empresaName: data['empresaName'] as String? ?? '',
      objetivo: data['objetivo'] as String? ?? '',
      fecha: parseDate(data['fecha']),
      horaInicio: data['horaInicio'] as String?,
      horaFin: data['horaFin'] as String?,
      lugar: data['lugar'] as String?,
      modalidad: MinutaModalidad.fromString(data['modalidad'] as String?),
      urlVideoconferencia: data['urlVideoconferencia'] as String?,
      direccion: data['direccion'] as String?,
      asistentes: parseAsistentes(data['asistentes']),
      asuntosTratados: parseAsuntos(data['asuntosTratados']),
      compromisos: parseCompromisos(data['compromisos']),
      adjuntos: parseStrList(data['adjuntos']),
      refTickets: parseStrList(data['refTickets']),
      refRequerimientos: parseStrList(data['refRequerimientos']),
      refCita: data['refCita'] as String?,
      participantUids: parseStrList(data['participantUids']),
      resumenIA: data['resumenIA'] as String?,
      observaciones: data['observaciones'] as String?,
      createdBy: data['createdBy'] as String?,
      createdByName: data['createdByName'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final now = DateTime.now();
    return {
      'folio': folio,
      'version': version,
      'projectId': projectId,
      'projectName': projectName,
      'empresaName': empresaName,
      'objetivo': objetivo,
      if (fecha != null) 'fecha': Timestamp.fromDate(fecha!),
      if (horaInicio != null) 'horaInicio': horaInicio,
      if (horaFin != null) 'horaFin': horaFin,
      if (lugar != null) 'lugar': lugar,
      'modalidad': modalidad.name,
      if (urlVideoconferencia != null)
        'urlVideoconferencia': urlVideoconferencia,
      if (direccion != null) 'direccion': direccion,
      'asistentes': asistentes.map((a) => a.toMap()).toList(),
      'asuntosTratados': asuntosTratados.map((a) => a.toMap()).toList(),
      'compromisos': compromisos.map((c) => c.toMap()).toList(),
      if (adjuntos.isNotEmpty) 'adjuntos': adjuntos,
      if (refTickets.isNotEmpty) 'refTickets': refTickets,
      if (refRequerimientos.isNotEmpty) 'refRequerimientos': refRequerimientos,
      if (refCita != null) 'refCita': refCita,
      if (participantUids.isNotEmpty) 'participantUids': participantUids,
      if (resumenIA != null) 'resumenIA': resumenIA,
      if (observaciones != null) 'observaciones': observaciones,
      if (createdBy != null) 'createdBy': createdBy,
      'createdByName': createdByName,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  Minuta copyWith({
    String? folio,
    String? version,
    String? projectId,
    String? projectName,
    String? empresaName,
    String? objetivo,
    DateTime? fecha,
    String? horaInicio,
    String? horaFin,
    String? lugar,
    MinutaModalidad? modalidad,
    String? urlVideoconferencia,
    String? direccion,
    List<AsistenteMinuta>? asistentes,
    List<AsuntoTratado>? asuntosTratados,
    List<CompromisoMinuta>? compromisos,
    List<String>? adjuntos,
    List<String>? refTickets,
    List<String>? refRequerimientos,
    String? refCita,
    List<String>? participantUids,
    String? resumenIA,
    String? observaciones,
    String? createdBy,
    String? createdByName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Minuta(
      id: id,
      folio: folio ?? this.folio,
      version: version ?? this.version,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      empresaName: empresaName ?? this.empresaName,
      objetivo: objetivo ?? this.objetivo,
      fecha: fecha ?? this.fecha,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      lugar: lugar ?? this.lugar,
      modalidad: modalidad ?? this.modalidad,
      urlVideoconferencia: urlVideoconferencia ?? this.urlVideoconferencia,
      direccion: direccion ?? this.direccion,
      asistentes: asistentes ?? this.asistentes,
      asuntosTratados: asuntosTratados ?? this.asuntosTratados,
      compromisos: compromisos ?? this.compromisos,
      adjuntos: adjuntos ?? this.adjuntos,
      refTickets: refTickets ?? this.refTickets,
      refRequerimientos: refRequerimientos ?? this.refRequerimientos,
      refCita: refCita ?? this.refCita,
      participantUids: participantUids ?? this.participantUids,
      resumenIA: resumenIA ?? this.resumenIA,
      observaciones: observaciones ?? this.observaciones,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
