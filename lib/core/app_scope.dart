import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';

/// Makes [AppState] available to the widget tree and rebuilds listeners.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }

  /// Read without subscribing to changes.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }
}

/// Haptic helper that honours the user's setting.
void tap(BuildContext context, {bool strong = false}) {
  final state = AppScope.read(context);
  if (!state.haptics) return;
  if (strong) {
    HapticFeedback.mediumImpact();
  } else {
    HapticFeedback.selectionClick();
  }
}
