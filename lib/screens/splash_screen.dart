import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/app_palette.dart';
import '../core/app_state.dart';
import 'home_shell.dart';
import 'morning_charge_screen.dart';
import 'onboarding_screen.dart';

/// Start-up screen. Works in both orientations (the artwork swaps with the
/// device), and its progress bar is driven by the real bootstrap steps, so it
/// can never reach 100% before the app is actually ready.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onReady});

  /// Hands the freshly booted state to the app root, which publishes it above
  /// the navigator.
  final ValueChanged<AppState> onReady;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  double _target = 0;
  double _shown = 0;
  AppState? _state;
  bool _failed = false;
  String _error = '';
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _report(double value, String label) {
    if (!mounted) return;
    setState(() => _target = max(_target, value.clamp(0.0, 1.0)));
  }

  Future<void> _boot() async {
    try {
      final state = await AppState.bootstrap(_report);
      if (!mounted) return;
      _state = state;

      _report(0.96, 'Polishing the visuals');
      await precacheImage(const AssetImage('assets/Game_Name.webp'), context);
      if (!mounted) return;
      await precacheImage(const AssetImage('assets/icon_small.png'), context);
      if (!mounted) return;

      _report(1.0, 'Ready');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _error = error.toString();
      });
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;

    final diff = _target - _shown;
    if (diff > 0) {
      // Never runs ahead of the real work: the shown value is clamped to the
      // progress actually reported by the bootstrap steps.
      final speed = min(0.42, max(0.09, diff * 1.7));
      setState(() => _shown = min(_target, _shown + speed * dt));
    }

    if (!_navigated && _shown >= 0.9995 && _state != null) {
      _navigated = true;
      _enterApp();
    }
  }

  Future<void> _enterApp() async {
    _ticker.stop();
    final state = _state!;
    widget.onReady(state);

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, _, _) => _nextScreen(state),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Onboarding first, then the once-a-day Morning Charge, then Today.
  Widget _nextScreen(AppState state) {
    if (!state.onboarded) return const OnboardingScreen();
    if (state.morningChargePending) return const MorningChargeScreen();
    return const HomeShell();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherColors.night,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final portrait = orientation == Orientation.portrait;
          final asset = portrait
              ? 'assets/Vertical_Loading_Screen.webp'
              : 'assets/Horizontal_Loading_Screen.webp';

          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(decoration: BoxDecoration(gradient: AetherColors.backdrop)),
              Image.asset(
                asset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                frameBuilder: (context, child, frame, wasSync) => AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 420),
                  child: child,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AetherColors.night.withValues(alpha: portrait ? 0.72 : 0.85),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: portrait ? 30 : 76,
                      vertical: portrait ? 44 : 22,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: _failed
                          ? _BootFailure(error: _error, onRetry: _retry)
                          : _LoadingBlock(progress: _shown),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _retry() {
    setState(() {
      _failed = false;
      _error = '';
      _target = 0;
      _shown = 0;
    });
    _boot();
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return AetherProgressBar(value: progress);
  }
}

/// "Loading" with trailing dots cycling 1 -> 2 -> 3 -> 1.
class DottedLoadingText extends StatefulWidget {
  const DottedLoadingText({super.key, this.text = 'Loading', this.fontSize = 22});

  final String text;
  final double fontSize;

  @override
  State<DottedLoadingText> createState() => _DottedLoadingTextState();
}

class _DottedLoadingTextState extends State<DottedLoadingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white,
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      shadows: [
        Shadow(color: AetherColors.azure.withValues(alpha: 0.8), blurRadius: 16),
        const Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
      ],
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dots = (_controller.value * 3).floor() % 3 + 1;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(widget.text, style: style),
            // Reserved width keeps the label from jittering as dots appear.
            SizedBox(
              width: widget.fontSize * 0.9,
              child: Text('.' * dots, style: style, maxLines: 1),
            ),
          ],
        );
      },
    );
  }
}

/// Left-to-right progress bar with a travelling spark head.
class AetherProgressBar extends StatelessWidget {
  const AetherProgressBar({super.key, required this.value, this.height = 14});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fill = width * clamped;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: AetherColors.night.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(height),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(height),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: fill,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AetherColors.azure,
                          AetherColors.sky,
                          AetherColors.electric,
                          AetherColors.goldLight,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (clamped > 0.015)
                Positioned(
                  left: (fill - height * 0.9).clamp(0.0, width - height * 0.9),
                  top: -height * 0.32,
                  child: Container(
                    width: height * 1.7,
                    height: height * 1.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AetherColors.electric.withValues(alpha: 0.9),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.bolt_rounded,
                      size: height,
                      color: AetherColors.azure,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BootFailure extends StatelessWidget {
  const _BootFailure({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, color: AetherColors.goldLight, size: 34),
        const SizedBox(height: 10),
        const Text(
          'The bolt fizzled',
          style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          error,
          maxLines: 3,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
          style: FilledButton.styleFrom(
            backgroundColor: AetherColors.azure,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
