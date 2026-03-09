import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Empresa.
///
/// Colección Firestore: `Empresas/{docId}` (existente V1).
class Empresa {
  const Empresa({
    required this.id,
    required this.nombreEmpresa,
    required this.isActive,
  });

  final String id;
  final String nombreEmpresa;
  final bool isActive;

  factory Empresa.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Empresa(
      id: doc.id,
      nombreEmpresa: data['nombreEmpresa'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'nombreEmpresa': nombreEmpresa, 'isActive': isActive};
  }
}
