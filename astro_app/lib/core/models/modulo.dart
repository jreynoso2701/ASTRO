import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Módulo.
///
/// Colección Firestore: `Modulos/{docId}` (existente V1 + campos V2).
class Modulo {
  const Modulo({
    required this.id,
    required this.nombreModulo,
    required this.folioModulo,
    required this.fkProyecto,
    required this.estatusModulo,
    this.projectId,
    this.descripcion,
    this.porcentCompletaModulo,
    this.fechaActualizaModulo,
    this.usuarioActualizoModulo,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nombreModulo;
  final String folioModulo;
  final String fkProyecto; // Nombre del proyecto (V1 compat)
  final bool estatusModulo;

  // Campos V2
  final String? projectId;
  final String? descripcion;
  final double? porcentCompletaModulo; // 0–100
  final String? fechaActualizaModulo; // V1: string
  final String? usuarioActualizoModulo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Modulo.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return Modulo(
      id: doc.id,
      nombreModulo: data['nombreModulo'] as String? ?? '',
      folioModulo: data['folioModulo'] as String? ?? '',
      fkProyecto: data['fkProyecto'] as String? ?? '',
      estatusModulo: data['estatusModulo'] as bool? ?? true,
      projectId: data['projectId'] as String?,
      descripcion: data['descripcion'] as String?,
      porcentCompletaModulo: parseDouble(data['porcentCompletaModulo']),
      fechaActualizaModulo: data['fechaActualizaModulo'] as String?,
      usuarioActualizoModulo: data['usuarioActualizoModulo'] as String?,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombreModulo': nombreModulo,
      'folioModulo': folioModulo,
      'fkProyecto': fkProyecto,
      'estatusModulo': estatusModulo,
      if (projectId != null) 'projectId': projectId,
      if (descripcion != null) 'descripcion': descripcion,
      if (porcentCompletaModulo != null)
        'porcentCompletaModulo': porcentCompletaModulo,
      if (fechaActualizaModulo != null)
        'fechaActualizaModulo': fechaActualizaModulo,
      if (usuarioActualizoModulo != null)
        'usuarioActualizoModulo': usuarioActualizoModulo,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  Modulo copyWith({
    String? nombreModulo,
    String? folioModulo,
    String? fkProyecto,
    bool? estatusModulo,
    String? projectId,
    String? descripcion,
    double? porcentCompletaModulo,
    String? fechaActualizaModulo,
    String? usuarioActualizoModulo,
    DateTime? updatedAt,
  }) {
    return Modulo(
      id: id,
      nombreModulo: nombreModulo ?? this.nombreModulo,
      folioModulo: folioModulo ?? this.folioModulo,
      fkProyecto: fkProyecto ?? this.fkProyecto,
      estatusModulo: estatusModulo ?? this.estatusModulo,
      projectId: projectId ?? this.projectId,
      descripcion: descripcion ?? this.descripcion,
      porcentCompletaModulo:
          porcentCompletaModulo ?? this.porcentCompletaModulo,
      fechaActualizaModulo: fechaActualizaModulo ?? this.fechaActualizaModulo,
      usuarioActualizoModulo:
          usuarioActualizoModulo ?? this.usuarioActualizoModulo,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
