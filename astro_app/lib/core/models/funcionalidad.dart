import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Funcionalidad (sub-feature de un Módulo).
///
/// Colección Firestore: `Modulos/{moduleId}/Funcionalidades/{docId}`.
class Funcionalidad {
  const Funcionalidad({
    required this.id,
    required this.nombre,
    required this.completada,
    required this.estatus,
    this.descripcion,
    this.orden = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nombre;
  final String? descripcion;
  final bool completada;
  final bool estatus; // soft delete
  final int orden;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Funcionalidad.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Funcionalidad(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      descripcion: data['descripcion'] as String?,
      completada: data['completada'] as bool? ?? false,
      estatus: data['estatus'] as bool? ?? true,
      orden: (data['orden'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      'completada': completada,
      'estatus': estatus,
      'orden': orden,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  Funcionalidad copyWith({
    String? nombre,
    String? descripcion,
    bool? completada,
    bool? estatus,
    int? orden,
    DateTime? updatedAt,
  }) {
    return Funcionalidad(
      id: id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      completada: completada ?? this.completada,
      estatus: estatus ?? this.estatus,
      orden: orden ?? this.orden,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
