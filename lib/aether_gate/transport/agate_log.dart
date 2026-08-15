import 'package:flutter/foundation.dart';

/// Assert-wrapped logger: in release builds the closure never runs and its
/// string literals are stripped from the binary. Never call bare
/// `debugPrint('[AGATE...] ...')` — the literal would ship as a symbol and
/// cluster the app with siblings.
void agateLog(String Function() build) {
  assert(() {
    debugPrint(build());
    return true;
  }());
}
