import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mood_tag.dart';
import '../../providers/auth_provider.dart';
import '../../services/insights_service.dart';
import '../../widgets/mood_tag_chip.dart';


class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final _service = InsightsService();
  Future<InsightsResult>? _futureInsights;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final userId = context.read<AuthProvider>().currentUser?.uid;
    if (userId == null) return;
    setState(() {
      _futureInsights = _service.computeForUser(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<InsightsResult>(
        future: _futureInsights,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load insights.'));
          }
          final result = snapshot.data;
          if (result == null) {
            return const Center(child: Text('No data yet.'));
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatGrid(result: result),
                const SizedBox(height: 24),
                _TopMoodsCard(result: result),
                const SizedBox(height: 16),
                _TopArtistsCard(result: result),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}


/// Grid of summary stats: sessions hosted, sessions joined, tracks added,
/// upvotes given, downvotes given. Two columns on phones.
class _StatGrid extends StatelessWidget {
  final InsightsResult result;
  const _StatGrid({required this.result});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(
        icon: Icons.star,
        label: 'Hosted',
        value: result.sessionsHosted,
      ),
      _StatItem(
        icon: Icons.group,
        label: 'Joined',
        value: result.sessionsJoined,
      ),
      _StatItem(
        icon: Icons.queue_music,
        label: 'Tracks added',
        value: result.totalTracksAdded,
      ),
      _StatItem(
        icon: Icons.thumb_up,
        label: 'Upvotes given',
        value: result.upvotesGiven,
      ),
      _StatItem(
        icon: Icons.thumb_down,
        label: 'Downvotes given',
        value: result.downvotesGiven,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: stats.map((s) => _StatCard(item: s)).toList(),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final int value;
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, color: scheme.primary, size: 28),
            const SizedBox(height: 4),
            Text(
              '${item.value}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              item.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}


class _TopMoodsCard extends StatelessWidget {
  final InsightsResult result;
  const _TopMoodsCard({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.topMoods.isEmpty) {
      return _EmptyCard(
        icon: Icons.mood,
        message: 'Tag tracks with moods to see your trends here.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your top moods',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.topMoods.map((entry) {
                final tag = MoodTag.lookup(entry.key);
                if (tag == null) {
                  return Chip(label: Text('${entry.key} (${entry.value})'));
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoodTagChip(tag: tag),
                    const SizedBox(width: 4),
                    Text(
                      '× ${entry.value}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(width: 12),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}


class _TopArtistsCard extends StatelessWidget {
  final InsightsResult result;
  const _TopArtistsCard({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.topArtists.isEmpty) {
      return _EmptyCard(
        icon: Icons.person,
        message: 'Add tracks to sessions to see your top artists.',
      );
    }

    final maxCount = result.topArtists.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your top artists',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...result.topArtists.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        // Simple horizontal bar to visualize relative count.
                        // Width scales to the highest count so the leader
                        // always fills the row.
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: entry.value / maxCount,
                            minHeight: 8,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${entry.value}',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}


class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}