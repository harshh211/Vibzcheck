import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/session.dart';

/// FirestoreService centralizes every Firestore read and write for
/// sessions, users, tracks, votes, and messages. Screens and providers
/// never touch FirebaseFirestore directly — it all goes through here.
///
/// This layer is where business rules live: generating join codes,
/// running vote transactions, enforcing membership checks on the client
/// before the write (the rules file enforces on the server).
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- Collection references (typed) ------------------------------------

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ---- Users ------------------------------------------------------------

  /// Fetch a user profile. Returns null if the profile doc doesn't exist
  /// (edge case: user created in Auth but profile write failed).
  Future<AppUser?> getUser(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    return AppUser.fromFirestore(snap);
  }

  /// Stream of a single user's profile. Used for avatars / names that
  /// may update mid-session.
  Stream<AppUser?> streamUser(String uid) {
    return _users.doc(uid).snapshots().map(
          (snap) => snap.exists ? AppUser.fromFirestore(snap) : null,
        );
  }

  // ---- Sessions ---------------------------------------------------------

  /// Create a new session. The creator is the host and first member.
  /// Returns the generated session ID.
  Future<String> createSession({
    required String name,
    required String hostId,
  }) async {
    final joinCode = _generateJoinCode();
    final docRef = _sessions.doc(); // auto-generated ID

    final session = Session(
      id: docRef.id,
      name: name.trim(),
      hostId: hostId,
      joinCode: joinCode,
      memberIds: [hostId],
      isActive: true,
    );

    await docRef.set(session.toCreateMap());
    return docRef.id;
  }

  /// Join a session by its 6-character code. Throws if the code doesn't
  /// match any active session.
  ///
  /// Uses arrayUnion so duplicate joins are idempotent — rejoining an
  /// already-joined session won't add duplicate entries or fail.
  Future<Session> joinSessionByCode({
    required String joinCode,
    required String userId,
  }) async {
    final normalized = joinCode.trim().toUpperCase();

    final query = await _sessions
        .where('joinCode', isEqualTo: normalized)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('No active session found for code $normalized');
    }

    final doc = query.docs.first;
    await doc.reference.update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });

    // Re-fetch after the update so the returned Session has userId in memberIds.
    final updated = await doc.reference.get();
    return Session.fromFirestore(updated);
  }

  /// Leave a session. If the leaver is the host, the session is marked
  /// inactive rather than deleted (preserves history).
  Future<void> leaveSession({
    required String sessionId,
    required String userId,
  }) async {
    final ref = _sessions.doc(sessionId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final session = Session.fromFirestore(snap);

    if (session.isHost(userId)) {
      // Host leaving: close the session so no one else can join/write.
      await ref.update({'isActive': false});
    } else {
      await ref.update({
        'memberIds': FieldValue.arrayRemove([userId]),
      });
    }
  }

  /// Real-time stream of the sessions the user belongs to.
  /// Ordered by most recent activity.
  Stream<List<Session>> streamMySessions(String userId) {
    return _sessions
        .where('memberIds', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Session.fromFirestore).toList());
  }

  /// Real-time stream of a single session. Used by SessionScreen so the
  /// member list updates live as people join/leave.
  Stream<Session> streamSession(String sessionId) {
    return _sessions.doc(sessionId).snapshots().map(Session.fromFirestore);
  }

  /// Fetch the profiles for a list of member UIDs. Used to render names
  /// and avatars. Firestore 'in' queries cap at 30 values; we chunk to
  /// handle larger sessions (not expected, but safe).
  Future<List<AppUser>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];

    final users = <AppUser>[];
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, min(i + 30, uids.length));
      final snap = await _users.where(FieldPath.documentId, whereIn: chunk).get();
      users.addAll(snap.docs.map(AppUser.fromFirestore));
    }
    return users;
  }

  // ---- Helpers ----------------------------------------------------------

  /// Generate a 6-character join code using letters + digits, excluding
  /// confusable characters (0/O, 1/I/L).
  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(rand.nextInt(chars.length)),
      ),
    );
  }
}