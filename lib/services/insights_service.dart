import 'package:cloud_firestore/cloud_firestore.dart';


class InsightsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;


  Future<InsightsResult> computeForUser(String userId) async {
   
    final sessionsSnap = await _db
        .collection('sessions')
        .where('memberIds', arrayContains: userId)
        .get();

    int sessionsHosted = 0;
    int sessionsJoined = 0;
    int totalTracksAdded = 0;
    final moodCounts = <String, int>{};
    final artistCounts = <String, int>{};
    int upvotesGiven = 0;
    int downvotesGiven = 0;

    for (final sessionDoc in sessionsSnap.docs) {
      final data = sessionDoc.data();
      if ((data['hostId'] as String?) == userId) {
        sessionsHosted++;
      } else {
        sessionsJoined++;
      }

      // Pull tracks subcollection for this session.
      final tracksSnap =
          await sessionDoc.reference.collection('tracks').get();

      for (final trackDoc in tracksSnap.docs) {
        final t = trackDoc.data();

        // Tracks added by THIS user.
        if ((t['addedBy'] as String?) == userId) {
          totalTracksAdded++;
          final artist = t['artist'] as String?;
          if (artist != null && artist.isNotEmpty) {
            artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
          }
        }

        // Votes BY this user (regardless of who added the track).
        final upvoters = List<String>.from(t['upvoters'] as List? ?? []);
        final downvoters = List<String>.from(t['downvoters'] as List? ?? []);
        if (upvoters.contains(userId)) upvotesGiven++;
        if (downvoters.contains(userId)) downvotesGiven++;

        // Mood tags on tracks the user has interacted with (added or voted on).
        final involvedHere = (t['addedBy'] as String?) == userId ||
            upvoters.contains(userId) ||
            downvoters.contains(userId);
        if (involvedHere) {
          final tags = List<String>.from(t['moodTags'] as List? ?? []);
          for (final tag in tags) {
            moodCounts[tag] = (moodCounts[tag] ?? 0) + 1;
          }
        }
      }
    }

    return InsightsResult(
      sessionsHosted: sessionsHosted,
      sessionsJoined: sessionsJoined,
      totalTracksAdded: totalTracksAdded,
      upvotesGiven: upvotesGiven,
      downvotesGiven: downvotesGiven,
      topArtists: _topN(artistCounts, 5),
      topMoods: _topN(moodCounts, 5),
    );
  }


  List<MapEntry<String, int>> _topN(Map<String, int> counts, int n) {
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return sorted.take(n).toList();
  }
}


class InsightsResult {
  final int sessionsHosted;
  final int sessionsJoined;
  final int totalTracksAdded;
  final int upvotesGiven;
  final int downvotesGiven;
  final List<MapEntry<String, int>> topArtists;
  final List<MapEntry<String, int>> topMoods;

  InsightsResult({
    required this.sessionsHosted,
    required this.sessionsJoined,
    required this.totalTracksAdded,
    required this.upvotesGiven,
    required this.downvotesGiven,
    required this.topArtists,
    required this.topMoods,
  });
}