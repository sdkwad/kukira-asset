import 'package:flutter/material.dart';

import 'data/vault.dart';
import 'services/error_log.dart';
import 'services/files.dart';
import 'services/notifications.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Errors nobody caught go to the error log too (Reminder health check shows it).
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    ErrorLog.record('flutter', d.exception);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (e, _) {
    ErrorLog.record('uncaught', e);
    return true;
  };
  await Notifier.init();
  await SecureFiles.clearTemp();
  final boot = await Vault.open();
  runApp(KukiraApp(boot: boot));
}
