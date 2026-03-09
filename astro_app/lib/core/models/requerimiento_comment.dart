import 'package:cloud_firestore/cloud_firestore.dart';

/// Comentario / entrada en el historial de un requerimiento.
///
/// Colección: `ComentariosRequerimientos/{docId}` (separada de tickets).
class RequerimientoComment {
  const RequerimientoComment({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    this.requerimientoId,
    this.type = ReqCommentType.comment,
    this.createdAt,
  });

  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final String? requerimientoId;
  final ReqCommentType type;
  final DateTime? createdAt;

  factory RequerimientoComment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return RequerimientoComment(
      id: doc.id,
      text: data['text'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      requerimientoId: data['refRequerimiento'] as String?,
      type: ReqCommentType.fromString(data['type'] as String? ?? 'comment'),
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (requerimientoId != null) 'refRequerimiento': requerimientoId,
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }
}

/// Tipo de entrada en el historial del requerimiento.
enum ReqCommentType {
  comment,
  statusChange,
  assignment,
  priorityChange,
  faseChange;

  static ReqCommentType fromString(String value) {
    return ReqCommentType.values.firstWhere(
      (c) => c.name == value,
      orElse: () => ReqCommentType.comment,
    );
  }
}
