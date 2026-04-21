import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
 
/// AuthService wraps all Firebase Auth operations so the rest of the app
/// never imports FirebaseAuth directly. This keeps screens free of Firebase
/// logic and makes the auth layer easy to swap or mock in tests.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
 
  /// Stream of the current user. Null means signed out.
  /// Used by AuthGate in main.dart to route between sign-in and home.
  Stream<User?> get userChanges => _auth.authStateChanges();
 
  /// The currently signed-in user, or null.
  User? get currentUser => _auth.currentUser;
 
  /// Sign in an existing user with email and password.
  /// Throws FirebaseAuthException on wrong credentials, invalid email, etc.
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }
 
  /// Create a new user, set their display name, and write their profile
  /// document to Firestore in one flow. If the Firestore write fails we
  /// do NOT roll back auth — the user can log in next time and we'll
  /// lazy-create their profile doc then.
  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) return null;
 
    await user.updateDisplayName(displayName.trim());
 
    // Create the user's profile document. Keyed by UID so security rules
    // can check `request.auth.uid == userId`.
    await _db.collection('users').doc(user.uid).set({
      'displayName': displayName.trim(),
      'email': email.trim(),
      'avatarUrl': null,
      'fcmToken': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
 
    return user;
  }
 
  Future<void> signOut() => _auth.signOut();
}