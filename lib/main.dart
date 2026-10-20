import 'package:flutter/material.dart';

import 'data/vault.dart';
import 'services/notifications.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.init();
  final boot = await Vault.open();
  runApp(KukiraApp(boot: boot));
}
