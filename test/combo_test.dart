// Pick lists (0.2.7c): fields that suggest from a list and keep anything typed, the official
// council and insurer lists, and the council's website link.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/councils.dart';
import 'package:kukira_asset/domain/lists.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/links.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/combo.dart';
import 'package:kukira_asset/ui/forms.dart';

import 'helpers.dart';

World withProfiles(World w, {HouseProfile? house, VehicleProfile? car, List<UpkeepRecord>? records}) => World(
      assets: w.assets,
      houses: house == null ? w.houses : {1: house},
      vehicles: car == null ? w.vehicles : {2: car},
      reminders: w.reminders,
      records: records ?? w.records,
      odometer: w.odometer,
      vendors: w.vendors,
      documents: w.documents,
      settings: w.settings,
      costItems: w.costItems,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  List<String> values(List<ComboOption> o) => [for (final x in o) x.value];

  group('matching', () {
    final opts = [for (final v in ['Alza', 'Aruz', 'Axia', 'Myvi', 'Bezza', 'CX-5', 'Corolla Cross']) ComboOption(v)];

    test('starts-with first, then a word that starts with it, then anywhere', () {
      expect(values(comboMatches(opts, 'a')), ['Alza', 'Aruz', 'Axia', 'Bezza', 'Corolla Cross']);
      expect(values(comboMatches(opts, 'cross')), ['Corolla Cross']);
      expect(values(comboMatches(opts, 'vi')), ['Myvi']);
    });

    test('spaces, case and punctuation do not matter', () {
      expect(values(comboMatches(opts, 'cx5')), ['CX-5'], reason: 'offered, to write it the usual way');
      expect(values(comboMatches(opts, 'AXIA ')), isEmpty, reason: 'the field already says Axia');
      expect(values(comboMatches(opts, 'AX')), ['Axia']);
    });

    test('an empty field lists everything; the short form and second line are searched too', () {
      expect(comboMatches(opts, '').length, opts.length);
      const council = ComboOption('Majlis Bandaraya Shah Alam (MBSA)', detail: 'Selangor', also: 'MBSA');
      expect(comboMatches([council], 'mbsa'), [council]);
      expect(comboMatches([council], 'selangor'), [council]);
    });

    test('what the owner typed before comes first, once', () {
      final o = withTyped([ComboOption('Perodua'), ComboOption('Proton')], ['perodua', 'Chery ', null, '', 'Chery']);
      expect(values(o), ['Chery', 'Perodua', 'Proton']);
    });
  });

  group('official lists', () {
    test('every state and federal territory has its councils, and nothing else', () {
      expect(councilsByState.keys.toSet(), malaysianStates.toSet());
      for (final e in councilsByState.entries) {
        expect(e.value, isNotEmpty, reason: e.key);
        expect(e.value.map((c) => c.name).toSet().length, e.value.length, reason: 'no council twice in ${e.key}');
      }
      final all = councilsFor(null);
      expect(all.length, 156);
      expect(all.map((m) => m.$1.label).toSet().length, all.length);
    });

    test('every website is a plain http or https address', () {
      var linked = 0;
      for (final (c, _) in councilsFor(null)) {
        if (c.web == null) continue;
        linked++;
        final u = Uri.parse(c.web!);
        expect(u.scheme, anyOf('https', 'http'), reason: c.name);
        expect(u.host, endsWith('.gov.my'), reason: c.name);
      }
      expect(linked, 150);
    });

    test('a council is found by its label, name or short form, and a shared short form needs the state', () {
      expect(councilNamed('MBSA')?.$1.name, 'Majlis Bandaraya Shah Alam');
      expect(councilNamed('mbsa')?.$2, 'Selangor');
      expect(councilNamed('Majlis Bandaraya Shah Alam (MBSA)')?.$1.web, 'https://www.mbsa.gov.my');
      expect(councilNamed('majlis bandaraya petaling jaya')?.$1.abbr, 'MBPJ');
      // MPS is Sandakan (Sabah) and Selayang (Selangor).
      expect(councilNamed('MPS'), isNull);
      expect(councilNamed('MPS', state: 'Selangor')?.$1.name, 'Majlis Perbandaran Selayang');
      expect(councilNamed('Majlis kampung saya'), isNull);
      expect(councilsFor('selangor').length, 12);
      expect(councilsFor('Kuala Lumpur').single.$1.abbr, 'DBKL');
    });

    test('states are understood however they are typed', () {
      expect(stateNamed('selangor'), 'Selangor');
      expect(stateNamed('Kuala Lumpur'), 'W.P. Kuala Lumpur');
      expect(stateNamed('KL'), 'W.P. Kuala Lumpur');
      expect(stateNamed('Penang'), 'Pulau Pinang');
      expect(stateNamed('Atlantis'), isNull);
    });

    test('insurers are the general insurance and general takaful licences', () {
      expect(insurers.length, 23);
      expect(insurers.map((i) => i.name).toSet().length, insurers.length);
      expect(insurers.where((i) => i.licensedName.contains('Takaful')).length, 4);
      expect(insurers.any((i) => i.licensedName.contains('Life') || i.licensedName.contains('Family')), isFalse);
    });

    test('models follow the make, however it was typed', () {
      expect(modelsFor('car', 'perodua'), contains('Myvi'));
      expect(modelsFor('motorcycle', 'Honda'), contains('EX5'));
      expect(modelsFor('car', 'Honda'), isNot(contains('EX5')));
      expect(modelsFor('car', 'Kereta saya'), isEmpty);
      expect(yearOptions(DateTime(2026)).first, '2027');
    });
  });

  group('forms', () {
    String textOf(WidgetTester tester, String label) => tester.widget<TextField>(find.widgetWithText(TextField, label)).controller!.text;

    testWidgets('the model list follows the make, and a tap fills the field', (tester) async {
      setPhone(tester, height: 2400);
      final w = withProfiles(fakeWorld(), car: VehicleProfile(assetId: 2, vehicleType: 'car', plate: 'WXY 4821', make: 'Perodua'));
      await tester.pumpWidget(harness(const VehicleEditScreen(assetId: 2), w));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextField, s.model));
      await tester.enterText(find.widgetWithText(TextField, s.model), 'A');
      await tester.pumpAndSettle();
      for (final m in ['Alza', 'Aruz', 'Ativa', 'Axia']) {
        expect(find.text(m), findsOneWidget, reason: m);
      }
      expect(find.text(s.comboNotListed), findsOneWidget);
      expect(find.text('Saga'), findsNothing);
      await tester.tap(find.text('Axia'));
      await tester.pumpAndSettle();
      expect(textOf(tester, s.model), 'Axia');
      expect(find.text(s.comboNotListed), findsNothing, reason: 'the suggestions close after a pick');
    });

    testWidgets('anything typed is kept, even when Enter is pressed', (tester) async {
      setPhone(tester, height: 2400);
      final w = withProfiles(fakeWorld(), car: VehicleProfile(assetId: 2, vehicleType: 'car', plate: 'WXY 4821', make: 'Perodua'));
      await tester.pumpWidget(harness(const VehicleEditScreen(assetId: 2), w));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextField, s.model));
      await tester.enterText(find.widgetWithText(TextField, s.model), 'My');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(comboOptionsKey), matching: find.text('Myvi')), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(textOf(tester, s.model), 'My', reason: 'Enter does not swap in a suggestion');
      await tester.enterText(find.widgetWithText(TextField, s.model), 'Myvi GT Special');
      await tester.pumpAndSettle();
      expect(textOf(tester, s.model), 'Myvi GT Special');
    });

    testWidgets('the arrow opens the whole list; picking another make changes the models', (tester) async {
      setPhone(tester, height: 2400);
      await tester.pumpWidget(harness(const VehicleEditScreen(assetId: 2), fakeWorld()));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.widgetWithText(TextField, s.make), matching: find.byTooltip(s.showList)));
      await tester.pumpAndSettle();
      expect(find.text(s.typeYourOwn), findsOneWidget);
      await tester.tap(find.text('Proton'));
      await tester.pumpAndSettle();
      expect(textOf(tester, s.make), 'Proton');
      await tester.tap(find.widgetWithText(TextField, s.model));
      await tester.enterText(find.widgetWithText(TextField, s.model), 'sa');
      await tester.pumpAndSettle();
      expect(find.text('Saga'), findsOneWidget);
      expect(find.text('Satria'), findsOneWidget);
    });

    testWidgets('insurers show the licensed name, and the source of the list', (tester) async {
      setPhone(tester, height: 2400);
      await tester.pumpWidget(harness(const VehicleEditScreen(assetId: 2), fakeWorld()));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextField, s.insurer));
      await tester.enterText(find.widgetWithText(TextField, s.insurer), 'ikhlas');
      await tester.pumpAndSettle();
      expect(find.text('Takaful Ikhlas'), findsOneWidget);
      expect(find.text('Takaful Ikhlas General Berhad'), findsOneWidget);

      await tester.tap(find.descendant(of: find.widgetWithText(TextField, s.insurer), matching: find.byTooltip(s.showList)));
      await tester.pumpAndSettle();
      expect(find.text('${s.typeYourOwn} ${s.insurerListSource}'), findsOneWidget);
    });

    testWidgets('a council picked from every state fills in its state, and links to its website', (tester) async {
      setPhone(tester, height: 3200);
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(Links.channel, (c) async {
        calls.add(c);
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(Links.channel, null));
      await tester.pumpWidget(harness(const HouseEditScreen(assetId: 1), fakeWorld()));
      await tester.pumpAndSettle();
      expect(find.byTooltip(s.openWebsite), findsNothing);
      await tester.tap(find.widgetWithText(TextField, s.council));
      await tester.enterText(find.widgetWithText(TextField, s.council), 'shah alam');
      await tester.pumpAndSettle();
      expect(find.text('Selangor'), findsOneWidget, reason: 'with every state listed, each council says its state');
      await tester.tap(find.text('Majlis Bandaraya Shah Alam (MBSA)'));
      await tester.pumpAndSettle();
      expect(textOf(tester, s.state), 'Selangor');
      await tester.tap(find.byTooltip(s.openWebsite));
      await tester.pumpAndSettle();
      expect(calls.single.method, 'openWeb');
      expect(calls.single.arguments, 'https://www.mbsa.gov.my');
    });

    testWidgets('with a state chosen, only its councils are listed', (tester) async {
      setPhone(tester, height: 3200);
      final w = withProfiles(fakeWorld(), house: HouseProfile(assetId: 1, propertyType: 'landed', state: 'Perlis'));
      await tester.pumpWidget(harness(const HouseEditScreen(assetId: 1), w));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.widgetWithText(TextField, s.council), matching: find.byTooltip(s.showList)));
      await tester.pumpAndSettle();
      expect(find.text('Majlis Perbandaran Perlis'), findsOneWidget);
      expect(find.textContaining('Shah Alam'), findsNothing);
      expect(find.text('${s.typeYourOwn} ${s.councilListSource}'), findsOneWidget);
    });

    testWidgets('a council typed before as its short form is the listed council, not a second entry', (tester) async {
      setPhone(tester, height: 3200);
      final w = withProfiles(fakeWorld(), house: HouseProfile(assetId: 1, propertyType: 'landed', state: 'Selangor', council: 'MBSA'));
      expect(values(councilOptions(w, 'Selangor')).where((v) => v.contains('MBSA')), ['Majlis Bandaraya Shah Alam (MBSA)']);
      await tester.pumpWidget(harness(const HouseEditScreen(assetId: 1), w));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.widgetWithText(TextField, s.council), matching: find.byTooltip(s.showList)));
      await tester.pumpAndSettle();
      final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Majlis Bandaraya Shah Alam (MBSA)'));
      expect(tile.selected, isTrue, reason: 'the field says MBSA, so this one is ticked');

      final own = withProfiles(fakeWorld(), house: HouseProfile(assetId: 1, propertyType: 'landed', state: 'Selangor', council: 'Majlis kampung saya'));
      expect(values(councilOptions(own, 'Selangor')).first, 'Majlis kampung saya', reason: 'a name of their own is still offered');
    });

    testWidgets('a short form typed before still gets the link when the state makes it clear', (tester) async {
      setPhone(tester, height: 2400);
      final w = withProfiles(fakeWorld(), house: HouseProfile(assetId: 1, propertyType: 'landed', state: 'Selangor', council: 'MPS'));
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), w));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.houseDetails));
      await tester.pumpAndSettle();
      expect(find.text(s.councilWebsite('MPS')), findsOneWidget);

      final unclear = withProfiles(fakeWorld(), house: HouseProfile(assetId: 1, propertyType: 'landed', council: 'MPS'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), unclear));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.houseDetails));
      await tester.pumpAndSettle();
      expect(find.text(s.councilWebsite('MPS')), findsNothing, reason: 'Sandakan or Selayang: no guess');
    });

    testWidgets('areas suggest the rooms of a house and the ones used before', (tester) async {
      setPhone(tester, height: 2400);
      final used = UpkeepRecord(id: 9, assetId: 1, kind: 'defect', title: 'Crack', date: DateTime(2026, 3, 1), area: 'Granny flat', createdAt: DateTime(2026, 3, 1));
      await tester.pumpWidget(harness(const RecordFormScreen(assetId: 1, kind: 'defect'), withProfiles(fakeWorld(), records: [used])));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextField, s.area));
      await tester.enterText(find.widgetWithText(TextField, s.area), 'bath');
      await tester.pumpAndSettle();
      expect(find.text('Master bathroom'), findsOneWidget);
      expect(find.text('Bathroom 2'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, s.area), 'gran');
      await tester.pumpAndSettle();
      expect(find.text('Granny flat'), findsOneWidget);
    });

    testWidgets('the vehicle form fits a 360 dp phone at 130% text', (tester) async {
      setPhone(tester, height: 1800);
      await tester.pumpWidget(harness(
        MediaQuery.withClampedTextScaling(minScaleFactor: 1.3, maxScaleFactor: 1.3, child: const VehicleEditScreen(assetId: 2)),
        fakeWorld(),
        lang: 'ms',
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
