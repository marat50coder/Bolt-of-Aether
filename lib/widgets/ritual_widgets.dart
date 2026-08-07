import 'package:flutter/material.dart';

import '../core/app_palette.dart';
import '../core/models.dart';

/// Row of five mood icons, shared by the Evening Discharge mood picker and
/// the Dream Journal's "mood on waking" picker.
class RitualMoodSelector extends StatelessWidget {
  const RitualMoodSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.color = AetherColors.electric,
  });

  final RitualMood? value;
  final ValueChanged<RitualMood> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final mood in RitualMood.values)
          _MoodDot(
            mood: mood,
            active: value == mood,
            color: color,
            onTap: () => onChanged(mood),
          ),
      ],
    );
  }
}

class _MoodDot extends StatelessWidget {
  const _MoodDot({
    required this.mood,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final RitualMood mood;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        width: active ? 54 : 46,
        height: active ? 54 : 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? color.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.85) : AetherColors.glassStroke,
            width: active ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(mood.icon, color: active ? color : AetherColors.muted, size: active ? 24 : 20),
          ],
        ),
      ),
    );
  }
}

/// Multi-select chip row for the Dream Journal's tags.
class DreamTagChips extends StatelessWidget {
  const DreamTagChips({
    super.key,
    required this.selected,
    required this.onToggle,
    this.color = AetherColors.violet,
  });

  final Set<DreamTag> selected;
  final ValueChanged<DreamTag> onToggle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in DreamTag.values)
          _TagChip(
            tag: tag,
            active: selected.contains(tag),
            color: color,
            onTap: () => onToggle(tag),
          ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final DreamTag tag;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.8) : AetherColors.glassStroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tag.icon, size: 14, color: active ? color : AetherColors.muted),
            const SizedBox(width: 6),
            Text(
              tag.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? color : AetherColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
