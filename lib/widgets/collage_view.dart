import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_palette.dart';
import '../core/models.dart';

/// Builds a visual collage out of a word cluster — no network images needed,
/// every collage is painted on the device.
class CollageView extends StatelessWidget {
  const CollageView({super.key, required this.bolt, this.compact = false});

  final Bolt bolt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = CollagePalette.at(bolt.palette);
    final random = Random(bolt.id.hashCode);
    final words = bolt.words.isEmpty
        ? bolt.text.split(' ').take(5).toList()
        : bolt.words;

    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 16 : 22),
      child: AspectRatio(
        aspectRatio: compact ? 16 / 10 : 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: palette.colors,
                ),
              ),
            ),
            CustomPaint(painter: _CollagePainter(palette, bolt.id.hashCode)),
            Padding(
              padding: EdgeInsets.all(compact ? 12 : 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < words.length; i++)
                    _CollageWord(
                      text: words[i],
                      palette: palette,
                      index: i,
                      total: words.length,
                      compact: compact,
                      random: random,
                    ),
                ],
              ),
            ),
            Positioned(
              right: compact ? 10 : 16,
              top: compact ? 10 : 16,
              child: Icon(
                Icons.bolt_rounded,
                size: compact ? 20 : 30,
                color: palette.accent.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollageWord extends StatelessWidget {
  const _CollageWord({
    required this.text,
    required this.palette,
    required this.index,
    required this.total,
    required this.compact,
    required this.random,
  });

  final String text;
  final CollagePalette palette;
  final int index;
  final int total;
  final bool compact;
  final Random random;

  @override
  Widget build(BuildContext context) {
    final isShout = text.toUpperCase() == text && text.length > 1;
    final scale = compact ? 0.55 : 1.0;
    final baseSize = (isShout ? 34.0 : 20.0) - (total > 4 ? 3.0 : 0.0);
    final tilt = ((index % 3) - 1) * 0.035;
    final indent = (index % 3) * (compact ? 8.0 : 22.0);

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: compact ? 2 : 6),
      child: Transform.rotate(
        angle: tilt,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: baseSize * scale,
            height: 1.05,
            fontWeight: isShout ? FontWeight.w900 : FontWeight.w500,
            fontStyle: isShout ? FontStyle.normal : FontStyle.italic,
            letterSpacing: isShout ? 1.6 : 0.2,
            color: isShout ? palette.ink : palette.accent,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollagePainter extends CustomPainter {
  _CollagePainter(this.palette, this.seed);

  final CollagePalette palette;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);

    // Torn paper shapes.
    for (var i = 0; i < 4; i++) {
      final rect = Rect.fromLTWH(
        size.width * (random.nextDouble() * 0.7 - 0.1),
        size.height * (random.nextDouble() * 0.8 - 0.1),
        size.width * (0.3 + random.nextDouble() * 0.5),
        size.height * (0.12 + random.nextDouble() * 0.25),
      );
      final paint = Paint()
        ..color = (i.isEven ? Colors.white : palette.accent)
            .withValues(alpha: 0.06 + random.nextDouble() * 0.07);
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate((random.nextDouble() - 0.5) * 0.5);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      canvas.drawRect(rect, paint);
      canvas.restore();
    }

    // Aether arcs.
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.18);
    for (var i = 0; i < 3; i++) {
      final path = Path();
      final startY = size.height * random.nextDouble();
      path.moveTo(0, startY);
      var x = 0.0;
      var y = startY;
      while (x < size.width) {
        x += size.width / 6;
        y += (random.nextDouble() - 0.5) * size.height * 0.18;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, arcPaint);
    }

    // Vignette.
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
        stops: const [0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignette);
  }

  @override
  bool shouldRepaint(_CollagePainter oldDelegate) => oldDelegate.seed != seed;
}
