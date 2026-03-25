import 'package:cloud_firestore/cloud_firestore.dart';

/// Comentario / entrada en el historial de un ticket.
///
/// Colección: `Comentarios/{docId}` (V1: top-level con refIncidente).
class TicketComment {
  const TicketComment({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    this.ticketId,
    this.type = CommentType.comment,
    this.createdAt,
    this.adjuntos = const [],
    this.deleted = false,
  });

  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final String? ticketId; // V1: refIncidente (top-level collection link)
  final CommentType type;
  final DateTime? createdAt;
  final List<String> adjuntos;
  final bool deleted;

  factory TicketComment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return TicketComment(
      id: doc.id,
      // V1 → V2 field mappings with fallback
      text:
          data['comentario'] as String? ??
          data['texto'] as String? ??
          data['text'] as String? ??
          '',
      authorId:
          data['fkxUsuarioId'] as String? ?? data['authorId'] as String? ?? '',
      authorName:
          data['usuario'] as String? ??
          data['fkxUsuario'] as String? ??
          data['authorName'] as String? ??
          '',
      ticketId: data['refIncidente'] as String?,
      type: CommentType.fromString(data['type'] as String? ?? 'comment'),
      createdAt: parseDate(data['fechaCreacion'] ?? data['createdAt']),
      adjuntos:
          (data['adjuntos'] as List<dynamic>?)?.cast<String>() ?? const [],
      deleted: data['deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      // V1 fields
      if (ticketId != null) 'refIncidente': ticketId,
      'comentario': text,
      'usuario': authorName,
      'fkxUsuarioId': authorId,
      'fechaCreacion': Timestamp.fromDate(createdAt ?? DateTime.now()),
      // V2 fields
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

/// Tipo de entrada en el historial.
enum CommentType {
  comment, // Comentario normal
  statusChange, // Cambio de estado
  assignment, // Cambio de asignación
  priorityChange; // Cambio de prioridad

  static CommentType fromString(String value) {
    return CommentType.values.firstWhere(
      (c) => c.name == value,
      orElse: () => CommentType.comment,
    );
  }
}
