// Reminder rules. Pure Dart with no Flutter or database imports, so it can be unit tested.
//
// The database is the source of truth. Status is always calculated from the
// stored due date / due odometer, never stored.

enum RStatus { overdue, dueSoon, upcoming, done }

/// How far ahead "Due soon" looks on the Today screen.
const dueSoonDays = 30;

class RemInfo {
  const RemInfo({
    required this.rule,
    this.due,
    this.dueKm,
    this.repeatMonths,
    this.repeatKm,
    this.repeatDays,
    this.repeatFrom = 'completion',
    this.leadDays = 7,
    this.leadKm = 1000,
    this.done = false,
    this.snoozedUntil,
  });

  /// fixed | repeat | mileage | either (whichever comes first)
  final String rule;
  final DateTime? due;
  final int? dueKm;
  final int? repeatMonths;
  final int? repeatKm;
  final int? repeatDays;

  /// completion | due
  final String repeatFrom;
  final int leadDays;
  final int leadKm;
  final bool done;
  final DateTime? snoozedUntil;

  bool get usesDate => rule != 'mileage';
  bool get usesKm => rule == 'mileage' || rule == 'either';
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysBetween(DateTime a, DateTime b) =>
    (dayOnly(b).difference(dayOnly(a)).inHours / 24).round();

/// Adds calendar months, clamping to the last day (31 Aug + 6 months = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final y = d.year + (total ~/ 12);
  final m = total % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > last ? last : d.day);
}

RStatus statusOf(RemInfo r, {required DateTime today, int? odometer}) {
  if (r.done) return RStatus.done;
  final t = dayOnly(today);
  if (r.snoozedUntil != null && dayOnly(r.snoozedUntil!).isAfter(t)) {
    return RStatus.dueSoon;
  }
  var level = 0; // 0 upcoming, 1 due soon, 2 overdue
  if (r.usesDate && r.due != null) {
    final n = daysBetween(t, r.due!);
    final soon = r.leadDays > dueSoonDays ? r.leadDays : dueSoonDays;
    final l = n < 0 ? 2 : (n <= soon ? 1 : 0);
    if (l > level) level = l;
  }
  if (r.usesKm && r.dueKm != null && odometer != null) {
    final left = r.dueKm! - odometer;
    final l = left <= 0 ? 2 : (left <= r.leadKm ? 1 : 0);
    if (l > level) level = l;
  }
  return level == 2
      ? RStatus.overdue
      : level == 1
          ? RStatus.dueSoon
          : RStatus.upcoming;
}

class NextDue {
  const NextDue({this.due, this.dueKm, required this.done});
  final DateTime? due;
  final int? dueKm;

  /// True when nothing repeats, so the reminder is finished.
  final bool done;
}

/// What happens when the user marks a reminder done on [today].
/// By default the next one counts from completion; tax presets count from the previous due date.
NextDue nextAfterDone(RemInfo r, {required DateTime today, int? odometer}) {
  if (r.rule == 'fixed') return NextDue(due: r.due, dueKm: r.dueKm, done: true);
  final t = dayOnly(today);
  var due = r.due;
  var dueKm = r.dueKm;
  var repeats = false;

  final months = r.repeatMonths ?? 0;
  final everyDays = r.repeatDays ?? 0;
  if (r.usesDate && everyDays > 0 && months == 0) {
    final base = (r.repeatFrom == 'due' && r.due != null) ? dayOnly(r.due!) : t;
    var next = base.add(Duration(days: everyDays));
    while (!next.isAfter(t)) {
      next = next.add(Duration(days: everyDays));
    }
    due = DateTime(next.year, next.month, next.day);
    repeats = true;
  } else if (r.usesDate && months > 0) {
    final base = (r.repeatFrom == 'due' && r.due != null) ? dayOnly(r.due!) : t;
    var k = 1;
    var next = addMonths(base, months * k);
    while (!next.isAfter(t)) {
      k++;
      next = addMonths(base, months * k);
    }
    due = next;
    repeats = true;
  }

  final km = r.repeatKm ?? 0;
  if (r.usesKm && km > 0) {
    final base = (r.repeatFrom == 'due' && r.dueKm != null) ? r.dueKm! : (odometer ?? r.dueKm ?? 0);
    var next = base + km;
    if (odometer != null) {
      while (next <= odometer) {
        next += km;
      }
    }
    dueKm = next;
    repeats = true;
  }
  return NextDue(due: due, dueKm: dueKm, done: !repeats);
}

