import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_palette.dart';
import '../core/app_scope.dart';
import '../core/date_keys.dart';
import '../core/models.dart';
import '../core/sleep_utils.dart';
import '../widgets/glass.dart';
import 'evening_discharge_screen.dart';

/// Personal history of the sleep ritual: streak, per-day heatmap, mood trend,
/// evening reflections and dream journal — all local, all yours.
class RitualsScreen extends StatefulWidget {
  const RitualsScreen({super.key});

  @override
  State<RitualsScreen> createState() => _RitualsScreenState();
}

enum _Filter { all, evenings, dreams }

class _RitualsScreenState extends State<RitualsScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final evenings = state.eveningEntries;
    final dreams = state.dreamEntries;
    final mornings = state.morningChargeDayKeys;
    final streak = state.sleepStreak;
    final lastNight = state.lastNightSummary;
    final showEveningBanner =
        !state.eveningDoneToday && state.eveningBannerDue;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
      children: [
        ShaderText(
          'Rituals',
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Your inner charge, tracked one day at a time.',
          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.68)),
        ),
        const SizedBox(height: 18),
        _StreakCard(streak: streak, lastNight: lastNight),
        const SizedBox(height: 14),
        _StatsRow(
          mornings: mornings.length,
          evenings: evenings.length,
          dreams: dreams.length,
        ),
        const SizedBox(height: 18),
        const SectionTitle('Last 14 days'),
        const SizedBox(height: 10),
        _ActivityStrip(
          mornings: mornings,
          eveningKeys: {for (final e in evenings) e.dateKey},
          dreamKeys: {for (final d in dreams) d.dateKey},
        ),
        if (evenings.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionTitle('Recent moods'),
          const SizedBox(height: 10),
          _MoodTrend(entries: evenings),
        ],
        if (showEveningBanner) ...[
          const SizedBox(height: 18),
          _DischargeBanner(
            onTap: () {
              tap(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EveningDischargeScreen()),
              );
            },
          ),
        ],
        const SizedBox(height: 22),
        _FilterBar(
          value: _filter,
          eveningsCount: evenings.length,
          dreamsCount: dreams.length,
          onChanged: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 14),
        ..._buildTimeline(evenings, dreams),
      ],
    );
  }

  /// Builds either a merged, most-recent-first timeline of both kinds of
  /// entries, or just one of them depending on the active filter.
  List<Widget> _buildTimeline(
    List<EveningEntry> evenings,
    List<DreamEntry> dreams,
  ) {
    final widgets = <Widget>[];

    if (_filter == _Filter.evenings) {
      if (evenings.isEmpty) {
        widgets.add(const _EmptyBlock(
          icon: Icons.nightlight_round,
          title: 'No evening entries yet',
          body: 'Discharge your day after 9pm to start building a record.',
        ));
      } else {
        for (final entry in evenings.take(40)) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EveningTile(entry: entry),
          ));
        }
      }
      return widgets;
    }

    if (_filter == _Filter.dreams) {
      if (dreams.isEmpty) {
        widgets.add(const _EmptyBlock(
          icon: Icons.auto_awesome_rounded,
          title: 'No dreams logged yet',
          body: 'The Dream Journal appears after every Morning Charge.',
        ));
      } else {
        for (final dream in dreams.take(40)) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DreamTile(dream: dream),
          ));
        }
      }
      return widgets;
    }

    // "All": interleave evenings and dreams by createdAt.
    final merged = <_TimelineItem>[
      for (final e in evenings) _TimelineItem.evening(e),
      for (final d in dreams) _TimelineItem.dream(d),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (merged.isEmpty) {
      widgets.add(const _EmptyBlock(
        icon: Icons.self_improvement_rounded,
        title: 'No rituals recorded yet',
        body: 'Your first Morning Charge and Evening Discharge will land here.',
      ));
      return widgets;
    }

    for (final item in merged.take(40)) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: item.evening != null
            ? _EveningTile(entry: item.evening!)
            : _DreamTile(dream: item.dream!),
      ));
    }
    return widgets;
  }
}

class _TimelineItem {
  _TimelineItem.evening(EveningEntry e)
      : evening = e,
        dream = null,
        createdAt = e.createdAt;
  _TimelineItem.dream(DreamEntry d)
      : evening = null,
        dream = d,
        createdAt = d.createdAt;

  final EveningEntry? evening;
  final DreamEntry? dream;
  final DateTime createdAt;
}

// ─── Streak card ────────────────────────────────────────────────────────────

class _StreakCard extends StatefulWidget {
  const _StreakCard({required this.streak, required this.lastNight});

  final int streak;
  final String? lastNight;

