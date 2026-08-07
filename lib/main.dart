import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_palette.dart';
import 'core/app_scope.dart';
import 'core/app_state.dart';
import 'screens/splash_screen.dart';

void main() {
  // Any unexpected error is logged and swallowed instead of taking the app
  // down: a review build must never crash.
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('Caught framework error: ${details.exceptionAsString()}');
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Caught platform error: $error');
        return true;
      };
      ErrorWidget.builder = (details) => const _SafeErrorView();

      // The loading screen may be portrait or landscape; the app itself locks
      // to portrait once the splash hands over (see SplashScreen).
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AetherColors.night,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

      runApp(const BoltOfAetherApp());
    },
    (error, stack) => debugPrint('Caught zone error: $error'),
  );
}

class BoltOfAetherApp extends StatefulWidget {
  const BoltOfAetherApp({super.key});

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
      home: SplashScreen(onReady: (state) => setState(() => _state = state)),
      // Wrapping here (above the Navigator) keeps the app state available to
      // every route that gets pushed later on.
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        final state = _state;
        // Text scale is clamped so extreme system font sizes cannot break
        // the card layouts.
        final media = MediaQuery.of(context);
        final scaled = MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.25),
          ),
          child: content,
        );
        if (state == null) return scaled;
        return AppScope(state: state, child: scaled);
      },
    );
  }
}

/// Replaces the red error box with something presentable if a widget throws.
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
