import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/mood_tag.dart';
import '../../models/session.dart';
import '../../models/track.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/recommendation_engine.dart';
import '../../widgets/mood_tag_chip.dart';
import '../../widgets/track_tile.dart';
import '../../widgets/vote_buttons.dart';
import 'search_tracks_screen.dart';
import 'chat_screen.dart';

/// SessionScreen is the room the user is in. It shows:
///   - Session name + shareable join code
///   - Live-streaming member list (avatars update as users change them)
///   - Suggestions card (top 3 from RecommendationEngine)
///   - Live-streaming track queue with vote controls + mood tags
///   - FAB to open the Spotify search screen
///   - Leave button (becomes "Close session" if you're the host)
class SessionScreen extends StatelessWidget {
  final String sessionId;
  const SessionScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.read<SessionProvider>();
    final userId = context.read<AuthProvider>().currentUser?.uid;

    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<Session>(
      stream: sessionProvider.streamSession(sessionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('This session is no longer available.'),
            ),
          );
        }

        final session = snapshot.data!;
        final isHost = session.isHost(userId);

        return Scaffold(
          appBar: AppBar(
            title: Text(session.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Chat',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        sessionId: sessionId,
                        memberIds: session.memberIds,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                tooltip: isHost ? 'Close session' : 'Leave session',
                onPressed: () => _confirmLeave(context, session, userId),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _JoinCodeCard(joinCode: session.joinCode),
              const SizedBox(height: 24),
              _SectionHeader(
                'Members · ${session.memberIds.length}',
              ),
              const SizedBox(height: 8),
              _MembersList(
                memberIds: session.memberIds,
                hostId: session.hostId,
              ),
              const SizedBox(height: 24),
              const _SectionHeader('Queue'),
              const SizedBox(height: 8),
              _QueueList(
                sessionId: sessionId,
                currentUserId: userId,
                hostId: session.hostId,
              ),
              const SizedBox(height: 80),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add tracks'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SearchTracksScreen(sessionId: sessionId),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmLeave(
    BuildContext context,
    Session session,
    String userId,
  ) async {
    final isHost = session.isHost(userId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isHost ? 'Close this session?' : 'Leave this session?'),
        content: Text(
          isHost
              ? 'Closing ends it for everyone. This cannot be undone.'
              : 'You can rejoin later if you still have the code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isHost ? 'Close' : 'Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<SessionProvider>().leaveSession(
          sessionId: session.id,
          userId: userId,
        );
    if (context.mounted) Navigator.of(context).pop();
  }
}

// -------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  final String joinCode;
  const _JoinCodeCard({required this.joinCode});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Join code',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              joinCode,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: joinCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copied'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersList extends StatelessWidget {
  final List<String> memberIds;
  final String hostId;

  const _MembersList({required this.memberIds, required this.hostId});

  @override
  Widget build(BuildContext context) {
    final sortedIds = List<String>.from(memberIds)..sort();

    return FutureBuilder<List<AppUser>>(
      future: FirestoreService().getUsersByIds(sortedIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Text('No members yet.');
        }

        users.sort((a, b) {
          if (a.uid == hostId) return -1;
          if (b.uid == hostId) return 1;
          return a.displayName.compareTo(b.displayName);
        });

        return Column(
          children: users.map((user) {
            final isHost = user.uid == hostId;
            final avatar = (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                ? CircleAvatar(
                    backgroundImage:
                        CachedNetworkImageProvider(user.avatarUrl!),
                  )
                : CircleAvatar(
                    child: Text(
                      user.displayName.isEmpty
                          ? '?'
                          : user.displayName[0].toUpperCase(),
                    ),
                  );

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: avatar,
                title: Text(user.displayName),
                trailing: isHost
                    ? const Chip(
                        label: Text('Host'),
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Live queue list. Streams the tracks subcollection in real time so any
/// member adding/removing/voting on/tagging a track shows up here without refresh.
class _QueueList extends StatelessWidget {
  final String sessionId;
  final String currentUserId;
  final String hostId;

  const _QueueList({
    required this.sessionId,
    required this.currentUserId,
    required this.hostId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SessionProvider>();

    return StreamBuilder<List<Track>>(
      stream: provider.streamTracks(sessionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Could not load queue.'),
          );
        }
        final tracks = snapshot.data ?? [];
        if (tracks.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.queue_music, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'No tracks yet — tap "Add tracks" to start the vibe.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            // ---- Suggestions card (top 3 recommendations) ----
            _SuggestionsCard(
              tracks: tracks,
              currentUserId: currentUserId,
            ),

            // ---- Queue ----
            ...tracks.map((track) {
              final canRemove = track.addedBy == currentUserId ||
                  hostId == currentUserId;
              return Column(
                children: [
                  TrackTile(
                    track: track,
                    onTap: () => _showTagPicker(
                      context,
                      sessionId: sessionId,
                      track: track,
                    ),
                    leading: VoteButtons(
                      track: track,
                      currentUserId: currentUserId,
                      onUpTap: () {
                        final newDirection =
                            track.isUpvotedBy(currentUserId) ? 0 : 1;
                        provider.voteOnTrack(
                          sessionId: sessionId,
                          trackId: track.id,
                          userId: currentUserId,
                          direction: newDirection,
                        );
                      },
                      onDownTap: () {
                        final newDirection =
                            track.isDownvotedBy(currentUserId) ? 0 : -1;
                        provider.voteOnTrack(
                          sessionId: sessionId,
                          trackId: track.id,
                          userId: currentUserId,
                          direction: newDirection,
                        );
                      },
                    ),
                    trailing: canRemove
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            tooltip: 'Remove',
                            onPressed: () => provider.removeTrack(
                              sessionId: sessionId,
                              trackId: track.id,
                            ),
                          )
                        : null,
                  ),
                  // Show applied tags as a horizontal row beneath the track
                  if (track.moodTags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: track.moodTags
                            .map((label) => MoodTag.lookup(label))
                            .where((tag) => tag != null)
                            .cast<MoodTag>()
                            .map((tag) => MoodTagChip(tag: tag))
                            .toList(),
                      ),
                    ),
                ],
              );
            }),
          ],
        );
      },
    );
  }

  /// Modal bottom sheet that lets any session member toggle mood tags
  /// on a track. Tags are session-wide (anyone can tag), so we read the
  /// current state from the track itself and let the user toggle from
  /// there. Real-time listener will reflect changes immediately.
  Future<void> _showTagPicker(
    BuildContext context, {
    required String sessionId,
    required Track track,
  }) async {
    await showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            // Local copy for instant UI feedback while Firestore write runs.
            final localTags = Set<String>.from(track.moodTags);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tag this track',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tags shape the session\'s mood for recommendations.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MoodTag.all.map((tag) {
                      final isOn = localTags.contains(tag.label);
                      return MoodTagChip(
                        tag: tag,
                        selected: isOn,
                        onTap: () {
                          setSheetState(() {
                            if (isOn) {
                              localTags.remove(tag.label);
                            } else {
                              localTags.add(tag.label);
                            }
                          });
                          FirestoreService().toggleMoodTag(
                            sessionId: sessionId,
                            trackId: track.id,
                            tag: tag.label,
                            currentlyApplied: isOn,
                          );
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Suggestions card showing the top 3 recommended tracks for the current
/// user. Pure UI — the scoring lives in RecommendationEngine. We hide
/// the card if there are no meaningful recommendations (all tracks are
/// already voted by user or queue is too small).
class _SuggestionsCard extends StatelessWidget {
  final List<Track> tracks;
  final String currentUserId;

  const _SuggestionsCard({
    required this.tracks,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final recs = RecommendationEngine.rank(
      tracks: tracks,
      currentUserId: currentUserId,
      limit: 3,
    );

    if (recs.isEmpty || recs.every((r) => r.score <= 0)) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Suggested for you',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...recs.map((rec) => _SuggestionRow(rec: rec)),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final Recommendation rec;
  const _SuggestionRow({required this.rec});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Score pill so users see WHY this ranks where it does.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${rec.score}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  rec.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}