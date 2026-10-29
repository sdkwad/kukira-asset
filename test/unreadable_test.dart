import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/vault.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/more.dart';
import 'package:path/path.dart' as p;

import 'helpers.dart';

void main() {
  group('Vault.setAside', () {
    late Directory base;
    setUp(() async => base = await Directory.systemTemp.createTemp('kukira_'));
    tearDown(() => base.delete(recursive: true));

    Future<void> write(String rel, String body) async {
      final f = File(p.join(base.path, rel));
      await f.parent.create(recursive: true);
      await f.writeAsString(body);
    }

    test('moves the database and the encrypted files instead of deleting them', () async {
      await write('kukira.db', 'db');
      await write('kukira.db-wal', 'wal');
      await write('files/abc.jpg.enc', 'photo');

      final dest = await Vault.setAside(base, '20261029-101500');

      expect(dest, isNotNull);
      expect(File(p.join(base.path, 'kukira.db')).existsSync(), isFalse);
      expect(Directory(p.join(base.path, 'files')).existsSync(), isFalse);
      expect(File(p.join(dest!.path, 'kukira.db')).readAsStringSync(), 'db');
      expect(File(p.join(dest.path, 'kukira.db-wal')).readAsStringSync(), 'wal');
      expect(File(p.join(dest.path, 'files', 'abc.jpg.enc')).readAsStringSync(), 'photo');
    });

    test('never overwrites an earlier set-aside copy', () async {
      await write('kukira.db', 'first');
      final a = await Vault.setAside(base, '20261029-101500');
      await write('kukira.db', 'second');
      final b = await Vault.setAside(base, '20261029-101500');

      expect(a!.path, isNot(b!.path));
      expect(File(p.join(a.path, 'kukira.db')).readAsStringSync(), 'first');
      expect(File(p.join(b.path, 'kukira.db')).readAsStringSync(), 'second');
    });

    test('does nothing when there is nothing to keep', () async {
      expect(await Vault.setAside(base, '20261029-101500'), isNull);
      expect(Directory(p.join(base.path, 'unreadable')).existsSync(), isFalse);
    });
  });

  testWidgets('the start-fresh warning says the records are set aside, not erased', (tester) async {
    setPhone(tester);
    final s = strFor('en');
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('ms'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: UnreadableScreen(s: s, onReady: (_) {}),
    ));
    // The list builds lazily, so scroll until each button exists and is on screen.
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text(s.startFresh), 200, scrollable: list);
    await tester.tap(find.text(s.startFresh));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(s.eraseAndStart), 200, scrollable: list);

    expect(find.text(s.startFreshWarning), findsOneWidget);
    expect(s.startFreshWarning, contains('instead of deleting'));
    expect(find.text(s.eraseAndStart), findsOneWidget);
    expect(find.text(s.keepIt), findsOneWidget);
    expect(strFor('ms').startFreshWarning, contains('bukan memadamnya'));
  });
}
