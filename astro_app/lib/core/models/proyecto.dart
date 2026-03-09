import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Proyecto.
///
/// Colección Firestore: `Proyectos/{docId}` (existente V1 + campos V2).
class Proyecto {
  const Proyecto({
    required this.id,
    required this.nombreProyecto,
    required this.folioProyecto,
    required this.fkEmpresa,
    required this.estatusProyecto,
    this.empresaId,
    this.descripcion,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nombreProyecto;
  final String folioProyecto;
  final String fkEmpresa; // Nombre de empresa (V1 compat)
  final bool estatusProyecto;

  // Campos V2
  final String? empresaId;
  final String? descripcion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Proyecto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Proyecto(
      id: doc.id,
      nombreProyecto: data['nombreProyecto'] as String? ?? '',
      folioProyecto: data['folioProyecto'] as String? ?? '',
      fkEmpresa: data['fkEmpresa'] as String? ?? '',
      estatusProyecto: data['estatusProyecto'] as bool? ?? true,
      empresaId: data['empresaId'] as String?,
      descripcion: data['descripcion'] as String?,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombreProyecto': nombreProyecto,
      'folioProyecto': folioProyecto,
      'fkEmpresa': fkEmpresa,
      'estatusProyecto': estatusProyecto,
      if (empresaId != null) 'empresaId': empresaId,
      if (descripcion != null) 'descripcion': descripcion,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  Proyecto copyWith({
    String? nombreProyecto,
    String? folioProyecto,
    String? fkEmpresa,
    bool? estatusProyecto,
    String? empresaId,
    String? descripcion,
    DateTime? updatedAt,
  }) {
    return Proyecto(
      id: id,
      nombreProyecto: nombreProyecto ?? this.nombreProyecto,
      folioProyecto: folioProyecto ?? this.folioProyecto,
      fkEmpresa: fkEmpresa ?? this.fkEmpresa,
      estatusProyecto: estatusProyecto ?? this.estatusProyecto,
      empresaId: empresaId ?? this.empresaId,
      descripcion: descripcion ?? this.descripcion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
