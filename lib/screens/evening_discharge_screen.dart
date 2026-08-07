import 'package:flutter/material.dart';

import '../core/app_palette.dart';
import '../core/app_scope.dart';
import '../core/models.dart';
import '../widgets/glass.dart';
import '../widgets/ritual_widgets.dart';

/// Evening Ritual: three short prompts, a mood, and an optional, hand-typed
/// bedtime. Nothing here ever reads real sleep data from the device.
class EveningDischargeScreen extends StatefulWidget {
  const EveningDischargeScreen({super.key});

  @override
  State<EveningDischargeScreen> createState() => _EveningDischargeScreenState();
}

class _EveningDischargeScreenState extends State<EveningDischargeScreen>
    with SingleTickerProviderStateMixin {
  final _wentWell = TextEditingController();
  final _grateful = TextEditingController();
  final _intention = TextEditingController();
  RitualMood? _mood = RitualMood.okay;
  TimeOfDay? _bedTime;
  bool _discharging = false;

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    final existing = state.eveningEntryFor(state.todayKey);
    if (existing != null) {
      _wentWell.text = existing.wentWell;
      _grateful.text = existing.grateful;
      _intention.text = existing.intention;
      _mood = existing.mood ?? _mood;
      _bedTime = existing.bedTime;
    }
  }

  @override
  void dispose() {
    _wentWell.dispose();
    _grateful.dispose();
    _intention.dispose();
    _flash.dispose();
    super.dispose();
  }

  Future<void> _pickBedTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _bedTime ?? TimeOfDay.now(),
      helpText: 'When are you going to sleep?',
    );
    if (picked != null && mounted) setState(() => _bedTime = picked);
  }

  Future<void> _discharge() async {
    if (_discharging) return;
    setState(() => _discharging = true);
    tap(context, strong: true);

    final state = AppScope.read(context);
    final entry = EveningEntry(
      dateKey: state.todayKey,
      wentWell: _wentWell.text.trim(),
      grateful: _grateful.text.trim(),
      intention: _intention.text.trim(),
      mood: _mood,
      bedTime: _bedTime,
      createdAt: DateTime.now(),
    );
    await state.saveEveningEntry(entry);
    await _flash.forward(from: 0);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Day discharged 🌙')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherColors.nightIndigo,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AetherColors.nightBackdrop)),
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AetherColors.moonViolet.withValues(alpha: 0.35),
                    AetherColors.moonViolet.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 18, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: AetherColors.moonGlow),
                      ),
                      Expanded(
                        child: ShaderText(
                          'EVENING DISCHARGE',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                          colors: const [
                            AetherColors.moonGlow,
                            AetherColors.moonViolet,
                            AetherColors.violet,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                    children: [
                      Center(
                        child: PulsingBolt(
                          icon: Icons.nightlight_round,
                          size: 88,
                          duration: const Duration(milliseconds: 2600),
                          ringColor: AetherColors.moonViolet,
                          glowColor: AetherColors.moonViolet,
                          coreColors: const [AetherColors.duskIndigo, AetherColors.nightIndigo],
                          iconColors: const [AetherColors.moonGlow, AetherColors.moonViolet],
                        ),
                      ),
                      const SizedBox(height: 26),
                      _Question(label: 'What went well today?', controller: _wentWell),
                      const SizedBox(height: 14),
                      _Question(label: 'What are you grateful for?', controller: _grateful),
                      const SizedBox(height: 14),
                      _Question(
                        label: 'What is your intention for tomorrow?',
                        controller: _intention,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'HOW DO YOU FEEL RIGHT NOW',
                        style: TextStyle(
                          color: AetherColors.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RitualMoodSelector(
                        value: _mood,
                        color: AetherColors.moonViolet,
                        onChanged: (mood) => setState(() => _mood = mood),
                      ),
                      const SizedBox(height: 24),
                      GlassPanel(
                        radius: 20,
                        onTap: _pickBedTime,
                        fill: _bedTime == null ? null : AetherColors.moonViolet.withValues(alpha: 0.14),
                        stroke:
                            _bedTime == null ? null : AetherColors.moonViolet.withValues(alpha: 0.5),
                        child: Row(
                          children: [
                            const Icon(Icons.nightlight_round, color: AetherColors.moonViolet),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _bedTime == null
                                    ? "I'm going to sleep now"
                                    : 'Bedtime: ${_bedTime!.format(context)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            if (_bedTime != null)
                              IconButton(
                                onPressed: () => setState(() => _bedTime = null),
                                icon: const Icon(Icons.close_rounded, size: 18, color: AetherColors.muted),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      BoltButton(
                        label: _discharging ? 'Discharging…' : 'DISCHARGE',
                        icon: Icons.bolt_rounded,
                        colors: const [AetherColors.moonViolet, AetherColors.violet],
                        onPressed: _discharging ? null : _discharge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Brief moon-flare confirming the discharge, gone within 800ms.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (context, _) {
                final t = _flash.value;
                if (t == 0) return const SizedBox.shrink();
                final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0);
                return Center(
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 200 + t * 140,
                      height: 200 + t * 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AetherColors.moonGlow.withValues(alpha: 0.9),
                            AetherColors.moonViolet.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          maxLength: 280,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'A few words are enough…',
            counterStyle: TextStyle(color: AetherColors.muted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
