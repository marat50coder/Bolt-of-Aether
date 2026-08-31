import 'package:flutter/material.dart';

import '../studio/app_palette.dart';
import '../studio/app_scope.dart';
import '../studio/models.dart';
import '../surface/glass.dart';
import '../surface/swipe_deck.dart';

/// Tinder-style discovery: swipe right to keep a bolt, left to let it pass.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final SwipeDeckController _deck = SwipeDeckController();
  String? _flash;

  void _showFlash(String message) {
    setState(() => _flash = message);
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final deck = state.deck;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ShaderText(
                  'Discover',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              AetherTag(
                label: '${state.saved.length} kept',
                icon: Icons.bookmark_rounded,
                color: AetherColors.mint,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Swipe right to charge it, left to pass.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final topic in BoltTopic.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      topic: topic,
                      active: state.topics.contains(topic),
                      onTap: () {
                        tap(context);
                        state.toggleTopic(topic);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: deck.isEmpty
                ? _DeckEmpty(onReshuffle: state.reshuffleDeck)
                : Stack(
                    children: [
                      Positioned.fill(
                        child: SwipeDeck(
                          items: deck,
                          controller: _deck,
                          onSwipe: (bolt, liked) {
                            tap(context, strong: liked);
                            state.registerSwipe(bolt, liked: liked);
                            _showFlash(liked ? 'Charged and saved' : 'Passed');
                          },
                        ),
                      ),
                      if (_flash != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: 1,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AetherColors.night.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: AetherColors.glassStroke),
                                ),
                                child: Text(
                                  _flash!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DeckAction(
                icon: Icons.close_rounded,
                color: AetherColors.rose,
                size: 60,
                onTap: deck.isEmpty ? null : _deck.swipeLeft,
              ),
              const SizedBox(width: 22),
              _DeckAction(
                icon: Icons.shuffle_rounded,
                color: AetherColors.goldLight,
                size: 48,
                onTap: () {
                  tap(context);
                  state.reshuffleDeck();
                },
              ),
              const SizedBox(width: 22),
              _DeckAction(
                icon: Icons.bolt_rounded,
                color: AetherColors.mint,
                size: 60,
                onTap: deck.isEmpty ? null : _deck.swipeRight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.topic, required this.active, required this.onTap});

  final BoltTopic topic;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? topic.color.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: active
                ? topic.color.withValues(alpha: 0.75)
                : AetherColors.glassStroke,
          ),
        ),
        child: Row(
          children: [
            Icon(
              topic.icon,
              size: 14,
              color: active ? topic.color : AetherColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              topic.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? topic.color : AetherColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckAction extends StatelessWidget {
  const _DeckAction({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.14),
            border: Border.all(color: color.withValues(alpha: 0.55), width: 1.6),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: size * 0.44),
        ),
      ),
    );
  }
}

class _DeckEmpty extends StatelessWidget {
  const _DeckEmpty({required this.onReshuffle});

  final Future<void> Function() onReshuffle;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 28,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 44, color: AetherColors.goldLight),
          const SizedBox(height: 14),
          const Text(
            'The deck is quiet',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Reshuffle to run through the bolts again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AetherColors.muted),
          ),
          const SizedBox(height: 18),
          GhostButton(
            label: 'Reshuffle',
            icon: Icons.shuffle_rounded,
            onPressed: onReshuffle,
            color: AetherColors.electric,
          ),
        ],
      ),
    );
  }
}
