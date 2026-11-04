// Asset cards (0.2.7b, fade changed in 0.2.7d): the photo fills the card and shows at full
// strength on the right and at a quarter under the text; without a photo the card keeps the
// neutral icon.

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
      // Under the full veil, which holds to 55% of the width.
      expect(r.right, lessThanOrEqualTo(card.left + card.width * 0.55), reason: t);
    }
    // The photo fills the card instead of its right half.
    expect(tester.getRect(find.byType(SecureImage)).width, card.width);
    // The car has no photo: its icon, no fade.
    expect(find.byType(AssetAvatar), findsOneWidget);
  });

  testWidgets('text on a photo uses the main colour, and the status sits on its own chip', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const AssetsScreen(), withHousePhoto()));
    await tester.pumpAndSettle();
    final card = find.ancestor(of: find.byType(PhotoFade), matching: find.byType(Card));
    final status = tester.widget<StatusLabel>(find.descendant(of: card, matching: find.byType(StatusLabel)));
    expect(status.boxed, isTrue);
    final inStatus = find.descendant(of: find.byType(StatusLabel), matching: find.byType(Text));
    final plain = find.descendant(of: card, matching: find.byType(Text)).evaluate().where((e) => !inStatus.evaluate().contains(e));
    expect(plain, isNotEmpty);
    for (final e in plain) {
      final color = (e.widget as Text).style?.color;
      expect(color, KukiraColors.light.text, reason: '"${(e.widget as Text).data}" is on the photo');
    }

    // Without a photo nothing changes: the car's status is not boxed.
    final carCard = find.ancestor(of: find.byType(AssetAvatar), matching: find.byType(Card));
    for (final l in tester.widgetList<StatusLabel>(find.descendant(of: carCard, matching: find.byType(StatusLabel)))) {
      expect(l.boxed, isFalse);
    }
  });

  test('the veil holds under the text and thins out to nothing at the right edge', () {
    const card = PhotoFade(photo: 'x', color: Colors.white);
    expect(card.coverAt(0), photoVeil);
    expect(card.coverAt(photoTextWidth), photoVeil, reason: 'all card text is under the full veil');
    expect(card.coverAt(1), 0);
    expect(card.coverAt(0.8), closeTo(photoVeil * (0.2 / 0.45), 1e-9));
    const header = PhotoFade(photo: 'x', color: Colors.white, holdTo: 0.66);
    expect(header.coverAt(0.64), photoVeil, reason: 'the header name ends by 64%');
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
