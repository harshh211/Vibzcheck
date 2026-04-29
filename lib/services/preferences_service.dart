import 'package:cloud_firestore/cloud_firestore.dart';

/// PreferencesService persists per-user app preferences. Stored in
/// Firestore (not on-device) so prefs follow the user across devices.
///
/// Keyed under /users/{uid}.preferences (a map field) rather than a
/// subcollection — this is a small, fixed set of fields that always
/// load together with the user profile, so a flat map keeps reads cheap.
class PreferencesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Load preferences from the user doc. Returns defaults if no prefs
  /// exist yet (first launch after upgrade).
  Future<UserPreferences> load(String userId) async {
    final snap = await _db.collection('users').doc(userId).get();
    final data = snap.data() ?? {};
    final raw = data['preferences'] as Map<String, dynamic>? ?? {};
    return UserPreferences.fromMap(raw);
  }

  /// Persist preferences. Uses set with merge so we don't accidentally
  /// overwrite other user fields (displayName, fcmToken, etc).
  Future<void> save(String userId, UserPreferences prefs) async {
    await _db.collection('users').doc(userId).set(
      {'preferences': prefs.toMap()},
      SetOptions(merge: true),
    );
  }
}

/// Simple data carrier for app preferences. Add fields here as new
/// settings are introduced — defaults flow through fromMap.
class UserPreferences {
  /// Whether the user wants to receive push notifications. Note: this
  /// is the user's stated preference, separate from the OS-level
  /// permission. The actual decision is "OS allows AND user opted in".
  final bool notificationsEnabled;

  /// Recommendation engine bias toward popularity (1-10).
  /// Higher = highly-voted tracks rank harder.
  final int popularityWeight;

  /// Recommendation engine bias toward mood matching (1-10).
  /// Higher = tracks matching session mood rank harder.
  final int moodWeight;

  const UserPreferences({
    this.notificationsEnabled = true,
    this.popularityWeight = 5,
    this.moodWeight = 5,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      notificationsEnabled:
          (map['notificationsEnabled'] as bool?) ?? true,
      popularityWeight:
          (map['popularityWeight'] as num?)?.toInt() ?? 5,
      moodWeight: (map['moodWeight'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toMap() => {
        'notificationsEnabled': notificationsEnabled,
        'popularityWeight': popularityWeight,
        'moodWeight': moodWeight,
      };

  UserPreferences copyWith({
    bool? notificationsEnabled,
    int? popularityWeight,
    int? moodWeight,
  }) {
    return UserPreferences(
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      popularityWeight: popularityWeight ?? this.popularityWeight,
      moodWeight: moodWeight ?? this.moodWeight,
    );
  }
}