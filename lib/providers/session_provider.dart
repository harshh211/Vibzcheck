import 'package:flutter/foundation.dart';

import '../models/session.dart';
import '../models/track.dart';
import '../services/firestore_service.dart';

/// SessionProvider wraps FirestoreService calls with loading/error state
/// and exposes them to screens. Screens never call FirestoreService
/// directly — they call provider methods and watch for state changes.
class SessionProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Stream the sessions this user belongs to. Consumers use StreamBuilder
  /// directly — the provider just exposes the stream factory.
  Stream<List<Session>> streamMySessions(String userId) =>
      _firestore.streamMySessions(userId);

  /// Stream a single session live. Used by SessionScreen to reflect
  /// member joins/leaves in real time.
  Stream<Session> streamSession(String sessionId) =>
      _firestore.streamSession(sessionId);

  /// Create a new session. Returns the new session ID on success, null
  /// on failure (errorMessage is set).
  Future<String?> createSession({
    required String name,
    required String hostId,
  }) async {
    _setLoading(true);
    try {
      final id = await _firestore.createSession(name: name, hostId: hostId);
      _errorMessage = null;
      return id;
    } catch (e) {
      _errorMessage = 'Could not create session. Try again.';
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Join a session by join code. Returns the joined Session on success,
  /// null on failure (errorMessage is set).
  Future<Session?> joinSessionByCode({
    required String code,
    required String userId,
  }) async {
    _setLoading(true);
    try {
      final session = await _firestore.joinSessionByCode(
        joinCode: code,
        userId: userId,
      );
      _errorMessage = null;
      return session;
    } catch (_) {
      // FirestoreService throws on no match; hide internals from user.
      _errorMessage = 'No session found for that code.';
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Leave (or close, if host) a session.
  Future<void> leaveSession({
    required String sessionId,
    required String userId,
  }) async {
    try {
      await _firestore.leaveSession(sessionId: sessionId, userId: userId);
    } catch (_) {
      _errorMessage = 'Could not leave session.';
      notifyListeners();
    }
  }
  // ---- Tracks ----------------------------------------------------------

  /// Real-time stream of the queue for a session.
  Stream<List<Track>> streamTracks(String sessionId) =>
      _firestore.streamTracks(sessionId);

  /// Add a track to the queue. Returns true on success, false on failure
  /// (errorMessage is set). UI can show a snackbar on false.
  Future<bool> addTrack({
    required String sessionId,
    required Track track,
    required String addedBy,
  }) async {
    try {
      await _firestore.addTrack(
        sessionId: sessionId,
        track: track,
        addedBy: addedBy,
      );
      return true;
    } catch (_) {
      _errorMessage = 'Could not add track. Try again.';
      notifyListeners();
      return false;
    }
  }

  /// Remove a track from the queue. Silent failure path — UI can refresh
  /// stream to verify; we don't surface every Firestore error to users.
  Future<void> removeTrack({
    required String sessionId,
    required String trackId,
  }) async {
    try {
      await _firestore.removeTrack(sessionId: sessionId, trackId: trackId);
    } catch (_) {
      _errorMessage = 'Could not remove track.';
      notifyListeners();
    }
  }
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}