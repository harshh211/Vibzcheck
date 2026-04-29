import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/session.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../session/session_screen.dart';
import 'create_session_screen.dart';
import 'join_session_sheet.dart';
import '../profile/profile_screen.dart';
import '../insights/insights_screen.dart';

/// HomeScreen is the signed-in landing page. It streams the user's active
/// sessions in real time so newly-created or newly-joined sessions appear
/// without refresh. Two actions: create a session, or join one by code.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sessionProvider = context.read<SessionProvider>();

    final userId = auth.currentUser?.uid;
    final displayName = auth.currentUser?.displayName ?? 'there';

    // Defensive: if somehow we get here without a user, show a loader.
    // AuthGate normally handles this, but a race during sign-out can slip through.
    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibzcheck'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'Insights',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InsightsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // ---- Greeting ----
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Hey, $displayName',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your sessions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),

          // ---- Session list (real-time Firestore stream) ----
          Expanded(
            child: StreamBuilder<List<Session>>(
              stream: sessionProvider.streamMySessions(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load sessions. Pull to retry.'),
                  );
                }
                final sessions = snapshot.data ?? [];
                if (sessions.isEmpty) {
                  return const _EmptySessions();
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return _SessionTile(
                      session: session,
                      isHost: session.isHost(userId),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                SessionScreen(sessionId: session.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _HomeActions(userId: userId),
    );
  }
}

// -------------------------------------------------------------------------
// Private widgets kept in this file since they have no standalone reuse.
// -------------------------------------------------------------------------

class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.queue_music, size: 64),
            const SizedBox(height: 16),
            Text(
              'No active sessions yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create one or join with a friend\'s code.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Session session;
  final bool isHost;
  final VoidCallback onTap;

  const _SessionTile({
    required this.session,
    required this.isHost,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final memberCount = session.memberIds.length;
    final created = session.createdAt;
    final subtitle = [
      '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
      if (created != null) DateFormat.MMMd().format(created),
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            session.name.isEmpty ? '?' : session.name[0].toUpperCase(),
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(session.name, overflow: TextOverflow.ellipsis)),
            if (isHost) ...[
              const SizedBox(width: 8),
              const Chip(
                label: Text('Host'),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _HomeActions extends StatelessWidget {
  final String userId;
  const _HomeActions({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'join',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => JoinSessionSheet(userId: userId),
            );
          },
          icon: const Icon(Icons.login),
          label: const Text('Join'),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'create',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreateSessionScreen(hostId: userId),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Create'),
        ),
      ],
    );
  }
}
