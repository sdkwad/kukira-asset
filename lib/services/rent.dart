// Saving tenancies and rent payments (0.3, F3), and the reminders a let house follows. Every
// change runs in one transaction with [syncRent], so the reminders never fall out of step.

import 'package:drift/drift.dart' show BooleanExpressionOperators, InsertMode, Value;

import '../data/db.dart';
import '../domain/rent.dart';
import '../domain/rules.dart';
import '../l10n/strings.dart';
import 'error_log.dart';

/// The reminders a let house keeps, in Reminders.autoSource.
const autoRent = 'rent';
const autoRentStamp = 'rentStamp';
const autoTenancyEnd = 'tenancyEnd';
const autoDeposit = 'deposit';

const rentSources = {autoRent, autoRentStamp, autoTenancyEnd, autoDeposit};

/// Brings the house's rent reminders in step with its tenancies:
/// - rent: the oldest month still owed, notified [rentGraceDays] after its due date;
/// - stamping: 30 days after the agreement was signed, until it is stamped;
/// - end: 60 days before the agreed end, until the tenancy is ended;
/// - deposit: 14 days after the last tenancy ended, until the deposit is settled.
Future<void> syncRent(AppDb db, Str s, int assetId, {DateTime? today}) async {
  final all = await (db.select(db.tenancies)..where((t) => t.assetId.equals(assetId))).get();
  final cur = currentTenancy(all, assetId);
  final pays = cur == null ? <RentPayment>[] : await (db.select(db.rentPayments)..where((p) => p.tenancyId.equals(cur.id))).get();
  final owed = cur == null ? null : oldestOwed(cur, pays, today: dayOnly(today ?? DateTime.now()));
  final ended = all.where((t) => t.endedOn != null).toList()..sort((a, b) => b.endedOn!.compareTo(a.endedOn!));

  await _keep(db, assetId, autoRent,
      due: owed == null ? null : rentDueOn(owed, cur!.dueDay).add(const Duration(days: rentGraceDays)),
      title: owed == null ? '' : s.rentUnpaidTitle(s.monthYear(owed)),
      lead: 0);
  await _keep(db, assetId, autoRentStamp,
      due: cur == null ? null : stampDue(cur), title: s.rentStampTitle, lead: 7, estimated: true, note: s.rentStampNote, confirm: s.rentStampConfirm);
  await _keep(db, assetId, autoTenancyEnd, due: cur?.endDate, title: s.tenancyEndTitle, lead: 60);
  await _keep(db, assetId, autoDeposit, due: ended.isEmpty ? null : depositDue(ended.first), title: s.depositTitle, lead: 7, note: s.depositNote);
}

/// The one reminder of [source] on the asset: made when [due] is set, moved when [due] or its
/// title changes (a new date is a new thing to do, so it is brought back if it was done or
/// snoozed), and removed when [due] is null. An unchanged one is left as it is.
Future<void> _keep(AppDb db, int assetId, String source,
    {required DateTime? due, required String title, required int lead, bool estimated = false, String? note, String? confirm}) async {
  final existing = await (db.select(db.reminders)..where((r) => r.assetId.equals(assetId) & r.autoSource.equals(source))).get();
  if (due == null) {
    for (final r in existing) {
      await db.deleteReminder(r.id);
    }
    return;
  }
  final d = dayOnly(due);
  if (existing.isEmpty) {
    await db.addReminder(RemindersCompanion(
      assetId: Value(assetId),
      title: Value(title),
      category: const Value('rent'),
      ruleType: const Value('fixed'),
      dueDate: Value(d),
      leadDays: Value(lead),
      source: const Value('auto'),
      estimated: Value(estimated),
      note: Value(note),
      confirmWith: Value(confirm),
      autoSource: Value(source),
    ));
    return;
  }
  for (final extra in existing.skip(1)) {
    await db.deleteReminder(extra.id);
  }
  final r = existing.first;
  if (r.dueDate != null && dayOnly(r.dueDate!) == d && r.title == title) return;
  await db.updateReminder(r.id, RemindersCompanion(title: Value(title), dueDate: Value(d), done: const Value(false), snoozedUntil: const Value(null)));
}

/// Rent reminders for every house, for instance after an upgrade moved an old tenancy over.
Future<void> syncAllRent(AppDb db, Str s) async {
  try {
    final houses = {for (final t in await db.select(db.tenancies).get()) t.assetId};
    for (final id in houses) {
      await db.transaction(() => syncRent(db, s, id));
    }
  } catch (e) {
    ErrorLog.record('rent.sync', e);
  }
}

/// Adds a tenancy ([id] null) or changes one, and its reminders, in one transaction.
Future<int> saveTenancy(AppDb db, Str s, int assetId, TenanciesCompanion c, {int? id}) => db.transaction(() async {
      final c2 = c.copyWith(assetId: Value(assetId));
      final tid = id ?? await db.into(db.tenancies).insert(c2);
      if (id != null) await (db.update(db.tenancies)..where((t) => t.id.equals(id))).write(c2);
      await syncRent(db, s, assetId);
      return tid;
    });

/// Marks month [month] of [t] paid on [paidOn] (the full rent unless [amount] says otherwise).
Future<void> markPaid(AppDb db, Str s, Tenancy t, int month, {required DateTime paidOn, double? amount, String? notes}) => db.transaction(() async {
      await db.into(db.rentPayments).insert(
            RentPaymentsCompanion(tenancyId: Value(t.id), month: Value(month), paidOn: Value(dayOnly(paidOn)), amount: Value(amount ?? t.rent), notes: Value(notes)),
            mode: InsertMode.insertOrReplace,
          );
      await syncRent(db, s, t.assetId);
    });

/// Takes back a payment marked by mistake.
Future<void> unmarkPaid(AppDb db, Str s, Tenancy t, int month) => db.transaction(() async {
      await (db.delete(db.rentPayments)..where((p) => p.tenancyId.equals(t.id) & p.month.equals(month))).go();
      await syncRent(db, s, t.assetId);
    });

/// Ends a tenancy on [on]. It stays in the history with all its payments.
Future<void> endTenancy(AppDb db, Str s, Tenancy t, {required DateTime on}) => db.transaction(() async {
      await (db.update(db.tenancies)..where((x) => x.id.equals(t.id))).write(TenanciesCompanion(endedOn: Value(dayOnly(on))));
      await syncRent(db, s, t.assetId);
    });

/// Records that the deposit of [t] was settled on [on].
Future<void> settleDeposit(AppDb db, Str s, Tenancy t, {required DateTime on}) => db.transaction(() async {
      await (db.update(db.tenancies)..where((x) => x.id.equals(t.id))).write(TenanciesCompanion(depositReturnedOn: Value(dayOnly(on))));
      await syncRent(db, s, t.assetId);
    });

/// Records that the agreement of [t] was stamped on [on].
Future<void> markStamped(AppDb db, Str s, Tenancy t, {required DateTime on}) => db.transaction(() async {
      await (db.update(db.tenancies)..where((x) => x.id.equals(t.id))).write(TenanciesCompanion(stampedOn: Value(dayOnly(on))));
      await syncRent(db, s, t.assetId);
    });

/// Deletes a tenancy added by mistake, with its payments.
Future<void> deleteTenancy(AppDb db, Str s, Tenancy t) => db.transaction(() async {
      await (db.delete(db.tenancies)..where((x) => x.id.equals(t.id))).go();
      await syncRent(db, s, t.assetId);
    });
