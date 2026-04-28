import 'package:flutter/material.dart';

class MoodTag {
  final String label;
  final IconData icon;
  final Color color;

  const MoodTag({
    required this.label,
    required this.icon,
    required this.color,
  });

  /// Master list. The order here is the order users see in the picker
  /// — high-energy first, then low-energy, then genre-flavored.
  static const List<MoodTag> all = [
    MoodTag(label: 'hype',    icon: Icons.local_fire_department, color: Color(0xFFE74C3C)),
    MoodTag(label: 'party',   icon: Icons.celebration,           color: Color(0xFFE91E63)),
    MoodTag(label: 'workout', icon: Icons.fitness_center,        color: Color(0xFFFF9800)),
    MoodTag(label: 'chill',   icon: Icons.cloud,                 color: Color(0xFF3498DB)),
    MoodTag(label: 'focus',   icon: Icons.center_focus_strong,   color: Color(0xFF1ABC9C)),
    MoodTag(label: 'sad',     icon: Icons.water_drop,            color: Color(0xFF2C3E50)),
    MoodTag(label: 'romance', icon: Icons.favorite,              color: Color(0xFFE91E63)),
    MoodTag(label: 'throwback', icon: Icons.history,             color: Color(0xFF9B59B6)),
  ];

  /// Look up a tag by its stored label. Returns null if the label is
  /// unknown (defensive — useful when reading old data after a tag is
  /// removed from the master list).
  static MoodTag? lookup(String label) {
    for (final tag in all) {
      if (tag.label == label) return tag;
    }
    return null;
  }
}