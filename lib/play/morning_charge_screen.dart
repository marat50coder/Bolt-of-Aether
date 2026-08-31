import 'package:flutter/material.dart';

import '../studio/app_palette.dart';
import '../studio/app_scope.dart';
import '../studio/models.dart';
import '../studio/ritual_content.dart';
import '../studio/sleep_utils.dart';
import '../surface/aether_background.dart';
import '../surface/glass.dart';
import '../surface/ritual_widgets.dart';
import 'home_shell.dart';

/// Morning Ritual: the word+quote of the day, plus an optional Dream
/// Journal. Shown once, right after the splash, on the first open of a new
/// calendar day. Every time value in here is typed in by hand.
class MorningChargeScreen extends StatefulWidget {
  const MorningChargeScreen({super.key});

  @override
  State<MorningChargeScreen> createState() => _MorningChargeScreenState();
}

class _MorningChargeScreenState extends State<MorningChargeScreen>
    with SingleTickerProviderStateMixin {
  late final String _word;
  late final String _quote;
  late final AnimationController _chargeFlash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  bool _charged = false;

  final _dreamText = TextEditingController();
  final Set<DreamTag> _tags = {};
  RitualMood? _wakingMood;
  TimeOfDay? _wakeTime;
  bool _dreamSaved = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _word = RitualContent.wordOfDay(now);
    _quote = RitualContent.quoteOfDay(now);
  }

  @override
  void dispose() {
    _chargeFlash.dispose();
    _dreamText.dispose();
    super.dispose();
  }

  Duration? get _sleptDuration {
    if (_wakeTime == null) return null;
    final state = AppScope.read(context);
    final bedTime = state.eveningEntryFor(state.yesterdayKey)?.bedTime;
    if (bedTime == null) return null;
    return sleepDurationBetween(bedTime, _wakeTime!);
  }

  Future<void> _chargeMe() async {
    if (_charged) return;
    tap(context, strong: true);
    final state = AppScope.read(context);
    await _chargeFlash.forward(from: 0);
    await state.saveMorningCharge(word: _word, quote: _quote);
    await state.completeMorningCharge();
    if (!mounted) return;
    setState(() => _charged = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved ⚡')),
    );
  }

  void _skipDream() {
    tap(context);
    setState(() {
      _dreamText.clear();
      _tags.clear();
      _wakingMood = null;
      _wakeTime = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dream journal skipped')),
    );
  }

  Future<void> _pickWakeTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _wakeTime ?? TimeOfDay.now(),
      helpText: 'When did you wake up?',
    );
    if (picked != null && mounted) setState(() => _wakeTime = picked);
  }

  Future<void> _saveDream() async {
    tap(context, strong: true);
    final state = AppScope.read(context);
    final duration = _sleptDuration;
    final entry = DreamEntry(
      id: 'dream-${DateTime.now().microsecondsSinceEpoch}',
      dateKey: state.todayKey,
      text: _dreamText.text.trim(),
      tags: _tags.toList(),
      mood: _wakingMood,
      wakeTime: _wakeTime,
      sleepDurationMinutes: duration?.inMinutes,
      createdAt: DateTime.now(),
    );
    await state.saveDream(entry);
    if (!mounted) return;
    setState(() => _dreamSaved = true);
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duration = _sleptDuration;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        body: AetherBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ShaderText(
                          'MORNING CHARGE',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _goHome,
                        child: const Text(
                          'Skip for today',
                          style: TextStyle(color: AetherColors.muted, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
                    children: [
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const PulsingBolt(),
                            IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _chargeFlash,
                                builder: (context, _) {
                                  final t = _chargeFlash.value;
                                  if (t == 0) return const SizedBox.shrink();
                                  final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0);
                                  return Opacity(
                                    opacity: opacity,
                                    child: Container(
                                      width: 104 + t * 90,
                                      height: 104 + t * 90,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            AetherColors.goldLight.withValues(alpha: 0.9),
                                            AetherColors.gold.withValues(alpha: 0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      GlassPanel(
                        radius: 26,
                        glowColor: AetherColors.gold,
                        child: Column(
                          children: [
                            const Text(
                              'WORD OF THE DAY',
                              style: TextStyle(
                                color: AetherColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ShaderText(
                              _word,
                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                              colors: const [AetherColors.electric, AetherColors.gold, AetherColors.goldLight],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _quote,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.4,
                                fontStyle: FontStyle.italic,
                                color: AetherColors.ivory,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      BoltButton(
                        label: _charged ? 'Charged ✓' : 'CHARGE ME',
                        icon: _charged ? Icons.check_rounded : Icons.bolt_rounded,
                        colors: const [AetherColors.gold, AetherColors.goldLight],
                        onPressed: _charged ? null : _chargeMe,
                      ),
                      const SizedBox(height: 30),
                      SectionTitle('Dream journal', trailing: TextButton(
                        onPressed: _skipDream,
                        child: const Text('Skip', style: TextStyle(color: AetherColors.muted)),
                      )),
                      const SizedBox(height: 14),
                      const Text(
                        'What do you remember from your dream?',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _dreamText,
                        minLines: 2,
                        maxLines: 5,
                        maxLength: 400,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Optional — write whatever surfaces…',
                          counterStyle: TextStyle(color: AetherColors.muted, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DreamTagChips(
                        selected: _tags,
                        onToggle: (tag) => setState(() {
                          if (_tags.contains(tag)) {
                            _tags.remove(tag);
                          } else {
                            _tags.add(tag);
                          }
                        }),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'MOOD ON WAKING',
                        style: TextStyle(
                          color: AetherColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RitualMoodSelector(
                        value: _wakingMood,
                        onChanged: (mood) => setState(() => _wakingMood = mood),
                      ),
                      const SizedBox(height: 20),
                      GlassPanel(
                        radius: 20,
                        onTap: _pickWakeTime,
                        fill: _wakeTime == null ? null : AetherColors.electric.withValues(alpha: 0.12),
                        stroke: _wakeTime == null ? null : AetherColors.electric.withValues(alpha: 0.5),
                        child: Row(
                          children: [
                            const Icon(Icons.wb_twilight_rounded, color: AetherColors.electric),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _wakeTime == null ? 'Log wake time (optional)' : 'Woke at: ${_wakeTime!.format(context)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            if (_wakeTime != null)
                              IconButton(
                                onPressed: () => setState(() => _wakeTime = null),
                                icon: const Icon(Icons.close_rounded, size: 18, color: AetherColors.muted),
                              ),
                          ],
                        ),
                      ),
                      if (duration != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'You slept ~${formatSleepDuration(duration)}',
                          style: const TextStyle(
                            color: AetherColors.goldLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      if (!_dreamSaved)
                        BoltButton(
                          label: 'SAVE DREAM',
                          icon: Icons.auto_awesome_rounded,
                          colors: const [AetherColors.violet, AetherColors.electric],
                          onPressed: _saveDream,
                        )
                      else
                        Row(
                          children: const [
                            Icon(Icons.check_circle_rounded, color: AetherColors.mint),
                            SizedBox(width: 6),
                            Text(
                              'Dream saved to your journal',
                              style: TextStyle(color: AetherColors.mint, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: !_charged
              ? const SizedBox.shrink(key: ValueKey('hidden'))
              : Padding(
                  key: const ValueKey('continue'),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    16 + safeBottomInset(context) * 0.5,
                  ),
                  child: BoltButton(
                    label: 'Continue to Today',
                    icon: Icons.arrow_forward_rounded,
                    colors: const [AetherColors.azure, AetherColors.electric],
                    onPressed: _goHome,
                  ),
                ),
        ),
      ),
    );
  }
}
