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