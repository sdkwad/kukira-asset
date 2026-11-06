// Found in the third audit (before 0.3): editing only the words of a reminder or a document
// brought back a reminder that was done or snoozed.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Table, Column;
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/common.dart';
import 'package:kukira_asset/ui/documents.dart';
import 'package:kukira_asset/ui/forms.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  final due = DateTime(2026, 12, 1);

  group('a new schedule', () {
    final r = fakeReminder(due: due).copyWith(ruleType: 'repeat', repeatMonths: const Value(6));
    bool changed({String rule = 'repeat', DateTime? d, int? months = 6, int? days, String from = 'completion'}) =>
        changesSchedule(r, rule: rule, due: d ?? due, months: months, days: days, repeatFrom: from);

    test('is a new rule, date, repeat or count-from', () {
      expect(changed(), isFalse);
      expect(changed(rule: 'fixed', months: null), isTrue);
      expect(changed(d: DateTime(2026, 12, 2)), isTrue);
      expect(changed(months: 12), isTrue);
      expect(changed(from: 'due'), isTrue);
    });

    test('ignores what the rule does not use', () {
      // A preset stored a repeat on a one-off reminder: it was never part of its schedule.
      final oneOff = fakeReminder(due: due).copyWith(ruleType: 'fixed', repeatMonths: const Value(12), repeatKm: const Value(5000));
      expect(changesSchedule(oneOff, rule: 'fixed', due: due, repeatFrom: oneOff.repeatFrom), isFalse);
    });
  });

  Future<void> scrollTo(WidgetTester tester, Finder f) => tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);

  testWidgets('renaming a snoozed reminder keeps it snoozed', (tester) async {
    setPhone(tester, height: 2000);
    final db = AppDb(NativeDatabase.memory());
    // Whole seconds: the database keeps no finer time.
    final until = DateTime(2026, 11, 28);
    final id = (await tester.runAsync(() async {
      final car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
      return db.addReminder(RemindersCompanion.insert(
        assetId: car,
        title: 'Wiper blades',
        ruleType: 'fixed',
        dueDate: Value(due),
        snoozedUntil: Value(until),
      ));
    }))!;
    final w = (await tester.runAsync(db.loadWorld))!;
    await tester.pumpWidget(harness(
      Builder(builder: (c) => TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ReminderFormScreen(editId: id))), child: const Text('open'))),
      w,
      db: db,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Wiper blades'), 'Front wiper blades');
    await scrollTo(tester, find.byType(SaveButton));
    await tester.tap(find.byType(SaveButton));
    await tester.pumpAndSettle();
    final r = (await tester.runAsync(() => (db.select(db.reminders)..where((t) => t.id.equals(id))).getSingle()))!;
    await tester.runAsync(db.close);
    expect(r.title, 'Front wiper blades');
    expect(r.snoozedUntil, until, reason: 'only the name changed');
    expect(r.done, isFalse);
  });

  testWidgets('renaming a document keeps its expiry reminder done', (tester) async {
    setPhone(tester, height: 2000);
    final db = AppDb(NativeDatabase.memory());
    final ids = (await tester.runAsync(() async {
      final car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
      final rem = await db.addReminder(RemindersCompanion.insert(
        assetId: car,
        title: 'Policy expires',
        ruleType: 'fixed',
        dueDate: Value(due),
        done: const Value(true),
      ));
      final doc = await db.addDocument(DocumentsCompanion.insert(
        assetId: car,
        filePath: 'p.pdf',
        title: 'Policy',
        docType: 'insurance',
        expiry: Value(due),
        linkedReminderId: Value(rem),
      ));
      return (rem, doc);
    }))!;
    final w = (await tester.runAsync(db.loadWorld))!;
    await tester.pumpWidget(harness(
      Builder(builder: (c) => TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DocumentFormScreen(editId: ids.$2))), child: const Text('open'))),
      w,
      db: db,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Policy'), 'Policy 2026');
    final save = find.text(s.saveDocument);
    await scrollTo(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final rem = (await tester.runAsync(() => (db.select(db.reminders)..where((t) => t.id.equals(ids.$1))).getSingle()))!;
    await tester.runAsync(db.close);
    expect(rem.title, s.docExpires('Policy 2026'), reason: 'the reminder still follows the name');
    expect(rem.done, isTrue, reason: 'the expiry did not change');
  });
}
