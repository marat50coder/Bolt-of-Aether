import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_palette.dart';
import '../core/models.dart';
import 'bolt_card.dart';

/// Lets buttons drive the deck from outside.
class SwipeDeckController {
  _SwipeDeckState? _state;

  void swipeRight() => _state?._programmatic(true);
  void swipeLeft() => _state?._programmatic(false);
  bool get isBusy => _state?._busy ?? false;
}

/// Tinder-style card stack: drag right to keep a bolt, left to let it pass.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.items,
    required this.onSwipe,
    this.controller,
    this.onTapCard,
  });

  final List<Bolt> items;
  final void Function(Bolt bolt, bool liked) onSwipe;
  final SwipeDeckController? controller;
  final void Function(Bolt bolt)? onTapCard;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..addListener(_onTick);

  Offset _drag = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  bool _busy = false;
  bool? _pendingLike;
  Size _size = const Size(360, 620);

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _anim.dispose();
    super.dispose();
  }

  void _onTick() {
    final curve = _pendingLike == null
        ? Curves.easeOutBack.transform(_anim.value)
        : Curves.easeOutCubic.transform(_anim.value);
    setState(() => _drag = Offset.lerp(_from, _to, curve)!);
    if (_anim.isCompleted) _finish();
  }

  void _finish() {
    final liked = _pendingLike;
    _pendingLike = null;
    _busy = false;
    _anim.reset();
    if (liked != null && widget.items.isNotEmpty) {
      final bolt = widget.items.first;
      setState(() => _drag = Offset.zero);
      widget.onSwipe(bolt, liked);
    } else {
      setState(() => _drag = Offset.zero);
    }
  }

  void _programmatic(bool liked) {
    if (_busy || widget.items.isEmpty) return;
    _fling(liked);
  }

  void _fling(bool liked) {
    _busy = true;
    _pendingLike = liked;
    _from = _drag;
    _to = Offset(
      liked ? _size.width * 1.6 : -_size.width * 1.6,
      _drag.dy - 60,
    );
    _anim
      ..duration = const Duration(milliseconds: 330)
      ..forward(from: 0);
  }

  void _springBack() {
    _busy = true;
    _pendingLike = null;
    _from = _drag;
    _to = Offset.zero;
    _anim
      ..duration = const Duration(milliseconds: 420)
      ..forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final visible = widget.items.take(3).toList();
        final threshold = _size.width * 0.28;
        final ratio = (_drag.dx / threshold).clamp(-1.5, 1.5);

        return Stack(
          alignment: Alignment.center,
          children: [
            for (var i = visible.length - 1; i >= 1; i--)
              Positioned.fill(
                child: IgnorePointer(
                  child: Transform.translate(
                    offset: Offset(0, i * 12.0),
                    child: Transform.scale(
                      scale: 1 - i * 0.045,
                      child: Opacity(
                        opacity: i == 1 ? 0.75 : 0.45,
                        child: BoltCard(bolt: visible[i]),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onTapCard?.call(visible.first),
                onPanUpdate: _busy
                    ? null
                    : (details) => setState(() => _drag += details.delta),
                onPanEnd: _busy
                    ? null
                    : (details) {
                        final velocity = details.velocity.pixelsPerSecond.dx;
                        if (_drag.dx.abs() > threshold || velocity.abs() > 900) {
                          _fling(_drag.dx > 0 || velocity > 0);
                        } else {
                          _springBack();
                        }
                      },
                child: Transform.translate(
                  offset: _drag,
                  child: Transform.rotate(
                    angle: (_drag.dx / _size.width) * 0.32,
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                        Positioned.fill(child: BoltCard(bolt: visible.first)),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _SwipeOverlay(ratio: ratio),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SwipeOverlay extends StatelessWidget {
  const _SwipeOverlay({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final keep = ratio > 0;
    final strength = ratio.abs().clamp(0.0, 1.0);
    if (strength < 0.02) return const SizedBox.shrink();

    final color = keep ? AetherColors.mint : AetherColors.rose;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: color.withValues(alpha: 0.10 * strength),
        border: Border.all(color: color.withValues(alpha: 0.7 * strength), width: 2),
      ),
      padding: const EdgeInsets.all(22),
      child: Align(
        alignment: keep ? Alignment.topRight : Alignment.topLeft,
        child: Transform.rotate(
          angle: keep ? -0.22 : 0.22,
          child: Opacity(
            opacity: min(1, strength * 1.4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 2.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(keep ? Icons.bolt_rounded : Icons.close_rounded, color: color, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    keep ? 'CHARGED' : 'PASS',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
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
