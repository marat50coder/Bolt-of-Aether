import 'dart:math';

import 'package:flutter/material.dart';

import '../studio/app_palette.dart';

/// Living backdrop: soft aether glows plus slowly drifting sparks.
/// Falls back to a static gradient when the user disables motion.
class AetherBackground extends StatefulWidget {
  const AetherBackground({
    super.key,
    required this.child,
    this.animate = true,
    this.sparkCount = 26,
    this.tint,
  });

  final Widget child;
  final bool animate;
  final int sparkCount;
  final Color? tint;

  @override
  State<AetherBackground> createState() => _AetherBackgroundState();
}

class _AetherBackgroundState extends State<AetherBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    final random = Random(7);
    _sparks = List.generate(widget.sparkCount, (_) => _Spark.random(random));
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(AetherBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AetherColors.backdrop),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _AetherPainter(
                  t: _controller.value,
                  sparks: _sparks,
                  tint: widget.tint ?? AetherColors.azure,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Spark {
  _Spark(this.x, this.y, this.radius, this.speed, this.opacity, this.gold);

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double opacity;
  final bool gold;

  factory _Spark.random(Random random) => _Spark(
        random.nextDouble(),
        random.nextDouble(),
        0.6 + random.nextDouble() * 2.2,
        0.25 + random.nextDouble() * 0.9,
        0.16 + random.nextDouble() * 0.5,
        random.nextInt(3) == 0,
      );
}

class _AetherPainter extends CustomPainter {
  _AetherPainter({required this.t, required this.sparks, required this.tint});

  final double t;
  final List<_Spark> sparks;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final wobble = sin(t * 2 * pi);
    final wobble2 = cos(t * 2 * pi);

    _glow(
      canvas,
      Offset(size.width * (0.18 + wobble * 0.06), size.height * 0.14),
      size.width * 0.85,
      tint.withValues(alpha: 0.26),
    );
    _glow(
      canvas,
      Offset(size.width * (0.86 + wobble2 * 0.05), size.height * 0.34),
      size.width * 0.7,
      AetherColors.electric.withValues(alpha: 0.14),
    );
    _glow(
      canvas,
      Offset(size.width * 0.5, size.height * (0.92 + wobble * 0.02)),
      size.width * 0.95,
      AetherColors.gold.withValues(alpha: 0.10),
    );

    for (final spark in sparks) {
      final progress = (spark.y - t * spark.speed) % 1.0;
      final dx = size.width * (spark.x + sin((t + spark.x) * 2 * pi) * 0.012);
      final dy = size.height * progress;
      final paint = Paint()
        ..color = (spark.gold ? AetherColors.goldLight : AetherColors.electric)
            .withValues(alpha: spark.opacity * (0.55 + 0.45 * sin(progress * pi)))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawCircle(Offset(dx, dy), spark.radius, paint);
    }
  }

  void _glow(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_AetherPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.tint != tint;
}
