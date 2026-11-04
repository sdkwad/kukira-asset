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
  runApp(KukiraApp(boot: await boot()));
}

/// Gets the app ready to show something, whatever fails: without notifications the app
/// still works (Today shows everything), and a database that cannot be opened leads to the
/// "records can't be opened" screen, which sets data aside safely, never to a blank screen.
Future<BootResult> boot() async {
  try {
    await Notifier.init();
  } catch (e) {
    ErrorLog.record('boot.notifications', e);
  }
  await SecureFiles.clearTemp();
  await SecureFiles.clearPickerCopies();
  try {
    return await Vault.open();
  } catch (e) {
    ErrorLog.record('boot.vault', e);
    return const BootResult(BootState.failed);
  }
}
