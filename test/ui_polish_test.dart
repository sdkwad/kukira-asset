// Checks for the 0.2.5 UI polish (from the screenshot review): each test pins one change.

import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/common.dart';
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
}
