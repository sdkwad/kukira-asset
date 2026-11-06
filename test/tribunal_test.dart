// The last day to claim defects at the Tribunal Tuntutan Pembeli Rumah (0.3, F1): 12 months
// after the DLP ends, as an estimate that follows the DLP date.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/auto_sync.dart';
import 'package:kukira_asset/domain/rules.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/auto_reminders.dart';
import 'package:kukira_asset/ui/assets.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');

  test('months can be taken away across years', () {
    expect(addMonths(DateTime(2026, 11, 6), -25), DateTime(2024, 10, 6));
    expect(addMonths(DateTime(2026, 1, 31), -1), DateTime(2025, 12, 31));
    expect(addMonths(DateTime(2026, 3, 31), -1), DateTime(2026, 2, 28));
    expect(addMonths(DateTime(2026, 11, 6), -12), DateTime(2025, 11, 6));
    expect(addMonths(DateTime(2026, 11, 6), 14), DateTime(2028, 1, 6));
  });

  group('the deadline', () {
    final today = DateTime(2026, 11, 6);

    test('is 12 months after the DLP ends, which is 24 months after VP unless the SPA says otherwise', () {
      expect(tribunalDeadlineFrom(DateTime(2027, 1, 15)), DateTime(2028, 1, 15));
      expect(activeTribunalDeadline(vp: DateTime(2025, 1, 15), override: null, source: 'new_from_developer', today: today), DateTime(2028, 1, 15));
      expect(activeTribunalDeadline(vp: DateTime(2025, 1, 15), override: DateTime(2026, 7, 15), source: null, today: today), DateTime(2027, 7, 15));
    });

    test('still runs for a year after the DLP has ended', () {
      // VP 1 Dec 2023: the DLP ended 1 Dec 2025, and defects can be claimed until 1 Dec 2026.
      expect(activeTribunalDeadline(vp: DateTime(2023, 12, 1), override: null, source: null, today: today), DateTime(2026, 12, 1));
    });

    test('is not given for a subsale, without a VP date, or once it has passed', () {
      expect(activeTribunalDeadline(vp: DateTime(2025, 1, 15), override: null, source: 'subsale', today: today), isNull);
      expect(activeTribunalDeadline(vp: null, override: null, source: null, today: today), isNull);
      expect(activeTribunalDeadline(vp: DateTime(2023, 1, 1), override: null, source: null, today: today), isNull);
    });
  });

  test('a VP date makes an estimated reminder, with who to confirm it with, 60 days ahead', () async {
    final db = AppDb(NativeDatabase.memory());
    final house = await db.createAsset(category: 'house', nickname: 'Rumah Setia Alam', propertyType: 'landed');
    final t = DateTime(2026, 11, 6);
    final change = planChange(const [], house, autoTribunal,
        oldDate: null, newDate: activeTribunalDeadline(vp: DateTime(2025, 1, 15), override: null, source: null, today: t), today: t);
    await applyAuto(db, s, house, [change]);
    final r = (await db.select(db.reminders).get()).single;
    expect(r.autoSource, autoTribunal);
    expect(r.title, s.tribunalReminderTitle);
    expect(r.dueDate, DateTime(2028, 1, 15));
    expect(r.leadDays, 60);
    expect(r.estimated, isTrue);
    expect(r.confirmWith, s.tribunalConfirm);
    expect(r.category, 'tribunal');
    await db.close();
  });

  group('screens', () {
    // The DLP ended a month ago, so the tribunal year is running.
    final vp = addMonths(dayOnly(DateTime.now()), -25);

    testWidgets('after the DLP, the house shows how long defects can still be claimed', (tester) async {
      // Tall enough that the whole overview is built.
      setPhone(tester, height: 3200);
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), fakeWorld(vp: vp, source: 'new_from_developer')));
      await tester.pumpAndSettle();
      expect(find.text(s.tribunalRowTitle), findsOneWidget);
      expect(find.text(s.tribunalRowMeta(s.dLong(tribunalDeadlineFrom(dlpEndFrom(vp))))), findsOneWidget);
    });

    testWidgets('a subsale shows no tribunal deadline', (tester) async {
      setPhone(tester, height: 3200);
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), fakeWorld(vp: vp, source: 'subsale')));
      await tester.pumpAndSettle();
      expect(find.text(s.tribunalRowTitle), findsNothing);
    });

    testWidgets('house details explain the tribunal year and ask for the CCC date', (tester) async {
      setPhone(tester, height: 2600);
      final recent = DateTime(2025, 6, 1);
      await tester.pumpWidget(harness(const HouseEditScreen(assetId: 1), fakeWorld(vp: recent, source: 'new_from_developer')));
      await tester.pumpAndSettle();
      expect(find.text(s.autoSyncNoteTribunal(s.dLong(DateTime(2028, 6, 1)))), findsOneWidget);
      expect(find.text(s.cccDateLabel), findsOneWidget);
    });
  });
}
