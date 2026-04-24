import 'package:cloud_firestore/cloud_firestore.dart';

/// Session mirrors the /sessions/{sessionId} Firestore document.
/// A Session is a shared listening room: one host, many members, a shared
/// queue of tracks, and a chat thread.
class Session {
  final String id;
  final String name;
  final String hostId;
  final String joinCode;
  final List<String> memberIds;
  final DateTime? createdAt;
  final bool isActive;

  Session({
    required this.id,
    required this.name,
    required this.hostId,
    required this.joinCode,
    required this.memberIds,
    required this.isActive,
    this.createdAt,
  });

  factory Session.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Session(
      id: doc.id,
      name: data['name'] as String? ?? 'Untitled session',
      hostId: data['hostId'] as String? ?? '',
      joinCode: data['joinCode'] as String? ?? '',
      // List<dynamic> from Firestore; cast to List<String>.
      memberIds: List<String>.from(data['memberIds'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  /// Used by FirestoreService when creating a new session. createdAt uses
  /// FieldValue.serverTimestamp() so the server sets the time, not the
  /// client (clients can have wrong clocks).
  Map<String, dynamic> toCreateMap() => {
        'name': name,
        'hostId': hostId,
        'joinCode': joinCode,
        'memberIds': memberIds,
        'isActive': isActive,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Convenience: is the given user the host of this session?
  bool isHost(String uid) => hostId == uid;
}