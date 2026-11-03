// Checks for the 0.2.5 UI polish (from the screenshot review): each test pins one change.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/rules.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/common.dart';
import 'package:kukira_asset/ui/forms.dart';
import 'package:kukira_asset/ui/more.dart';
import 'package:kukira_asset/ui/today.dart';

import 'helpers.dart';

void main() {
  final s = strFor('en');

  group('status is said once', () {
    testWidgets('Today groups by status, so its rows have no status pill', (tester) async {
      setPhone(tester, height: 1600);
      await tester.pumpWidget(harness(const TodayScreen(), fakeWorld(reminders: [fakeReminder(due: DateTime.now().subtract(const Duration(days: 3)))])));
      await tester.pumpAndSettle();
      expect(find.text(s.overdue), findsWidgets);
      expect(find.byType(ReminderTile), findsOneWidget);
      expect(find.byType(StatusPill), findsNothing);
    });

    testWidgets('mixed lists (All reminders) still show the pill', (tester) async {
      setPhone(tester, height: 1600);
      await tester.pumpWidget(harness(const AllRemindersScreen(), fakeWorld(reminders: [fakeReminder(due: DateTime.now().subtract(const Duration(days: 3)))])));
      await tester.pumpAndSettle();
      expect(find.byType(StatusPill), findsWidgets);
    });

    testWidgets('an asset card names its next reminder without a second pill', (tester) async {
      setPhone(tester, height: 1600);
      await tester.pumpWidget(harness(const AssetsScreen(), fakeWorld(reminders: [fakeReminder(due: DateTime.now().subtract(const Duration(days: 3)))])));
      await tester.pumpAndSettle();
      expect(find.text(s.overdueCount(1)), findsOneWidget);
      expect(find.byType(StatusPill), findsNothing);
    });
  });

  testWidgets('no backup yet is a warning, not a green note, and the tile says Never', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const TodayScreen(), fakeWorld()));
    await tester.pumpAndSettle();
    final banner = tester.widget<InfoBanner>(find.ancestor(of: find.text(s.noBackupBanner), matching: find.byType(InfoBanner)));
    expect(banner.warn, isTrue);
    expect(find.text(s.neverShort), findsOneWidget);
    expect(find.text('–'), findsNothing);
  });

  group('no decorative banner without a photo', () {
    testWidgets('asset cards show the small category avatar instead', (tester) async {
      setPhone(tester, height: 1600);
      await tester.pumpWidget(harness(const AssetsScreen(), fakeWorld()));
      await tester.pumpAndSettle();
      expect(find.byType(AssetBanner), findsNothing);
      expect(find.byType(AssetAvatar), findsNWidgets(2));
    });

    testWidgets('the overview starts with the facts, and the edit screen labels the photo buttons', (tester) async {
      setPhone(tester, height: 1600);
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 2), fakeWorld()));
      await tester.pumpAndSettle();
      expect(find.byType(AssetBanner), findsNothing);

      await tester.pumpWidget(harness(const VehicleEditScreen(assetId: 2), fakeWorld()));
      await tester.pumpAndSettle();
      expect(find.byType(AssetBanner), findsNothing);
      expect(find.text(s.assetPhoto), findsOneWidget);
    });
  });

  testWidgets('a vehicle record shows the odometer field without opening More details', (tester) async {
    setPhone(tester, height: 2000);
    await tester.pumpWidget(harness(const RecordFormScreen(assetId: 2), fakeWorld()));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, s.odometerKm), findsOneWidget);

    // A new form, not the car's form reused with its state.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(const RecordFormScreen(assetId: 1), fakeWorld()));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, s.odometerKm), findsNothing, reason: 'a house has no odometer');
  });

  testWidgets('More says whether the app lock is on, instead of repeating its title', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const MoreScreen(), fakeWorld()));
    await tester.pumpAndSettle();
    expect(find.text(s.appLock), findsOneWidget);
    expect(find.text(s.lockStatusOff), findsOneWidget);

    await tester.pumpWidget(harness(const MoreScreen(), fakeWorld(), lockMode: 'pin_bio'));
    await tester.pumpAndSettle();
    expect(find.text(s.lockStatusPinBio), findsOneWidget);
  });

  testWidgets('the battery advice in Reminder health check uses the full width', (tester) async {
    setPhone(tester, height: 1800);
    await tester.pumpWidget(harness(const HealthScreen(), fakeWorld()));
    await tester.pumpAndSettle();
    final text = tester.getRect(find.text(s.batteryBody));
    final button = tester.getRect(find.widgetWithText(FilledButton, s.open));
    expect(button.top, greaterThanOrEqualTo(text.bottom), reason: 'the button sits under the text');
    expect(text.width, greaterThan(220), reason: 'the text is not squeezed beside the button');
  });

  testWidgets('the number plate has an edge in dark mode only', (tester) async {
    Future<BoxBorder?> edge(Brightness b) async {
      await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: b), home: const Scaffold(body: Plate('WXY 4821'))));
      // MaterialApp animates a theme change; let it finish.
      await tester.pumpAndSettle();
      final box = tester.widget<Container>(find.descendant(of: find.byType(Plate), matching: find.byType(Container)));
      return (box.decoration! as BoxDecoration).border;
    }

    expect(await edge(Brightness.light), isNull);
    expect(await edge(Brightness.dark), isNotNull);
  });

  testWidgets('Backup and restore has one note about phone backups, not two stacked boxes', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const BackupScreen(), fakeWorld()));
    await tester.pumpAndSettle();
    expect(find.byType(NoteBox), findsNWidgets(2));
    expect(find.textContaining(s.phoneBackupNote), findsOneWidget);
    expect(find.textContaining(s.backupNudgeNote), findsOneWidget);
  });

  testWidgets('the reminder sheet says overdue once and shows the next notification, not a past one', (tester) async {
    setPhone(tester, height: 1600);
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final r = fakeReminder(due: due);
    await tester.pumpWidget(harness(
      Builder(builder: (c) => TextButton(onPressed: () => showReminderSheet(c, r.id), child: const Text('open'))),
      fakeWorld(reminders: [r]),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('${s.statusLabel(RStatus.overdue)} · '), findsNothing);
    final next = planNotes([r.info], now: now, limit: 1).single.at;
    expect(next.isAfter(now), isTrue);
    expect(find.text(s.notifyOnAt(s.dShort(next), s.hm(next.hour, next.minute))), findsOneWidget);
  });
}
