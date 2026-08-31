import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../studio/app_palette.dart';
import '../../studio/app_scope.dart';
import '../../studio/app_state.dart';
import '../config/link_config.dart';
import '../pages/nova_warmup.dart';
import '../router/link_router.dart';
import '../transport/anchor_attrib.dart';
import '../transport/link_agent.dart';
import '../transport/link_courier.dart';
import '../transport/link_ledger.dart';
import '../transport/net_probe.dart';
import '../transport/nova_log.dart';
import '../transport/push_bridge.dart';

/// Wires chrome, remote services, and the root widget. AppsFlyer is not
/// constructed here — [AnchorAttrib.start] asks ATT first.
class SparkIgnite {
  const SparkIgnite._();

  static Future<Widget> assemble() async {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      novaLog(() => 'Caught framework error: ${details.exceptionAsString()}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      novaLog(() => 'Caught platform error: $error');
      return true;
    };
    ErrorWidget.builder = (details) => const _SafeErrorView();

    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AetherColors.night,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    final ledger = await LinkLedger.open();
    final probe = NetProbe(Connectivity());
    final agent = await LinkAgent.ready();
    final courier = LinkCourier(agent);

    var firebaseReady = false;
    if (LinkConfig.remoteReady) {
      try {
        await Firebase.initializeApp();
        firebaseReady = true;
      } catch (error) {
        novaLog(() => '[NOVA.boot] Firebase.initializeApp failed: $error');
      }
    }
    final push = PushBridge(ledger: ledger, enabled: firebaseReady);
    unawaited(push.init());
    final attrib = AnchorAttrib(ledger: ledger);
    final router = LinkRouter(
      ledger: ledger,
      probe: probe,
      attrib: attrib,
      courier: courier,
      push: push,
      remoteEnabled: LinkConfig.remoteReady,
    );

    novaLog(() => '[NOVA.boot] remoteEnabled=${LinkConfig.remoteReady}');

    return BoltOfAetherApp(
      ledger: ledger,
      push: push,
      router: router,
      agent: agent,
    );
  }
}

class BoltOfAetherApp extends StatefulWidget {
  const BoltOfAetherApp({
    super.key,
    required this.ledger,
    required this.push,
    required this.router,
    required this.agent,
  });

  final LinkLedger ledger;
  final PushBridge push;
  final LinkRouter router;
  final LinkAgent agent;

  @override
  State<BoltOfAetherApp> createState() => _BoltOfAetherAppState();
}

class _BoltOfAetherAppState extends State<BoltOfAetherApp> {
  AppState? _state;

  @override
  void dispose() {
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bolt of Aether',
      debugShowCheckedModeBanner: false,
      theme: buildAetherTheme(),
      home: NovaWarmup(
        router: widget.router,
        ledger: widget.ledger,
        push: widget.push,
        agent: widget.agent,
        onNativeReady: (state) => setState(() => _state = state),
      ),
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        final state = _state;
        final media = MediaQuery.of(context);
        final scaled = MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler
                .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.25),
          ),
          child: content,
        );
        if (state == null) return scaled;
        return AppScope(state: state, child: scaled);
      },
    );
  }
}

class _SafeErrorView extends StatelessWidget {
  const _SafeErrorView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AetherColors.night,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Something flickered here.\nGo back and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AetherColors.muted, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
