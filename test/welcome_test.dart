// First run (0.2.7c): a welcome that says what Kukira does, then a short setup. Shown once,
// on a fresh install only.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/add_asset.dart';
import 'package:kukira_asset/ui/app.dart';
import 'package:kukira_asset/ui/welcome.dart';

import 'helpers.dart';

World emptyWorld({Map<String, String> settings = const {}}) => World(
      assets: const [],
      houses: const {},
      vehicles: const {},
      reminders: const [],
      records: const [],
      odometer: const {},
      vendors: const [],
      documents: const [],
      settings: settings,
      costItems: const {},
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');

  test('only a fresh install with nothing in it sees the welcome', () {
    expect(needsWelcome(emptyWorld()), isTrue);
    expect(needsWelcome(emptyWorld(settings: {'onboarded': '2026-11-04'})), isFalse);
    expect(needsWelcome(fakeWorld()), isFalse, reason: 'an update, or a restored backup, has assets');
  });

  testWidgets('the app opens on the welcome the first time, and on Today after', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const Home(), emptyWorld()));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text(s.welcomeTagline), findsOneWidget);
    expect(find.text(s.welcomePrivateBody), findsOneWidget);
    expect(find.text(s.restoreFromOldPhone), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(const Home(), emptyWorld(settings: {'onboarded': '2026-11-04'})));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(Shell), findsOneWidget);
  });

  testWidgets('the language can be chosen on the welcome', (tester) async {
    setPhone(tester);
    final picked = <String>[];
    await tester.pumpWidget(harness(const WelcomeScreen(), emptyWorld(), lang: 'ms', setLang: picked.add));
    await tester.pumpAndSettle();
    expect(find.text(strFor('ms').welcomeTagline), findsOneWidget, reason: 'Bahasa Melayu first');
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(picked, ['en']);
  });

  testWidgets('setup offers notifications, their time and the PIN, and Not now finishes the first run', (tester) async {
    setPhone(tester, height: 1600);
    final db = AppDb(NativeDatabase.memory());
    await tester.pumpWidget(harness(const WelcomeScreen(), emptyWorld(), db: db, notif: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.start));
    await tester.pumpAndSettle();
    expect(find.text(s.setupTitle), findsOneWidget);
    expect(find.text(s.notifPitchShort), findsOneWidget);
    expect(find.widgetWithText(FilledButton, s.allow), findsOneWidget);
    expect(find.text(s.everyDayAt('09:00')), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text(s.setupBackupNote), findsOneWidget);

    await tester.tap(find.text(s.notNow));
    await tester.pumpAndSettle();
    expect(find.byType(SetupScreen), findsNothing, reason: 'back to the first page, which becomes Today');
    final seen = await tester.runAsync(() => db.getSetting('onboarded'));
    await tester.runAsync(db.close);
    expect(seen, isNotNull);
  });

  testWidgets('Add first asset finishes the first run and opens Add asset', (tester) async {
    setPhone(tester);
    final db = AppDb(NativeDatabase.memory());
    await tester.pumpWidget(harness(const WelcomeScreen(), emptyWorld(), db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.start));
    await tester.pumpAndSettle();
    expect(find.text(s.allowed), findsOneWidget, reason: 'notifications already allowed');
    await tester.tap(find.text(s.addFirstAsset));
    await tester.pumpAndSettle();
    expect(find.byType(AddAssetScreen), findsOneWidget);
    final seen = await tester.runAsync(() => db.getSetting('onboarded'));
    await tester.runAsync(db.close);
    expect(seen, isNotNull);
  });

  testWidgets('the PIN switch shows the lock that is on', (tester) async {
    setPhone(tester);
    await tester.pumpWidget(harness(const SetupScreen(), emptyWorld(), lockMode: 'pin'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('both pages fit a 360 dp phone at 130% text', (tester) async {
    setPhone(tester);
    for (final page in const [WelcomeScreen(), SetupScreen()]) {
      await tester.pumpWidget(harness(MediaQuery.withClampedTextScaling(minScaleFactor: 1.3, maxScaleFactor: 1.3, child: page), emptyWorld(), lang: 'ms', notif: false));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
