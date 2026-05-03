import 'package:flutter/foundation.dart';

import '../models/session.dart';
import '../models/track.dart';
import '../services/firestore_service.dart';

class SessionProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Stream<List<Session>> streamMySessions(String userId) =>
      _firestore.streamMySessions(userId);

  Stream<Session> streamSession(String sessionId) =>
      _firestore.streamSession(sessionId);

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

      _errorMessage = 'No session found for that code.';
      return null;
    } finally {
      _setLoading(false);
    }
  }


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

  Stream<List<Track>> streamTracks(String sessionId) =>
      _firestore.streamTracks(sessionId);


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
  Future<void> voteOnTrack({
    required String sessionId,
    required String trackId,
    required String userId,
    required int direction,
  }) async {
    try {
      await _firestore.voteOnTrack(
        sessionId: sessionId,
        trackId: trackId,
        userId: userId,
        direction: direction,
      );
    } catch (_) {
      _errorMessage = "You'r vote did not count please try again";
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