import 'package:cloud_firestore/cloud_firestore.dart';

/// AppUser mirrors the /users/{uid} Firestore document. Named AppUser (not
/// User) to avoid clashing with firebase_auth.User.
class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final String? fcmToken;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    this.fcmToken,
    this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'Anonymous',
      email: data['email'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      fcmToken: data['fcmToken'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'avatarUrl': avatarUrl,
        'fcmToken': fcmToken,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}