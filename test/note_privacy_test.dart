// Notifications without details (0.2.8 build 16): a notification shows on the lock screen
// and on a paired watch, where the app lock does not reach, so the owner can have it say only
// that there is a reminder. Until they choose, it follows the app lock.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/notifications.dart';
import 'package:kukira_asset/ui/lock.dart';
import 'package:kukira_asset/ui/more.dart';

import 'helpers.dart';

World withSettings(World w, Map<String, String> settings) => World(
      assets: w.assets,
      houses: w.houses,
      vehicles: w.vehicles,
      reminders: w.reminders,
      records: w.records,
      odometer: w.odometer,
      vendors: w.vendors,
      documents: w.documents,
      settings: settings,
      costItems: w.costItems,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('ms');

  test('details are hidden when the owner says so, or with the app lock until they choose', () {
    expect(Notifier.hidesDetails({}, 'none'), isFalse);
    expect(Notifier.hidesDetails({}, 'pin'), isTrue);
    expect(Notifier.hidesDetails({}, 'pin_bio'), isTrue);
    expect(Notifier.hidesDetails({'noteDetails': 'show'}, 'pin'), isFalse);
    expect(Notifier.hidesDetails({'noteDetails': 'hide'}, 'none'), isTrue);
  });

  test('a hidden notification names neither the reminder nor the asset', () {
    for (final kind in ['lead', 'due', 'overdue', 'snooze']) {
      final (title, body) = Notifier.reminderNote(s, title: 'Cukai jalan WXY 4821', asset: 'Myvi', kind: kind, due: DateTime(2026, 11, 13), hide: true);
      expect((title, body), (s.noteHiddenTitle, s.noteHiddenBody));
      for (final secret in ['Myvi', 'WXY', 'Cukai']) {
        expect('$title $body', isNot(contains(secret)), reason: '$kind: $secret');
      }
    }
    // Shown as before when details are on.
    expect(
      Notifier.reminderNote(s, title: 'Cukai jalan', asset: 'Myvi', kind: 'lead', due: DateTime(2026, 11, 13), hide: false),
      ('Cukai jalan', s.noteLead('Myvi', s.dShort(DateTime(2026, 11, 13)))),
    );
    expect(Notifier.reminderNote(s, title: 'Cukai jalan', asset: 'Myvi', kind: 'overdue', hide: false), ('Cukai jalan', s.noteOverdue('Myvi')));
  });

  for (final (place, screen) in [('App lock', const SecurityScreen()), ('Reminder health', const HealthScreen())]) {
    testWidgets('$place has the switch, on with the lock, and it saves the choice', (tester) async {
      final en = strFor('en');
      setPhone(tester, height: 1800);
      final db = AppDb(NativeDatabase.memory());
      await tester.pumpWidget(harness(screen, fakeWorld(), db: db, lockMode: 'pin'));
      await tester.pumpAndSettle();
      final tile = find.widgetWithText(SwitchListTile, en.hideNoteDetails);
      expect(tile, findsOneWidget);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue, reason: 'the app lock is on');
      expect(find.text(en.hideNoteDetailsOn), findsOneWidget);

      await tester.tap(tile);
      await tester.pump();
      expect(await tester.runAsync(() => db.getSetting('noteDetails')), 'show');

      // With details shown and no lock, the switch is off until turned on.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(harness(screen, withSettings(fakeWorld(), {'noteDetails': 'show'}), db: db, lockMode: 'none'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, en.hideNoteDetails)).value, isFalse);
      expect(find.text(en.hideNoteDetailsOff), findsOneWidget);
      await tester.tap(find.widgetWithText(SwitchListTile, en.hideNoteDetails));
      await tester.pump();
      expect(await tester.runAsync(() => db.getSetting('noteDetails')), 'hide');
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    });
  }
}
