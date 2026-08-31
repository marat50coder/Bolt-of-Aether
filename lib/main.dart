import 'dart:async';

import 'package:flutter/widgets.dart';

import 'lumen/boot/spark_ignite.dart';
import 'lumen/transport/nova_log.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(await SparkIgnite.assemble());
    },
    (error, stack) => novaLog(() => 'Caught zone error: $error'),
  );
}
