// Rent tracking for a let house (0.3, F3). Pure Dart: which months a tenancy covers, whether
// each was paid on time, what is still owed, and the dates the linked reminders follow.

import '../data/db.dart';
import 'rules.dart';

/// A month as one number: year * 100 + month (202612 is December 2026).
int monthKey(DateTime d) => d.year * 100 + d.month;

/// The first day of month [key].
DateTime monthStart(int key) => DateTime(key ~/ 100, key % 100);

/// The month after [key].
int nextMonth(int key) => monthKey(DateTime(key ~/ 100, key % 100 + 1));

/// Rent for month [key] is due on [dueDay], or on the last day of a shorter month.
DateTime rentDueOn(int key, int? dueDay) {
  final start = monthStart(key);
  final last = DateTime(start.year, start.month + 1, 0).day;
  final day = (dueDay ?? 1).clamp(1, last);
  return DateTime(start.year, start.month, day);
}

enum MonthState {
  /// Paid on or before the due date.
  paid,

  /// Paid, after the due date.
  late,

  /// The due date has passed and it is not paid.
  unpaid,

  /// Not due yet.
  upcoming,

  /// Before the tenancy was added to Kukira and not marked: not tracked, so not owed.
  untracked,

  /// Outside the tenancy.
  outside,
}

/// The first month whose rent is owed under [t]: the start month, or, for a tenancy added
/// to Kukira after it began, the month it was added (earlier months can still be marked).
int? trackedFrom(Tenancy t) {
  final start = t.startDate;
  if (start == null) return null;
  final s = monthKey(start);
  final added = monthKey(t.createdAt);
  return added > s ? added : s;
}

/// The last month of [t]: when it ended, else its end date, else none (still running).
int? lastMonth(Tenancy t) {
  final end = t.endedOn ?? t.endDate;
  return end == null ? null : monthKey(end);
}

bool covers(Tenancy t, int key) {
  final start = t.startDate;
  if (start == null || key < monthKey(start)) return false;
  final last = lastMonth(t);
  return last == null || key <= last;
}

MonthState monthState(Tenancy t, int key, RentPayment? paid, {required DateTime today}) {
  if (!covers(t, key)) return MonthState.outside;
  final due = rentDueOn(key, t.dueDay);
  if (paid != null) return dayOnly(paid.paidOn).isAfter(due) ? MonthState.late : MonthState.paid;
  final from = trackedFrom(t);
  if (from == null || key < from) return MonthState.untracked;
  // Owed from the day after the due date; on the day itself it can still come in.
  return dayOnly(today).isAfter(due) ? MonthState.unpaid : MonthState.upcoming;
}

RentPayment? paymentFor(List<RentPayment> payments, int key) => payments.where((p) => p.month == key).firstOrNull;

/// The oldest month still owed (unpaid, or not due yet), from the month tracking starts to
/// the end of the tenancy. Null when everything is paid to the end, or nothing is tracked.
int? oldestOwed(Tenancy t, List<RentPayment> payments, {required DateTime today}) {
  final from = trackedFrom(t);
  if (from == null) return null;
  final last = lastMonth(t);
  // A running tenancy is looked at up to the month after this one.
  final until = last ?? nextMonth(monthKey(today));
  final paid = {for (final p in payments) p.month};
  var key = from;
  while (key <= until) {
    if (!paid.contains(key)) return key;
    key = nextMonth(key);
  }
  return null;
}

/// How long after the due date unpaid rent is notified (the owner's choice: 7 days).
const rentGraceDays = 7;

/// A year of a tenancy at a glance.
class RentYear {
  const RentYear({required this.received, required this.owedMonths, required this.owedAmount, required this.paidMonths, required this.dueMonths, this.nextDue});

  /// What was received for the months of this year.
  final double received;

  /// Months of this year whose due date has passed unpaid, and what they come to (null when
  /// the rent is not known).
  final int owedMonths;
  final double? owedAmount;

  /// Months of this year paid, out of those already due.
  final int paidMonths;
  final int dueMonths;

  /// The next due date still to be paid.
  final DateTime? nextDue;
}

RentYear rentYear(Tenancy t, List<RentPayment> payments, int year, {required DateTime today}) {
  var received = 0.0;
  var owed = 0;
  var paid = 0;
  var due = 0;
  for (var m = 1; m <= 12; m++) {
    final key = year * 100 + m;
    final p = paymentFor(payments, key);
    final st = monthState(t, key, p, today: today);
    if (p != null && covers(t, key)) received += p.amount ?? t.rent ?? 0;
    switch (st) {
      case MonthState.paid || MonthState.late:
        paid++;
        due++;
      case MonthState.unpaid:
        owed++;
        due++;
      default:
        break;
    }
  }
  final next = oldestOwed(t, payments, today: today);
  return RentYear(
    received: received,
    owedMonths: owed,
    owedAmount: t.rent == null ? null : owed * t.rent!,
    paidMonths: paid,
    dueMonths: due,
    nextDue: next == null ? null : rentDueOn(next, t.dueDay),
  );
}

/// The tenancy that is running now (or about to start): the latest one not ended.
Tenancy? currentTenancy(List<Tenancy> all, int assetId) {
  final mine = all.where((t) => t.assetId == assetId && t.endedOn == null).toList()
    ..sort((a, b) => (b.startDate ?? b.createdAt).compareTo(a.startDate ?? a.createdAt));
  return mine.firstOrNull;
}

/// A tenancy agreement must be stamped within 30 days of signing (Stamp Act 1949 s.47; at
/// LHDN through e-Duti Setem on MyTax). An estimate to confirm with LHDN. Null once stamped.
DateTime? stampDue(Tenancy t) => t.signedOn == null || t.stampedOn != null ? null : dayOnly(t.signedOn!).add(const Duration(days: 30));

/// When the deposit of an ended tenancy should be settled: 14 days after it ended, unless
/// returned. An estimate: the agreement decides.
DateTime? depositDue(Tenancy t) {
  if ((t.deposit ?? 0) <= 0 || t.depositReturnedOn != null) return null;
  final ended = t.endedOn;
  return ended == null ? null : dayOnly(ended).add(const Duration(days: 14));
}
