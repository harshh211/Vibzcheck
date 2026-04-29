import '../models/track.dart';

class Recommendation {
  final Track track;
  final int score;
  final String reason;

  const Recommendation({
    required this.track,
    required this.score,
    required this.reason,
  });
}

class RecommendationEngine {
  static const int _popularityWeight = 10;
  static const int _moodMatchWeight = 8;
  static const int _audioFeatureWeight = 6;
  static const int _alreadyUpvotedPenalty = 25;
  static const int _alreadyDownvotedPenalty = 100;
  static const int _untaggedSmallBoost = 2;

  /// Rank tracks for the given user. Returns up to [limit] suggestions
  /// sorted by score descending. Ties broken by original queue order.
  static List<Recommendation> rank({
    required List<Track> tracks,
    required String currentUserId,
    int limit = 3,
  }) {
    if (tracks.isEmpty) return const [];

    final sessionMood = _computeSessionMood(tracks);
    final sessionAudio = _computeSessionAudioProfile(tracks);

    final scored = tracks.map((track) {
      final contributions = _scoreTrack(
        track: track,
        currentUserId: currentUserId,
        sessionMood: sessionMood,
        sessionAudio: sessionAudio,
      );

      final totalScore =
          contributions.fold<int>(0, (sum, c) => sum + c.score);

      contributions.sort((a, b) => b.score.abs().compareTo(a.score.abs()));
      final headlineReason =
          contributions.isEmpty ? 'Default' : contributions.first.label;

      return Recommendation(
        track: track,
        score: totalScore,
        reason: headlineReason,
      );
    }).toList();

    final indexed = scored.asMap().entries.toList();
    indexed.sort((a, b) {
      final scoreCompare = b.value.score.compareTo(a.value.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.key.compareTo(b.key);
    });

    return indexed.take(limit).map((e) => e.value).toList();
  }

  // ---- Internal scoring -----------------------------------------------

  static List<_Contribution> _scoreTrack({
    required Track track,
    required String currentUserId,
    required Map<String, int> sessionMood,
    required _AudioProfile? sessionAudio,
  }) {
    final out = <_Contribution>[];

    // RULE 1: Popularity.
    if (track.voteScore != 0) {
      out.add(_Contribution(
        score: track.voteScore * _popularityWeight,
        label: track.voteScore > 0
            ? 'Highly upvoted by the group'
            : 'Group voted this down',
      ));
    }

    // RULE 2: Mood tag match.
    final matchingTagCount =
        track.moodTags.where((tag) => sessionMood.containsKey(tag)).length;
    if (matchingTagCount > 0) {
      out.add(_Contribution(
        score: matchingTagCount * _moodMatchWeight,
        label: 'Matches the session mood',
      ));
    }

    // RULE 3: Audio feature similarity to session profile.
    // Only applied when both the track and the session have audio data.
    if (sessionAudio != null &&
        track.energy != null &&
        track.tempo != null &&
        track.danceability != null) {
      final energyDiff = (track.energy! - sessionAudio.avgEnergy).abs();
      final danceDiff =
          (track.danceability! - sessionAudio.avgDanceability).abs();
      // Tempo is 60-200 BPM — normalise to 0-1 range before comparing.
      final tempoDiff =
          ((track.tempo! - sessionAudio.avgTempo) / 140.0).abs().clamp(0.0, 1.0);

      // Sum of diffs: 0 = perfect match, 3 = complete mismatch.
      final totalDiff = energyDiff + danceDiff + tempoDiff;

      // Convert to a 0–3 similarity score (3 = perfect match).
      final similarity = (3.0 - totalDiff).clamp(0.0, 3.0);
      final pts = (similarity * _audioFeatureWeight).round();

      if (pts > 0) {
        out.add(_Contribution(
          score: pts,
          label: 'Fits the session vibe',
        ));
      }
    }

    // RULE 4: User already voted.
    if (track.isUpvotedBy(currentUserId)) {
      out.add(const _Contribution(
        score: -_alreadyUpvotedPenalty,
        label: 'You already upvoted this',
      ));
    }
    if (track.isDownvotedBy(currentUserId)) {
      out.add(const _Contribution(
        score: -_alreadyDownvotedPenalty,
        label: 'You downvoted this',
      ));
    }

    // RULE 5: Fresh track boost.
    if (track.voteScore == 0 &&
        track.moodTags.isEmpty &&
        !track.isUpvotedBy(currentUserId) &&
        !track.isDownvotedBy(currentUserId)) {
      out.add(const _Contribution(
        score: _untaggedSmallBoost,
        label: 'Fresh addition to the queue',
      ));
    }

    return out;
  }

  /// Average audio features across upvoted tracks that have feature data.
  static _AudioProfile? _computeSessionAudioProfile(List<Track> tracks) {
    final upvoted = tracks.where((t) =>
        t.voteScore > 0 &&
        t.energy != null &&
        t.tempo != null &&
        t.danceability != null).toList();

    if (upvoted.isEmpty) return null;

    final avgEnergy =
        upvoted.map((t) => t.energy!).reduce((a, b) => a + b) / upvoted.length;
    final avgTempo =
        upvoted.map((t) => t.tempo!).reduce((a, b) => a + b) / upvoted.length;
    final avgDanceability =
        upvoted.map((t) => t.danceability!).reduce((a, b) => a + b) /
            upvoted.length;

    return _AudioProfile(
      avgEnergy: avgEnergy,
      avgTempo: avgTempo,
      avgDanceability: avgDanceability,
    );
  }

  /// Top 3 mood tags across upvoted tracks.
  static Map<String, int> _computeSessionMood(List<Track> tracks) {
    final counts = <String, int>{};
    for (final track in tracks) {
      if (track.voteScore <= 0) continue;
      for (final tag in track.moodTags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const {};

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted.take(3)) e.key: e.value};
  }
}

class _AudioProfile {
  final double avgEnergy;
  final double avgTempo;
  final double avgDanceability;

  const _AudioProfile({
    required this.avgEnergy,
    required this.avgTempo,
    required this.avgDanceability,
  });
}

/// Internal: a single rule's contribution to a track's score.
class _Contribution {
  final int score;
  final String label;
  const _Contribution({required this.score, required this.label});
}