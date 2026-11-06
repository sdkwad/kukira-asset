// Rent tracking (0.3, F3): which months a tenancy owes, paid on time or late, the year at a
// glance, and the reminders a let house keeps (rent unpaid 7 days after it is due, stamping
// within 30 days, the end of the agreement, the deposit).

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/rent.dart';
import 'package:kukira_asset/domain/rules.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/backup.dart';
import 'package:kukira_asset/services/rent.dart';

import 'helpers.dart';

Tenancy tenancy({DateTime? start, DateTime? end, DateTime? ended, int? dueDay = 5, double? rent = 1800, DateTime? added, DateTime? signed, DateTime? stamped, double? deposit, DateTime? depositBack}) =>
    Tenancy(
      id: 1,
      assetId: 1,
      startDate: start ?? DateTime(2026, 1, 1),
      endDate: end,
      endedOn: ended,
      dueDay: dueDay,
      rent: rent,
      deposit: deposit,
      signedOn: signed,
      stampedOn: stamped,
      depositReturnedOn: depositBack,
      createdAt: added ?? DateTime(2025, 12, 20),
    );

RentPayment paid(int month, DateTime on, {double? amount}) => RentPayment(id: month, tenancyId: 1, month: month, paidOn: on, amount: amount);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('ms');

  group('months', () {
    test('are counted across the turn of the year', () {
      expect(monthKey(DateTime(2026, 12, 9)), 202612);
      expect(nextMonth(202612), 202701);
      expect(monthStart(202702), DateTime(2027, 2));
      expect(s.monthYear(202612), 'Dis 2026');
    });

    test('rent due on the 31st falls on the last day of a shorter month', () {
      expect(rentDueOn(202602, 31), DateTime(2026, 2, 28));
      expect(rentDueOn(202603, 31), DateTime(2026, 3, 31));
      expect(rentDueOn(202603, null), DateTime(2026, 3, 1));
    });
  });

  group('a month is', () {
    final t = tenancy(end: DateTime(2026, 12, 31));
    final today = DateTime(2026, 6, 10);

    test('paid, or paid late after the due date', () {
      expect(monthState(t, 202605, paid(202605, DateTime(2026, 5, 5)), today: today), MonthState.paid);
      expect(monthState(t, 202605, paid(202605, DateTime(2026, 5, 9)), today: today), MonthState.late);
    });

    test('unpaid once the due date has passed, and not before', () {
      expect(monthState(t, 202606, null, today: DateTime(2026, 6, 5)), MonthState.upcoming, reason: 'it can still come in on the day');
      expect(monthState(t, 202606, null, today: DateTime(2026, 6, 6)), MonthState.unpaid);
      expect(monthState(t, 202607, null, today: today), MonthState.upcoming);
    });

    test('outside the tenancy before its start and after its end', () {
      expect(monthState(t, 202512, null, today: today), MonthState.outside);
      expect(monthState(t, 202701, null, today: today), MonthState.outside);
      final moved = tenancy(end: DateTime(2026, 12, 31), ended: DateTime(2026, 8, 15));
      expect(monthState(moved, 202609, null, today: today), MonthState.outside, reason: 'it ended early');
    });

    test('not owed when it is from before the tenancy was added to Kukira', () {
      final late = tenancy(start: DateTime(2025, 1, 1), added: DateTime(2026, 6, 1));
      expect(monthState(late, 202503, null, today: today), MonthState.untracked);
      expect(monthState(late, 202503, paid(202503, DateTime(2025, 3, 5)), today: today), MonthState.paid, reason: 'it can still be marked');
      expect(monthState(late, 202605, null, today: today), MonthState.untracked);
      expect(monthState(late, 202606, null, today: today), MonthState.unpaid);
    });
  });

  group('what is owed', () {
    test('is the oldest month not paid, up to the month after this one', () {
      final t = tenancy();
      final today = DateTime(2026, 3, 20);
      expect(oldestOwed(t, [paid(202601, DateTime(2026, 1, 5))], today: today), 202602);
      final upToApril = [for (final m in [202601, 202602, 202603, 202604]) paid(m, DateTime(2026, 1, 5))];
      expect(oldestOwed(t, upToApril, today: today), isNull, reason: 'paid ahead');
    });

    test('ends with the tenancy', () {
      final t = tenancy(end: DateTime(2026, 2, 28));
      expect(oldestOwed(t, [paid(202601, DateTime(2026, 1, 5)), paid(202602, DateTime(2026, 2, 5))], today: DateTime(2026, 6, 1)), isNull);
    });

    test('adds up for the year', () {
      final t = tenancy();
      final y = rentYear(t, [paid(202601, DateTime(2026, 1, 5)), paid(202602, DateTime(2026, 2, 8), amount: 1700)], 2026, today: DateTime(2026, 4, 10));
      expect(y.received, 3500);
      expect(y.paidMonths, 2);
      expect(y.dueMonths, 4);
      expect(y.owedMonths, 2);
      expect(y.owedAmount, 3600);
      expect(y.nextDue, DateTime(2026, 5, 5), reason: 'March and April are owed; May is the next one ahead');
    });
  });

  test('stamping is due 30 days after signing, and settling a deposit 14 days after the end', () {
    expect(stampDue(tenancy(signed: DateTime(2026, 1, 2))), DateTime(2026, 2, 1));
    expect(stampDue(tenancy(signed: DateTime(2026, 1, 2), stamped: DateTime(2026, 1, 20))), isNull);
    expect(depositDue(tenancy(deposit: 5400, ended: DateTime(2026, 8, 15))), DateTime(2026, 8, 29));
    expect(depositDue(tenancy(deposit: 5400, ended: DateTime(2026, 8, 15), depositBack: DateTime(2026, 8, 20))), isNull);
    expect(depositDue(tenancy(deposit: 5400)), isNull, reason: 'still running');
  });

  group('the reminders', () {
    late AppDb db;
    late int house;
    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      house = await db.createAsset(category: 'house', nickname: 'Rumah Setia Alam', propertyType: 'landed');
    });
    tearDown(() => db.close());

    Future<Map<String, Reminder>> rems() async => {for (final r in await db.select(db.reminders).get()) r.autoSource!: r};
    final thisMonth = monthKey(DateTime.now());

    test('follow the tenancy: rent, stamping, the end, then the deposit', () async {
      final signed = dayOnly(DateTime.now());
      final id = await saveTenancy(db, s, house, TenanciesCompanion(
        tenantName: const Value('Encik Hafiz'),
        startDate: Value(monthStart(thisMonth)),
        endDate: Value(addMonths(monthStart(thisMonth), 12)),
        rent: const Value(1800),
        dueDay: const Value(1),
        deposit: const Value(5400),
        signedOn: Value(signed),
      ));
      var r = await rems();
      expect(r.keys, containsAll([autoRent, autoRentStamp, autoTenancyEnd]));
      expect(r[autoRent]!.dueDate, rentDueOn(thisMonth, 1).add(const Duration(days: 7)), reason: 'notified a week after it is due');
      expect(r[autoRent]!.leadDays, 0);
      expect(r[autoRent]!.title, s.rentUnpaidTitle(s.monthYear(thisMonth)));
      expect(r[autoRentStamp]!.dueDate, signed.add(const Duration(days: 30)));
      expect(r[autoRentStamp]!.estimated, isTrue);
      expect(r[autoTenancyEnd]!.leadDays, 60);

      final t = (await db.select(db.tenancies).get()).single;
      expect(t.id, id);
      await markPaid(db, s, t, thisMonth, paidOn: DateTime.now());
      r = await rems();
      expect(r[autoRent]!.title, s.rentUnpaidTitle(s.monthYear(nextMonth(thisMonth))), reason: 'moves on to the next month');
      final payment = (await db.select(db.rentPayments).get()).single;
      expect(payment.amount, 1800, reason: 'the full rent unless said otherwise');

      await unmarkPaid(db, s, t, thisMonth);
      expect((await rems())[autoRent]!.title, s.rentUnpaidTitle(s.monthYear(thisMonth)));

      await markStamped(db, s, t, on: DateTime.now());
      expect((await rems()).containsKey(autoRentStamp), isFalse);

      await endTenancy(db, s, t, on: DateTime.now());
      r = await rems();
      expect(r.keys, isNot(anyOf(contains(autoRent), contains(autoTenancyEnd))));
      expect(r[autoDeposit]!.dueDate, dayOnly(DateTime.now()).add(const Duration(days: 14)));
      expect((await db.select(db.tenancies).get()).single.endedOn, isNotNull, reason: 'kept in the history');

      await settleDeposit(db, s, (await db.select(db.tenancies).get()).single, on: DateTime.now());
      expect(await rems(), isEmpty);
    });

    test('leave a snoozed or done reminder alone while nothing changes', () async {
      await saveTenancy(db, s, house, TenanciesCompanion(startDate: Value(monthStart(thisMonth)), dueDay: const Value(1)));
      final rent = (await rems())[autoRent]!;
      await db.updateReminder(rent.id, RemindersCompanion(snoozedUntil: Value(dayOnly(DateTime.now()).add(const Duration(days: 3)))));
      await syncRent(db, s, house);
      expect((await rems())[autoRent]!.snoozedUntil, isNotNull);
    });
  });

  test('a rent reminder is listed only once the rent is due', () {
    final today = dayOnly(DateTime.now());
    final w = fakeWorld(reminders: [
      fakeReminder(id: 1, autoSource: autoRent, due: today.add(const Duration(days: 20))),
      fakeReminder(id: 2, autoSource: autoRent, due: today.add(const Duration(days: 3))),
      fakeReminder(id: 3, due: today.add(const Duration(days: 20))),
    ]);
    expect(w.listed.map((r) => r.id), [2, 3]);
    expect(w.reminders, hasLength(3), reason: 'still notified');
  });

  group('a tenancy from before 0.3', () {
    test('moves into the tenancies once, and is tracked from now', () async {
      final db = AppDb(NativeDatabase.memory());
      final house = await db.createAsset(category: 'house', nickname: 'Rumah', propertyType: 'landed');
      await db.updateHouse(house, HouseProfilesCompanion(occupancy: const Value('rented'), tenancyStart: Value(DateTime(2024, 3, 1)), tenancyEnd: Value(DateTime(2027, 2, 28)), rentDueDay: const Value(30)));
      await db.copyOldTenancies();
      await db.copyOldTenancies();
      final t = (await db.select(db.tenancies).get()).single;
      expect(t.startDate, DateTime(2024, 3, 1));
      expect(t.dueDay, 28, reason: 'a due day fits every month');
      expect(t.endedOn, isNull);
      expect(monthState(t, 202406, null, today: DateTime.now()), MonthState.untracked, reason: 'no made-up arrears');
      await db.close();
    });

    test('of a house no longer rented out becomes an ended tenancy', () async {
      final db = AppDb(NativeDatabase.memory());
      final house = await db.createAsset(category: 'house', nickname: 'Rumah', propertyType: 'landed');
      await db.updateHouse(house, HouseProfilesCompanion(occupancy: const Value('vacant'), tenancyStart: Value(DateTime(2022, 1, 1)), tenancyEnd: Value(DateTime(2023, 12, 31))));
      await db.copyOldTenancies();
      expect((await db.select(db.tenancies).get()).single.endedOn, DateTime(2023, 12, 31));
      await db.close();
    });

    test('comes over when an older backup is restored', () async {
      await useTempStorage();
      const pass = 'correct horse battery';
      final body = {
        'created': DateTime(2026, 10, 1).toIso8601String(),
        'schema': 5,
        'tables': {
          'assets': [
            {'id': 1, 'nickname': 'Rumah', 'category': 'house', 'createdAt': 0, 'updatedAt': 0},
          ],
          'houseProfiles': [
            {'assetId': 1, 'propertyType': 'landed', 'occupancy': 'rented', 'tenancyStart': DateTime(2025, 1, 1).millisecondsSinceEpoch, 'rentDueDay': 5},
          ],
        },
      };
      final c = await Backup.open(await Backup.pack(body, const {}, pass), pass);
      final db = AppDb(NativeDatabase.memory());
      await Backup.restore(db, c);
      expect((await db.select(db.tenancies).get()).single.dueDay, 5);
      await db.close();
    });
  });
}
