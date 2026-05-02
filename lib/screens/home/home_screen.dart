import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/session.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import '../session/session_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
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


class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              'No sessions yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a session or join one using a code to get the vibe going.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Tap "Create" or "Join" below',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
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
        leading: _MemberAvatarStack(memberIds: session.memberIds),
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
/// Stack of up to 3 member avatars overlaid Russian-doll style. Used on
/// session tiles in the home list to give a glanceable sense of who's
/// in each session.
///
/// Performance: each tile fetches its own member profiles. With 3-5
/// sessions on screen this is fine; for a chattier app we'd batch.
class _MemberAvatarStack extends StatelessWidget {
  final List<String> memberIds;
  const _MemberAvatarStack({required this.memberIds});

  @override
  Widget build(BuildContext context) {
    // Show at most 3 avatars to keep the leading slot tidy. The order
    // is just memberIds order — host is typically first since they're
    // written in that position when the session is created.
    final shownIds = memberIds.take(3).toList();

    return SizedBox(
      width: 56,
      height: 40,
      child: FutureBuilder<List<AppUser>>(
        future: FirestoreService().getUsersByIds(shownIds),
        builder: (context, snapshot) {
          // Show a quiet placeholder while loading — avoids a flash of
          // empty space that pushes the title around.
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.group, size: 18),
            );
          }

          // Stack avatars with a slight horizontal offset for the
          // overlap effect.
          return Stack(
            children: [
              for (var i = 0; i < users.length; i++)
                Positioned(
                  left: i * 14.0,
                  child: _SmallAvatar(user: users[i]),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  final AppUser user;
  const _SmallAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final hasUrl = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;
    final initial =
        user.displayName.isEmpty ? '?' : user.displayName[0].toUpperCase();

    // White ring around each avatar so the overlap is visually clean.
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
      child: hasUrl
          ? CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(user.avatarUrl!),
            )
          : CircleAvatar(
              child: Text(
                initial,
                style: const TextStyle(fontSize: 12),
              ),
            ),
    );
  }
}