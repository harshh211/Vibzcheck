import 'package:cloud_firestore/cloud_firestore.dart';

/// Message mirrors the /sessions/{sessionId}/messages/{messageId} doc.
/// Messages are immutable after send (security rules block updates/deletes)
/// — this matches user expectation in chat: you can't un-say something.
class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime? sentAt;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    this.sentAt,
  });

  factory Message.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Message(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'senderId': senderId,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
      };
}