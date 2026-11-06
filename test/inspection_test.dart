// The room-by-room check (0.3, F4): rooms and things by house, a defect recorded at a tap,
// an undone tap leaving nothing, progress, and the report sent to the developer.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Table, Column;
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/inspection.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/inspection.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/inspection.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('ms');

  group('the rooms', () {
    test('follow the house: bedrooms, bathrooms, and a balcony or the outside', () {
      expect(inspectionRooms(bedrooms: 3, bathrooms: 2, propertyType: 'landed'), ['living', 'kitchen', 'bed1', 'bed2', 'bed3', 'bath1', 'bath2', 'outside']);
      expect(inspectionRooms(bedrooms: 2, bathrooms: 1, propertyType: 'strata').last, 'balcony');
    });

    test('each have the things worth checking there, named in both languages', () {
      expect(roomItems('bath2'), containsAll(['toilet', 'shower', 'sink']));
      expect(roomItems('kitchen'), contains('sink'));
      expect(roomItems('outside'), containsAll(['gate', 'roof', 'drain']));
      for (final lang in ['ms', 'en']) {
        final x = strFor(lang);
        for (final r in inspectionRooms(bedrooms: 1, bathrooms: 1, propertyType: 'landed')..add('balcony')) {
          expect(x.roomName(r), isNot(r), reason: '$lang $r');
          for (final i in roomItems(r)) {
            expect(x.inspectionItemName(i), isNot(i), reason: '$lang $i');
          }
        }
      }
      expect(s.roomName('bed2'), 'Bilik tidur 2');
    });

    test('file a defect under the right category', () {
      expect(defectCategory('walls'), 'wall_crack');
      expect(defectCategory('toilet'), 'plumbing');
      expect(defectCategory('switches'), 'electrical');
      expect(defectCategory('gate'), 'door_window');
    });
  });

  test('progress counts what was checked and what was a defect', () {
    final rooms = ['kitchen'];
    final p = progressOf(rooms, {'kitchen|ceiling': 'ok', 'kitchen|walls': 'defect', 'kitchen|sink': 'na'});
    expect((p.checked, p.total, p.defects), (3, roomItems('kitchen').length, 1));
    expect(p.finished, isFalse);
  });

  test('the report is numbered and grouped by room, with notes', () {
    final text = defectReport(
      heading: 'Senarai kecacatan · Rumah',
      address: 'No. 8, Jalan Setia',
      dateLine: 'Tarikh: 7 Nov 2026',
      defects: const [
        ReportedDefect(title: 'Siling · Dapur', area: 'Dapur', notes: 'retak 30 cm'),
        ReportedDefect(title: 'Pintu · Bilik tidur 1', area: 'Bilik tidur 1'),
        ReportedDefect(title: 'Dinding · Dapur', area: 'Dapur'),
        ReportedDefect(title: 'Pagar', area: null),
      ],
      otherArea: 'Lain-lain',
      footer: 'Dihantar dari Kukira Asset.',
    );
    expect(text, contains('No. 8, Jalan Setia'));
    expect(text, contains('Dapur\n1. Siling · Dapur (retak 30 cm)\n2. Dinding · Dapur\n'));
    expect(text, contains('Bilik tidur 1\n3. Pintu · Bilik tidur 1\n'));
    expect(text, contains('Lain-lain\n4. Pagar\n'));
    expect(text.trim(), endsWith('Dihantar dari Kukira Asset.'));
  });

  group('marking a thing', () {
    late AppDb db;
    late Inspection ins;
    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      final house = await db.createAsset(category: 'house', nickname: 'Rumah', propertyType: 'landed');
      final id = await startInspection(db, house, kind: 'vp', bedrooms: 3, bathrooms: 2);
      ins = (await db.select(db.inspections).get()).singleWhere((x) => x.id == id);
    });
    tearDown(() => db.close());

    test('as a defect records it once, named after the thing and the room', () async {
      await setCheck(db, s, ins, 'kitchen', 'walls', 'defect');
      await setCheck(db, s, ins, 'kitchen', 'walls', 'defect');
      final r = (await db.select(db.records).get()).single;
      expect(r.kind, 'defect');
      expect(r.title, 'Dinding · Dapur');
      expect(r.area, 'Dapur');
      expect(r.category, 'wall_crack');
      expect(r.status, 'open');
      expect((await db.select(db.inspectionChecks).get()).single.recordId, r.id);
    });

    test('back to OK removes a defect nothing was added to, but keeps one with a note', () async {
      await setCheck(db, s, ins, 'kitchen', 'walls', 'defect');
      await setCheck(db, s, ins, 'kitchen', 'walls', 'ok');
      expect(await db.select(db.records).get(), isEmpty);
      expect((await db.select(db.inspectionChecks).get()).single.result, 'ok');

      await setCheck(db, s, ins, 'bath1', 'toilet', 'defect');
      final r = (await db.select(db.records).get()).single;
      await db.updateRecord(r.id, const RecordsCompanion(notes: Value('bocor di bawah')));
      await setCheck(db, s, ins, 'bath1', 'toilet', 'na');
      expect((await db.select(db.records).get()).single.notes, 'bocor di bawah', reason: 'the owner worked on it');
    });
  });

  testWidgets('the check lists the rooms, and a tap on Cacat records the defect', (tester) async {
    setPhone(tester, height: 2400);
    final db = AppDb(NativeDatabase.memory());
    final id = (await tester.runAsync(() async {
      final house = await db.createAsset(category: 'house', nickname: 'Rumah', propertyType: 'landed');
      return startInspection(db, house, kind: 'vp', bedrooms: 2, bathrooms: 1);
    }))!;
    final w = (await tester.runAsync(db.loadWorld))!;
    await tester.pumpWidget(harness(InspectionScreen(inspectionId: id), w, db: db, lang: 'ms'));
    await tester.pumpAndSettle();
    expect(find.text(s.inspectionKindName('vp')), findsOneWidget);
    expect(find.text(s.roomName('living')), findsOneWidget);
    expect(find.text(s.inspectionProgress(0, progressOf(inspectionRooms(bedrooms: 2, bathrooms: 1, propertyType: 'landed'), const {}).total, 0)), findsOneWidget);

    await tester.tap(find.descendant(of: find.byKey(const ValueKey('check-living-ceiling')), matching: find.text(s.resultDefect)));
    await tester.pumpAndSettle();
    final r = (await tester.runAsync(() => db.select(db.records).get()))!;
    await tester.runAsync(db.close);
    expect(r.single.title, 'Siling · Ruang tamu');
  });

  testWidgets('the defects tab offers a room check, and sending the list once there are defects', (tester) async {
    setPhone(tester, height: 2400);
    final en = strFor('en');
    final w = fakeWorld();
    final withDefect = World(
      assets: w.assets,
      houses: w.houses,
      vehicles: w.vehicles,
      reminders: w.reminders,
      records: [
        UpkeepRecord(id: 1, assetId: 1, kind: 'defect', title: 'Wall crack', date: DateTime(2026, 10, 1), area: 'Kitchen', status: 'open', createdAt: DateTime(2026, 10, 1)),
        // A second kind, so the Records tab shows its kind filter.
        UpkeepRecord(id: 2, assetId: 1, kind: 'maintenance', title: 'Aircond service', date: DateTime(2026, 9, 1), createdAt: DateTime(2026, 9, 1)),
      ],
      odometer: w.odometer,
      vendors: w.vendors,
      documents: w.documents,
      settings: w.settings,
      costItems: w.costItems,
    );
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), withDefect));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.upkeepTab));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, en.kindName('defect')));
    await tester.pumpAndSettle();
    expect(find.text(en.startInspection), findsOneWidget);
    final send = find.text(en.sendDefects);
    await tester.scrollUntilVisible(send, 200, scrollable: find.byType(Scrollable).last);
    expect(send, findsOneWidget);

    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text(en.sendDefectsBody(1)), findsOneWidget, reason: 'it says the text and photos leave the phone');
  });
}
