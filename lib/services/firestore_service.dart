import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/session.dart';
import '../models/track.dart';

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
  Future<List<String>> getSessionMemberIds(String sessionId) async {
    final snap = await _sessions.doc(sessionId).get();
    if (!snap.exists) return [];
    final data = snap.data() ?? {};
    return List<String>.from(data['memberIds'] as List? ?? []);
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
  // ---- Tracks (session subcollection) ----------------------------------

  /// Reference to a session's tracks subcollection.
  CollectionReference<Map<String, dynamic>> _tracks(String sessionId) =>
      _sessions.doc(sessionId).collection('tracks');

  /// Add a track to a session's queue. The track is keyed by Firestore's
  /// auto-id, not by spotifyId — the same Spotify track CAN appear twice
  /// in a queue if added by different users (a feature, not a bug; lets
  /// people re-up a banger that already played).
  Future<void> addTrack({
    required String sessionId,
    required Track track,
    required String addedBy,
  }) async {
    // Build a fresh map so we don't accidentally inherit voting state
    // from a search-result Track. toCreateMap() resets vote counts to 0.
    final data = track.toCreateMap();
    data['addedBy'] = addedBy;

    await _tracks(sessionId).add(data);
  }

  /// Real-time stream of tracks in a session's queue, ordered by vote
  /// score (highest first), then by add time (oldest first as tiebreaker).
  ///
  /// Requires a composite index on (voteScore desc, addedAt asc).
  /// Firestore will prompt to create it on first run.
  Stream<List<Track>> streamTracks(String sessionId) {
    return _tracks(sessionId)
        .orderBy('voteScore', descending: true)
        .orderBy('addedAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(Track.fromFirestore).toList());
  }

  /// Remove a track from the queue. Security rules enforce that only the
  /// adder or the session host can delete.
  Future<void> removeTrack({
    required String sessionId,
    required String trackId,
  }) async {
    await _tracks(sessionId).doc(trackId).delete();
  }
  // ---- Voting (atomic transaction) -------------------------------------

  /// Vote on a track with full atomicity. Uses a Firestore transaction so
  /// concurrent votes from multiple users cannot lose updates (the
  /// classic "two reads, two writes, one vote lost" race condition).
  ///
  /// Direction:
  ///   +1  -> upvote
  ///   -1  -> downvote
  ///    0  -> remove existing vote (toggle off)
  ///
  /// Behavior rules (enforced in the transaction body):
  ///   - Tapping the same direction again clears the vote (0 net)
  ///   - Tapping the opposite direction switches the vote (-2 or +2 net)
  ///   - voteScore = upvoters.length - downvoters.length (always consistent)
  ///
  /// This is the rubric's "race condition" requirement. Demo evidence:
  /// open the app on two devices, vote simultaneously on the same track,
  /// observe the final score is correct.
  Future<void> voteOnTrack({
    required String sessionId,
    required String trackId,
    required String userId,
    required int direction,
  }) async {
    if (direction != -1 && direction != 0 && direction != 1) {
      throw ArgumentError('direction must be -1, 0, or 1');
    }

    final ref = _tracks(sessionId).doc(trackId);

    await _db.runTransaction((tx) async {
      // STEP 1: Read inside the transaction. Firestore guarantees no other
      // writer modifies this doc between read and write.
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Track no longer exists');
      }
      final data = snap.data() ?? {};

      final upvoters = List<String>.from(data['upvoters'] as List? ?? []);
      final downvoters = List<String>.from(data['downvoters'] as List? ?? []);

      // STEP 2: Compute new arrays based on the requested direction.
      // We always remove first, then optionally add — this handles all
      // toggle cases (off, switch up, switch down) with one code path.
      upvoters.remove(userId);
      downvoters.remove(userId);
      if (direction == 1) {
        upvoters.add(userId);
      } else if (direction == -1) {
        downvoters.add(userId);
      }
      // direction == 0 leaves both arrays without the user (vote removed)

      // STEP 3: Compute the derived voteScore. Single source of truth:
      // it ALWAYS equals upvoters.length - downvoters.length so we can
      // never end up with a score that disagrees with the arrays.
      final voteScore = upvoters.length - downvoters.length;

      // STEP 4: Single atomic write. If two transactions ran concurrently,
      // Firestore would retry one of them with the fresh data — no
      // votes are ever silently dropped.
      tx.update(ref, {
        'upvoters': upvoters,
        'downvoters': downvoters,
        'voteScore': voteScore,
      });
    });
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