  @override
  State<_StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<_StreakCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.streak > 0;
    final headline = widget.streak == 0
        ? 'No streak yet'
        : '${widget.streak} day${widget.streak == 1 ? '' : 's'} in a row';

    return GlassPanel(
      radius: 26,
      glowColor: active ? AetherColors.gold : AetherColors.moonViolet,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = 0.5 + 0.5 * math.sin(_pulse.value * 2 * math.pi);
                  return Container(
                    width: 62,
                    height: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: active
                            ? const [AetherColors.goldLight, AetherColors.gold]
                            : const [AetherColors.moonGlow, AetherColors.moonViolet],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (active ? AetherColors.gold : AetherColors.moonViolet)
                              .withValues(alpha: 0.35 + t * 0.35),
                          blurRadius: 18 + t * 8,
                          spreadRadius: 1 + t * 1.5,
                        ),
                      ],
                    ),
                    child: Icon(
                      active ? Icons.local_fire_department_rounded : Icons.nightlight_round,
                      color: AetherColors.night,
                      size: 30,
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Streak counts consecutive Morning Charges.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.lastNight != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: AetherColors.moonViolet.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AetherColors.moonViolet.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bedtime_rounded, size: 16, color: AetherColors.moonViolet),
                  const SizedBox(width: 8),
                  Text(
                    'Last night: ${widget.lastNight}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AetherColors.moonGlow,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Stats trio ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.mornings,
    required this.evenings,
    required this.dreams,
  });

  final int mornings;
  final int evenings;
  final int dreams;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.wb_sunny_rounded,
            color: AetherColors.goldLight,
            label: 'Mornings',
            value: mornings,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.nightlight_round,
            color: AetherColors.moonViolet,
            label: 'Evenings',
            value: evenings,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.auto_awesome_rounded,
            color: AetherColors.violet,
            label: 'Dreams',
            value: dreams,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AetherColors.muted,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 14-day activity strip ──────────────────────────────────────────────────

class _ActivityStrip extends StatelessWidget {
  const _ActivityStrip({
    required this.mornings,
    required this.eveningKeys,
    required this.dreamKeys,
  });

  final Set<String> mornings;
  final Set<String> eveningKeys;
  final Set<String> dreamKeys;

  static const _labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // 14 dots, oldest on the left, today on the right.
    final days = List.generate(
      14,
      (i) => today.subtract(Duration(days: 13 - i)),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final date in days)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _ActivityDot(
                weekdayLabel: _labels[date.weekday % 7],
                dayNumber: date.day,
                morning: mornings.contains(dayKeyFor(date)),
                evening: eveningKeys.contains(dayKeyFor(date)),
                dream: dreamKeys.contains(dayKeyFor(date)),
                isToday: dayKeyFor(date) == dayKeyFor(today),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityDot extends StatelessWidget {
  const _ActivityDot({
    required this.weekdayLabel,
    required this.dayNumber,
    required this.morning,
    required this.evening,
    required this.dream,
    required this.isToday,
  });

  final String weekdayLabel;
  final int dayNumber;
  final bool morning;
  final bool evening;
  final bool dream;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final anything = morning || evening || dream;
    final both = morning && evening;

    final Color fill;
    if (both) {
      fill = AetherColors.gold;
    } else if (morning) {
      fill = AetherColors.goldLight;
    } else if (evening) {
      fill = AetherColors.moonViolet;
    } else if (dream) {
      fill = AetherColors.violet;
    } else {
      fill = Colors.white.withValues(alpha: 0.05);
    }

    return Column(
      children: [
        Text(
          weekdayLabel,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: AetherColors.muted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: anything ? fill.withValues(alpha: 0.9) : fill,
            border: Border.all(
              color: isToday
                  ? AetherColors.electric
                  : fill.withValues(alpha: anything ? 0.9 : 0.25),
              width: isToday ? 1.6 : 1,
            ),
            boxShadow: anything
                ? [
                    BoxShadow(
                      color: fill.withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Text(
            '$dayNumber',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: anything ? AetherColors.night : AetherColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Mood trend ─────────────────────────────────────────────────────────────

class _MoodTrend extends StatelessWidget {
  const _MoodTrend({required this.entries});

  final List<EveningEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Newest-first list from AppState; take the 7 most recent that have a mood.
    final recent = entries
        .where((e) => e.mood != null)
        .take(7)
        .toList()
        .reversed
        .toList();

    if (recent.isEmpty) {
      return GlassPanel(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: Text(
          'Log an evening mood to see your trend appear here.',
          style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.68)),
        ),
      );
    }

    return GlassPanel(
      radius: 18,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final entry in recent)
            _MoodBubble(mood: entry.mood!, label: entry.dateKey.substring(5)),
        ],
      ),
    );
  }
}

class _MoodBubble extends StatelessWidget {
  const _MoodBubble({required this.mood, required this.label});

  final RitualMood mood;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AetherColors.moonViolet.withValues(alpha: 0.18),
            border: Border.all(
              color: AetherColors.moonViolet.withValues(alpha: 0.55),
            ),
          ),
          child: Icon(mood.icon, size: 18, color: AetherColors.moonGlow),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AetherColors.muted,
          ),
        ),
      ],
    );
  }
}

