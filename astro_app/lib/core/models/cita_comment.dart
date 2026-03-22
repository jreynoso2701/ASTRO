import 'package:cloud_firestore/cloud_firestore.dart';

/// Comentario / entrada en el historial de una cita.
///
/// Colección: `ComentariosCitas/{docId}`.
class CitaComment {
  const CitaComment({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    this.citaId,
    this.type = CitaCommentType.comment,
    this.createdAt,
  });

  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final String? citaId;
  final CitaCommentType type;
  final DateTime? createdAt;

  factory CitaComment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return CitaComment(
      id: doc.id,
      text: data['text'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      citaId: data['refCita'] as String?,
      type: CitaCommentType.fromString(data['type'] as String? ?? 'comment'),
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (citaId != null) 'refCita': citaId,
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }
}

/// Tipo de entrada en el historial de la cita.
enum CitaCommentType {
  comment,
  statusChange,
  completion;

  static CitaCommentType fromString(String value) {
    return CitaCommentType.values.firstWhere(
      (c) => c.name == value,
      orElse: () => CitaCommentType.comment,
    );
  }
}
