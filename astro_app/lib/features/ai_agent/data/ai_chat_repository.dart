import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/ai_chat_message.dart';

/// Repositorio para mensajes del agente IA.
///
/// Colección: `chatAI/{docId}`
class AiChatRepository {
  AiChatRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('chatAI');

  /// Stream de mensajes del usuario, ordenados por fecha ascendente.
  Stream<List<AiChatMessage>> watchMessages(String userId) {
    return _collection
        .where('creador', isEqualTo: userId)
        .orderBy('fecha', descending: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => AiChatMessage.fromFirestore(d)).toList(),
        );
  }

  /// Agrega un mensaje a la conversación.
  Future<String> addMessage(AiChatMessage message) async {
    final doc = await _collection.add(message.toFirestore());
    return doc.id;
  }

  /// Elimina todo el historial de chat de un usuario.
  Future<void> clearHistory(String userId) async {
    final snap = await _collection.where('creador', isEqualTo: userId).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
