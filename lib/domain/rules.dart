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
  if (r.usesDate && months > 0) {
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

class PlannedNote {
  const PlannedNote(this.at, this.kind, this.index);
  final DateTime at;

  /// lead | due | overdue | snooze
  final String kind;

  /// Index into the list passed to [planNotes].
  final int index;
}

/// The rolling notification window. The OS schedule is disposable: it is rebuilt
/// from the database on app open and after every change. Mileage reminders cannot be
/// scheduled by time; they are checked when the odometer is updated.
List<PlannedNote> planNotes(List<RemInfo> rs, {required DateTime now, int hour = 9, int limit = 50}) {
  DateTime at(DateTime d) => DateTime(d.year, d.month, d.day, hour);
  final out = <PlannedNote>[];
  for (var i = 0; i < rs.length; i++) {
    final r = rs[i];
    if (r.done || !r.usesDate || r.due == null) continue;
    if (r.snoozedUntil != null && at(r.snoozedUntil!).isAfter(now)) {
      out.add(PlannedNote(at(r.snoozedUntil!), 'snooze', i));
      continue;
    }
    final due = at(r.due!);
    final lead = due.subtract(Duration(days: r.leadDays));
    if (r.leadDays > 0 && lead.isAfter(now)) out.add(PlannedNote(lead, 'lead', i));
    if (due.isAfter(now)) out.add(PlannedNote(due, 'due', i));
    // One follow-up the day after it becomes overdue; after that it stays on Today.
    final follow = due.add(const Duration(days: 1));
    if (follow.isAfter(now)) out.add(PlannedNote(follow, 'overdue', i));
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out.length > limit ? out.sublist(0, limit) : out;
}

/// Defect liability period: 24 months from vacant possession (Schedule G/H SPAs). An estimate.
DateTime dlpEndFrom(DateTime vp) => addMonths(dayOnly(vp), 24);
