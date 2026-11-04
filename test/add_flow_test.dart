// The four-tab navigation and "Tambah": with no asset, one asset and several, from Today
// and from an asset's page. Nothing may be added to an asset the user did not choose.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/presets.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/add_actions.dart';
import 'package:kukira_asset/ui/add_asset.dart';
import 'package:kukira_asset/ui/app.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/documents.dart';
import 'package:kukira_asset/ui/forms.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'helpers.dart';

/// [w] with only the asset [id] (and its profile).
World onlyAsset(World w, int id) => World(
      assets: w.assets.where((a) => a.id == id).toList(),
      houses: {for (final e in w.houses.entries) if (e.key == id) e.key: e.value},
      vehicles: {for (final e in w.vehicles.entries) if (e.key == id) e.key: e.value},
      reminders: w.reminders.where((r) => r.assetId == id).toList(),
      records: const [],
      odometer: const {},
      vendors: const [],
      documents: const [],
      settings: const {},
      costItems: const {},
    );

World noAssets() => World(
      assets: const [],
      houses: const {},
      vehicles: const {},
      reminders: const [],
      records: const [],
      odometer: const {},
      vendors: const [],
      documents: const [],
      settings: const {},
      costItems: const {},
    );

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    PackageInfo.setMockInitialValues(appName: 'Kukira Asset', packageName: 'app.kukira.kukira_asset', version: '0.0.0', buildNumber: '0', buildSignature: '');
  });
  final s = strFor('en');
  // The tab stack keeps every page built; only the visible page's button can be tapped.
  final fab = find.byType(FloatingActionButton).hitTestable();

  Future<void> openAdd(WidgetTester tester) async {
    await tester.tap(fab);
    await tester.pumpAndSettle();
  }

  group('navigation', () {
    testWidgets('four real tabs, and Tambah is not one of them', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(harness(const Shell(), fakeWorld()));
      await tester.pumpAndSettle();
      final labels = tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)).map((d) => d.label).toList();
      expect(labels, [s.today, s.assetsTab, s.documentsTab, s.moreTab]);

      // Each tab opens its page; nothing opens a sheet instead.
      await tester.tap(find.widgetWithText(NavigationDestination, s.documentsTab));
      await tester.pumpAndSettle();
      expect(find.text(s.noDocsTitle).hitTestable(), findsOneWidget);
      await tester.tap(find.widgetWithText(NavigationDestination, s.moreTab));
      await tester.pumpAndSettle();
      expect(find.text(s.backupRestore).hitTestable(), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('Tambah is on Today and Assets, not on Documents or More', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(harness(const Shell(), fakeWorld()));
      await tester.pumpAndSettle();
      expect(fab, findsOneWidget);
      await tester.tap(find.widgetWithText(NavigationDestination, s.assetsTab));
      await tester.pumpAndSettle();
      expect(fab, findsOneWidget);
      for (final tab in [s.documentsTab, s.moreTab]) {
        await tester.tap(find.widgetWithText(NavigationDestination, tab));
        await tester.pumpAndSettle();
        expect(fab, findsNothing, reason: tab);
      }
    });
  });

  group('Tambah', () {
    testWidgets('with no asset there is no Tambah button; the first-asset button is the one action', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(harness(const Shell(), noAssets()));
      await tester.pumpAndSettle();
      expect(fab, findsNothing);
      expect(find.ancestor(of: find.text(s.addFirstAsset), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)), findsOneWidget);
    });

    testWidgets('with one asset it goes straight to that asset\'s actions', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(harness(const Shell(), onlyAsset(fakeWorld(), 2)));
      await tester.pumpAndSettle();
      await openAdd(tester);
      expect(find.text(s.forAsset), findsOneWidget);
      expect(find.text(s.whichAsset), findsNothing);
      for (final k in addKindsFor('car')) {
        expect(find.text(s.addActionName(k.name, 'car')), findsOneWidget, reason: k.name);
      }

      await tester.tap(find.text(s.addActionName('maintenance', 'car')));
      await tester.pumpAndSettle();
      expect(find.text(s.newRecord), findsOneWidget);
      final asset = tester.widget<DropdownButtonFormField<int>>(find.byType(DropdownButtonFormField<int>));
      expect(asset.initialValue, 2, reason: 'the car\'s record form');
    });

    testWidgets('with several assets it asks which one first, and can go back', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(harness(const Shell(), fakeWorld()));
      await tester.pumpAndSettle();
      await openAdd(tester);
      final inSheet = find.byType(BottomSheet);
      expect(find.text(s.whichAsset), findsOneWidget);
      expect(find.descendant(of: inSheet, matching: find.text('Setia Alam house')), findsOneWidget);
      expect(find.descendant(of: inSheet, matching: find.text('Myvi')), findsOneWidget);
      expect(find.text(s.addActionName('maintenance', 'car')), findsNothing, reason: 'no action before an asset is chosen');

      await tester.tap(find.descendant(of: inSheet, matching: find.text('Myvi')));
      await tester.pumpAndSettle();
      expect(find.text(s.addActionName('odometer', 'car')), findsOneWidget);

      await tester.tap(find.text(s.changeAsset));
      await tester.pumpAndSettle();
      expect(find.text(s.whichAsset), findsOneWidget);

      await tester.tap(find.text(s.newAsset));
      await tester.pumpAndSettle();
      expect(find.byType(AddAssetScreen), findsOneWidget);
    });

    testWidgets('from a house page it is for that house, with its own actions', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), fakeWorld()));
      await tester.pumpAndSettle();
      await openAdd(tester);
      expect(find.text(s.whichAsset), findsNothing);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Setia Alam house')), findsOneWidget);
      expect(find.text(s.addActionName('defect', 'house')), findsOneWidget);
      expect(find.text(s.addActionName('renovation', 'house')), findsOneWidget);
      expect(find.text(s.addActionName('odometer', 'house')), findsNothing, reason: 'a house has no odometer');

      await tester.tap(find.text(s.addActionName('defect', 'house')));
      await tester.pumpAndSettle();
      expect(find.text(s.newDefect), findsOneWidget);
    });

    testWidgets('from a car page, Odometer asks for the reading of that car', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), fakeWorld()));
      await tester.pumpAndSettle();
      await openAdd(tester);
      await tester.tap(find.text(s.addActionName('odometer', 'car')));
      await tester.pumpAndSettle();
      expect(find.text(s.odoDialogTitle('Myvi')), findsOneWidget);
    });

    test('every record kind the form allows can be reached from Tambah', () {
      for (final cat in ['house', 'car', 'motorcycle']) {
        final names = addKindsFor(cat).map((k) => k.name).toSet();
        expect(names.containsAll(kindsFor(cat)), isTrue, reason: cat);
        expect(names.containsAll(['reminder', 'document']), isTrue, reason: cat);
      }
    });

    testWidgets('the Tambah button never covers the last item of a list', (tester) async {
      setPhone(tester);
      for (final (screen, last) in [
        (const Shell() as Widget, find.textContaining(s.allReminders(1))),
        (const AssetDetailScreen(assetId: 1), find.text(s.houseDetails)),
      ]) {
        await tester.pumpWidget(harness(screen, fakeWorld()));
        await tester.pumpAndSettle();
        for (var i = 0; i < 4; i++) {
          await tester.dragFrom(const Offset(phoneWidth / 2, 420), const Offset(0, -1500));
          await tester.pumpAndSettle();
        }
        expect(tester.getRect(last.last).bottom, lessThanOrEqualTo(tester.getRect(fab).top), reason: '$screen');
      }
    });
  });

  group('a form opened without an asset', () {
    final cases = <String, (Widget, String)>{
      'record': (const RecordFormScreen(), s.newRecord),
      'reminder': (const ReminderFormScreen(), s.newReminder),
      'document': (const DocumentFormScreen(), s.attachDocument),
    };
    for (final MapEntry(key: name, value: (form, title)) in cases.entries) {
      testWidgets('asks which asset when there are several ($name)', (tester) async {
        setPhone(tester);
        await tester.pumpWidget(harness(form, fakeWorld()));
        await tester.pumpAndSettle();
        expect(find.text(s.whichAsset), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.byType(TextField), findsNothing, reason: 'no form until an asset is chosen');

        await tester.tap(find.text('Myvi'));
        await tester.pumpAndSettle();
        expect(find.text(s.whichAsset), findsNothing);
      });

      testWidgets('uses the only asset when there is one ($name)', (tester) async {
        setPhone(tester);
        await tester.pumpWidget(harness(form, onlyAsset(fakeWorld(), 2)));
        await tester.pumpAndSettle();
        expect(find.text(s.whichAsset), findsNothing);
      });
    }

    testWidgets('after choosing, the record form is for the chosen asset', (tester) async {
      setPhone(tester, height: 1600);
      await tester.pumpWidget(harness(const RecordFormScreen(), fakeWorld()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Setia Alam house'));
      await tester.pumpAndSettle();
      final asset = tester.widget<DropdownButtonFormField<int>>(find.byType(DropdownButtonFormField<int>));
      expect(asset.initialValue, 1);
      expect(find.widgetWithText(TextField, s.odometerKm), findsNothing, reason: 'the house form');
    });
  });
}
