// An asset page always has the same four tabs. Defects are records: listed under Records
// with a filter, reached from the overview while the DLP runs, and still there after it ends.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/assets.dart';

import 'helpers.dart';

/// [fakeWorld] with a defect and a repair on the house.
World withHouseRecords({DateTime? vp}) {
  final w = fakeWorld(vp: vp);
  final t = DateTime.now();
  return World(
    assets: w.assets,
    houses: w.houses,
    vehicles: w.vehicles,
    reminders: w.reminders,
    records: [
      UpkeepRecord(id: 1, assetId: 1, kind: 'defect', title: 'Crack in bedroom wall', date: t, area: 'Bedroom 2', status: 'open', createdAt: t),
      UpkeepRecord(id: 2, assetId: 1, kind: 'maintenance', category: 'plumbing', title: 'Kitchen pipe', date: t, cost: 180, createdAt: t),
    ],
    odometer: w.odometer,
    vendors: w.vendors,
    documents: w.documents,
    settings: w.settings,
    costItems: w.costItems,
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  final inDlp = DateTime.now().subtract(const Duration(days: 300));
  final dlpOver = DateTime.now().subtract(const Duration(days: 3 * 365));

  List<String> tabLabels(WidgetTester tester) => tester.widgetList<Tab>(find.byType(Tab)).map((t) => t.text!).toList();

  testWidgets('every asset has the same four tabs, during the DLP and after it', (tester) async {
    setPhone(tester);
    final four = [s.overviewTab, s.upkeepTab, s.remindersTab, s.documentsTab];
    for (final (id, w) in [(1, withHouseRecords(vp: inDlp)), (1, withHouseRecords(vp: dlpOver)), (1, fakeWorld()), (2, fakeWorld())]) {
      await tester.pumpWidget(harness(AssetDetailScreen(assetId: id), w));
      await tester.pumpAndSettle();
      expect(tabLabels(tester), four);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Records lists defects with the rest, and filters by kind', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), withHouseRecords(vp: inDlp)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.upkeepTab));
    await tester.pumpAndSettle();
    expect(find.text('Crack in bedroom wall'), findsOneWidget);
    expect(find.text('Kitchen pipe'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, s.kindName('maintenance')));
    await tester.pumpAndSettle();
    expect(find.text('Crack in bedroom wall'), findsNothing);
    expect(find.text('Kitchen pipe'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, s.kindName('defect')));
    await tester.pumpAndSettle();
    expect(find.text('Kitchen pipe'), findsNothing);
    expect(find.text(s.defectOpen), findsOneWidget, reason: 'defects are grouped by repair status');
    expect(find.text('Crack in bedroom wall'), findsOneWidget);
    expect(find.text(s.addDefect), findsOneWidget);
  });

  testWidgets('the overview opens the defect list while the DLP runs', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), withHouseRecords(vp: inDlp)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.openDefectList(1)));
    await tester.pumpAndSettle();
    expect(find.text(s.defectOpen), findsOneWidget);
    expect(find.text('Crack in bedroom wall'), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, s.kindName('defect')));
    expect(chip.selected, isTrue);
  });

  testWidgets('after the DLP ends, defects are still listed under Records', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), withHouseRecords(vp: dlpOver)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.upkeepTab));
    await tester.pumpAndSettle();
    expect(find.text('Crack in bedroom wall'), findsOneWidget);
  });
}
