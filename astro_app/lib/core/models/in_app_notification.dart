import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/notification_type.dart';

/// Notificación almacenada en la bandeja del usuario.
///
/// Colección Firestore: `Notificaciones/{docId}`
class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.userId,
    required this.titulo,
    required this.cuerpo,
    required this.tipo,
    required this.refType,
    required this.refId,
    required this.projectId,
    required this.projectName,
    this.leida = false,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String titulo;
  final String cuerpo;
  final NotificationType tipo;
  final NotificationRefType refType;
  final String refId;
  final String projectId;
  final String projectName;
  final bool leida;
  final DateTime? createdAt;

  factory InAppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return InAppNotification(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      cuerpo: data['cuerpo'] as String? ?? '',
      tipo: NotificationType.fromString(data['tipo'] as String? ?? ''),
      refType: NotificationRefType.fromString(
        data['refType'] as String? ?? 'ticket',
      ),
      refId: data['refId'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      projectName: data['projectName'] as String? ?? '',
      leida: data['leida'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'titulo': titulo,
      'cuerpo': cuerpo,
      'tipo': tipo.value,
      'refType': refType.value,
      'refId': refId,
      'projectId': projectId,
      'projectName': projectName,
      'leida': leida,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  InAppNotification copyWith({bool? leida}) {
    return InAppNotification(
      id: id,
      userId: userId,
      titulo: titulo,
      cuerpo: cuerpo,
      tipo: tipo,
      refType: refType,
      refId: refId,
      projectId: projectId,
      projectName: projectName,
      leida: leida ?? this.leida,
      createdAt: createdAt,
    );
  }
}
