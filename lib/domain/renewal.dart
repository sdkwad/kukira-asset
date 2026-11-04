// Renewing a vehicle's road tax or insurance: the suggested period, worked out from the
// current end date and the last period on record. Pure, so it is unit tested; saving is
// lib/services/renewal.dart.

import 'rules.dart';

/// The two covers a vehicle renews.
enum RenewKind { roadTax, insurance }

/// The record category a renewal is saved under (the same as the reminders use).
String renewCategory(RenewKind k) => k == RenewKind.roadTax ? 'road_tax' : 'insurance_premium';

/// The last day of a cover of [months] starting on [start]: the day before the same date
/// [months] later (13 Nov 2026 for 12 months ends 12 Nov 2027). When that month is too short
/// for the date (31 Aug plus 6 months), the cover runs to its last day (28 Feb).
DateTime coverEnd(DateTime start, int months) {
  final from = dayOnly(start);
  final same = addMonths(from, months);
  if (same.day < from.day) return same;
  return DateTime(same.year, same.month, same.day - 1);
}

/// How many months a cover from [start] to [end] (both included) lasts, to the nearest
/// month: 13 Nov 2025 to 12 Nov 2026 is 12.
int coverMonths(DateTime start, DateTime end) {
  final days = daysBetween(start, end) + 1;
  final m = (days / 30.44).round();
  return m < 1 ? 1 : m;
}

/// What the renewal form starts with.
class RenewSuggestion {
  const RenewSuggestion({required this.months, required this.start, required this.end, required this.fromHistory});
  final int months;
  final DateTime start;
  final DateTime end;

  /// [months] is the length of the last period on record, not the usual 12.
  final bool fromHistory;
}

/// How long a cover lapsed may have been and still be renewed from the day after it ended.
/// Past that, the new cover is suggested from today. Both dates stay editable: the rules
/// for back-dating differ, so the form says to check the e-LKM or the policy.
const renewFollowOnDays = 30;

/// The suggested renewal of a cover ending [currentEnd] (null if never set), whose last
/// period on record started [lastStart] (null if there is none).
RenewSuggestion suggestRenewal({required DateTime? currentEnd, required DateTime? lastStart, required DateTime today}) {
  final t = dayOnly(today);
  var months = 12;
  var known = false;
  if (currentEnd != null && lastStart != null && !dayOnly(lastStart).isAfter(dayOnly(currentEnd))) {
    months = coverMonths(lastStart, currentEnd);
    known = true;
  }
  var start = t;
  if (currentEnd != null && daysBetween(dayOnly(currentEnd), t) <= renewFollowOnDays) {
    start = DateTime(currentEnd.year, currentEnd.month, currentEnd.day + 1);
  }
  return RenewSuggestion(months: months, start: start, end: coverEnd(start, months), fromHistory: known);
}

/// From how many days before the end the asset page offers Renew on the row itself.
const renewSoonDays = 60;

/// Whether road tax and insurance end close enough together to offer renewing both at once.
bool renewTogether(DateTime? roadTaxEnd, DateTime? insuranceEnd) =>
    roadTaxEnd != null && insuranceEnd != null && daysBetween(roadTaxEnd, insuranceEnd).abs() <= 31;
