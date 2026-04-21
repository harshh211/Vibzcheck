import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
 
import '../services/auth_service.dart';
 
/// AuthProvider sits between the UI and AuthService. Screens read isLoading
/// and errorMessage from here and call signIn/signUp/signOut. This keeps
/// screens free of try/catch blocks and loading flags.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
 
  bool _isLoading = false;
  String? _errorMessage;
 
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _authService.currentUser;
 
  /// Returns true on success, false on failure.
  /// On failure, errorMessage is set and listeners are notified.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      await _authService.signIn(email: email, password: password);
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }
 
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setLoading(true);
    try {
      await _authService.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }
 
  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }
 
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
 
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
 
  /// Translate Firebase error codes into user-facing messages.
  /// We never show raw Firebase errors — they leak implementation details.
  String _friendlyError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      default:
        return 'Could not sign in. Try again.';
    }
  }
}