import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../studio/app_palette.dart';
import '../studio/app_scope.dart';
import '../surface/aether_background.dart';
import 'create_screen.dart';
import 'daily_screen.dart';
import 'discover_screen.dart';
import 'rituals_screen.dart';
import 'saved_screen.dart';

/// Lets any descendant jump to another tab.
class HomeNav extends InheritedWidget {
  const HomeNav({super.key, required this.goTo, required super.child});

  final void Function(int index) goTo;

  static void jump(BuildContext context, int index) {
    context.getInheritedWidgetOfExactType<HomeNav>()?.goTo(index);
  }

  @override
  bool updateShouldNotify(HomeNav oldWidget) => false;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _goTo(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return HomeNav(
      goTo: _goTo,
      child: PopScope(
        // Back returns to Today first, and only then leaves the app.
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goTo(0);
        },
        child: Scaffold(
          // The nav bar is placed via a Stack + Positioned(bottom: 0) instead
          // of Scaffold.bottomNavigationBar so it is always flush against the
          // bottom edge of the screen. Some device/orientation transitions
          // were leaving the bottom-nav slot hanging around the middle of the
          // screen on this device — pinning it manually removes that risk.
          body: Stack(
            fit: StackFit.expand,
            children: [
              AetherBackground(
                animate: state.motion,
                child: SafeArea(
                  bottom: false,
                  child: IndexedStack(
                    index: _index,
                    children: const [
                      DailyScreen(),
                      DiscoverScreen(),
                      CreateScreen(),
                      RitualsScreen(),
                      SavedScreen(),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _AetherNavBar(
                  index: _index,
                  onTap: (value) {
                    tap(context);
                    _goTo(value);
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

class _AetherNavBar extends StatelessWidget {
  const _AetherNavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.wb_twilight_rounded, 'Today'),
    (Icons.style_rounded, 'Discover'),
    (Icons.add_rounded, 'Create'),
    (Icons.auto_awesome_rounded, 'Rituals'),
    (Icons.bookmark_rounded, 'Saved'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: 12 + safeBottomInset(context) * 0.5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AetherColors.night.withValues(alpha: 0.0),
            AetherColors.night.withValues(alpha: 0.88),
            AetherColors.night,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < _items.length; i++)
            i == 2
                ? _CreateButton(active: index == i, onTap: () => onTap(i))
                : _NavButton(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    active: index == i,
                    onTap: () => onTap(i),
                  ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AetherColors.electric : AetherColors.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(top: active ? 2 : 6, bottom: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                scale: active ? 1.14 : 1.0,
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: active ? 20 : 0,
                height: 3,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AetherColors.electric, AetherColors.goldLight],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatefulWidget {
  const _CreateButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  State<_CreateButton> createState() => _CreateButtonState();
}

class _CreateButtonState extends State<_CreateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final pulse = widget.active
                ? 0.0
                : 0.5 + 0.5 * math.sin(_controller.value * 2 * math.pi);
            return InkWell(
              onTap: widget.onTap,
              customBorder: const CircleBorder(),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: widget.active
                        ? const [AetherColors.goldLight, AetherColors.gold]
                        : const [AetherColors.azure, AetherColors.electric],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.active ? AetherColors.gold : AetherColors.electric)
                          .withValues(alpha: 0.45 + pulse * 0.18),
                      blurRadius: 18 + pulse * 6,
                      spreadRadius: pulse * 1.5,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  widget.active ? Icons.edit_rounded : Icons.add_rounded,
                  color: AetherColors.night,
                  size: 30,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}