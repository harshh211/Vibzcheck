import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/track.dart';

/// TrackTile is a reusable row showing album art, title, and artist for a
/// Track. Used by both the queue (with vote controls in Stage 5) and the
/// search results screen (with an "add" action).
///
/// Two slots — `leading` and `trailing` — let callers customize without
/// forking the widget. Pass an Icon, IconButton, or any small widget.
class TrackTile extends StatelessWidget {
  final Track track;

  /// Optional leading widget shown before the album art (e.g. a queue
  /// position number, or vote score). If null, only album art is shown.
  final Widget? leading;

  /// Optional trailing widget (e.g. an "Add" button or vote buttons).
  final Widget? trailing;

  /// Optional row tap handler (e.g. for a "view track details" flow).
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

/// Album art with placeholder + error fallback. Uses cached_network_image
/// so we don't re-download every time the queue rebuilds (which happens
/// often on real-time updates).
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