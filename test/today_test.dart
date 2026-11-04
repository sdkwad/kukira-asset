// Today (0.2.7b): busy and calm states, the short status on each row, backup and search.

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/rules.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/common.dart';
import 'package:kukira_asset/ui/today.dart';

import 'helpers.dart';

World withSettings(World w, Map<String, String> settings) => World(
      assets: w.assets,
      houses: w.houses,
      vehicles: w.vehicles,
      reminders: w.reminders,
      records: w.records,
      odometer: w.odometer,
      vendors: w.vendors,
      documents: w.documents,
      settings: settings,
      costItems: w.costItems,
    );

World withOdometer(World w, int assetId, int km) => World(
      assets: w.assets,
      houses: w.houses,
      vehicles: w.vehicles,
      reminders: w.reminders,
      records: w.records,
      odometer: {assetId: OdometerReading(id: 1, assetId: assetId, date: today(), km: km)},
      vendors: w.vendors,
      documents: w.documents,
      settings: w.settings,
      costItems: w.costItems,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  final t = today();
  Reminder rem(int id, String title, int days, {String rule = 'fixed', int? dueKm, int leadKm = 1000}) =>
      fakeReminder(id: id, title: title, due: t.add(Duration(days: days))).copyWith(ruleType: rule, dueOdometer: Value(dueKm), leadKm: leadKm);

  group('short status', () {
    final w = withOdometer(fakeWorld(), 2, 47000);
    String text(Reminder r) => shortDue(s, r, w).$1;
    Tone tone(Reminder r) => shortDue(s, r, w).$2;

    test('days late, today, tomorrow, days to go', () {
      expect(text(rem(1, 'a', -6)), s.lateDays(6));
      expect(tone(rem(1, 'a', -6)), Tone.overdue);
      expect(text(rem(1, 'a', 0)), s.dueToday);
      expect(text(rem(1, 'a', 1)), s.dueTomorrow);
      expect(text(rem(1, 'a', 9)), s.inDays(9));
      expect(tone(rem(1, 'a', 9)), Tone.dueSoon);
      expect(tone(rem(1, 'a', 120)), Tone.upcoming);
    });

    test('whichever comes first: the measure that is nearer, and the date on a tie', () {
      // Due by km (500 km past) while the date is still months away.
      expect(text(rem(1, 'oil', 120, rule: 'either', dueKm: 46500)), s.lateKm(s.km(500)));
      // Both upcoming: the date is shown.
      expect(text(rem(1, 'oil', 120, rule: 'either', dueKm: 57000)), s.inDays(120));
      // Close on km, far on date.
      expect(text(rem(1, 'oil', 120, rule: 'either', dueKm: 47600)), s.kmToGoShort(s.km(600)));
      expect(text(rem(1, 'tyres', 0, rule: 'mileage', dueKm: 50000)), s.kmToGoShort(s.km(3000)));
    });

    test('the second line says when, without repeating how late', () {
      final d = t.add(const Duration(days: 9));
      expect(dueDetail(s, rem(1, 'a', 9), w), s.dueOn(s.dShort(d)));
      expect(dueDetail(s, rem(1, 'oil', 9, rule: 'either', dueKm: 50120), w), s.limitEither(s.dShort(d), s.km(50120)));
      expect(dueDetail(s, rem(1, 'tyres', 0, rule: 'mileage', dueKm: 50000), w), s.atKm(s.km(50000)));
      expect(dueDetail(s, rem(1, 'a', 9).copyWith(autoSource: const Value('roadTax')), w), s.endsOn(s.dShort(d)));
    });
  });

  testWidgets('busy: one sentence, then what needs action and what is due in 30 days', (tester) async {
    setPhone(tester, height: 1600);
    final w = fakeWorld(reminders: [rem(1, 'Engine oil', -6), rem(2, 'Road tax', 9), rem(3, 'Tyres', 120)]);
    await tester.pumpWidget(harness(const TodayScreen(), w));
    await tester.pumpAndSettle();
    expect(find.text(s.todaySummary(1, 1, 2).map((p) => p.$1).join()), findsOneWidget);
    expect(find.text(s.needsAction), findsOneWidget);
    expect(find.text(s.next30), findsOneWidget);
    expect(find.text('Tyres'), findsNothing, reason: 'an upcoming reminder is not on a busy Today');
    expect(find.text(s.allClear), findsNothing);
  });

  testWidgets('calm: says so, shows the next three, and no empty sections', (tester) async {
    setPhone(tester, height: 1600);
    final w = fakeWorld(reminders: [for (var i = 1; i <= 4; i++) rem(i, 'Later $i', 40 + i)]);
    await tester.pumpWidget(harness(const TodayScreen(), w));
    await tester.pumpAndSettle();
    expect(find.text(s.allClear), findsOneWidget);
    expect(find.text(s.comingUp), findsOneWidget);
    expect(find.byType(ReminderTile), findsNWidgets(3));
    expect(find.text(s.needsAction), findsNothing);
    expect(find.text(s.next30), findsNothing);
    expect(find.text(s.allReminders(4)), findsOneWidget);
  });

  testWidgets('with no reminders at all it says how to start, not "all in order"', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const TodayScreen(), fakeWorld(reminders: [])));
    await tester.pumpAndSettle();
    expect(find.text(s.noRemindersCalm), findsOneWidget);
    expect(find.text(s.allClear), findsNothing);
    expect(find.text(s.noBackupTitle), findsNothing, reason: 'nothing to lose yet');
  });

  testWidgets('a recent backup is a quiet line at the end instead of a warning', (tester) async {
    setPhone(tester, height: 1600);
    final when = DateTime.now().subtract(const Duration(days: 2));
    final w = withSettings(fakeWorld(reminders: [rem(1, 'Later', 60)]), {'lastBackup': when.toIso8601String()});
    await tester.pumpWidget(harness(const TodayScreen(), w));
    await tester.pumpAndSettle();
    expect(find.text(s.noBackupTitle), findsNothing);
    expect(find.text(s.lastBackupAt('${s.dShort(when)}, ${s.hm(when.hour, when.minute)}')), findsOneWidget);
  });

  testWidgets('the search button finds an asset by its plate', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const TodayScreen(), fakeWorld()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(s.search));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text(s.searchPrompt), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'wxy');
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(SearchResults), matching: find.text('Myvi')), findsOneWidget);
  });

  testWidgets('Today fits a 360 dp phone at 130% text, busy and calm', (tester) async {
    setPhone(tester);
    for (final w in [
      fakeWorld(reminders: [rem(1, 'Servis penghawa dingin bilik utama', -2), rem(2, 'Pembaharuan cukai jalan', 9)]),
      fakeWorld(reminders: [rem(1, 'Cukai taksiran (penggal 1)', 120)]),
    ]) {
      await tester.pumpWidget(harness(MediaQuery.withClampedTextScaling(minScaleFactor: 1.3, maxScaleFactor: 1.3, child: const TodayScreen()), w, lang: 'ms'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  test('every status has a tone that matches the reminder rules', () {
    final w = fakeWorld();
    for (final d in [-3, 0, 5, 200]) {
      final r = rem(1, 'x', d);
      expect(shortDue(s, r, w).$2, toneOf(remStatus(r, w)), reason: '$d days');
    }
    expect(RStatus.values.length, 4);
  });
}
