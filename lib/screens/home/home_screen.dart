import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/session.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../session/session_screen.dart';
import 'create_session_screen.dart';
import 'join_session_sheet.dart';
import '../profile/profile_screen.dart';
import '../insights/insights_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sessionProvider = context.read<SessionProvider>();

    final userId = auth.currentUser?.uid;
    final displayName = auth.currentUser?.displayName ?? 'there';

    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('VibzCheck'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 98, 13, 105).withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hey, $displayName 👋',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a session, join your friends, and keep the music going.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(
              children: [
                Text(
                  'Your Sessions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                const Icon(Icons.queue_music, size: 20),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Session>>(
              stream: sessionProvider.streamMySessions(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load sessions. Try again later.'),
                  );
                }

                final sessions = snapshot.data ?? [];

                if (sessions.isEmpty) {
                  return const _EmptySessions();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
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
              size: 76,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              'No sessions yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a session or join one with a code to start sharing music.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Use the buttons below to get started',
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
      if (created != null) 'Created ${DateFormat.MMMd().format(created)}',
    ].join(' · ');

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _MemberAvatarStack(memberIds: session.memberIds),
        title: Row(
          children: [
            Flexible(
              child: Text(
                session.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isHost) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Text('Host'),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                backgroundColor:
                    const Color.fromARGB(255, 148, 40, 158).withOpacity(0.12),
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

class _MemberAvatarStack extends StatelessWidget {
  final List<String> memberIds;

  const _MemberAvatarStack({required this.memberIds});

  @override
  Widget build(BuildContext context) {
    final shownIds = memberIds.take(3).toList();

    return SizedBox(
      width: 56,
      height: 40,
      child: FutureBuilder<List<AppUser>>(
        future: FirestoreService().getUsersByIds(shownIds),
        builder: (context, snapshot) {
          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.group, size: 18),
            );
          }

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