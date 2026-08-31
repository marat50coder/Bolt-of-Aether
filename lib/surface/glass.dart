import 'dart:ui';

import 'package:flutter/material.dart';

import '../studio/app_palette.dart';

/// Frosted panel used for cards, sheets and chips.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 26,
    this.blur = 14,
    this.fill,
    this.stroke,
    this.onTap,
    this.glowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? fill;
  final Color? stroke;
  final VoidCallback? onTap;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill ?? AetherColors.glassFill,
            borderRadius: borderRadius,
            border: Border.all(color: stroke ?? AetherColors.glassStroke),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (glowColor != null) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.28),
              blurRadius: 28,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: content,
      );
    }

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Small label pill, e.g. "Quote · Motivation".
class AetherTag extends StatelessWidget {
  const AetherTag({
    super.key,
    required this.label,
    this.icon,
    this.color = AetherColors.electric,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 11,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 10.5 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold-to-sky gradient action button.
class BoltButton extends StatelessWidget {
  const BoltButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.colors,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final List<Color>? colors;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final gradientColors = colors ?? const [AetherColors.azure, AetherColors.electric];
    final active = enabled && onPressed != null;
    return Opacity(
      opacity: active ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: gradientColors),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withValues(alpha: active ? 0.35 : 0),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: active ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19, color: AetherColors.night),
                    const SizedBox(width: 9),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: AetherColors.night,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined, quieter counterpart of [BoltButton].
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AetherColors.ivory,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.circle, size: 18, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }
}

/// Big heading with a subtle sky-to-gold gradient wash, used for the large
/// titles at the top of each screen so the app feels less flat.
class ShaderText extends StatelessWidget {
  const ShaderText(
    this.text, {
    super.key,
    required this.style,
    this.colors = const [AetherColors.ivory, AetherColors.electric, AetherColors.goldLight],
  });

  final String text;
  final TextStyle style;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: colors,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

/// Pulsing icon inside a glowing circle. Originally the sealed daily bolt's
/// centerpiece; the colors are parameterised so the same animation can also
/// stand in as a slowly breathing moon on the Evening Discharge screen.
class PulsingBolt extends StatefulWidget {
  const PulsingBolt({
    super.key,
    this.icon = Icons.bolt_rounded,
    this.size = 104,
    this.duration = const Duration(milliseconds: 2200),
    this.ringColor = AetherColors.electric,
    this.glowColor = AetherColors.azure,
    this.coreColors = const [AetherColors.azure, AetherColors.deep],
    this.iconColors = const [AetherColors.electric, AetherColors.goldLight],
  });

  final IconData icon;
  final double size;
  final Duration duration;
  final Color ringColor;
  final Color glowColor;
  final List<Color> coreColors;
  final List<Color> iconColors;

  @override
  State<PulsingBolt> createState() => _PulsingBoltState();
}

class _PulsingBoltState extends State<PulsingBolt> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: widget.coreColors),
            border: Border.all(
              color: widget.ringColor.withValues(alpha: 0.4 + t * 0.5),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.25 + t * 0.35),
                blurRadius: 30 + t * 20,
                spreadRadius: t * 4,
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: widget.size * 0.52 + t * 4,
            color: Color.lerp(widget.iconColors.first, widget.iconColors.last, t),
          ),
        );
      },
    );
  }
}

/// Section heading with a hairline rule.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AetherColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: AetherColors.glassStroke, height: 1)),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}
