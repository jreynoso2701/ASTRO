import 'package:cloud_firestore/cloud_firestore.dart';

/// Acciones que se registran en la bitácora de documentos.
enum BitacoraAccion {
  creado('Creado'),
  editado('Editado'),
  nuevaVersion('Nueva versión'),
  eliminado('Eliminado'),
  restaurado('Restaurado'),
  compartido('Compartido'),
  descompartido('Acceso retirado');

  const BitacoraAccion(this.label);

  final String label;

  static BitacoraAccion fromString(String value) {
    return BitacoraAccion.values.firstWhere(
      (a) => a.label.toLowerCase() == value.toLowerCase(),
      orElse: () => BitacoraAccion.editado,
    );
  }
}

/// Entrada de bitácora de documentos formales.
///
/// Colección Firestore: `BitacoraDocumentos/{logId}`.
class BitacoraDocumento {
  const BitacoraDocumento({
    required this.id,
    required this.documentId,
    required this.documentFolio,
    required this.documentTitulo,
    required this.projectId,
    required this.projectName,
    required this.accion,
    required this.descripcion,
    required this.userId,
    required this.userName,
    required this.userRole,
    this.detalles,
    this.createdAt,
  });

  final String id;
  final String documentId;
  final String documentFolio;
  final String documentTitulo;
  final String projectId;
  final String projectName;
  final BitacoraAccion accion;
  final String descripcion;
  final String userId;
  final String userName;
  final String userRole;
  final Map<String, dynamic>? detalles;
  final DateTime? createdAt;

  factory BitacoraDocumento.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return BitacoraDocumento(
      id: doc.id,
      documentId: data['documentId'] as String? ?? '',
      documentFolio: data['documentFolio'] as String? ?? '',
      documentTitulo: data['documentTitulo'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      projectName: data['projectName'] as String? ?? '',
      accion: BitacoraAccion.fromString(data['accion'] as String? ?? ''),
      descripcion: data['descripcion'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userRole: data['userRole'] as String? ?? '',
      detalles: data['detalles'] as Map<String, dynamic>?,
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'documentId': documentId,
      'documentFolio': documentFolio,
      'documentTitulo': documentTitulo,
      'projectId': projectId,
      'projectName': projectName,
      'accion': accion.label,
      'descripcion': descripcion,
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      if (detalles != null) 'detalles': detalles,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }
}
