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
            return const _InsightsMessage(
              icon: Icons.error_outline,
              title: 'Could not load insights',
              message: 'Try refreshing or check your connection.',
            );
          }

          final result = snapshot.data;

          if (result == null) {
            return const _InsightsMessage(
              icon: Icons.music_note,
              title: 'No insights yet',
              message:
                  'Add songs, vote, and tag moods to build your music profile.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InsightsHeader(result: result),
                const SizedBox(height: 16),

                _StatGrid(result: result),

                const SizedBox(height: 24),

                _AudioProfileCard(result: result),

                const SizedBox(height: 16),

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

class _InsightsHeader extends StatelessWidget {
  final InsightsResult result;

  const _InsightsHeader({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color.fromARGB(255, 98, 13, 105).withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(
              Icons.insights,
              size: 42,
              color: Color.fromARGB(255, 98, 13, 105),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your music insights',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'See your sessions, votes, moods, and music habits.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Audio profile card -------------------------------------------------

class _AudioProfileCard extends StatelessWidget {
  final InsightsResult result;

  const _AudioProfileCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final hasData = result.avgTempo != null ||
        result.avgEnergy != null ||
        result.avgDanceability != null;

    if (!hasData) {
      return const _EmptyCard(
        icon: Icons.graphic_eq,
        message: 'Add tracks to sessions to see your audio profile here.',
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your audio profile',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Averages across tracks you have added.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            if (result.avgTempo != null)
              _AudioBar(
                icon: Icons.speed,
                label: 'Tempo',
                display: '${result.avgTempo!.round()} BPM',
                fraction: ((result.avgTempo! - 60) / 140).clamp(0.0, 1.0),
                color: Theme.of(context).colorScheme.tertiary,
              ),

            if (result.avgEnergy != null) ...[
              const SizedBox(height: 10),
              _AudioBar(
                icon: Icons.bolt,
                label: 'Energy',
                display: '${(result.avgEnergy! * 100).round()}%',
                fraction: result.avgEnergy!.clamp(0.0, 1.0),
                color: Theme.of(context).colorScheme.error,
              ),
            ],

            if (result.avgDanceability != null) ...[
              const SizedBox(height: 10),
              _AudioBar(
                icon: Icons.directions_walk,
                label: 'Danceability',
                display: '${(result.avgDanceability! * 100).round()}%',
                fraction: result.avgDanceability!.clamp(0.0, 1.0),
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AudioBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final String display;
  final double fraction;
  final Color color;

  const _AudioBar({
    required this.icon,
    required this.label,
    required this.display,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              color: color,
              backgroundColor: color.withOpacity(0.15),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}

// ---- Stat cards ---------------------------------------------------------

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
      childAspectRatio: 1.4,
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
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: scheme.primary.withOpacity(0.12),
              child: Icon(item.icon, color: scheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              '${item.value}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Mood card ----------------------------------------------------------

class _TopMoodsCard extends StatelessWidget {
  final InsightsResult result;

  const _TopMoodsCard({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.topMoods.isEmpty) {
      return const _EmptyCard(
        icon: Icons.mood,
        message: 'Tag tracks with moods to see your trends here.',
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your top moods',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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

// ---- Artist card --------------------------------------------------------

class _TopArtistsCard extends StatelessWidget {
  final InsightsResult result;

  const _TopArtistsCard({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.topArtists.isEmpty) {
      return const _EmptyCard(
        icon: Icons.person,
        message: 'Add tracks to sessions to see your top artists.',
      );
    }

    final maxCount = result.topArtists.first.value;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your top artists',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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

// ---- Empty / error states -----------------------------------------------

class _InsightsMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InsightsMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyCard({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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