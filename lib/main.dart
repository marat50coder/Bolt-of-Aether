import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aether_gate/config/relay_config.dart';
import 'aether_gate/pages/aether_warmup.dart';
import 'aether_gate/router/aether_router.dart';
import 'aether_gate/transport/agate_log.dart';
import 'aether_gate/transport/bolt_agent.dart';
import 'aether_gate/transport/bolt_pulse.dart';
import 'aether_gate/transport/channel_dispatch.dart';
import 'aether_gate/transport/relay_vault.dart';
import 'aether_gate/transport/signal_probe.dart';
import 'aether_gate/transport/storm_attrib.dart';
import 'core/app_palette.dart';
import 'core/app_scope.dart';
import 'core/app_state.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        agateLog(() => 'Caught framework error: ${details.exceptionAsString()}');
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        agateLog(() => 'Caught platform error: $error');
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

      // Gray-flow services — every step guarded so a Firebase or plugin
      // failure never disables the gate (`gray_flow_lessons.md` §5).
      final vault = await RelayVault.open();
      final probe = SignalProbe(Connectivity());
      final agent = await BoltAgent.ready();
      final dispatch = ChannelDispatch(agent);

      // Firebase MUST be configured before any FirebaseMessaging call and
      // before iOS delivers a notification response. The sibling reference
      // (Velvet-Jester-Spin main.dart) awaits this in main; running it
      // lazily inside `pulse.init()` reproducibly loses tap-events on cold
      // launch (the log `[FirebaseCore][I-COR000005] No app has been
      // configured yet.` is the tell). Guarded so a Firebase failure never
      // disables the gate — `pulse.enabled=false` will short-circuit push
      // handling but leave the WebView / native branches intact.
      var firebaseReady = false;
      if (AetherRelayConfig.grayCredentialsReady) {
        try {
          await Firebase.initializeApp();
          firebaseReady = true;
        } catch (error) {
          agateLog(() => '[AGATE.boot] Firebase.initializeApp failed: $error');
        }
      }
      final pulse = BoltPulse(vault: vault, enabled: firebaseReady);
      // Attach listeners SYNCHRONOUSLY (they need to exist before any
      // background/foreground push tap can fire onMessageOpenedApp).
      // `getInitialMessage` awaits inside — 4 s hard cap — but the returned
      // future is only awaited by AetherWarmup, not by main.
      unawaited(pulse.init());
      final attrib = StormAttrib(vault: vault);
      final router = AetherRouter(
        vault: vault,
        probe: probe,
        attrib: attrib,
        dispatch: dispatch,
        pulse: pulse,
        gateEnabled: AetherRelayConfig.grayCredentialsReady,
      );

      agateLog(() => '[AGATE.boot] gateEnabled=${AetherRelayConfig.grayCredentialsReady}');

      runApp(BoltOfAetherApp(
        vault: vault,
        pulse: pulse,
        router: router,
        agent: agent,
      ));
    },
    (error, stack) => agateLog(() => 'Caught zone error: $error'),
  );
}

class BoltOfAetherApp extends StatefulWidget {
  const BoltOfAetherApp({
    super.key,
    required this.vault,
    required this.pulse,
    required this.router,
    required this.agent,
  });

  final RelayVault vault;
  final BoltPulse pulse;
  final AetherRouter router;
  final BoltAgent agent;

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
      home: AetherWarmup(
        router: widget.router,
        vault: widget.vault,
        pulse: widget.pulse,
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
