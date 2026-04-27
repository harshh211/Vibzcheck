import 'package:cloud_firestore/cloud_firestore.dart';

/// Track mirrors the /sessions/{sessionId}/tracks/{trackId} Firestore document.
/// Combines Spotify metadata (title, artist, album art) with collaborative
/// voting state (voteScore, upvoters, downvoters) and mood tags.
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

  Track({
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
      };

  /// Convenience for the UI: did this user already upvote / downvote?
  bool isUpvotedBy(String userId) => upvoters.contains(userId);
  bool isDownvotedBy(String userId) => downvoters.contains(userId);
}