// Septic tank desludging by IWK (0.3, F2): a landed house with its own tank gets an estimated
// preset, every 24 months inside a PBT area and 36 months outside.

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/presets.dart';
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

  group('the preset', () {
    List<String> keys(String p, {bool septic = false, bool? pbt}) => templatesFor('house', p, septicTank: septic, insidePbt: pbt).map((x) => x.key).toList();

    test('is offered only to a house with its own septic tank, never to a condo', () {
      expect(keys('landed'), isNot(contains('desludging')));
      expect(keys('landed', septic: true), contains('desludging'));
      expect(keys('strata_landed', septic: true), contains('desludging'));
      expect(keys('strata', septic: true), isNot(anyOf(contains('desludging'), contains('desludgingRural'))));
    });

    test('repeats every 2 years inside a PBT area and every 3 years outside, as an estimate', () {
      expect(desludgingFor(true).repeatMonths, 24);
      expect(desludgingFor(null).repeatMonths, 24, reason: 'most houses with a tank are in a PBT area');
      expect(desludgingFor(false).repeatMonths, 36);
      for (final p in [desludging, desludgingRural]) {
        expect(p.estimated, isTrue);
        expect(p.repeatFrom, 'completion', reason: 'counted from the last desludging');
        expect(p.category, 'septic');
        expect(presetByKey(p.key), p);
      }
    });

    test('says who to confirm with, in both languages', () {
      for (final lang in ['ms', 'en']) {
        final s = strFor(lang);
        for (final p in [desludging, desludgingRural]) {
          expect(p.title(s), isNot(p.key));
          expect(p.hint(s), isNotEmpty);
          expect(p.note(s), contains('24'));
          expect(p.confirm(s), contains('IWK'));
        }
        expect(s.catName('septic'), isNot('septic'));
      }
    });
  });

  group('house details', () {
    final s = strFor('en');

    testWidgets('ask about a septic tank, and then about the PBT area', (tester) async {
      setPhone(tester, height: 3200);
      await tester.pumpWidget(harness(const HouseEditScreen(assetId: 1), fakeWorld(ptype: 'landed')));
      await tester.pumpAndSettle();
      expect(find.text(s.septicQ), findsOneWidget);
      expect(find.text(s.insidePbtQ), findsNothing);
      expect(find.text(s.presetTitle('desludging')), findsNothing);

      await tester.tap(find.text(s.septicQ));
      await tester.pumpAndSettle();
      expect(find.text(s.insidePbtQ), findsOneWidget);
      expect(find.text(s.presetTitle('desludging')), findsOneWidget, reason: 'the preset is suggested at once');
    });

    testWidgets('do not ask a condo owner', (tester) async {
      setPhone(tester, height: 3200);
      await tester.pumpWidget(harness(const HouseEditScreen(assetId: 1), fakeWorld(ptype: 'strata')));
      await tester.pumpAndSettle();
      expect(find.text(s.septicQ), findsNothing);
    });

    testWidgets('remember a house outside a PBT area', (tester) async {
      setPhone(tester, height: 3200);
      final w = fakeWorld(ptype: 'landed');
      await tester.pumpWidget(harness(
        const HouseEditScreen(assetId: 1),
        withHouse(w, w.houses[1]!.copyWith(septicTank: const Value(true), insidePbt: const Value(false))),
      ));
      await tester.pumpAndSettle();
      final pbt = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, s.insidePbtQ));
      expect(pbt.value, isFalse);
      // The preset offered is the 3-yearly one (same title, see the preset test).
      expect(find.text(s.presetTitle('desludgingRural')), findsOneWidget);
    });
  });
}
