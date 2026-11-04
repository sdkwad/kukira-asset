// Wide screens (0.2.8): a navigation rail with Tambah, Today and Assets as list and detail
// side by side, the asset overview in two columns, and pages kept to a readable width.
// A phone is unchanged.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/app.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/common.dart';
import 'package:kukira_asset/ui/forms.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'helpers.dart';

/// A window of [width] x [height] logical pixels with no system bars, like a tablet.
void setScreen(WidgetTester tester, double width, double height) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(width * 2, height * 2);
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    PackageInfo.setMockInitialValues(appName: 'Kukira Asset', packageName: 'app.kukira.kukira_asset', version: '0.0.0', buildNumber: '0', buildSignature: '');
  });
  final s = strFor('en');
  final t = today();
  List<Reminder> reminders() => [
        fakeReminder(id: 1, assetId: 2, title: 'Engine oil change', due: t.subtract(const Duration(days: 6))),
        fakeReminder(id: 2, assetId: 1, title: 'Aircond service', due: t.add(const Duration(days: 5))),
      ];
  // The page's floating Tambah (the rail's own has an icon only).
  final pageTambah = find.widgetWithText(FloatingActionButton, s.add);

  test('window size classes follow Material', () {
    expect(WindowSize.values, [WindowSize.compact, WindowSize.medium, WindowSize.expanded]);
  });

  testWidgets('a phone keeps the bottom bar and the floating Tambah', (tester) async {
    setPhone(tester);
    await tester.pumpWidget(harness(const Shell(), fakeWorld(reminders: reminders())));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(pageTambah.hitTestable(), findsOneWidget);
  });

  testWidgets('a tablet has the rail, with the one Tambah on it', (tester) async {
    setScreen(tester, 1280, 800);
    await tester.pumpWidget(harness(const Shell(), fakeWorld(reminders: reminders())));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(pageTambah, findsNothing, reason: 'the rail has Tambah; the pages do not repeat it');
    await tester.tap(find.byTooltip(s.add));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(s.orPickAsset)), findsOneWidget, reason: 'the same sheet as on a phone');
  });

  testWidgets('every main place opens on a tablet and on a medium window without layout errors', (tester) async {
    for (final (w, h) in [(1280.0, 800.0), (700.0, 1000.0)]) {
      setScreen(tester, w, h);
      await tester.pumpWidget(harness(const Shell(), fakeWorld(reminders: reminders())));
      await tester.pumpAndSettle();
      for (final d in [s.assetsTab, s.documentsTab, s.moreTab, s.today]) {
        await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(d)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$d at $w');
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Today shows the reminder picked beside the list, not in a sheet', (tester) async {
    setScreen(tester, 1280, 800);
    await tester.pumpWidget(harness(const Shell(), fakeWorld(reminders: reminders())));
    await tester.pumpAndSettle();
    // The most urgent one is open to begin with.
    expect(tester.widget<ReminderDetail>(find.byType(ReminderDetail)).reminderId, 1);
    await tester.tap(find.text('Aircond service'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.widget<ReminderDetail>(find.byType(ReminderDetail)).reminderId, 2);
    expect(find.text(s.markDone), findsOneWidget, reason: 'its actions are in the pane');
  });

  testWidgets('Assets shows the asset picked beside the list, without opening a page', (tester) async {
    setScreen(tester, 1280, 800);
    await tester.pumpWidget(harness(const Shell(), fakeWorld(reminders: reminders())));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(s.assetsTab)));
    await tester.pumpAndSettle();
    AssetDetailScreen pane() => tester.widget<AssetDetailScreen>(find.byType(AssetDetailScreen));
    expect(pane().assetId, 1);
    expect(pane().embedded, isTrue);
    await tester.tap(find.descendant(of: find.byType(Card), matching: find.text('Myvi')).first);
    await tester.pumpAndSettle();
    expect(pane().assetId, 2);
    expect(find.byType(NavigationRail), findsOneWidget, reason: 'still on Assets, not a page over it');
  });

  testWidgets('an asset page on a tablet puts the records beside the status', (tester) async {
    setScreen(tester, 1280, 900);
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), fakeWorld(reminders: reminders())));
    await tester.pumpAndSettle();
    final status = tester.getRect(find.text(s.stateTitle));
    final records = tester.getRect(find.text(s.recordsYear(t.year, s.rm(0))));
    expect(records.left, greaterThan(status.right), reason: 'a second column');

    setPhone(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), fakeWorld(reminders: reminders())));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final phoneStatus = find.text(s.stateTitle);
    final phoneRecords = find.text(s.recordsYear(t.year, s.rm(0)));
    if (phoneStatus.evaluate().isNotEmpty && phoneRecords.evaluate().isNotEmpty) {
      expect(tester.getRect(phoneRecords).top, greaterThan(tester.getRect(phoneStatus).bottom), reason: 'one column on a phone');
    }
  });

  testWidgets('forms keep a readable width on a tablet', (tester) async {
    setScreen(tester, 1280, 800);
    await tester.pumpWidget(harness(const RecordFormScreen(assetId: 2), fakeWorld()));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(ListView).first).width, lessThanOrEqualTo(readableWidth));
    expect(tester.takeException(), isNull);
  });
}
