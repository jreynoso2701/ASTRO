import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/cita_status.dart';
import 'package:astro/core/models/minuta_modalidad.dart';

/// Participante de una cita programada.
class ParticipanteCita {
  const ParticipanteCita({
    required this.uid,
    required this.nombre,
    this.rol,
    this.confirmado = false,
  });

  final String uid;
  final String nombre;
  final String? rol;
  final bool confirmado;

  factory ParticipanteCita.fromMap(Map<String, dynamic> data) {
    return ParticipanteCita(
      uid: data['uid'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      rol: data['rol'] as String?,
      confirmado: data['confirmado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'nombre': nombre,
    if (rol != null) 'rol': rol,
    'confirmado': confirmado,
  };

  ParticipanteCita copyWith({
    String? uid,
    String? nombre,
    String? rol,
    bool? confirmado,
  }) {
    return ParticipanteCita(
      uid: uid ?? this.uid,
      nombre: nombre ?? this.nombre,
      rol: rol ?? this.rol,
      confirmado: confirmado ?? this.confirmado,
    );
  }
}

/// Modelo de Cita / Reunión programada.
///
/// Colección Firestore: `Citas/{docId}`.
class Cita {
  const Cita({
    required this.id,
    required this.folio,
    required this.titulo,
    required this.projectId,
    required this.projectName,
    required this.empresaName,
    required this.createdByName,
    this.descripcion,
    this.fecha,
    this.horaInicio,
    this.horaFin,
    this.modalidad = MinutaModalidad.videoconferencia,
    this.urlVideoconferencia,
    this.direccion,
    this.participantes = const [],
    this.refTickets = const [],
    this.refRequerimientos = const [],
    this.refMinuta,
    this.recordatorios = const [15, 60],
    this.status = CitaStatus.programada,
    this.notas,
    this.createdBy,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String folio;
  final String titulo;
  final String projectId;
  final String projectName;
  final String empresaName;
  final String createdByName;

  final String? descripcion;
  final DateTime? fecha;
  final String? horaInicio;
  final String? horaFin;
  final MinutaModalidad modalidad;
  final String? urlVideoconferencia;
  final String? direccion;

  final List<ParticipanteCita> participantes;
  final List<String> refTickets;
  final List<String> refRequerimientos;
  final String? refMinuta; // Minuta generada tras la reunión

  /// Minutos antes de la cita para enviar recordatorio (ej. [15, 60]).
  final List<int> recordatorios;

  final CitaStatus status;
  final String? notas;
  final String? createdBy;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Cita.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
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

    List<int> parseIntList(dynamic value) {
      if (value is List) {
        return value
            .map((e) => e is num ? e.toInt() : null)
            .whereType<int>()
            .toList();
      }
      return [15, 60];
    }

    List<ParticipanteCita> parseParticipantes(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map(ParticipanteCita.fromMap)
            .toList();
      }
      return [];
    }

    return Cita(
      id: doc.id,
      folio: data['folio'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      projectName: data['projectName'] as String? ?? '',
      empresaName: data['empresaName'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      descripcion: data['descripcion'] as String?,
      fecha: parseDate(data['fecha']),
      horaInicio: data['horaInicio'] as String?,
      horaFin: data['horaFin'] as String?,
      modalidad: MinutaModalidad.fromString(data['modalidad'] as String?),
      urlVideoconferencia: data['urlVideoconferencia'] as String?,
      direccion: data['direccion'] as String?,
      participantes: parseParticipantes(data['participantes']),
      refTickets: parseStrList(data['refTickets']),
      refRequerimientos: parseStrList(data['refRequerimientos']),
      refMinuta: data['refMinuta'] as String?,
      recordatorios: parseIntList(data['recordatorios']),
      status: CitaStatus.fromString(data['status'] as String?),
      notas: data['notas'] as String?,
      createdBy: data['createdBy'] as String?,
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
      'projectId': projectId,
      'projectName': projectName,
      'empresaName': empresaName,
      'createdByName': createdByName,
      if (descripcion != null) 'descripcion': descripcion,
      if (fecha != null) 'fecha': Timestamp.fromDate(fecha!),
      if (horaInicio != null) 'horaInicio': horaInicio,
      if (horaFin != null) 'horaFin': horaFin,
      'modalidad': modalidad.name,
      if (urlVideoconferencia != null)
        'urlVideoconferencia': urlVideoconferencia,
      if (direccion != null) 'direccion': direccion,
      'participantes': participantes.map((p) => p.toMap()).toList(),
      if (refTickets.isNotEmpty) 'refTickets': refTickets,
      if (refRequerimientos.isNotEmpty) 'refRequerimientos': refRequerimientos,
      if (refMinuta != null) 'refMinuta': refMinuta,
      'recordatorios': recordatorios,
      'status': status.name,
      if (notas != null) 'notas': notas,
      if (createdBy != null) 'createdBy': createdBy,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  Cita copyWith({
    String? folio,
    String? titulo,
    String? projectId,
    String? projectName,
    String? empresaName,
    String? createdByName,
    String? descripcion,
    DateTime? fecha,
    String? horaInicio,
    String? horaFin,
    MinutaModalidad? modalidad,
    String? urlVideoconferencia,
    String? direccion,
    List<ParticipanteCita>? participantes,
    List<String>? refTickets,
    List<String>? refRequerimientos,
    String? refMinuta,
    List<int>? recordatorios,
    CitaStatus? status,
    String? notas,
    String? createdBy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Cita(
      id: id,
      folio: folio ?? this.folio,
      titulo: titulo ?? this.titulo,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      empresaName: empresaName ?? this.empresaName,
      createdByName: createdByName ?? this.createdByName,
      descripcion: descripcion ?? this.descripcion,
      fecha: fecha ?? this.fecha,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      modalidad: modalidad ?? this.modalidad,
      urlVideoconferencia: urlVideoconferencia ?? this.urlVideoconferencia,
      direccion: direccion ?? this.direccion,
      participantes: participantes ?? this.participantes,
      refTickets: refTickets ?? this.refTickets,
      refRequerimientos: refRequerimientos ?? this.refRequerimientos,
      refMinuta: refMinuta ?? this.refMinuta,
      recordatorios: recordatorios ?? this.recordatorios,
      status: status ?? this.status,
      notas: notas ?? this.notas,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