/// The day the first notification goes out (due date minus lead time), for date-based reminders.
DateTime? firstNotice(RemInfo r) =>
    r.usesDate && r.due != null ? dayOnly(r.due!).subtract(Duration(days: r.leadDays)) : null;

/// Overdue follow-ups, in days after the due date: the next day, then weekly, four in all.
/// After about four weeks the reminder stays on Today without more notifications.
const overdueNudgeDays = [1, 8, 15, 22];

/// Follow-ups after a snooze ends on a reminder that is overdue by then: the snooze
/// notification itself, then weekly, four in all, like [overdueNudgeDays].
const snoozeNudgeDays = [7, 14, 21];

class PlannedNote {
  const PlannedNote(this.at, this.kind, this.index, [this.slot = 0]);
  final DateTime at;

  /// lead | due | overdue | snooze
  final String kind;

  /// Index into the list passed to [planNotes].
  final int index;

  /// Which of the reminder's notifications this is, 0 to 9, so each one keeps the same
  /// notification id when the schedule is rebuilt: 0 snooze, 1 lead, 2 due,
  /// 3 to 6 overdue follow-ups, 7 to 9 follow-ups after a snooze.
  final int slot;
}

/// The rolling notification window. The OS schedule is disposable: it is rebuilt
/// from the database on app open and after every change. Mileage reminders cannot be
/// scheduled by time; they are checked when the odometer is updated.
List<PlannedNote> planNotes(List<RemInfo> rs, {required DateTime now, int hour = 9, int minute = 0, int limit = 50}) {
  final all = _allNotes(rs, now: now, hour: hour, minute: minute);
  return all.length > limit ? all.sublist(0, limit) : all;
}

/// When the window of [limit] notifications is full and more are due later, the time for
/// one "open Kukira" notice: the day after the last scheduled one. Opening the app then
/// schedules the rest. Null when everything fits.
DateTime? refreshNoticeAt(List<RemInfo> rs, {required DateTime now, int hour = 9, int minute = 0, required int limit}) {
  final all = _allNotes(rs, now: now, hour: hour, minute: minute);
  if (all.length <= limit) return null;
  final last = all[limit - 1].at;
  return DateTime(last.year, last.month, last.day + 1, hour, minute);
}

List<PlannedNote> _allNotes(List<RemInfo> rs, {required DateTime now, required int hour, required int minute}) {
  DateTime at(DateTime d) => DateTime(d.year, d.month, d.day, hour, minute);
  final out = <PlannedNote>[];
  for (var i = 0; i < rs.length; i++) {
    final r = rs[i];
    if (r.done || !r.usesDate || r.due == null) continue;
    final due = at(r.due!);
    final snooze = r.snoozedUntil != null && at(r.snoozedUntil!).isAfter(now) ? at(r.snoozedUntil!) : null;
    // Nothing is sent before a snooze ends.
    final from = snooze ?? now;
    if (snooze != null) out.add(PlannedNote(snooze, 'snooze', i, 0));
    final lead = due.subtract(Duration(days: r.leadDays));
    if (r.leadDays > 0 && lead.isAfter(from)) out.add(PlannedNote(lead, 'lead', i, 1));
    if (due.isAfter(from)) out.add(PlannedNote(due, 'due', i, 2));
    // A missed, swiped-away or snoozed notification must not leave an overdue reminder silent.
    if (snooze != null && !snooze.isBefore(due)) {
      for (var k = 0; k < snoozeNudgeDays.length; k++) {
        out.add(PlannedNote(snooze.add(Duration(days: snoozeNudgeDays[k])), 'overdue', i, 7 + k));
      }
    } else {
      for (var k = 0; k < overdueNudgeDays.length; k++) {
        final follow = due.add(Duration(days: overdueNudgeDays[k]));
        if (follow.isAfter(from)) out.add(PlannedNote(follow, 'overdue', i, 3 + k));
      }
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// Defect liability period: 24 months from vacant possession (Schedule G/H SPAs). An estimate.
DateTime dlpEndFrom(DateTime vp) => addMonths(dayOnly(vp), 24);
