import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/domain/presets.dart';
import 'package:kukira_asset/domain/rules.dart';
import 'package:kukira_asset/l10n/strings.dart';

void main() {
  final today = DateTime(2026, 10, 20);

  group('addMonths', () {
    test('clamps to the last day of the month', () {
      expect(addMonths(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
      expect(addMonths(DateTime(2027, 8, 31), 6), DateTime(2028, 2, 29));
      expect(addMonths(DateTime(2026, 11, 8), 6), DateTime(2027, 5, 8));
      expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
    });
  });

  group('status', () {
    test('date reminders', () {
      expect(statusOf(RemInfo(rule: 'fixed', due: DateTime(2026, 10, 19)), today: today), RStatus.overdue);
      expect(statusOf(RemInfo(rule: 'fixed', due: DateTime(2026, 11, 3)), today: today), RStatus.dueSoon);
      expect(statusOf(RemInfo(rule: 'fixed', due: DateTime(2027, 2, 1)), today: today), RStatus.upcoming);
      expect(statusOf(RemInfo(rule: 'fixed', due: DateTime(2027, 2, 1), done: true), today: today), RStatus.done);
    });

    test('mileage becomes overdue when the odometer passes the threshold (criterion 10)', () {
      const r = RemInfo(rule: 'mileage', dueKm: 32000, leadKm: 500);
      expect(statusOf(r, today: today, odometer: 31000), RStatus.upcoming);
      expect(statusOf(r, today: today, odometer: 31600), RStatus.dueSoon);
      expect(statusOf(r, today: today, odometer: 32100), RStatus.overdue);
    });

    test('whichever first takes the worse of date and mileage', () {
      final r = RemInfo(rule: 'either', due: DateTime(2027, 4, 1), dueKm: 48000);
      expect(statusOf(r, today: today, odometer: 40000), RStatus.upcoming);
      expect(statusOf(r, today: today, odometer: 48210), RStatus.overdue);
    });

    test('snoozed items show as due soon', () {
      final r = RemInfo(rule: 'fixed', due: DateTime(2026, 9, 1), snoozedUntil: DateTime(2026, 10, 23));
      expect(statusOf(r, today: today), RStatus.dueSoon);
    });
  });

  group('mark done', () {
    test('repeat counts from completion by default (criterion 5)', () {
      final r = RemInfo(rule: 'repeat', due: DateTime(2026, 11, 8), repeatMonths: 6);
      final n = nextAfterDone(r, today: today);
      expect(n.done, isFalse);
      expect(n.due, DateTime(2027, 4, 20));
    });

    test('tax presets count from the previous due date and keep the anchor day', () {
      final r = RemInfo(rule: 'repeat', due: DateTime(2026, 8, 31), repeatMonths: 6, repeatFrom: 'due');
      expect(nextAfterDone(r, today: today).due, DateTime(2027, 2, 28));
      final r2 = RemInfo(rule: 'repeat', due: DateTime(2027, 2, 28), repeatMonths: 6, repeatFrom: 'due');
      expect(nextAfterDone(r2, today: DateTime(2027, 3, 1)).due, DateTime(2027, 8, 28));
    });

    test('repeat every N days counts from completion', () {
      final r = RemInfo(rule: 'repeat', due: DateTime(2026, 10, 10), repeatDays: 14);
      expect(nextAfterDone(r, today: today).due, DateTime(2026, 11, 3));
      final weekly = RemInfo(rule: 'repeat', due: DateTime(2026, 10, 1), repeatDays: 7, repeatFrom: 'due');
      expect(nextAfterDone(weekly, today: today).due, DateTime(2026, 10, 22));
    });

    test('fixed reminders finish', () {
      final r = RemInfo(rule: 'fixed', due: DateTime(2026, 11, 3));
      expect(nextAfterDone(r, today: today).done, isTrue);
    });

    test('mileage counts from the current odometer', () {
      const r = RemInfo(rule: 'either', dueKm: 48000, repeatKm: 10000, repeatMonths: 6);
      final n = nextAfterDone(r, today: today, odometer: 48210);
      expect(n.dueKm, 58210);
      expect(n.due, DateTime(2027, 4, 20));
    });
  });

  group('notification plan', () {
    test('lead, due day and weekly overdue follow-ups, sorted and capped', () {
      final now = DateTime(2026, 10, 20, 10);
      final rs = [
        RemInfo(rule: 'fixed', due: DateTime(2026, 11, 3), leadDays: 14), // lead day already passed
        RemInfo(rule: 'fixed', due: DateTime(2026, 11, 10), leadDays: 5),
      ];
      final plan = planNotes(rs, now: now);
      expect(plan.map((p) => p.kind).toList(), ['due', 'overdue', 'lead', 'due', ...List.filled(7, 'overdue')]);
      expect(plan.first.at, DateTime(2026, 11, 3, 9));
      expect(plan.where((p) => p.index == 0 && p.kind == 'overdue').map((p) => p.at).toList(), [
        DateTime(2026, 11, 4, 9),
        DateTime(2026, 11, 11, 9),
        DateTime(2026, 11, 18, 9),
        DateTime(2026, 11, 25, 9),
      ]);
      final many = List.generate(40, (i) => RemInfo(rule: 'fixed', due: DateTime(2027, 1, 1 + i), leadDays: 3));
      expect(planNotes(many, now: now).length, 50);
    });

    test('a reminder that is already overdue keeps its remaining weekly nudges, then goes quiet', () {
      final r = RemInfo(rule: 'fixed', due: DateTime(2026, 10, 10));
      expect(planNotes([r], now: DateTime(2026, 10, 20, 10)).map((p) => p.at).toList(), [
        DateTime(2026, 10, 25, 9),
        DateTime(2026, 11, 1, 9),
      ]);
      expect(planNotes([r], now: DateTime(2026, 11, 2, 10)), isEmpty);
    });

    test('a snoozed overdue reminder is followed up weekly after the snooze', () {
      // Overdue since 10 Oct, snoozed until 23 Oct.
      final r = RemInfo(rule: 'fixed', due: DateTime(2026, 10, 10), snoozedUntil: DateTime(2026, 10, 23));
      final plan = planNotes([r], now: DateTime(2026, 10, 20, 10));
      expect(plan.map((p) => p.at).toList(), [
        DateTime(2026, 10, 23, 9),
        DateTime(2026, 10, 30, 9),
        DateTime(2026, 11, 6, 9),
        DateTime(2026, 11, 13, 9),
      ]);
      expect(plan.map((p) => p.kind).toList(), ['snooze', 'overdue', 'overdue', 'overdue']);
      expect(plan.map((p) => p.slot).toList(), [0, 7, 8, 9]);
    });

    test('a snooze before the due date keeps the due day and its follow-ups', () {
      final r = RemInfo(rule: 'fixed', due: DateTime(2026, 11, 3), leadDays: 14, snoozedUntil: DateTime(2026, 10, 25));
      final plan = planNotes([r], now: DateTime(2026, 10, 20, 10));
      expect(plan.map((p) => p.kind).toList(), ['snooze', 'due', 'overdue', 'overdue', 'overdue', 'overdue']);
      expect(plan[1].at, DateTime(2026, 11, 3, 9));
    });

    test('every notification of a reminder has its own slot', () {
      final plan = planNotes([RemInfo(rule: 'fixed', due: DateTime(2026, 11, 3), leadDays: 7)], now: DateTime(2026, 10, 20, 10));
      expect(plan.map((p) => p.slot).toList(), [1, 2, 3, 4, 5, 6]);
    });

    test('a full window ends with an open-Kukira notice the day after the last one', () {
      final now = DateTime(2026, 10, 20, 10);
      final many = List.generate(20, (i) => RemInfo(rule: 'fixed', due: DateTime(2026, 11, 1 + i), leadDays: 0));
      final plan = planNotes(many, now: now, limit: 5);
      expect(refreshNoticeAt(many, now: now, limit: 5), DateTime(plan.last.at.year, plan.last.at.month, plan.last.at.day + 1, 9));
      expect(refreshNoticeAt(many.take(1).toList(), now: now, limit: 5), isNull);
    });

    test('mileage-only reminders are not time-scheduled', () {
      final plan = planNotes([const RemInfo(rule: 'mileage', dueKm: 1000)], now: DateTime(2026, 10, 20));
      expect(plan, isEmpty);
    });
  });

  test('DLP is 24 months from vacant possession', () {
    expect(dlpEndFrom(DateTime(2025, 3, 15)), DateTime(2027, 3, 15));
  });

  test('presets suggest by property type', () {
    expect(suggestionsFor('house', 'strata').map((p) => p.key), ['maintenanceCharge', 'cukaiTaksiran', 'cukaiPetak']);
    expect(suggestionsFor('house', 'landed').map((p) => p.key), contains('houseInsurance'));
    expect(nextTaksiran(today), DateTime(2027, 2, 28));
    expect(nextOn(today, 5, 31), DateTime(2027, 5, 31));
  });

  test('every preset has text in both languages', () {
    for (final lang in ['ms', 'en']) {
      final s = strFor(lang);
      for (final c in ['house', 'car', 'motorcycle']) {
        for (final p in [...suggestionsFor(c, 'landed'), ...templatesFor(c, 'strata'), ...templatesFor(c, 'landed')]) {
          expect(p.title(s), isNot(p.key), reason: '$lang ${p.key}');
        }
      }
    }
    expect(strFor('ms').km(48210), '48,210 km');
    expect(strFor('en').rm(18500), 'RM 18,500.00');
  });
}
