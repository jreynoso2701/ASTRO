import 'package:cloud_firestore/cloud_firestore.dart';

/// Categoría personalizada creada por Root.
///
/// Colección Firestore: `CategoriasDocumento/{catId}`.
class CategoriaCustom {
  const CategoriaCustom({
    required this.id,
    required this.nombre,
    required this.projectId,
    required this.projectName,
    required this.createdBy,
    required this.createdByName,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String nombre;
  final String projectId;
  final String projectName;
  final String createdBy;
  final String createdByName;
  final bool isActive;
  final DateTime? createdAt;

  factory CategoriaCustom.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return CategoriaCustom(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      projectName: data['projectName'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'projectId': projectId,
      'projectName': projectName,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }
}
