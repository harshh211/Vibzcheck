import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/session.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';

/// SessionScreen is the room the user is in. For Stage 3 it shows:
///   - Session name + shareable join code
///   - Live-streaming member list (updates as people join/leave)
///   - Leave button (becomes "Close session" if you're the host)
///
/// Stage 4 will add the track queue. Stage 5 adds voting. Stage 6 adds chat.
/// Keeping this screen thin now makes those additions easier — each
/// becomes a tab or a section rather than a rewrite.
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
              Text(
                'Members · ${session.memberIds.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _MembersList(
                memberIds: session.memberIds,
                hostId: session.hostId,
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.queue_music, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Track queue coming in the next build',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

/// Fetches member profiles in one batch query. We rebuild this whenever
/// the parent stream delivers a new memberIds list — not every rebuild,
/// since FutureBuilder keys off its `future` parameter.
class _MembersList extends StatelessWidget {
  final List<String> memberIds;
  final String hostId;

  const _MembersList({required this.memberIds, required this.hostId});

  @override
  Widget build(BuildContext context) {
    // Sorted so the UI is stable across rebuilds.
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

        // Host appears first.
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