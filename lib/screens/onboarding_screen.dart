import 'package:flutter/material.dart';

import '../core/app_palette.dart';
import '../core/app_scope.dart';
import '../core/models.dart';
import '../widgets/aether_background.dart';
import '../widgets/glass.dart';
import 'home_shell.dart';

/// First run: explains the idea and collects topic preferences.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final Set<BoltTopic> _picked = {...BoltTopic.values};
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final state = AppScope.read(context);
    await state.setTopics(_picked);
    await state.setNickname(_name.text);
    await state.completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => const HomeShell(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      body: AetherBackground(
        animate: state.motion,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/Game_Name.webp',
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'One bolt a day.',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A quote, an affirmation, an odd fact or a collage — '
                        'small charges that move your mood.',
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.45,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _Highlight(
                        icon: Icons.swipe_rounded,
                        title: 'Swipe to charge',
                        text: 'Right keeps a bolt in your collection, left lets it pass.',
                      ),
                      const _Highlight(
                        icon: Icons.mic_none_rounded,
                        title: 'Make your own',
                        text: 'Text, a photo or a voice note — then keep it in your collection.',
                      ),
                      const _Highlight(
                        icon: Icons.wifi_off_rounded,
                        title: 'Works anywhere',
                        text: 'Everything is stored on your device, no connection needed.',
                      ),
                      const SizedBox(height: 22),
                      const SectionTitle('Pick your themes'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final topic in BoltTopic.values)
                            _TopicCard(
                              topic: topic,
                              selected: _picked.contains(topic),
                              onTap: () {
                                tap(context);
                                setState(() {
                                  if (_picked.contains(topic)) {
                                    if (_picked.length > 1) _picked.remove(topic);
                                  } else {
                                    _picked.add(topic);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const SectionTitle('Your name in the feed'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 22,
                        decoration: const InputDecoration(
                          hintText: 'Optional — defaults to "You"',
                          counterText: '',
                          prefixIcon: Icon(Icons.person_outline_rounded,
                              color: AetherColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                child: BoltButton(
                  label: 'Enter the storm',
                  icon: Icons.bolt_rounded,
                  colors: const [AetherColors.gold, AetherColors.goldLight],
                  onPressed: () {
                    tap(context, strong: true);
                    _enter();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AetherColors.azure.withValues(alpha: 0.18),
              border: Border.all(color: AetherColors.azure.withValues(alpha: 0.45)),
            ),
            child: Icon(icon, size: 21, color: AetherColors.electric),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12.8,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.selected, required this.onTap});

  final BoltTopic topic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 54) / 2;
    return SizedBox(
      width: width,
      child: GlassPanel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        radius: 20,
        fill: selected ? topic.color.withValues(alpha: 0.18) : null,
        stroke: selected ? topic.color : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(topic.icon, size: 18, color: topic.color),
                const Spacer(),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 17,
                  color: selected ? topic.color : AetherColors.muted,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              topic.label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
            ),
            const SizedBox(height: 3),
            Text(
              topic.blurb,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.25,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
