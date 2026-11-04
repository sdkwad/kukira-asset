// Renewing road tax and insurance (0.2.7e): the suggested period, what one save changes,
// that a failed save changes nothing, and the screens that lead to it.

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/auto_sync.dart';
import 'package:kukira_asset/domain/renewal.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/files.dart';
import 'package:kukira_asset/services/renewal.dart';
import 'package:kukira_asset/ui/add_actions.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/common.dart';
import 'package:kukira_asset/ui/renew.dart';

import 'helpers.dart';

World withCar(World w, VehicleProfile v, {List<Reminder>? reminders, List<UpkeepRecord> records = const []}) => World(
      assets: w.assets,
      houses: w.houses,
      vehicles: {2: v},
      reminders: reminders ?? w.reminders,
      records: records,
      odometer: w.odometer,
      vendors: w.vendors,
      documents: w.documents,
      settings: w.settings,
      costItems: w.costItems,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  final t = today();

  group('the suggested period', () {
    test('a cover ends the day before the same date a period later, at month ends too', () {
      expect(coverEnd(DateTime(2026, 11, 13), 12), DateTime(2027, 11, 12));
      expect(coverEnd(DateTime(2026, 11, 13), 6), DateTime(2027, 5, 12));
      expect(coverEnd(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28), reason: 'February is too short for the 31st: to its last day');
      expect(coverEnd(DateTime(2028, 2, 29), 12), DateTime(2029, 2, 28));
      expect(coverEnd(DateTime(2027, 3, 1), 12), DateTime(2028, 2, 29));
      expect(coverMonths(DateTime(2025, 11, 13), DateTime(2026, 11, 12)), 12);
      expect(coverMonths(DateTime(2026, 5, 13), DateTime(2026, 11, 12)), 6);
      expect(coverMonths(DateTime(2026, 1, 1), DateTime(2026, 1, 3)), 1);
    });

    test('follows on from the old end, at the length of the last period', () {
      final sg = suggestRenewal(currentEnd: DateTime(2026, 11, 12), lastStart: DateTime(2026, 5, 13), today: DateTime(2026, 11, 3));
      expect(sg.months, 6);
      expect(sg.fromHistory, isTrue);
      expect(sg.start, DateTime(2026, 11, 13));
      expect(sg.end, DateTime(2027, 5, 12));
    });

    test('with no period on record it suggests 12 months; long lapsed, from today', () {
      final fresh = suggestRenewal(currentEnd: DateTime(2026, 11, 12), lastStart: null, today: DateTime(2026, 11, 3));
      expect((fresh.months, fresh.fromHistory, fresh.start), (12, false, DateTime(2026, 11, 13)));
      final lapsed = suggestRenewal(currentEnd: DateTime(2026, 6, 1), lastStart: null, today: DateTime(2026, 11, 3));
      expect(lapsed.start, DateTime(2026, 11, 3));
      expect(lapsed.end, DateTime(2027, 11, 2));
      final justLapsed = suggestRenewal(currentEnd: DateTime(2026, 10, 20), lastStart: null, today: DateTime(2026, 11, 3));
      expect(justLapsed.start, DateTime(2026, 10, 21), reason: 'two weeks late still follows on');
      final never = suggestRenewal(currentEnd: null, lastStart: null, today: DateTime(2026, 11, 3));
      expect(never.start, DateTime(2026, 11, 3));
    });

    test('road tax and insurance are offered together only when they end close together', () {
      expect(renewTogether(DateTime(2026, 11, 12), DateTime(2026, 11, 12)), isTrue);
      expect(renewTogether(DateTime(2026, 11, 12), DateTime(2026, 12, 10)), isTrue);
      expect(renewTogether(DateTime(2026, 11, 12), DateTime(2027, 3, 1)), isFalse);
      expect(renewTogether(null, DateTime(2026, 11, 12)), isFalse);
    });
  });

  group('saving', () {
    late Directory root;
    late AppDb db;
    late int car;
    final end = DateTime(2026, 11, 12);
    setUp(() async {
      root = await useTempStorage();
      SecureFiles.reset();
      db = AppDb(NativeDatabase.memory());
      car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
      await db.updateVehicle(car, VehicleProfilesCompanion(roadTaxExpiry: Value(end), insuranceExpiry: Value(end), insuranceProvider: const Value('Etiqa')));
      await db.addReminder(RemindersCompanion.insert(
        assetId: car,
        title: 'Road tax renewal',
        ruleType: 'fixed',
        category: const Value('road_tax'),
        dueDate: Value(end),
        autoSource: const Value(autoRoadTax),
        done: const Value(true),
      ));
    });
    tearDown(() => db.close());

    List<File> stored() => Directory('${root.path}/support/files').existsSync()
        ? Directory('${root.path}/support/files').listSync().whereType<File>().where((f) => f.path.endsWith('.enc')).toList()
        : <File>[];

    test('one save keeps the period, moves the date and its reminder, and files the proof', () async {
      final w = await db.loadWorld();
      final msgs = await applyRenewal(db, s, w, car, [
        RenewInput(kind: RenewKind.roadTax, start: DateTime(2026, 11, 13), end: DateTime(2027, 11, 12), cost: 90, proof: (Uint8List.fromList([1, 2, 3]), 'pdf')),
      ], today: DateTime(2026, 11, 3));
      expect(msgs.single, s.renewedUntil(s.catName('road_tax'), s.dLong(DateTime(2027, 11, 12))));

      final after = await db.loadWorld();
      expect(after.vehicles[car]!.roadTaxExpiry, DateTime(2027, 11, 12));
      expect(after.vehicles[car]!.insuranceExpiry, end, reason: 'only road tax was renewed');
      final rec = after.records.single;
      expect((rec.kind, rec.category, rec.cost), ('payment', 'road_tax', 90.0));
      expect((rec.coverStart, rec.coverEnd), (DateTime(2026, 11, 13), DateTime(2027, 11, 12)));
      final r = after.reminders.single;
      expect(r.dueDate, DateTime(2027, 11, 12));
      expect(r.done, isFalse, reason: 'reopened: renewing is the reason to move it');
      expect(r.lastCompleted, DateTime(2026, 11, 3));
      final doc = after.documents.single;
      expect((doc.linkedRecordId, doc.expiry, doc.docType), (rec.id, DateTime(2027, 11, 12), 'receipt'));
      expect(stored(), hasLength(1));
      expect(currentCoverRecord(after, car, RenewKind.roadTax)?.id, rec.id, reason: 'the new period is the current one');
    });

    test('both at once, each with its own dates and the insurer', () async {
      final w = await db.loadWorld();
      await applyRenewal(db, s, w, car, [
        RenewInput(kind: RenewKind.roadTax, start: DateTime(2026, 11, 13), end: DateTime(2027, 11, 12)),
        RenewInput(kind: RenewKind.insurance, start: DateTime(2026, 11, 13), end: DateTime(2027, 5, 12), cost: 1086.4, insurer: ' Takaful Ikhlas '),
      ], today: DateTime(2026, 11, 3));
      final after = await db.loadWorld();
      expect(after.vehicles[car]!.insuranceExpiry, DateTime(2027, 5, 12));
      expect(after.vehicles[car]!.insuranceProvider, 'Takaful Ikhlas');
      expect(after.records, hasLength(2));
      expect(after.reminders.where((r) => r.autoSource == autoInsurance).single.dueDate, DateTime(2027, 5, 12),
          reason: 'insurance had no reminder yet, so one is made for the new end');
    });

    test('a save that fails changes nothing and leaves no file behind', () async {
      final w = await db.loadWorld();
      // A vehicle the database does not have: its proof is written, then the record cannot be added.
      final ghost = World(
        assets: w.assets,
        houses: w.houses,
        vehicles: {99: VehicleProfile(assetId: 99, vehicleType: 'car', plate: 'X', roadTaxExpiry: end)},
        reminders: w.reminders,
        records: w.records,
        odometer: w.odometer,
        vendors: w.vendors,
        documents: w.documents,
        settings: w.settings,
        costItems: w.costItems,
      );
      await expectLater(
        applyRenewal(db, s, ghost, 99, [
          RenewInput(kind: RenewKind.roadTax, start: DateTime(2026, 11, 13), end: DateTime(2027, 11, 12), proof: (Uint8List.fromList([9]), 'jpg')),
        ], today: DateTime(2026, 11, 3)),
        throwsA(anything),
      );
      final after = await db.loadWorld();
      expect(after.records, isEmpty);
      expect(after.documents, isEmpty);
      expect(after.vehicles[car]!.roadTaxExpiry, end);
      expect(stored(), isEmpty);
    });

    test('an end before the start is refused before anything is written', () async {
      final w = await db.loadWorld();
      await expectLater(
        applyRenewal(db, s, w, car, [RenewInput(kind: RenewKind.roadTax, start: DateTime(2026, 11, 13), end: DateTime(2026, 11, 1))], today: t),
        throwsArgumentError,
      );
      expect((await db.loadWorld()).records, isEmpty);
    });
  });

  group('screens', () {
    final soon = t.add(const Duration(days: 9));
    final car = VehicleProfile(assetId: 2, vehicleType: 'car', plate: 'WXY 4821', roadTaxExpiry: soon, insuranceExpiry: soon, insuranceProvider: 'Etiqa');
    final rt = fakeReminder(id: 1, assetId: 2, title: 'Road tax renewal', due: soon, autoSource: autoRoadTax);
    final ins = fakeReminder(id: 2, assetId: 2, title: 'Insurance renewal', due: soon, autoSource: autoInsurance);

    testWidgets('the form follows on from the old end, and the length moves the end', (tester) async {
      setPhone(tester, height: 2000);
      await tester.pumpWidget(harness(const RenewScreen(assetId: 2, kind: RenewKind.roadTax), withCar(fakeWorld(), car, reminders: [rt, ins])));
      await tester.pumpAndSettle();
      final start = DateTime(soon.year, soon.month, soon.day + 1);
      expect(find.text(s.dLong(start)), findsOneWidget);
      expect(find.text(s.dLong(coverEnd(start, 12))), findsOneWidget);
      expect(find.text(s.saveEndsOn(s.dLong(coverEnd(start, 12)))), findsOneWidget);
      await tester.tap(find.text(s.monthsCount(6)));
      await tester.pumpAndSettle();
      expect(find.text(s.dLong(coverEnd(start, 6))), findsOneWidget);
      expect(find.text(s.renewReplacesEnd(s.dLong(soon))), findsOneWidget, reason: 'no period on record yet: the old end is replaced');

      // Insurance ends the same day: it can be renewed at the same time, with its own dates.
      expect(find.text(s.renewAlsoQ(s.insuranceWord)), findsOneWidget);
      expect(find.widgetWithText(TextField, s.insurer), findsNothing);
      await tester.tap(find.text(s.renewAlsoQ(s.insuranceWord)));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, s.insurer), findsOneWidget);
      expect(find.text(s.monthsCount(12)), findsNWidgets(2));
    });

    testWidgets('saving closes the form and says until when', (tester) async {
      setPhone(tester, height: 2000);
      final db = AppDb(NativeDatabase.memory());
      final id = (await tester.runAsync(() async {
        final id = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
        await db.updateVehicle(id, VehicleProfilesCompanion(roadTaxExpiry: Value(soon)));
        return id;
      }))!;
      final w = (await tester.runAsync(db.loadWorld))!;
      await tester.pumpWidget(harness(
        Builder(
          builder: (c) => TextButton(onPressed: () => openRenewal(c, id, RenewKind.roadTax), child: const Text('open')),
        ),
        w,
        db: db,
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, s.costOptional), '90');
      final start = DateTime(soon.year, soon.month, soon.day + 1);
      await tester.tap(find.text(s.saveEndsOn(s.dLong(coverEnd(start, 12)))));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget, reason: 'the form closed');
      final rec = (await tester.runAsync(() => db.select(db.records).getSingle()))!;
      await tester.runAsync(db.close);
      expect(rec.cost, 90);
      expect(rec.coverStart, start);
    });

    testWidgets('a cost that is not a number is caught before saving', (tester) async {
      setPhone(tester, height: 2000);
      await tester.pumpWidget(harness(const RenewScreen(assetId: 2, kind: RenewKind.roadTax), withCar(fakeWorld(), car)));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, s.costOptional), '9o');
      await tester.tap(find.text(s.saveEndsOn(s.dLong(coverEnd(DateTime(soon.year, soon.month, soon.day + 1), 12)))));
      await tester.pumpAndSettle();
      expect(find.text(s.costInvalid), findsOneWidget);
      expect(find.byType(RenewScreen), findsOneWidget);
    });

    testWidgets('the asset page offers Renew on road tax and insurance once they are near', (tester) async {
      setPhone(tester, height: 2000);
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), withCar(fakeWorld(), car, reminders: [rt, ins])));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, s.renew), findsNWidgets(2));
      await tester.tap(find.widgetWithText(FilledButton, s.renew).first);
      await tester.pumpAndSettle();
      expect(find.byType(RenewScreen), findsOneWidget);

      final far = car.copyWith(roadTaxExpiry: Value(t.add(const Duration(days: 200))), insuranceExpiry: Value(t.add(const Duration(days: 200))));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), withCar(fakeWorld(), far, reminders: const [])));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, s.renew), findsNothing, reason: 'months away: it waits in the reminder');
    });

    testWidgets('a road tax reminder renews, and can still be only marked done', (tester) async {
      setPhone(tester, height: 2000);
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), withCar(fakeWorld(), car, reminders: [rt])));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.catName('road_tax')));
      await tester.pumpAndSettle();
      expect(find.text(s.markDoneOnly), findsOneWidget);
      expect(find.text(s.markDone), findsNothing);
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(s.renew)));
      await tester.pumpAndSettle();
      expect(find.byType(RenewScreen), findsOneWidget);
    });

    testWidgets('Tambah shows road tax and insurance ending together as one renewal', (tester) async {
      setPhone(tester, height: 1600);
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), withCar(fakeWorld(), car, reminders: [rt, ins])));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text(s.renewBoth), findsOneWidget);
      expect(find.text(s.renewRoadTax), findsNothing);
      expect(find.textContaining(s.bothEndOn(s.dShort(soon))), findsOneWidget);
      await tester.tap(find.text(s.renewBoth));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, s.insurer), findsOneWidget, reason: 'opened with both');
    });

    test('suggestion rows pair road tax with insurance only when they end together', () {
      final w = withCar(fakeWorld(), car, reminders: [rt, ins]);
      expect(suggestionRows(w, [rt, ins]).single.$2?.id, 2);
      final apart = withCar(fakeWorld(), car.copyWith(insuranceExpiry: Value(t.add(const Duration(days: 120)))), reminders: [rt, ins]);
      expect(suggestionRows(apart, [rt, ins]).length, 2);
    });

    testWidgets('the form fits a 360 dp phone at 130% text with both covers open', (tester) async {
      setPhone(tester, height: 2600);
      await tester.pumpWidget(harness(
        MediaQuery.withClampedTextScaling(minScaleFactor: 1.3, maxScaleFactor: 1.3, child: const RenewScreen(assetId: 2, kind: RenewKind.insurance, both: true)),
        withCar(fakeWorld(), car, reminders: [rt, ins]),
        lang: 'ms',
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
