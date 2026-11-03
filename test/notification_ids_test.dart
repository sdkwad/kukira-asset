import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/services/notifications.dart';

import 'helpers.dart';

void main() {
  final today = DateTime(2026, 11, 3);

  test('each reminder notification keeps the same id, and the id leads back to the reminder', () {
    expect(Notifier.noteId(7, 2), Notifier.noteId(7, 2));
    final ids = {for (final r in [1, 2, 7, 123456]) for (var slot = 0; slot < 10; slot++) Notifier.noteId(r, slot)};
    expect(ids, hasLength(40), reason: 'no two notifications share an id');
    for (final r in [1, 2, 7, 123456]) {
      for (var slot = 0; slot < 10; slot++) {
        expect(Notifier.reminderOfNote(Notifier.noteId(r, slot)), r);
      }
    }
    // The test, mileage, backup and refresh notices (and ids used before 0.2.4) are not reminders.
    for (final other in [0, 48, 8000, 8100, 9000, 9100]) {
      expect(Notifier.reminderOfNote(other), isNull);
    }
  });

  group('a notification already in the tray', () {
    test('stays while its reminder is overdue or due soon', () {
      expect(Notifier.keepShown(fakeReminder(due: DateTime(2026, 11, 1)), today: today), isTrue);
      expect(Notifier.keepShown(fakeReminder(due: DateTime(2026, 11, 10)), today: today), isTrue);
    });

    test('goes once the reminder is done, deleted, snoozed or no longer due soon', () {
      expect(Notifier.keepShown(fakeReminder(done: true), today: today), isFalse);
      expect(Notifier.keepShown(null, today: today), isFalse);
      expect(Notifier.keepShown(fakeReminder(due: DateTime(2026, 11, 1), snoozedUntil: DateTime(2026, 11, 6)), today: today), isFalse);
      // Marked done on a repeating reminder: the next one is months away.
      expect(Notifier.keepShown(fakeReminder(due: DateTime(2027, 5, 1)), today: today), isFalse);
    });
  });
}
