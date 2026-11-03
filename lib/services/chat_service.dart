import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send a text message to group chat
  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    if (content.trim().isEmpty) return;

    final docRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc();

    final message = MessageModel(
      messageId: docRef.id,
      senderId: senderId,
      senderName: senderName,
      senderUsername: senderName,
      content: content.trim(),
      timestamp: DateTime.now(),
    );

    await docRef.set(message.toMap());
  }

  /// Stream group messages sorted by timestamp ascending
  Stream<List<MessageModel>> getGroupMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
