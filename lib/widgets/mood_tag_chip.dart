import 'package:flutter/material.dart';

import '../models/mood_tag.dart';


class MoodTagChip extends StatelessWidget {
  final MoodTag tag;

  /// If null, the chip is display-only. If non-null, the chip behaves as a toggle showing the current selection state.
  final bool? selected;

  /// Called when the chip is tapped. Only fires if [selected] is non-null.
  final VoidCallback? onTap;

  const MoodTagChip({
    super.key,
    required this.tag,
    this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPickable = selected != null;
    final isOn = selected == true;

    // In display mode, treat the chip as "on" — we want the tag's color
    // to stand out so users can identify tagged tracks at a glance.
    final filled = !isPickable || isOn;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? tag.color.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
            color: filled ? tag.color : tag.color.withValues(alpha: 0.4),
            width: filled ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tag.icon, size: 14, color: tag.color),
            const SizedBox(width: 6),
            Text(
              tag.label,
              style: TextStyle(
                color: tag.color,
                fontSize: 12,
                fontWeight: filled ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}