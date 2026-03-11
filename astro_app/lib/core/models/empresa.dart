import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Empresa.
///
/// Colección Firestore: `Empresas/{docId}` (existente V1 + campos V2).
class Empresa {
  const Empresa({
    required this.id,
    required this.nombreEmpresa,
    required this.isActive,
    this.logoUrl,
    this.direccion,
    this.telefono,
    this.contacto,
    this.rfc,
    this.email,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nombreEmpresa;
  final bool isActive;

  // Campos V2
  final String? logoUrl;
  final String? direccion;
  final String? telefono;
  final String? contacto;
  final String? rfc;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Empresa.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Empresa(
      id: doc.id,
      nombreEmpresa: data['nombreEmpresa'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      logoUrl: data['logoUrl'] as String?,
      direccion: data['direccion'] as String?,
      telefono: data['telefono'] as String?,
      contacto: data['contacto'] as String?,
      rfc: data['rfc'] as String?,
      email: data['email'] as String?,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombreEmpresa': nombreEmpresa,
      'isActive': isActive,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (direccion != null) 'direccion': direccion,
      if (telefono != null) 'telefono': telefono,
      if (contacto != null) 'contacto': contacto,
      if (rfc != null) 'rfc': rfc,
      if (email != null) 'email': email,
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  Empresa copyWith({
    String? nombreEmpresa,
    bool? isActive,
    String? logoUrl,
    String? direccion,
    String? telefono,
    String? contacto,
    String? rfc,
    String? email,
    DateTime? updatedAt,
  }) {
    return Empresa(
      id: id,
      nombreEmpresa: nombreEmpresa ?? this.nombreEmpresa,
      isActive: isActive ?? this.isActive,
      logoUrl: logoUrl ?? this.logoUrl,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      contacto: contacto ?? this.contacto,
      rfc: rfc ?? this.rfc,
      email: email ?? this.email,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
