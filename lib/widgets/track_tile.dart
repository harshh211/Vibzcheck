import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/track.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const TrackTile({
    super.key,
    required this.track,
    this.leading,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAudioFeatures =
        track.tempo != null || track.energy != null || track.danceability != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              _AlbumArt(url: track.albumArtUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Audio feature chips — only shown when data is available.
                    if (hasAudioFeatures) ...[
                      const SizedBox(height: 6),
                      _AudioFeatureRow(track: track),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact row of audio feature badges. Each badge shows an icon + value.
/// Only renders fields that are non-null so search results (no features yet)
/// show nothing here.
class _AudioFeatureRow extends StatelessWidget {
  final Track track;
  const _AudioFeatureRow({required this.track});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 6,
      children: [
        if (track.tempo != null)
          _FeatureBadge(
            icon: Icons.speed,
            label: '${track.tempo!.round()} BPM',
            color: scheme.tertiary,
          ),
        if (track.energy != null)
          _FeatureBadge(
            icon: Icons.bolt,
            label: '${(track.energy! * 100).round()}% energy',
            color: scheme.error,
          ),
        if (track.danceability != null)
          _FeatureBadge(
            icon: Icons.directions_walk,
            label: '${(track.danceability! * 100).round()}% dance',
            color: scheme.primary,
          ),
      ],
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final String url;
  const _AlbumArt({required this.url});

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    if (url.isEmpty) {
      return _placeholder(context, size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(context, size),
        errorWidget: (_, __, ___) => _placeholder(context, size),
      ),
    );
  }

  Widget _placeholder(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.music_note, size: 28),
    );
  }
}