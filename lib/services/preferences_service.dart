import 'package:cloud_firestore/cloud_firestore.dart';

class PreferencesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserPreferences> load(String userId) async {
    final snap = await _db.collection('users').doc(userId).get();
    final data = snap.data() ?? {};
    final raw = data['preferences'] as Map<String, dynamic>? ?? {};
    return UserPreferences.fromMap(raw);
  }

  Future<void> save(String userId, UserPreferences prefs) async {
    await _db.collection('users').doc(userId).set(
      {'preferences': prefs.toMap()},
      SetOptions(merge: true),
    );
  }
}

class UserPreferences {
  final bool notificationsEnabled;

  /// Recommendation engine bias toward popularity (1-10).
  final int popularityWeight;

  /// Recommendation engine bias toward mood matching (1-10).
  final int moodWeight;

  /// Recommendation engine bias toward audio feature similarity (1-10).
  final int audioFeatureWeight;

  const UserPreferences({
    this.notificationsEnabled = true,
    this.popularityWeight = 5,
    this.moodWeight = 5,
    this.audioFeatureWeight = 5,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      notificationsEnabled: (map['notificationsEnabled'] as bool?) ?? true,
      popularityWeight: (map['popularityWeight'] as num?)?.toInt() ?? 5,
      moodWeight: (map['moodWeight'] as num?)?.toInt() ?? 5,
      audioFeatureWeight: (map['audioFeatureWeight'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toMap() => {
        'notificationsEnabled': notificationsEnabled,
        'popularityWeight': popularityWeight,
        'moodWeight': moodWeight,
        'audioFeatureWeight': audioFeatureWeight,
      };

  UserPreferences copyWith({
    bool? notificationsEnabled,
    int? popularityWeight,
    int? moodWeight,
    int? audioFeatureWeight,
  }) {
    return UserPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      popularityWeight: popularityWeight ?? this.popularityWeight,
      moodWeight: moodWeight ?? this.moodWeight,
      audioFeatureWeight: audioFeatureWeight ?? this.audioFeatureWeight,
    );
  }
}