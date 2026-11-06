// The house form asks only what applies (0.2.7c): the VP and DLP dates for a subsale only
// while the developer's DLP still runs, optional fields behind "+", and the tenancy only
// when the house is rented out.

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/assets.dart';

import 'helpers.dart';

World withHouse(World w, HouseProfile h) => World(
      assets: w.assets,
      houses: {1: h},
      vehicles: w.vehicles,
      reminders: w.reminders,
      records: w.records,
      odometer: w.odometer,
      vendors: w.vendors,
      documents: w.documents,
      settings: w.settings,
      costItems: w.costItems,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  // TextButton.icon is a subclass, which find.byType does not match.
  Finder button(String label) => find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

  Future<void> open(WidgetTester tester, HouseProfile h) async {
    setPhone(tester, height: 3200);
    await tester.pumpWidget(harness(const HouseEditScreen(assetId: 1), withHouse(fakeWorld(), h)));
    await tester.pumpAndSettle();
  }

  testWidgets('a house bought from the developer asks for the VP date, with no DLP question', (tester) async {
    await open(tester, const HouseProfile(assetId: 1, propertyType: 'landed', source: 'new_from_developer'));
    expect(find.text(s.vpDate), findsOneWidget);
    expect(find.text(s.stillInDlpQ), findsNothing);
  });

  testWidgets('a subsale with a VP date starts inside the DLP', (tester) async {
    await open(tester, HouseProfile(assetId: 1, propertyType: 'landed', source: 'subsale', vpDate: DateTime(2025, 6, 1)));
    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, s.stillInDlpQ)).value, isTrue);
    expect(find.text(s.vpDateSubsale), findsOneWidget);
    await tester.tap(find.text(s.stillInDlpQ));
    await tester.pumpAndSettle();
    expect(find.text(s.vpDateSubsale), findsNothing);
    expect(find.text(s.dlpEndOverrideLabel), findsNothing);
  });

  testWidgets('optional fields wait behind their + button until they are needed', (tester) async {
    await open(tester, const HouseProfile(assetId: 1, propertyType: 'landed', address: 'No. 8, Jalan Setia'));
    expect(find.widgetWithText(TextField, s.address), findsOneWidget, reason: 'it has a value, so it is shown');
    expect(button(s.address), findsNothing);
    expect(button(s.spaShort), findsOneWidget);
    expect(find.text(s.spaDate), findsNothing);
    expect(find.widgetWithText(TextField, s.contact), findsNothing);

    await tester.tap(button(s.contactShort));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, s.contact), findsOneWidget);
    await tester.tap(button(s.spaShort));
    await tester.pumpAndSettle();
    expect(find.text(s.spaDate), findsOneWidget);
  });

  testWidgets('the tenancy is asked only while the house is rented out, and says it is for reference', (tester) async {
    await open(tester, const HouseProfile(assetId: 1, propertyType: 'landed', occupancy: 'owner'));
    expect(find.text(s.tenancyStart), findsNothing);
    await tester.tap(find.text(s.occupancyName('rented')));
    await tester.pumpAndSettle();
    expect(find.text(s.tenancyStart), findsOneWidget);
    expect(find.text(s.tenancyEnd), findsOneWidget);
    expect(find.text(s.rentDue), findsOneWidget);
    expect(find.text(s.tenancyNote), findsOneWidget);
    await tester.tap(find.text(s.occupancyName('vacant')));
    await tester.pumpAndSettle();
    expect(find.text(s.tenancyStart), findsNothing);
  });

  testWidgets('the rent day is picked from a grid of days, and can be cleared', (tester) async {
    await open(tester, const HouseProfile(assetId: 1, propertyType: 'landed', occupancy: 'rented'));
    expect(find.text(s.notSet), findsOneWidget);
    await tester.tap(find.byType(DayOfMonthField));
    await tester.pumpAndSettle();
    expect(find.text('31'), findsOneWidget);
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    expect(find.text(s.rentDueDay(12)), findsOneWidget);

    await tester.tap(find.byType(DayOfMonthField));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.clear));
    await tester.pumpAndSettle();
    expect(find.text(s.notSet), findsOneWidget);
  });

  testWidgets('saving a subsale past the DLP clears its VP date, and keeps the tenancy when no longer rented', (tester) async {
    setPhone(tester, height: 3200);
    final db = AppDb(NativeDatabase.memory());
    final start = DateTime(2026, 3, 1);
    final id = (await tester.runAsync(() async {
      final id = await db.createAsset(category: 'house', nickname: 'Rumah Seksyen 7', propertyType: 'landed');
      await db.updateHouse(id, HouseProfilesCompanion(
        source: const Value('subsale'),
        vpDate: Value(DateTime(2019, 5, 1)),
        occupancy: const Value('rented'),
        tenancyStart: Value(start),
        rentDueDay: const Value(5),
      ));
      return id;
    }))!;
    final w = (await tester.runAsync(db.loadWorld))!;
    await tester.pumpWidget(harness(
      Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => HouseEditScreen(assetId: id))),
          child: const Text('open'),
        ),
      ),
      w,
      db: db,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(s.rentDueDay(5)), findsOneWidget);

    await tester.tap(find.text(s.stillInDlpQ));
    await tester.tap(find.text(s.occupancyName('owner')));
    await tester.pumpAndSettle();
    final save = find.text(s.saveChanges);
    await tester.scrollUntilVisible(save, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget, reason: 'the form closed after saving');

    final h = (await tester.runAsync(() => (db.select(db.houseProfiles)..where((t) => t.assetId.equals(id))).getSingle()))!;
    await tester.runAsync(db.close);
    expect(h.vpDate, isNull);
    expect(h.dlpEndOverride, isNull);
    expect(h.occupancy, 'owner');
    expect(h.tenancyStart, start);
    expect(h.rentDueDay, 5);
  });

  testWidgets('the details show the tenancy while the house is rented out', (tester) async {
    setPhone(tester, height: 2400);
    final h = HouseProfile(
      assetId: 1,
      propertyType: 'landed',
      occupancy: 'rented',
      tenancyStart: DateTime(2026, 3, 1),
      tenancyEnd: DateTime(2027, 2, 28),
      rentDueDay: 5,
    );
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), withHouse(fakeWorld(), h)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.houseDetails));
    await tester.pumpAndSettle();
    expect(find.text(s.tenancyPeriod(s.dLong(DateTime(2026, 3, 1)), s.dLong(DateTime(2027, 2, 28)))), findsOneWidget);
    expect(find.text(s.rentDueDay(5)), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), withHouse(fakeWorld(), h.copyWith(occupancy: const Value('owner')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.houseDetails));
    await tester.pumpAndSettle();
    expect(find.text(s.rentDueDay(5)), findsNothing);
  });

  test('the rent day reads naturally in both languages', () {
    expect(s.rentDueDay(1), 'Monthly, on the 1st');
    expect(s.rentDueDay(2), 'Monthly, on the 2nd');
    expect(s.rentDueDay(3), 'Monthly, on the 3rd');
    expect(s.rentDueDay(11), 'Monthly, on the 11th');
    expect(s.rentDueDay(22), 'Monthly, on the 22nd');
    expect(strFor('ms').rentDueDay(5), 'Setiap 5 haribulan');
    expect(s.tenancyPeriod(null, '28 Feb 2027'), 'Ends 28 Feb 2027');
  });

  testWidgets('the house form fits a 360 dp phone at 130% text, every section open', (tester) async {
    setPhone(tester, height: 3600);
    final h = HouseProfile(assetId: 1, propertyType: 'strata', source: 'subsale', vpDate: DateTime(2025, 6, 1), occupancy: 'rented', state: 'Selangor', council: 'MBSA');
    await tester.pumpWidget(harness(
      MediaQuery.withClampedTextScaling(minScaleFactor: 1.3, maxScaleFactor: 1.3, child: const HouseEditScreen(assetId: 1)),
      withHouse(fakeWorld(), h),
      lang: 'ms',
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
