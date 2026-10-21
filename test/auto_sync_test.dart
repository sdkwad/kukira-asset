import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/auto_sync.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/auto_reminders.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/forms.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final today = DateTime(2026, 10, 20);
  final nov = DateTime(2026, 11, 3);
  final nextYear = DateTime(2027, 11, 3);

  group('planAuto', () {
    test('setting a date creates the reminder', () {
      final p = planAuto(oldDate: null, newDate: nov, existing: null, today: today);
      expect(p.kind, AutoKind.create);
      expect(p.due, nov);
    });

    test('changing the date updates the same reminder', () {
      final p = planAuto(oldDate: nov, newDate: nextYear, existing: LinkedState(due: nov), today: today);
      expect(p.kind, AutoKind.update);
      expect(p.due, nextYear);
      expect(p.needsConfirm, isFalse);
    });

    test('clearing the date removes the reminder', () {
      expect(planAuto(oldDate: nov, newDate: null, existing: LinkedState(due: nov), today: today).kind, AutoKind.delete);
      expect(planAuto(oldDate: nov, newDate: null, existing: null, today: today).kind, AutoKind.none);
    });

    test('never creates a duplicate', () {
      // Saving again with the same date and a linked reminder present: nothing to do.
      expect(planAuto(oldDate: nov, newDate: nov, existing: LinkedState(due: nov), today: today).kind, AutoKind.none);
      // A changed date with a linked reminder updates it instead of creating another.
      expect(planAuto(oldDate: nov, newDate: nextYear, existing: LinkedState(due: nov), today: today).kind, AutoKind.update);
      // Unchanged date after the user deleted the reminder: it does not come back.
      expect(planAuto(oldDate: nov, newDate: nov, existing: null, today: today).kind, AutoKind.none);
    });

    test('a completed reminder is only reopened with confirmation', () {
      final p = planAuto(oldDate: nov, newDate: nextYear, existing: LinkedState(due: nov, done: true), today: today);
      expect(p.kind, AutoKind.update);
      expect(p.reopens, isTrue);
      expect(p.needsConfirm, isTrue);
      // Saving without changing the date leaves it alone.
      expect(planAuto(oldDate: nov, newDate: nov, existing: LinkedState(due: nov, done: true), today: today).kind, AutoKind.none);
    });

    test('a snoozed reminder is only changed with confirmation', () {
      final p = planAuto(oldDate: nov, newDate: nextYear, existing: LinkedState(due: nov, snoozedUntil: DateTime(2026, 10, 25)), today: today);
      expect(p.clearsSnooze, isTrue);
      expect(p.needsConfirm, isTrue);
      // A snooze that has already passed does not count.
      final old = planAuto(oldDate: nov, newDate: nextYear, existing: LinkedState(due: nov, snoozedUntil: DateTime(2026, 10, 1)), today: today);
      expect(old.needsConfirm, isFalse);
    });

    test('DLP reminder follows the active DLP end only', () {
      expect(activeDlpEnd(vp: DateTime(2025, 3, 15), override: null, today: today), DateTime(2027, 3, 15));
      expect(activeDlpEnd(vp: DateTime(2025, 3, 15), override: DateTime(2027, 6, 1), today: today), DateTime(2027, 6, 1));
      expect(activeDlpEnd(vp: DateTime(2020, 1, 1), override: null, today: today), isNull);
      expect(activeDlpEnd(vp: null, override: null, today: today), isNull);
    });
  });

  group('database', () {
    test('create, update, clear and no duplicate', () async {
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final s = strFor('en');
      final car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 1');
      Future<List<Reminder>> linked() async => (await db.select(db.reminders).get()).where((r) => r.autoSource == autoRoadTax).toList();
      Future<void> save(DateTime? from, DateTime? to) async {
        final rs = await db.select(db.reminders).get();
        await applyAuto(db, s, car, [planChange(rs, car, autoRoadTax, oldDate: from, newDate: to, today: today)]);
      }

      await save(null, nov);
      expect((await linked()).length, 1);
      expect((await linked()).single.title, s.presetTitle('roadTax'));

      await save(nov, nov);
      expect((await linked()).length, 1, reason: 'saving again must not add a second reminder');

      await save(nov, nextYear);
      final l = await linked();
      expect(l.length, 1);
      expect(l.single.dueDate, nextYear);

      await save(nextYear, null);
      expect(await linked(), isEmpty);
    });

    test('keeping a completed reminder as it is', () async {
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final s = strFor('en');
      final car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 1');
      await applyAuto(db, s, car, [planChange(const [], car, autoInsurance, oldDate: null, newDate: nov, today: today)]);
      final r = (await db.select(db.reminders).get()).single;
      await db.completeReminder(r, today: today);
      final rs = await db.select(db.reminders).get();
      final change = planChange(rs, car, autoInsurance, oldDate: nov, newDate: nextYear, today: today);
      expect(change.plan.reopens, isTrue);
      await applyAuto(db, s, car, [change], overwriteManual: false);
      final after = (await db.select(db.reminders).get()).single;
      expect(after.done, isTrue);
      expect(after.dueDate, nov);
    });
  });

  group('screens', () {
    testWidgets('a linked reminder has a read-only date and explains why', (tester) async {
      setPhone(tester, height: 1600);
      final s = strFor('en');
      final w = fakeWorld(roadTax: nov, reminders: [fakeReminder(autoSource: autoRoadTax)]);
      await tester.pumpWidget(harness(const ReminderFormScreen(editId: 1), w));
      await tester.pumpAndSettle();
      expect(find.text(s.autoLinkedNote(s.autoFieldName(autoRoadTax))), findsOneWidget);
      final deco = tester.widget<InputDecorator>(find.ancestor(of: find.text(s.dLong(nov)), matching: find.byType(InputDecorator)));
      expect(deco.decoration.enabled, isFalse);
    });

    testWidgets('vehicle details explain that dates keep their reminders', (tester) async {
      setPhone(tester, height: 2400);
      final s = strFor('en');
      await tester.pumpWidget(harness(const VehicleEditScreen(assetId: 2), fakeWorld(roadTax: nov)));
      await tester.pumpAndSettle();
      expect(find.text(s.autoSyncNoteVehicle), findsOneWidget);
    });
  });
}
