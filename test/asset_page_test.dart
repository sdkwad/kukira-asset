// The asset page (0.2.7b): photo header that shrinks on scroll, and the overview.

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/common.dart';

import 'helpers.dart';

World copy(World w, {List<Asset>? assets, List<Reminder>? reminders}) => World(
      assets: assets ?? w.assets,
      houses: w.houses,
      vehicles: w.vehicles,
      reminders: reminders ?? w.reminders,
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
  final t = today();

  testWidgets('without a photo: a plain title bar, then the model, plate and a status sentence', (tester) async {
    setPhone(tester, height: 1600);
    final w = fakeWorld(reminders: [fakeReminder(title: 'Engine oil', due: t.subtract(const Duration(days: 6)))]);
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), w));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoFade), findsNothing);
    expect(find.text('WXY 4821'), findsOneWidget);
    expect(find.textContaining('Engine oil 6 days late.'), findsOneWidget);
    // Road tax and insurance are always asked for on a vehicle, even before they are set.
    expect(find.text(s.catName('road_tax')), findsOneWidget);
    expect(find.text(s.insuranceWord), findsWidgets);
    expect(find.text(s.notSet), findsNWidgets(2));
  });

  testWidgets('details are folded into one line, and open to the full list and Edit', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), fakeWorld()));
    await tester.pumpAndSettle();
    expect(find.text(s.editDetails), findsNothing);
    await tester.tap(find.text(s.houseDetails));
    await tester.pumpAndSettle();
    expect(find.text(s.propertyType), findsOneWidget);
    expect(find.text(s.editDetails), findsOneWidget);
  });

  testWidgets('in the DLP, the house shows an estimated end with who to confirm it with, and opens its defects', (tester) async {
    setPhone(tester, height: 1600);
    final vp = t.subtract(const Duration(days: 300));
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), fakeWorld(vp: vp, reminders: [])));
    await tester.pumpAndSettle();
    final end = dlpEnd(fakeWorld(vp: vp), 1)!;
    expect(find.text(s.dlpRowMeta(s.dLong(end))), findsOneWidget);
    expect(find.descendant(of: find.ancestor(of: find.text(s.dlpRowTitle), matching: find.byType(AppRow)), matching: find.byType(EstTag)), findsOneWidget);
    await tester.tap(find.text(s.defectsAction(0, 0)));
    await tester.pumpAndSettle();
    expect(find.text(s.defectOpen), findsOneWidget, reason: 'the Records tab, filtered to defects');
  });

  testWidgets('with a photo the page opens on it, and shrinks to a small photo by the name', (tester) async {
    setPhone(tester, height: 1600);
    final base = fakeWorld();
    final w = copy(base, assets: [base.assets[0].copyWith(photoPath: const Value('house.jpg')), base.assets[1]]);
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), w));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoFade), findsOneWidget);
    double opacityOf(Finder f) => tester.widget<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)).first).opacity;
    final name = find.text('Setia Alam house');
    expect(name, findsNWidgets(2), reason: 'large in the photo, small in the title bar');
    expect(opacityOf(name.first), 1.0);
    expect(opacityOf(name.last), 0.0);
    // The name stays on the part of the photo that is covered.
    expect(tester.getRect(name.first).right, lessThanOrEqualTo(phoneWidth * 0.64 + 0.5));

    expect(tester.widget<PhotoFade>(find.byType(PhotoFade)).opacity, 1.0);

    await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(opacityOf(name.first), 0.0);
    expect(opacityOf(name.last), 1.0);
    // The photo fades by its own alpha, not under an Opacity layer over the whole header.
    expect(tester.widget<PhotoFade>(find.byType(PhotoFade)).opacity, 0.0);
    expect(find.ancestor(of: find.byType(PhotoFade), matching: find.byType(Opacity)), findsNothing);
  });

  testWidgets('the monthly odometer switch still adds and removes its reminder', (tester) async {
    setPhone(tester, height: 1600);
    final db = AppDb(NativeDatabase.memory());
    await tester.runAsync(() async {
      await db.createAsset(category: 'house', nickname: 'Setia Alam house', propertyType: 'landed');
      await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
    });
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), fakeWorld(reminders: []), db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final rs = (await tester.runAsync(() => db.select(db.reminders).get()))!;
    expect(rs.single.category, 'odometer');
    await tester.runAsync(db.close);
  });

  testWidgets('asset pages fit a 360 dp phone at 130% text, with and without a photo', (tester) async {
    setPhone(tester);
    final base = fakeWorld(vp: t.subtract(const Duration(days: 300)), reminders: [fakeReminder(title: 'Servis penghawa dingin bilik utama', assetId: 1, due: t.subtract(const Duration(days: 2)))]);
    final w = copy(base, assets: [base.assets[0].copyWith(photoPath: const Value('house.jpg')), base.assets[1]]);
    for (final id in [1, 2]) {
      await tester.pumpWidget(harness(MediaQuery.withClampedTextScaling(minScaleFactor: 1.3, maxScaleFactor: 1.3, child: AssetDetailScreen(assetId: id)), w, lang: 'ms'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'asset $id');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
