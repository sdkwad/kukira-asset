// A record's title is optional: left empty, the record is named after its category.

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/presets.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/forms.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');

  test('the default title is the category, or the kind when the category says nothing', () {
    expect(defaultRecordTitle(s, 'maintenance', 'oil'), s.catName('oil'));
    expect(defaultRecordTitle(s, 'payment', 'road_tax'), s.catName('road_tax'));
    expect(defaultRecordTitle(s, 'maintenance', 'other'), s.kindName('maintenance'));
    expect(defaultRecordTitle(s, 'incident', null), s.kindName('incident'));
    expect(defaultRecordTitle(s, 'renovation', 'minor'), '${s.kindName('renovation')} (${s.catName('minor')})');
  });

  /// Opens the record form for [assetId], leaves the title empty, saves, and returns the record.
  Future<UpkeepRecord> saveWithoutTitle(WidgetTester tester, {required int assetId, String kind = 'maintenance'}) async {
    setPhone(tester, height: 3000);
    final db = AppDb(NativeDatabase.memory());
    await tester.runAsync(() async {
      await db.createAsset(category: 'house', nickname: 'Setia Alam house', propertyType: 'landed');
      await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
    });
    await tester.pumpWidget(harness(
      Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RecordFormScreen(assetId: assetId, kind: kind))),
          child: const Text('open'),
        ),
      ),
      fakeWorld(),
      db: db,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final save = find.text(kind == 'defect' ? s.saveDefect : s.saveRecord);
    await tester.scrollUntilVisible(save, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget, reason: 'the form closed after saving');
    final records = (await tester.runAsync(() => db.select(db.records).get()))!;
    await tester.runAsync(db.close);
    return records.single;
  }

  testWidgets('the form says what an empty title will be, before saving', (tester) async {
    setPhone(tester, height: 2000);
    await tester.pumpWidget(harness(const RecordFormScreen(assetId: 2), fakeWorld()));
    await tester.pumpAndSettle();
    // A car's first maintenance category is engine oil.
    expect(find.text(s.titleIfEmpty(s.catName('oil'))), findsOneWidget);

    await tester.tap(find.text(s.catName('brake')));
    await tester.pumpAndSettle();
    expect(find.text(s.titleIfEmpty(s.catName('brake'))), findsOneWidget);
  });

  testWidgets("a record that completes a reminder takes the reminder's name instead", (tester) async {
    setPhone(tester, height: 2000);
    final due = fakeReminder(title: 'Change engine oil', due: DateTime.now().subtract(const Duration(days: 2))).copyWith(category: const Value('oil'));
    await tester.pumpWidget(harness(const RecordFormScreen(assetId: 2), fakeWorld(reminders: [due])));
    await tester.pumpAndSettle();
    expect(find.text(s.titleIfEmpty('Change engine oil')), findsOneWidget);

    // Not marking it done: the record is not that reminder, so it is named after the category.
    await tester.tap(find.text(s.looksLike('Change engine oil')));
    await tester.pumpAndSettle();
    expect(find.text(s.titleIfEmpty(s.catName('oil'))), findsOneWidget);
  });

  testWidgets('a car service saved with no title is named after its category', (tester) async {
    final r = await saveWithoutTitle(tester, assetId: 2);
    expect(r.title, s.catName('oil'));
    expect(r.kind, 'maintenance');
  });

  testWidgets('a defect saved with no title is named after its category', (tester) async {
    final r = await saveWithoutTitle(tester, assetId: 1, kind: 'defect');
    expect(r.title, s.catName('wall_crack'));
    expect(r.kind, 'defect');
  });
}
