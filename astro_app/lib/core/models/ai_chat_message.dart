import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de contenido que puede contener un mensaje del agente.
enum AiContentType {
  text,
  tickets,
  minutas,
  requerimientos,
  citas,
  progress,
  actionConfirm,
}

/// Rol del mensaje dentro de la conversación.
enum AiMessageRole { user, assistant }

/// Contenido enriquecido dentro de un mensaje del agente.
///
/// Un solo mensaje puede tener múltiples bloques: un texto acompañado
/// de una lista de tickets, por ejemplo.
class AiContentBlock {
  const AiContentBlock({
    required this.type,
    required this.text,
    this.data,
    this.items,
  });

  final AiContentType type;
  final String text;

  /// IDs asociados (ej: lista de ticket IDs).
  final List<String>? data;

  /// Datos enriquecidos por item (folio, título, status, etc.).
  final List<Map<String, dynamic>>? items;

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'text': text,
    if (data != null) 'data': data,
    if (items != null) 'items': items,
  };

  factory AiContentBlock.fromMap(Map<String, dynamic> map) {
    return AiContentBlock(
      type: AiContentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AiContentType.text,
      ),
      text: map['text'] ?? '',
      data: (map['data'] as List<dynamic>?)?.cast<String>(),
      items: (map['items'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}

/// Mensaje individual de la conversación con el agente IA.
///
/// Colección Firestore: `chatAI/{docId}`
class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.userId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.projectId,
    this.empresaId,
    this.threadId,
  });

  final String id;
  final String userId;
  final AiMessageRole role;
  final List<AiContentBlock> content;
  final DateTime createdAt;
  final String? projectId;
  final String? empresaId;
  final String? threadId;

  /// Texto plano combinado de todos los bloques de contenido.
  String get plainText => content.map((b) => b.text).join('\n');

  factory AiChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final rawContent = data['content'];
    List<AiContentBlock> contentBlocks;
    if (rawContent is List) {
      contentBlocks = rawContent
          .map((e) => AiContentBlock.fromMap(e as Map<String, dynamic>))
          .toList();
    } else {
      // Legacy: campo "mensaje" plano
      contentBlocks = [
        AiContentBlock(
          type: AiContentType.text,
          text: data['mensaje'] ?? data['text'] ?? '',
        ),
      ];
    }

    return AiChatMessage(
      id: doc.id,
      userId: data['creador'] ?? data['userId'] ?? '',
      role: (data['role'] ?? data['rol'] ?? 'user') == 'assistant'
          ? AiMessageRole.assistant
          : AiMessageRole.user,
      content: contentBlocks,
      createdAt: parseDate(data['fecha'] ?? data['createdAt']),
      projectId: data['fkProyecto'] as String?,
      empresaId: data['fkEmpresa'] as String?,
      threadId: data['thread'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'creador': userId,
    'role': role.name,
    'content': content.map((b) => b.toMap()).toList(),
    'fecha': FieldValue.serverTimestamp(),
    if (projectId != null) 'fkProyecto': projectId,
    if (empresaId != null) 'fkEmpresa': empresaId,
    if (threadId != null) 'thread': threadId,
  };
}
