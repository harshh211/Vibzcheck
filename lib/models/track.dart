import 'package:cloud_firestore/cloud_firestore.dart';


class Track {
  final String id;
  final String spotifyId;
  final String title;
  final String artist;
  final String albumArtUrl;
  final String? previewUrl;
  final String addedBy;
  final DateTime? addedAt;
  final int voteScore;
  final List<String> upvoters;
  final List<String> downvoters;
  final List<String> moodTags;
  final double? tempo;
  final double? energy;
  final double? danceability;

  const Track({
    required this.id,
    required this.spotifyId,
    required this.title,
    required this.artist,
    required this.albumArtUrl,
    required this.addedBy,
    required this.voteScore,
    required this.upvoters,
    required this.downvoters,
    required this.moodTags,
    this.previewUrl,
    this.addedAt,
    this.tempo,
    this.energy,
    this.danceability,
  });

  factory Track.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Track(
      id: doc.id,
      spotifyId: data['spotifyId'] as String? ?? '',
      title: data['title'] as String? ?? 'Unknown title',
      artist: data['artist'] as String? ?? 'Unknown artist',
      albumArtUrl: data['albumArtUrl'] as String? ?? '',
      previewUrl: data['previewUrl'] as String?,
      addedBy: data['addedBy'] as String? ?? '',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
      voteScore: (data['voteScore'] as num?)?.toInt() ?? 0,
      upvoters: List<String>.from(data['upvoters'] as List? ?? []),
      downvoters: List<String>.from(data['downvoters'] as List? ?? []),
      moodTags: List<String>.from(data['moodTags'] as List? ?? []),
      tempo: (data['tempo'] as num?)?.toDouble(),
      energy: (data['energy'] as num?)?.toDouble(),
      danceability: (data['danceability'] as num?)?.toDouble(),
    );
  }

  /// Used when adding a track to the queue. voteScore starts at 0,
  /// arrays start empty. The server timestamp guarantees correct
  /// ordering even if multiple users add tracks simultaneously.
  Map<String, dynamic> toCreateMap() => {
        'spotifyId': spotifyId,
        'title': title,
        'artist': artist,
        'albumArtUrl': albumArtUrl,
        'previewUrl': previewUrl,
        'addedBy': addedBy,
        'addedAt': FieldValue.serverTimestamp(),
        'voteScore': 0,
        'upvoters': <String>[],
        'downvoters': <String>[],
        'moodTags': <String>[],
        if (tempo != null) 'tempo': tempo,
        if (energy != null) 'energy': energy,
        if (danceability != null) 'danceability': danceability,
      };

  Track copyWith({
    String? id,
    String? spotifyId,
    String? title,
    String? artist,
    String? albumArtUrl,
    String? previewUrl,
    String? addedBy,
    DateTime? addedAt,
    int? voteScore,
    List<String>? upvoters,
    List<String>? downvoters,
    List<String>? moodTags,
    double? tempo,
    double? energy,
    double? danceability,
  }) {
    return Track(
      id: id ?? this.id,
      spotifyId: spotifyId ?? this.spotifyId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      addedBy: addedBy ?? this.addedBy,
      addedAt: addedAt ?? this.addedAt,
      voteScore: voteScore ?? this.voteScore,
      upvoters: upvoters ?? this.upvoters,
      downvoters: downvoters ?? this.downvoters,
      moodTags: moodTags ?? this.moodTags,
      tempo: tempo ?? this.tempo,
      energy: energy ?? this.energy,
      danceability: danceability ?? this.danceability,
    );
  }

  /// Convenience for the UI: did this user already upvote / downvote?
  bool isUpvotedBy(String userId) => upvoters.contains(userId);
  bool isDownvotedBy(String userId) => downvoters.contains(userId);
}