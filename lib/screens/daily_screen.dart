import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_palette.dart';
import '../core/app_scope.dart';
import '../core/models.dart';
import '../widgets/bolt_card.dart';
import '../widgets/glass.dart';
import 'evening_discharge_screen.dart';
import 'home_shell.dart';
import 'settings_screen.dart';

/// The daily bolt: one charge a day, sealed until the user unleashes it.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final bolt = state.dailyBolt;
    final cardHeight = min(520.0, MediaQuery.sizeOf(context).height * 0.56);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
      children: [
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -6,
                  top: -6,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AetherColors.azure.withValues(alpha: 0.45),
                          AetherColors.azure.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Image.asset('assets/Game_Name.webp', height: 62),
              ],
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Create a bolt',
              onPressed: () {
                tap(context);
                HomeNav.jump(context, 2);
              },
              icon: const Icon(Icons.add_circle_outline_rounded, color: AetherColors.ivory),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () {
                tap(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              icon: const Icon(Icons.tune_rounded, color: AetherColors.ivory),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ShaderText(
          'Today\'s bolt',
          style: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              state.todayLabel,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.68),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            AetherTag(
              label: '${state.streak} day streak',
              icon: Icons.local_fire_department_rounded,
              color: AetherColors.goldLight,
              dense: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: cardHeight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 520),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: bolt == null
                ? const _NoBolt()
                : state.dailyClaimed
                    ? _RevealedDaily(bolt: bolt, key: ValueKey('revealed-${bolt.id}'))
                    : _SealedDaily(
                        key: const ValueKey('sealed'),
                        onUnleash: () {
                          tap(context, strong: true);
                          state.claimDaily();
                        },
                      ),
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Your charge'),
        const SizedBox(height: 12),
        Row(
          children: [
            _Stat(
              value: '${state.saved.length}',
              label: 'Saved',
              icon: Icons.bookmark_rounded,
              color: AetherColors.mint,
            ),
            const SizedBox(width: 10),
            _Stat(
              value: '${state.myBolts.length}',
              label: 'Created',
              icon: Icons.brush_rounded,
              color: AetherColors.violet,
            ),
            const SizedBox(width: 10),
            _Stat(
              value: '${state.totalSwipes}',
              label: 'Swipes',
              icon: Icons.swipe_rounded,
              color: AetherColors.sky,
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionTitle('Sleep ritual'),
        const SizedBox(height: 12),
        const _SleepStreakCard(),
        if (state.eveningBannerDue) ...[
          const SizedBox(height: 12),
          const _EveningBanner(),
        ],
        const SizedBox(height: 22),
        const SectionTitle('Keep exploring'),
        const SizedBox(height: 12),
        _LinkCard(
          icon: Icons.style_rounded,
          color: AetherColors.electric,
          title: 'Discover the deck',
          subtitle: 'Swipe right to charge a bolt, left to let it pass.',
          onTap: () => HomeNav.jump(context, 1),
        ),
        const SizedBox(height: 12),
        _LinkCard(
          icon: Icons.auto_awesome_rounded,
          color: AetherColors.violet,
          title: 'Open your rituals',
          subtitle: 'Sleep streak, evening reflections and dreams.',
          onTap: () => HomeNav.jump(context, 3),
        ),
        const SizedBox(height: 12),
        _LinkCard(
          icon: Icons.add_circle_outline_rounded,
          color: AetherColors.goldLight,
          title: 'Make your own bolt',
          subtitle: 'Text, a photo or a voice note — yours to keep.',
          onTap: () => HomeNav.jump(context, 2),
        ),
      ],
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      radius: 22,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
            ),
            child: Icon(icon, color: color),
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
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: AetherColors.muted),
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

class _SealedDaily extends StatelessWidget {
  const _SealedDaily({super.key, required this.onUnleash});

  final VoidCallback onUnleash;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 30,
      glowColor: AetherColors.azure,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PulsingBolt(),
          const SizedBox(height: 26),
          const Text(
            'A bolt is waiting',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'One charge a day, chosen from the themes you follow. '
            'Open it and keep your streak alive.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 26),
          BoltButton(
            label: 'Unleash today\'s bolt',
            icon: Icons.bolt_rounded,
            expand: false,
            colors: const [AetherColors.gold, AetherColors.goldLight],
            onPressed: onUnleash,
          ),
        ],
      ),
    );
  }
}

class _RevealedDaily extends StatelessWidget {
  const _RevealedDaily({super.key, required this.bolt});

  final Bolt bolt;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final saved = state.isSaved(bolt.id);

    return BoltCard(
      bolt: bolt,
      footer: Row(
        children: [
          Expanded(
            child: BoltButton(
              label: saved ? 'In collection' : 'Keep it',
              icon: saved ? Icons.bookmark_added_rounded : Icons.bookmark_add_rounded,
              colors: saved
                  ? const [AetherColors.mint, AetherColors.electric]
                  : const [AetherColors.azure, AetherColors.electric],
              onPressed: () {
                tap(context, strong: true);
                state.toggleSaved(bolt);
              },
            ),
          ),
          const SizedBox(width: 10),
          _RoundAction(
            icon: Icons.copy_rounded,
            tooltip: 'Copy text',
            onTap: () {
              tap(context);
              Clipboard.setData(ClipboardData(text: _plain(bolt)));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
          const SizedBox(width: 8),
          _RoundAction(
            icon: Icons.bookmark_add_rounded,
            tooltip: 'Save to collection',
            onTap: () {
              tap(context);
              state.toggleSaved(bolt);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved to your collection')),
              );
              HomeNav.jump(context, 4);
            },
          ),
        ],
      ),
    );
  }

  static String _plain(Bolt bolt) {
    final author = bolt.author;
    return author == null || author.isEmpty
        ? '${bolt.text}\n\n— Bolt of Aether'
        : '${bolt.text}\n— $author\n\nvia Bolt of Aether';
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AetherColors.glassFill,
            border: Border.all(color: AetherColors.glassStroke),
          ),
          child: Icon(icon, size: 21, color: AetherColors.ivory),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        radius: 20,
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.16),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AetherColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepStreakCard extends StatelessWidget {
  const _SleepStreakCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lastNight = state.lastNightSummary;

    return GlassPanel(
      radius: 22,
      glowColor: AetherColors.moonViolet,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AetherColors.moonViolet, AetherColors.violet],
              ),
            ),
            child: const Text('🌙', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep streak: ${state.sleepStreak} 🔥',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  lastNight == null ? 'Log a bedtime and wake time to track this' : 'Last night: ~$lastNight',
                  style: const TextStyle(fontSize: 11.5, color: AetherColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EveningBanner extends StatelessWidget {
  const _EveningBanner();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 22,
      fill: AetherColors.moonViolet.withValues(alpha: 0.16),
      stroke: AetherColors.moonViolet.withValues(alpha: 0.55),
      onTap: () {
        tap(context);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EveningDischargeScreen()),
        );
      },
      child: Row(
        children: [
          const Text('🌙', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time to discharge',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                SizedBox(height: 2),
                Text(
                  'Three quiet questions before you rest.',
                  style: TextStyle(fontSize: 12, color: AetherColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AetherColors.moonGlow),
        ],
      ),
    );
  }
}

class _NoBolt extends StatelessWidget {
  const _NoBolt();

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      radius: 30,
      child: Center(
        child: Text(
          'No bolt for today yet.\nPick at least one theme in settings.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AetherColors.muted),
        ),
      ),
    );
  }
}
