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
  // Tunable weights as named constants so it's trivial to explain
  // "we weight popularity higher than mood overlap" in the demo.
  static const int _popularityWeight = 10;
  static const int _moodMatchWeight = 8;
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

    // Compute the "session mood" — most common tags on upvoted tracks.
    final sessionMood = _computeSessionMood(tracks);

    final scored = tracks.map((track) {
      final contributions = _scoreTrack(
        track: track,
        currentUserId: currentUserId,
        sessionMood: sessionMood,
      );

      final totalScore =
          contributions.fold<int>(0, (sum, c) => sum + c.score);

      // Headline reason = rule with largest absolute contribution.
      contributions.sort((a, b) => b.score.abs().compareTo(a.score.abs()));
      final headlineReason =
          contributions.isEmpty ? 'Default' : contributions.first.label;

      return Recommendation(
        track: track,
        score: totalScore,
        reason: headlineReason,
      );
    }).toList();

    // Sort by score desc, with original queue index as tiebreaker for
    // deterministic output.
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
  }) {
    final out = <_Contribution>[];

    // RULE 1: Popularity. Net votes drive the base score.
    if (track.voteScore != 0) {
      final pts = track.voteScore * _popularityWeight;
      out.add(_Contribution(
        score: pts,
        label: track.voteScore > 0
            ? 'Highly upvoted by the group'
            : 'Group voted this down',
      ));
    }

    // RULE 2: Mood match. Tags overlapping the session mood get a boost.
    final matchingTagCount =
        track.moodTags.where((tag) => sessionMood.containsKey(tag)).length;
    if (matchingTagCount > 0) {
      out.add(_Contribution(
        score: matchingTagCount * _moodMatchWeight,
        label: 'Matches the session mood',
      ));
    }

    // RULE 3: User already voted on this track. Penalize so we don't
    // recommend tracks the user has already weighed in on.
    if (track.isUpvotedBy(currentUserId)) {
      out.add(_Contribution(
        score: -_alreadyUpvotedPenalty,
        label: 'You already upvoted this',
      ));
    }
    if (track.isDownvotedBy(currentUserId)) {
      out.add(_Contribution(
        score: -_alreadyDownvotedPenalty,
        label: 'You downvoted this',
      ));
    }

    // RULE 4: Fresh tracks (no votes, no tags) get a tiny boost so
    // brand-new additions can still surface in suggestions.
    if (track.voteScore == 0 &&
        track.moodTags.isEmpty &&
        !track.isUpvotedBy(currentUserId) &&
        !track.isDownvotedBy(currentUserId)) {
      out.add(_Contribution(
        score: _untaggedSmallBoost,
        label: 'Fresh addition to the queue',
      ));
    }

    return out;
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

/// Internal: a single rule's contribution to a track's score.
class _Contribution {
  final int score;
  final String label;
  const _Contribution({required this.score, required this.label});
}