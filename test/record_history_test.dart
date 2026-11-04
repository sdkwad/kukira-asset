// The Records tab as a history (0.2.7b): years with counts and totals, items on each record,
// a search that looks inside items, and marking a defect reported from its card.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/common.dart';

import 'helpers.dart';

/// [fakeWorld] (house in its DLP) with car records over two years, one with four items,
/// and an unreported defect on the house.
World history() {
  final w = fakeWorld(vp: today().subtract(const Duration(days: 300)));
  final now = DateTime.now();
  final y = now.year;
  UpkeepRecord rec(int id, int asset, String kind, String title, DateTime d, {double? cost, String? vendor, int? km, String? status}) =>
      UpkeepRecord(id: id, assetId: asset, kind: kind, title: title, date: d, cost: cost, vendorName: vendor, odometer: km, status: status, createdAt: d);
  return World(
    assets: w.assets,
    houses: w.houses,
    vehicles: w.vehicles,
    reminders: const [],
    records: [
      // The defect is id 1, as the first record a test database gets.
      rec(1, 1, 'defect', 'Crack in bedroom wall', DateTime(y, 1, 15), status: 'open'),
      rec(2, 2, 'maintenance', 'Service 40,000 km', DateTime(y, 1, 28), cost: 245.5, vendor: 'Bengkel Ah Seng', km: 40120),
      rec(3, 2, 'maintenance', 'Wipers', DateTime(y, 1, 12), cost: 59),
      rec(4, 2, 'payment', 'Insurance renewal', DateTime(y - 1, 11, 13), cost: 1086.4, vendor: 'Takaful Ikhlas'),
    ],
    odometer: w.odometer,
    vendors: w.vendors,
    documents: w.documents,
    settings: w.settings,
    costItems: {
      2: const [
        CostItem(id: 1, recordId: 2, label: 'Engine oil 0W-20', amount: 150),
        CostItem(id: 2, recordId: 2, label: 'Oil filter', amount: 30),
        CostItem(id: 3, recordId: 2, label: 'Air filter', amount: 40),
        CostItem(id: 4, recordId: 2, label: 'Labour', amount: 25.5),
      ],
    },
  );
}

Future<void> openRecords(WidgetTester tester, int assetId, {AppDb? db}) async {
  await tester.pumpWidget(harness(AssetDetailScreen(assetId: assetId), history(), db: db));
  await tester.pumpAndSettle();
  await tester.tap(find.text(strFor('en').upkeepTab));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  final y = DateTime.now().year;

  testWidgets('records are grouped by year, newest first, with a count and total each', (tester) async {
    setPhone(tester, height: 1800);
    await openRecords(tester, 2);
    expect(find.text(s.yearCount(y, 2)), findsOneWidget);
    expect(find.text(s.rm(304.5)), findsOneWidget);
    expect(find.text(s.yearCount(y - 1, 1)), findsOneWidget);
    expect(tester.getTopLeft(find.text(s.yearCount(y, 2))).dy, lessThan(tester.getTopLeft(find.text(s.yearCount(y - 1, 1))).dy));
    expect(tester.getTopLeft(find.text('Service 40,000 km')).dy, lessThan(tester.getTopLeft(find.text('Wipers')).dy));
  });

  testWidgets('a record lists its items: up to three, or two and how many more', (tester) async {
    setPhone(tester, height: 1800);
    await openRecords(tester, 2);
    expect(find.text('Engine oil 0W-20'), findsOneWidget);
    expect(find.text('Oil filter'), findsOneWidget);
    expect(find.text('Air filter'), findsNothing);
    expect(find.text(s.moreItems(2)), findsOneWidget);
  });

  testWidgets('the search looks inside items, and says when nothing matches', (tester) async {
    setPhone(tester, height: 1800);
    await openRecords(tester, 2);
    await tester.enterText(find.byType(TextField), 'air filter');
    await tester.pumpAndSettle();
    expect(find.text('Service 40,000 km'), findsOneWidget);
    expect(find.text('Wipers'), findsNothing);
    await tester.enterText(find.byType(TextField), 'battery');
    await tester.pumpAndSettle();
    expect(find.text(s.noMatch), findsOneWidget);
  });

  testWidgets('an unreported defect in the DLP can be marked reported from its card', (tester) async {
    setPhone(tester, height: 1800);
    final db = AppDb(NativeDatabase.memory());
    await tester.runAsync(() async {
      final house = await db.createAsset(category: 'house', nickname: 'Setia Alam house', propertyType: 'landed');
      await db.addRecord(RecordsCompanion.insert(assetId: house, kind: 'defect', title: 'Crack in bedroom wall', date: DateTime(y, 1, 15)));
    });
    await openRecords(tester, 1, db: db);
    expect(find.text(s.notReportedYet), findsOneWidget);
    await tester.tap(find.text(s.markReportedShort));
    await tester.pumpAndSettle();
    final r = (await tester.runAsync(() => db.select(db.records).get()))!.single;
    expect(r.reportedToDeveloper, isNotNull);
    expect(r.status, 'in_progress');
    await tester.runAsync(db.close);
  });

  testWidgets('the history fits a 360 dp phone at 130% text', (tester) async {
    setPhone(tester);
    await tester.pumpWidget(harness(MediaQuery.withClampedTextScaling(minScaleFactor: 1.3, maxScaleFactor: 1.3, child: const AssetDetailScreen(assetId: 2)), history(), lang: 'ms'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strFor('ms').upkeepTab));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(RecordCard), findsWidgets);
  });
}
