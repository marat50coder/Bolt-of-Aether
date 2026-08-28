import 'package:flutter/foundation.dart';

/// Assert-wrapped logger. In release builds the closure never runs, so its
/// string literals are stripped from the shipping binary. Call sites use a
/// short prefix (`[NOVA.*]`) so a diagnostic log can be found quickly in
/// captured device output while still being invisible in release archives.
void novaLog(String Function() build) {
  assert(() {
    debugPrint(build());
    return true;
  }());
}
