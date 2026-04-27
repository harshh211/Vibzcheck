import 'package:flutter/material.dart';

import '../models/track.dart';

/// VoteButtons displays up/down arrows + the current score for a Track.
/// The user's current vote is shown with a filled icon (and accent color);
/// the unselected direction stays outlined and dim.
///
/// Tap behavior:
///   - Tap up arrow when not voted    -> upvote (+1 net)
///   - Tap up arrow when already up   -> clear vote (0 net)
///   - Tap up arrow when downvoted    -> switch to upvote (+2 net)
///   - Same logic mirrored for down arrow
///
/// The widget itself doesn't compute the new direction — it only emits
/// the user's intent ("up tapped" or "down tapped") and lets the caller
/// decide. This keeps the widget pure and the toggle logic in one place
/// (FirestoreService.voteOnTrack).
class VoteButtons extends StatelessWidget {
  final Track track;
  final String currentUserId;

  /// Called when user taps the up arrow. Caller is expected to dispatch
  /// a vote with direction = +1 if not already up, or 0 to clear.
  final VoidCallback onUpTap;

  /// Called when user taps the down arrow. Caller is expected to dispatch
  /// a vote with direction = -1 if not already down, or 0 to clear.
  final VoidCallback onDownTap;

  const VoteButtons({
    super.key,
    required this.track,
    required this.currentUserId,
    required this.onUpTap,
    required this.onDownTap,
  });

  @override
  Widget build(BuildContext context) {
    final upvoted = track.isUpvotedBy(currentUserId);
    final downvoted = track.isDownvotedBy(currentUserId);
    final score = track.voteScore;

    final scheme = Theme.of(context).colorScheme;
    final upColor = upvoted ? scheme.primary : scheme.onSurfaceVariant;
    final downColor = downvoted ? scheme.error : scheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            upvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
            color: upColor,
          ),
          tooltip: upvoted ? 'Remove upvote' : 'Upvote',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: onUpTap,
        ),
        // Score is shown in a fixed-width container so the column doesn't
        // jiggle as the score grows from "0" to "12" to "-3".
        SizedBox(
          width: 32,
          child: Text(
            score.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        IconButton(
          icon: Icon(
            downvoted ? Icons.thumb_down : Icons.thumb_down_outlined,
            color: downColor,
          ),
          tooltip: downvoted ? 'Remove downvote' : 'Downvote',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: onDownTap,
        ),
      ],
    );
  }
}