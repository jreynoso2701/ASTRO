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
    this.adjuntos = const [],
    this.deleted = false,
  });

  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final String? requerimientoId;
  final ReqCommentType type;
  final DateTime? createdAt;
  final List<String> adjuntos;
  final bool deleted;

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
      adjuntos:
          (data['adjuntos'] as List<dynamic>?)?.cast<String>() ?? const [],
      deleted: data['deleted'] as bool? ?? false,
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
      if (adjuntos.isNotEmpty) 'adjuntos': adjuntos,
      if (deleted) 'deleted': true,
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
