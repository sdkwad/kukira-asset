// Tambah suggestions (0.2.7d): what is overdue or due soon comes first in the sheet, and one
// tap opens the record that marks it done, or the reminder for a date the asset page keeps.

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/add_actions.dart';
import 'package:kukira_asset/ui/app.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/common.dart';
import 'package:kukira_asset/ui/renew.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  final t = today();
  Reminder rem(int id, int assetId, String title, int days, {String? auto, String? category}) =>
      fakeReminder(id: id, assetId: assetId, title: title, due: t.add(Duration(days: days)), autoSource: auto).copyWith(category: Value(category));
  final fab = find.byType(FloatingActionButton).hitTestable();

  group('which reminders', () {
    test('overdue first, then due soon; nothing upcoming, done or of another asset', () {
      final w = fakeWorld(reminders: [
        rem(1, 2, 'Tyres', 5),
        rem(2, 2, 'Engine oil change', -6),
        rem(3, 1, 'Aircond service', -2),
        rem(4, 2, 'Battery', 200),
        fakeReminder(id: 5, assetId: 2, title: 'Done one', due: t.subtract(const Duration(days: 9)), done: true),
      ]);
      expect(addSuggestions(w).map((r) => r.title), ['Engine oil change', 'Aircond service', 'Tyres']);
      expect(addSuggestions(w, assetId: 2).map((r) => r.title), ['Engine oil change', 'Tyres']);
      expect(addSuggestions(w, max: 1).map((r) => r.title), ['Engine oil change']);
      expect(addSuggestions(fakeWorld(reminders: [rem(1, 2, 'Battery', 200)])), isEmpty);
    });

    test('what each one opens, and what it is called', () {
      expect(suggestionAction(rem(1, 2, 'Engine oil change', -6)), SuggestionAction.record);
      expect(suggestionAction(rem(1, 2, 'Road tax', 3, auto: 'roadTax')), SuggestionAction.renew, reason: 'renewing it sets the next date (0.2.7e)');
      expect(suggestionAction(rem(1, 2, 'Insurance', 3, auto: 'insurance')), SuggestionAction.renew);
      expect(suggestionAction(rem(1, 1, 'DLP ends', 3, auto: 'dlp')), SuggestionAction.reminder);
      expect(suggestionAction(rem(1, 2, 'Odometer', 0, category: 'odometer')), SuggestionAction.reminder);
      expect(suggestionTitle(s, rem(1, 2, 'Engine oil change', -6)), 'Record engine oil change');
      expect(suggestionTitle(strFor('ms'), rem(1, 2, 'Tukar minyak enjin', -6)), 'Rekod tukar minyak enjin');
      expect(suggestionTitle(strFor('ms'), rem(1, 2, 'MBSA cukai taksiran', -6)), 'Rekod MBSA cukai taksiran', reason: 'a short form keeps its capitals');
      expect(suggestionTitle(s, rem(1, 2, 'Road tax renewal', 3, auto: 'roadTax')), s.renewRoadTax);
      expect(suggestionTitle(s, rem(1, 2, 'Insurance renewal', 3, auto: 'insurance')), s.renewInsurance);
    });
  });

  testWidgets('from Today: the suggestions come first, each with its asset, then the assets', (tester) async {
    setPhone(tester, height: 1600);
    final w = fakeWorld(reminders: [rem(1, 2, 'Engine oil change', -6), rem(2, 1, 'Aircond service', -2)]);
    await tester.pumpWidget(harness(const Shell(), w));
    await tester.pumpAndSettle();
    await tester.tap(fab);
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text(s.suggested)), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Record engine oil change')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Myvi · ${s.lateDays(6)}')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(s.orPickAsset)), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(s.whichAsset)), findsNothing);
    final first = tester.getRect(find.text('Record engine oil change')).top;
    expect(first, lessThan(tester.getRect(find.text(s.orPickAsset)).top), reason: 'suggestions above the assets');

    await tester.tap(find.text('Record engine oil change'));
    await tester.pumpAndSettle();
    expect(find.text(s.newRecord), findsOneWidget);
    expect(find.text(s.looksLike('Engine oil change')), findsOneWidget, reason: 'the record says it marks the reminder done');
    final box = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, s.looksLike('Engine oil change')));
    expect(box.value, isTrue);
  });

  testWidgets('on an asset page: that asset\'s suggestions, then its other actions', (tester) async {
    setPhone(tester, height: 1600);
    final w = fakeWorld(reminders: [rem(1, 2, 'Engine oil change', -6), rem(2, 1, 'Aircond service', -2)]);
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), w));
    await tester.pumpAndSettle();
    await tester.tap(fab);
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text('Record engine oil change')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Record aircond service')), findsNothing, reason: 'the house\'s, not this car\'s');
    expect(find.descendant(of: sheet, matching: find.text('${s.lateDays(6)} · ${s.marksReminderDone}')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(s.otherForAsset('Myvi'))), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(s.addActionName('maintenance', 'car'))), findsOneWidget);
  });

  testWidgets('a road tax suggestion opens its renewal', (tester) async {
    setPhone(tester, height: 1600);
    final w = fakeWorld(reminders: [rem(1, 2, 'Road tax renewal', 5, auto: 'roadTax')]);
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), w));
    await tester.pumpAndSettle();
    await tester.tap(fab);
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.renewRoadTax));
    await tester.pumpAndSettle();
    expect(find.text(s.newRecord), findsNothing);
    expect(find.byType(RenewScreen), findsOneWidget);
  });

  testWidgets('with nothing due the sheet is as before', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), fakeWorld(reminders: [rem(1, 2, 'Battery', 200)])));
    await tester.pumpAndSettle();
    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.text(s.suggested), findsNothing);
    expect(find.text(s.otherForAsset('Myvi')), findsNothing);
    expect(find.text(s.addActionName('maintenance', 'car')), findsOneWidget);
  });

  testWidgets('the sheet fits a 360 dp phone at 130% text', (tester) async {
    setPhone(tester);
    final w = fakeWorld(reminders: [rem(1, 2, 'Tukar minyak enjin dan penapis', -6), rem(2, 1, 'Servis penghawa dingin bilik utama', -2), rem(3, 2, 'Cukai jalan', 4, auto: 'roadTax')]);
    await tester.pumpWidget(harness(MediaQuery.withClampedTextScaling(minScaleFactor: 1.3, maxScaleFactor: 1.3, child: const Shell()), w, lang: 'ms'));
    await tester.pumpAndSettle();
    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
