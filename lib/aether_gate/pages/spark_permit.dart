import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_palette.dart';
import '../config/relay_config.dart';
import '../transport/bolt_agent.dart';
import '../transport/bolt_pulse.dart';
import '../transport/relay_vault.dart';
import 'storm_channel.dart';

/// Push permission screen. Programmatic gradient in the Aether palette — no
/// artwork asset lands in the binary, so nothing here shares bytes with a
/// sibling app's opt-in screen.
///
/// Navigates to StormChannel from its OWN state, never through a callback
/// captured on the parent's (unmounted-by-then) BuildContext.
class SparkPermit extends StatefulWidget {
  const SparkPermit({
    super.key,
    required this.pulse,
    required this.vault,
    required this.agent,
    required this.destination,
  });

  final BoltPulse pulse;
  final RelayVault vault;
  final BoltAgent agent;
  final String destination;

  @override
  State<SparkPermit> createState() => _SparkPermitState();
}

class _SparkPermitState extends State<SparkPermit> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The warmup locks portrait for the native handoff — re-enable rotation
    // here so a user in landscape does not see a portrait-locked opt-in.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final granted = await widget.pulse.askPermission();
      if (!granted) {
        final until = DateTime.now().add(
          const Duration(seconds: AetherRelayConfig.pushSnoozeSeconds),
        );
        await widget.vault.writeInviteCooldown(until);
      }
    } catch (_) {
      // Swallow: the forward navigation below must still run so a plugin
      // error never dead-ends the user on this screen.
    }
    _forward();
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    final until = DateTime.now().add(
      const Duration(seconds: AetherRelayConfig.pushSnoozeSeconds),
    );
    await widget.vault.writeInviteCooldown(until);
    _forward();
  }

  void _forward() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => StormChannel(
          destination: widget.destination,
          pulse: widget.pulse,
          vault: widget.vault,
          agent: widget.agent,
          coldStartPush: false,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherColors.night,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final landscape = orientation == Orientation.landscape;
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AetherColors.backdrop),
              ),
              const _AetherGlow(),
              landscape ? _landscapeContent(context) : _portraitContent(context),
            ],
          );
        },
      ),
    );
  }

  Widget _portraitContent(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        children: [
          const Spacer(),
          const _BellSpark(size: 128),
          const SizedBox(height: 34),
          _headline(context),
          const SizedBox(height: 16),
          _subhead(context),
          const Spacer(flex: 2),
          _acceptButton(),
          const SizedBox(height: 14),
          _skipButton(),
        ],
      ),
    );
  }

  Widget _landscapeContent(BuildContext context) {
    // Landscape: no SafeArea horizontal padding (would shift buttons off-center
    // relative to the artwork centre — see custom_screens.md).
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).viewPadding.top + 12,
        bottom: 20,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BellSpark(size: 96),
                  const SizedBox(height: 22),
                  _headline(context, align: TextAlign.left),
                  const SizedBox(height: 12),
                  _subhead(context, align: TextAlign.left),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _acceptButton(),
                    const SizedBox(height: 14),
                    _skipButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headline(BuildContext context, {TextAlign align = TextAlign.center}) {
    return Text(
      'ALLOW NOTIFICATIONS ABOUT\nBONUSES AND PROMOS',
      textAlign: align,
      style: const TextStyle(
        color: AetherColors.ivory,
        fontSize: 22,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        shadows: [Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2))],
      ),
    );
  }

  Widget _subhead(BuildContext context, {TextAlign align = TextAlign.center}) {
    return Text(
      'Stay tuned for special offers and rewards',
      textAlign: align,
      style: TextStyle(
        color: AetherColors.ivory.withValues(alpha: 0.86),
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _acceptButton() {
    return _GradientButton(
      label: 'Allow',
      colors: const [AetherColors.azure, AetherColors.sky, AetherColors.electric],
      onTap: _busy ? null : _accept,
      icon: Icons.notifications_active_rounded,
    );
  }

  Widget _skipButton() {
    return _GradientButton(
      label: 'Not now',
      colors: const [AetherColors.dusk, AetherColors.deep, AetherColors.night],
      onTap: _busy ? null : _skip,
      icon: Icons.skip_next_rounded,
    );
  }
}

class _BellSpark extends StatelessWidget {
  const _BellSpark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [AetherColors.electric, AetherColors.azure, AetherColors.deep],
          stops: [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AetherColors.sky.withValues(alpha: 0.5),
            blurRadius: 44,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Icon(
        Icons.notifications_rounded,
        size: size * 0.55,
        color: AetherColors.ivory,
      ),
    );
  }
}

class _AetherGlow extends StatelessWidget {
  const _AetherGlow();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.45),
            radius: 1.05,
            colors: [
              AetherColors.dusk.withValues(alpha: 0.85),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.colors,
    required this.onTap,
    this.icon,
  });

  final String label;
  final List<Color> colors;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
