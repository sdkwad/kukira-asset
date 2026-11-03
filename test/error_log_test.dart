import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/error_log.dart';
import 'package:kukira_asset/services/files.dart';
import 'package:kukira_asset/ui/more.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('ErrorLog', () {
    late Directory root;
    late AppDb db;
    setUp(() async {
      root = await useTempStorage();
      SecureFiles.reset();
      ErrorLog.detach();
      db = AppDb(NativeDatabase.memory());
    });
    tearDown(() async {
      ErrorLog.detach();
      await db.close();
    });

    File logFile() => File('${root.path}/support/error-log.enc');

    test('errors are kept encrypted on the phone and survive a restart', () async {
      ErrorLog.attach(db);
      ErrorLog.record('notifications.schedule', StateError('exact alarms not allowed'));
      expect((await ErrorLog.entries()).single.where, 'notifications.schedule');

      final raw = utf8.decode(logFile().readAsBytesSync(), allowMalformed: true);
      expect(raw.contains('notifications.schedule'), isFalse, reason: 'the log file is encrypted');

      // A restart: nothing in memory, the log is read back from the file.
      ErrorLog.detach();
      ErrorLog.attach(db);
      final back = await ErrorLog.entries();
      expect(back.single.what, contains('exact alarms not allowed'));
    });

    test('errors from before the database opened are saved once it opens', () async {
      ErrorLog.record('vault.read', Exception('keystore busy'));
      expect(await ErrorLog.entries(), hasLength(1));
      ErrorLog.attach(db);
      await ErrorLog.entries();
      expect(logFile().existsSync(), isTrue);
    });

    test('the same error within a minute is kept once; the newest 200 are kept', () async {
      ErrorLog.attach(db);
      for (var i = 0; i < 3; i++) {
        ErrorLog.record('notifications.schedule', StateError('same'));
      }
      ErrorLog.record('backup.save', StateError('same'));
      expect((await ErrorLog.entries()).map((e) => e.where), ['notifications.schedule', 'backup.save']);

      for (var i = 0; i < ErrorLog.max + 5; i++) {
        ErrorLog.record('test', StateError('error $i'));
      }
      final all = await ErrorLog.entries();
      expect(all, hasLength(ErrorLog.max));
      expect(all.last.what, contains('error ${ErrorLog.max + 4}'));
    });

    test('clearing removes the log, and the text to copy is newest first', () async {
      ErrorLog.attach(db);
      ErrorLog.record('a', StateError('first'));
      ErrorLog.record('b', StateError('second'));
      final text = ErrorLog.asText(await ErrorLog.entries(), version: '0.2.3 (5)');
      final lines = text.split('\n');
      expect(lines.first, 'Kukira Asset 0.2.3 (5)');
      expect(lines[1], contains('second'));
      expect(lines[2], contains('first'));

      await ErrorLog.clear();
      expect(await ErrorLog.entries(), isEmpty);
      expect(logFile().existsSync(), isFalse);
    });
  });

  testWidgets('Reminder health check shows caught errors and copies them', (tester) async {
    ErrorLog.detach();
    addTearDown(ErrorLog.detach);
    ErrorLog.record('backup.save', Exception('no space left on device'));
    PackageInfo.setMockInitialValues(appName: 'Kukira Asset', packageName: 'app.kukira.kukira_asset', version: '0.2.3', buildNumber: '5', buildSignature: '');
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    setPhone(tester, height: 2400);
    final s = strFor('en');
    await tester.pumpWidget(harness(const HealthScreen(), fakeWorld()));
    await tester.pumpAndSettle();

    expect(find.text('backup.save'), findsOneWidget);
    expect(find.textContaining('no space left on device'), findsOneWidget);
    await tester.tap(find.text(s.copyErrorLog));
    await tester.pumpAndSettle();
    expect(copied, contains('Kukira Asset 0.2.3 (5)'));
    expect(copied, contains('backup.save'));
    expect(find.text(s.errorLogCopied), findsOneWidget);
  });
}