// ─── Discharge banner ───────────────────────────────────────────────────────

class _DischargeBanner extends StatelessWidget {
  const _DischargeBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 22,
      fill: AetherColors.moonViolet.withValues(alpha: 0.14),
      stroke: AetherColors.moonViolet.withValues(alpha: 0.5),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AetherColors.moonViolet.withValues(alpha: 0.25),
            ),
            child: const Icon(Icons.nightlight_round, color: AetherColors.moonViolet),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discharge your day',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  'A few short prompts, then a good night.',
                  style: TextStyle(fontSize: 12, color: AetherColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AetherColors.muted),
        ],
      ),
    );
  }
}

// ─── Filter bar ─────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.value,
    required this.eveningsCount,
    required this.dreamsCount,
    required this.onChanged,
  });

  final _Filter value;
  final int eveningsCount;
  final int dreamsCount;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            icon: Icons.blur_on_rounded,
            color: AetherColors.electric,
            active: value == _Filter.all,
            onTap: () => onChanged(_Filter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Evenings · $eveningsCount',
            icon: Icons.nightlight_round,
            color: AetherColors.moonViolet,
            active: value == _Filter.evenings,
            onTap: () => onChanged(_Filter.evenings),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Dreams · $dreamsCount',
            icon: Icons.auto_awesome_rounded,
            color: AetherColors.violet,
            active: value == _Filter.dreams,
            onTap: () => onChanged(_Filter.dreams),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.75) : AetherColors.glassStroke,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? color : AetherColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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

// ─── Tiles ──────────────────────────────────────────────────────────────────

class _EveningTile extends StatelessWidget {
  const _EveningTile({required this.entry});

  final EveningEntry entry;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.nightlight_round, size: 15, color: AetherColors.moonViolet),
              const SizedBox(width: 6),
              Text(
                entry.dateKey,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
              if (entry.mood != null) ...[
                const SizedBox(width: 8),
                Icon(entry.mood!.icon, size: 15, color: AetherColors.moonGlow),
              ],
              const Spacer(),
              if (entry.bedTime != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AetherColors.moonViolet.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bedtime_rounded, size: 11, color: AetherColors.moonGlow),
                      const SizedBox(width: 4),
                      Text(
                        entry.bedTime!.format(context),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AetherColors.moonGlow,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (entry.wentWell.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Prompt(label: 'Went well', text: entry.wentWell),
          ],
          if (entry.grateful.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Prompt(label: 'Grateful', text: entry.grateful),
          ],
          if (entry.intention.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Prompt(label: 'Tomorrow', text: entry.intention),
          ],
        ],
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13.5, height: 1.35, color: AetherColors.ivory),
        children: [
          TextSpan(
            text: '$label · ',
            style: const TextStyle(
              color: AetherColors.muted,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
              letterSpacing: 0.4,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
    );
  }
}

class _DreamTile extends StatelessWidget {
  const _DreamTile({required this.dream});

  final DreamEntry dream;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 15, color: AetherColors.violet),
              const SizedBox(width: 6),
              Text(
                dream.dateKey,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
              if (dream.mood != null) ...[
                const SizedBox(width: 8),
                Icon(dream.mood!.icon, size: 15, color: AetherColors.muted),
              ],
              if (dream.sleepDurationMinutes != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AetherColors.violet.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '~${formatSleepDuration(Duration(minutes: dream.sleepDurationMinutes!))}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AetherColors.violet,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                tooltip: 'Delete',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  tap(context);
                  state.deleteDream(dream.id);
                },
                icon: const Icon(Icons.delete_outline_rounded, color: AetherColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dream.text.isEmpty ? 'No details written down.' : dream.text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              fontStyle: dream.text.isEmpty ? FontStyle.italic : FontStyle.normal,
              color: dream.text.isEmpty ? AetherColors.muted : AetherColors.ivory,
            ),
          ),
          if (dream.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in dream.tags)
                  AetherTag(
                    label: tag.label,
                    icon: tag.icon,
                    color: AetherColors.violet,
                    dense: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Empty state ────────────────────────────────────────────────────────────

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AetherColors.muted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AetherColors.muted),
          ),
        ],
      ),
    );
  }
}
