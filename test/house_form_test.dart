import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/domain/presets.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/assets.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  String title(String key) => presetByKey(key)!.title(s);

  group('options by property type', () {
    test('title status', () {
      expect(titleOptionsFor('landed'), ['individual', 'master']);
      expect(titleOptionsFor('strata'), ['master', 'strata_issued']);
      expect(titleOptionsFor('strata_landed'), ['master', 'strata_issued']);
    });

    test('templates', () {
      List<String> keys(String p) => templatesFor('house', p).map((x) => x.key).toList();
      expect(keys('landed'), containsAll(['cukaiTanah', 'houseInsurance', 'waterTank']));
      expect(keys('landed'), isNot(contains('cukaiPetak')));
      expect(keys('strata'), containsAll(['cukaiPetak', 'maintenanceCharge']));
      expect(keys('strata'), isNot(anyOf(contains('cukaiTanah'), contains('houseInsurance'), contains('waterTank'))));
      expect(keys('strata_landed'), containsAll(['cukaiPetak', 'maintenanceCharge', 'houseInsurance']));
      expect(keys('strata_landed'), isNot(contains('cukaiTanah')));
    });
  });

  final cases = <String, (List<String>, List<String>)>{
    'landed': (
      [s.titleName('individual'), s.titleName('master'), title('cukaiTanah'), title('houseInsurance'), title('waterTank')],
      [s.titleName('strata_issued'), title('cukaiPetak'), title('maintenanceCharge')],
    ),
    'strata': (
      [s.titleName('master'), s.titleName('strata_issued'), title('cukaiPetak'), title('maintenanceCharge')],
      [s.titleName('individual'), title('cukaiTanah'), title('houseInsurance'), title('waterTank')],
    ),
    'strata_landed': (
      [s.titleName('master'), s.titleName('strata_issued'), title('cukaiPetak'), title('maintenanceCharge'), title('houseInsurance')],
      [s.titleName('individual'), title('cukaiTanah')],
    ),
  };

  for (final MapEntry(key: ptype, value: (shown, hidden)) in cases.entries) {
    testWidgets('house edit for $ptype shows only matching title status and templates', (tester) async {
      setPhone(tester, height: 3200);
      await tester.pumpWidget(harness(const HouseEditScreen(assetId: 1), fakeWorld(ptype: ptype)));
      await tester.pumpAndSettle();
      for (final t in shown) {
        expect(find.text(t), findsOneWidget, reason: '$ptype should show "$t"');
      }
      for (final t in hidden) {
        expect(find.text(t), findsNothing, reason: '$ptype should not show "$t"');
      }
    });
  }

  testWidgets('switching property type updates the options at once', (tester) async {
    setPhone(tester, height: 3200);
    await tester.pumpWidget(harness(const HouseEditScreen(assetId: 1), fakeWorld(ptype: 'landed')));
    await tester.pumpAndSettle();
    expect(find.text(title('cukaiTanah')), findsOneWidget);
    await tester.tap(find.text(s.ptypeName('strata')));
    await tester.pumpAndSettle();
    expect(find.text(title('cukaiTanah')), findsNothing);
    expect(find.text(title('cukaiPetak')), findsOneWidget);
    expect(find.text(s.titleName('individual')), findsNothing);
  });

  testWidgets('subsale keeps the VP date, relabelled', (tester) async {
    setPhone(tester, height: 3200);
    await tester.pumpWidget(harness(const HouseEditScreen(assetId: 1), fakeWorld(source: 'subsale')));
    await tester.pumpAndSettle();
    expect(find.text(s.vpDateSubsale), findsOneWidget);
    expect(find.text(s.vpHelpSubsale), findsOneWidget);
    expect(find.text(s.vpDate), findsNothing);
  });

  testWidgets('subsale shows the DLP countdown only when a VP date exists', (tester) async {
    setPhone(tester, height: 2400);
    final recentVp = DateTime.now().subtract(const Duration(days: 180));
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), fakeWorld(source: 'subsale', vp: recentVp)));
    await tester.pumpAndSettle();
    expect(find.text(s.dlpDaysLeft), findsOneWidget);
    expect(find.text(s.vpDateSubsale), findsOneWidget);

    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), fakeWorld(source: 'subsale')));
    await tester.pumpAndSettle();
    expect(find.text(s.dlpDaysLeft), findsNothing);
  });
}
