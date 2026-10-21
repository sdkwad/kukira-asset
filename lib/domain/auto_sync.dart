// Reminders that follow a date field (road tax expiry, insurance expiry, DLP end).
// Pure Dart: decides what should happen to the one linked reminder when the date changes.

import 'rules.dart';

/// Date fields that keep a linked reminder. Stored in Reminders.autoSource.
const autoRoadTax = 'roadTax';
const autoInsurance = 'insurance';
const autoDlp = 'dlp';

enum AutoKind { none, create, update, delete }

/// The state of the existing linked reminder, if there is one.
class LinkedState {
  const LinkedState({this.due, this.done = false, this.snoozedUntil});
  final DateTime? due;
  final bool done;
  final DateTime? snoozedUntil;
}

class AutoPlan {
  const AutoPlan(this.kind, {this.due, this.reopens = false, this.clearsSnooze = false});
  final AutoKind kind;
  final DateTime? due;

  /// The linked reminder was marked done and would be reopened.
  final bool reopens;

  /// The linked reminder is snoozed and the snooze would be cleared.
  final bool clearsSnooze;

  /// The user must be told and asked before this plan touches their reminder.
  bool get needsConfirm => reopens || clearsSnooze;

  static const nothing = AutoPlan(AutoKind.none);
}

/// What to do with the linked reminder when a date field goes from [oldDate] to [newDate].
///
/// - Setting a date creates the reminder; changing it updates the same one; clearing it deletes it.
/// - An unchanged date never creates a reminder, so one the user deleted does not come back,
///   and saving twice never makes a duplicate.
/// - Reopening a completed reminder or clearing a snooze is flagged with [AutoPlan.needsConfirm].
AutoPlan planAuto({required DateTime? oldDate, required DateTime? newDate, required LinkedState? existing, required DateTime today}) {
  final n = newDate == null ? null : dayOnly(newDate);
  final o = oldDate == null ? null : dayOnly(oldDate);
  final t = dayOnly(today);
  if (n == null) return existing == null ? AutoPlan.nothing : const AutoPlan(AutoKind.delete);
  final changed = o == null || o != n;
  if (existing == null) return changed ? AutoPlan(AutoKind.create, due: n) : AutoPlan.nothing;

  final snoozed = existing.snoozedUntil != null && dayOnly(existing.snoozedUntil!).isAfter(t);
  final sameDue = existing.due != null && dayOnly(existing.due!) == n;
  if (!changed) {
    // Keep it in step if it drifted, but never touch a completed or snoozed reminder unasked.
    if (!sameDue && !existing.done && !snoozed) return AutoPlan(AutoKind.update, due: n);
    return AutoPlan.nothing;
  }
  if (sameDue && !existing.done) return AutoPlan.nothing;
  return AutoPlan(AutoKind.update, due: n, reopens: existing.done, clearsSnooze: snoozed);
}

/// The DLP end that the linked reminder follows: the owner's correction, else 24 months from VP.
/// Null when there is no VP date or the DLP has already ended.
DateTime? activeDlpEnd({required DateTime? vp, required DateTime? override, required DateTime today}) {
  if (vp == null) return null;
  final end = override ?? dlpEndFrom(vp);
  return dayOnly(end).isAfter(dayOnly(today)) ? end : null;
}
