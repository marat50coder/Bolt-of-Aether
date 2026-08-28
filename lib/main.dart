import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_palette.dart';
import 'core/app_scope.dart';
import 'core/app_state.dart';
import 'nova_link/config/link_config.dart';
import 'nova_link/pages/nova_warmup.dart';
import 'nova_link/router/link_router.dart';
import 'nova_link/transport/anchor_attrib.dart';
import 'nova_link/transport/link_agent.dart';
import 'nova_link/transport/link_courier.dart';
import 'nova_link/transport/link_ledger.dart';
import 'nova_link/transport/net_probe.dart';
import 'nova_link/transport/nova_log.dart';
import 'nova_link/transport/push_bridge.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

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

      // Remote-content services — every step guarded so a Firebase or
      // plugin failure never disables the pipeline as a whole.
      final ledger = await LinkLedger.open();
      final probe = NetProbe(Connectivity());
      final agent = await LinkAgent.ready();
      final courier = LinkCourier(agent);

      // Firebase MUST be configured before any FirebaseMessaging call
      // and before iOS delivers a notification response. Running it
      // lazily inside `push.init()` reproducibly loses tap-events on
      // cold launch (the log `[FirebaseCore][I-COR000005] No app has
      // been configured yet.` is the tell). Guarded so a Firebase
      // failure never disables the pipeline — `push.enabled = false`
      // will short-circuit push handling but leave the WebView and
      // native branches intact.
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
      // Attach listeners SYNCHRONOUSLY (they need to exist before any
      // background / foreground push tap can fire onMessageOpenedApp).
      // `getInitialMessage` awaits inside — 4 s hard cap — but the
      // returned future is only awaited by NovaWarmup, not by main.
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

      runApp(BoltOfAetherApp(
        ledger: ledger,
        push: push,
        router: router,
        agent: agent,
      ));
    },
    (error, stack) => novaLog(() => 'Caught zone error: $error'),
  );
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
