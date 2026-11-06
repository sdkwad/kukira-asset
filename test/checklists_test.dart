// Checklists used again and again (0.3, F7): ready-made lists for a long drive and for time
// away from the house, ticks cleared for the next trip, and a reminder on a chosen date.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/rules.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/checklists.dart';
import 'package:kukira_asset/ui/checklists.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('ms');

  test('the ready-made lists have the same items in both languages', () {
    for (final t in checklistTemplates) {
      expect(strFor('ms').checklistTemplateItems(t), hasLength(strFor('en').checklistTemplateItems(t).length));
      expect(strFor('ms').checklistTemplateItems(t), isNotEmpty);
    }
    expect(s.checklistTemplateItems('tripHouse'), contains('Tutup gas'));
  });

  group('a list', () {
    late AppDb db;
    setUp(() => db = AppDb(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('is made with its items in order, ticked, and cleared for the next trip', () async {
      final car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
      final id = await createChecklist(db, title: 'Balik kampung', assetId: car, labels: s.checklistTemplateItems('tripCar'));
      var w = await db.loadWorld();
      final items = w.checklistItems[id]!;
      expect(items.first.label, s.checklistTemplateItems('tripCar').first);
      expect(items.map((i) => i.position), [for (var i = 0; i < items.length; i++) i]);

      await setItemChecked(db, items.first, true);
      await setItemChecked(db, items[1], true);
      w = await db.loadWorld();
      expect(w.checklistItems[id]!.where((i) => i.checked), hasLength(2));

      await restartChecklist(db, w.checklists.single);
      w = await db.loadWorld();
      expect(w.checklistItems[id]!.where((i) => i.checked), isEmpty);
      expect(w.checklists.single.lastUsed, dayOnly(DateTime.now()));
    });

    test('can remind on a date, on its asset', () async {
      final car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
      await createChecklist(db, title: 'Balik kampung', assetId: car, labels: const ['Tayar']);
      final w = await db.loadWorld();
      expect(await remindChecklist(db, s, w, w.checklists.single, DateTime(2027, 3, 20)), isTrue);
      final r = (await db.select(db.reminders).get()).single;
      expect(r.assetId, car);
      expect(r.title, s.checklistReminderTitle('Balik kampung'));
      expect(r.dueDate, DateTime(2027, 3, 20));
    });

    test('cannot remind without an asset to keep the reminder on', () async {
      await createChecklist(db, title: 'Senarai', labels: const []);
      final w = await db.loadWorld();
      expect(await remindChecklist(db, s, w, w.checklists.single, DateTime(2027, 3, 20)), isFalse);
    });
  });

  testWidgets('a ready-made list is made from the list page and opened, and its items tick', (tester) async {
    setPhone(tester, height: 1600);
    final en = strFor('en');
    final db = AppDb(NativeDatabase.memory());
    await tester.runAsync(() => db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821'));
    var w = (await tester.runAsync(db.loadWorld))!;
    await tester.pumpWidget(harness(const ChecklistsScreen(), w, db: db));
    await tester.pumpAndSettle();
    expect(find.text(en.checklistsEmpty), findsOneWidget);
    await tester.tap(find.text(en.newChecklist));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.checklistTemplateTitle('tripCar')));
    await tester.pumpAndSettle();
    w = (await tester.runAsync(db.loadWorld))!;
    final list = w.checklists.single;
    expect(list.title, en.checklistTemplateTitle('tripCar'));
    expect(list.assetId, isNotNull, reason: 'kept with the only vehicle');

    await tester.pumpWidget(harness(ChecklistScreen(checklistId: list.id), w, db: db));
    await tester.pumpAndSettle();
    final first = en.checklistTemplateItems('tripCar').first;
    expect(find.text(first), findsOneWidget);
    expect(find.text(en.checkedCount(0, en.checklistTemplateItems('tripCar').length)), findsOneWidget);
    await tester.tap(find.text(first));
    await tester.pumpAndSettle();
    final ticked = (await tester.runAsync(() => db.select(db.checklistItems).get()))!.where((i) => i.checked).toList();
    await tester.runAsync(db.close);
    expect(ticked.single.label, first);
  });
}
