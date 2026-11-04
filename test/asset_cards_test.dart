// Asset cards (0.2.7b): a photo fades out from the right with the text on the solid part;
// without a photo the card keeps the neutral icon.

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/common.dart';
import 'package:kukira_asset/ui/documents.dart';

import 'helpers.dart';

/// [fakeWorld] with a photo on the house.
World withHousePhoto() {
  final w = fakeWorld(reminders: [fakeReminder(assetId: 1, title: 'Aircond service', due: today().subtract(const Duration(days: 2)))]);
  return World(
    assets: [w.assets[0].copyWith(photoPath: const Value('house.jpg')), w.assets[1]],
    houses: w.houses,
    vehicles: w.vehicles,
    reminders: w.reminders,
    records: w.records,
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

  testWidgets('a photo card shows the photo behind a fade, and keeps its text on the solid part', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const AssetsScreen(), withHousePhoto()));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoFade), findsOneWidget);
    expect(find.byType(SecureImage), findsOneWidget);
    final card = tester.getRect(find.ancestor(of: find.byType(PhotoFade), matching: find.byType(Card)));
    // As wide as the card without a photo, not shrunk to its text.
    expect(card.width, tester.getRect(find.ancestor(of: find.byType(AssetAvatar), matching: find.byType(Card))).width);
    for (final t in ['Setia Alam house', 'Aircond service', s.lateDays(2)]) {
      final r = tester.getRect(find.text(t));
      // The fade still covers at least 94% at 55% of the width.
      expect(r.right, lessThanOrEqualTo(card.left + card.width * 0.55), reason: t);
    }
    // The car has no photo: its icon, no fade.
    expect(find.byType(AssetAvatar), findsOneWidget);
  });

  testWidgets('the fade uses the card colour, so it works in dark mode', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(Theme(data: ThemeData(brightness: Brightness.dark), child: const AssetsScreen()), withHousePhoto()));
    await tester.pumpAndSettle();
    final fade = tester.widget<PhotoFade>(find.byType(PhotoFade));
    expect(fade.color, KukiraColors.dark.surface);
  });

  testWidgets('cards fit a 360 dp phone at 130% text, with and without a photo', (tester) async {
    setPhone(tester);
    await tester.pumpWidget(harness(MediaQuery.withClampedTextScaling(minScaleFactor: 1.3, maxScaleFactor: 1.3, child: const AssetsScreen()), withHousePhoto(), lang: 'ms'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
