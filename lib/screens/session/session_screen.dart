import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/session.dart';
import '../../models/track.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/track_tile.dart';
import '../../widgets/vote_buttons.dart';
import 'search_tracks_screen.dart';

/// SessionScreen is the room the user is in. As of Stage 4 it shows:
///   - Session name + shareable join code
///   - Live-streaming member list (updates as people join/leave)
///   - Live-streaming track queue (updates as tracks are added/removed/voted)
///   - FAB to open the Spotify search screen
///   - Leave button (becomes "Close session" if you're the host)
///
/// Stage 5 will add voting controls. Stage 6 adds chat.
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
              // Bottom padding so the FAB doesn't overlap the last item.
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
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    user.displayName.isEmpty
                        ? '?'
                        : user.displayName[0].toUpperCase(),
                  ),
                ),
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
/// member adding/removing a track shows up here without refresh.
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
          children: tracks.map((track) {
            final canRemove = track.addedBy == currentUserId ||
                hostId == currentUserId;
            return TrackTile(
              track: track,
              leading: VoteButtons(
                track: track,
                currentUserId: currentUserId,
                onUpTap: () {
                  // Toggle: if already upvoted, clear; otherwise upvote.
                  final newDirection = track.isUpvotedBy(currentUserId) ? 0 : 1;
                  provider.voteOnTrack(
                    sessionId: sessionId,
                    trackId: track.id,
                    userId: currentUserId,
                    direction: newDirection,
                  );
                },
                onDownTap: () {
                  // Toggle: if already downvoted, clear; otherwise downvote.
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
            );
          }).toList(),
        );
      },
    );
  }
}