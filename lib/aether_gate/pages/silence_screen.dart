import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_palette.dart';

/// No-Internet screen. Takes a builder for its Retry button so it never
/// captures a stale parent context (see `gray_flow_lessons.md` §3).
///
/// Retry behaviour matches the reference sibling (Velvet-Jester-Spin
/// `NoSignalScreen`): the first tap does an instant OS-level connectivity
/// check (`Connectivity().checkConnectivity()`, SCNetworkReachability under
/// the hood on iOS), and hands off to the retry builder the moment ANY
/// interface reports up. If not, the button briefly shows a spinner and
/// then flags "No connection yet" so the user is never left wondering.
/// Also auto-retries when the connectivity stream reports a live interface
/// — the button does not need to be spammed.
class SilenceScreen extends StatefulWidget {
  const SilenceScreen({super.key, required this.retryBuilder});

  final WidgetBuilder retryBuilder;

  @override
  State<SilenceScreen> createState() => _SilenceScreenState();
}

class _SilenceScreenState extends State<SilenceScreen> {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _watch;
  bool _checking = false;
  bool _stillOffline = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Auto-recover the moment iOS reports any live interface — the user
    // does not have to touch Retry the exact second WiFi comes back.
    _watch = _connectivity.onConnectivityChanged.listen((results) {
      if (_navigated || _checking) return;
      final live = results.any((r) => r != ConnectivityResult.none);
      if (live) unawaited(_retry(auto: true));
    });
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  Future<void> _retry({bool auto = false}) async {
    if (_checking || _navigated) return;
    if (!auto) HapticFeedback.lightImpact();
    setState(() {
      _checking = true;
      _stillOffline = false;
    });
    // Fast path: trust connectivity_plus. If ANY radio is up we hand off
    // to the retry builder immediately. WebView will re-attempt the actual
    // load and bounce back here if the network is truly dead. A DNS probe
    // here would block for up to ~7 s right after WiFi returns because
    // iOS's DNS cache is stale — that is the "nothing happens on first
    // tap" bug the user was hitting.
    var live = false;
    try {
      final results = await _connectivity.checkConnectivity();
      live = results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      live = false;
    }
    if (!mounted) return;
    if (live) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, _, _) => widget.retryBuilder(context),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
      return;
    }
    setState(() {
      _checking = false;
      _stillOffline = true;
    });
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
              _OfflineGlow(),
              landscape ? _landscape(context) : _portrait(context),
            ],
          );
        },
      ),
    );
  }

  Widget _portrait(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      child: Column(
        children: [
          const Spacer(),
          _icon(size: 128),
          const SizedBox(height: 32),
          _title(align: TextAlign.center),
          const SizedBox(height: 14),
          _subtitle(align: TextAlign.center),
          const Spacer(flex: 2),
          _retryButton(portrait: true),
          _statusLine(align: TextAlign.center),
        ],
      ),
    );
  }

  Widget _landscape(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top + 12, bottom: 20),
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
                  _icon(size: 88),
                  const SizedBox(height: 22),
                  _title(align: TextAlign.left),
                  const SizedBox(height: 12),
                  _subtitle(align: TextAlign.left),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _retryButton(portrait: false),
                    _statusLine(align: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [AetherColors.rose, AetherColors.violet, AetherColors.deep],
          stops: [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AetherColors.rose.withValues(alpha: 0.4),
            blurRadius: 44,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Icon(
        Icons.wifi_off_rounded,
        size: size * 0.5,
        color: AetherColors.ivory,
      ),
    );
  }

  Widget _title({required TextAlign align}) => Text(
        'NO INTERNET CONNECTION',
        textAlign: align,
        style: const TextStyle(
          color: AetherColors.ivory,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: 0.8,
          shadows: [Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2))],
        ),
      );

  Widget _subtitle({required TextAlign align}) => Text(
        'Check your connection and try again',
        textAlign: align,
        style: TextStyle(
          color: AetherColors.ivory.withValues(alpha: 0.85),
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
      );

  /// Micro-hint under the button — only shown after a retry that failed
  /// (no interface up). Softens the "nothing is happening" feeling.
  Widget _statusLine({required TextAlign align}) => AnimatedSize(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.topCenter,
        child: _stillOffline
            ? Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  'No connection yet',
                  textAlign: align,
                  style: TextStyle(
                    color: AetherColors.ivory.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      );

  Widget _retryButton({required bool portrait}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _checking ? null : _retry,
        child: Ink(
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              AetherColors.gold,
              AetherColors.goldLight,
            ]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AetherColors.gold.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.2),
          ),
          child: Center(
            child: _checking
                ? const SizedBox.square(
                    dimension: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: AetherColors.night,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.refresh_rounded, color: AetherColors.night, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Try Again',
                        style: TextStyle(
                          color: AetherColors.night,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
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

class _OfflineGlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.45),
            radius: 1.05,
            colors: [
              AetherColors.duskIndigo.withValues(alpha: 0.9),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
