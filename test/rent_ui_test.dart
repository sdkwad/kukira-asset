// The rent page (0.3, F3): the tenant, the year at a glance, twelve months in colour, marking
// a month paid, the tenancy form, and the rent reminders' own actions.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Table, Column;
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/rent.dart';
import 'package:kukira_asset/domain/rules.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/rent.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/forms.dart';
import 'package:kukira_asset/ui/rent.dart';

import 'helpers.dart';

World withRent(World w, {List<Tenancy> tenancies = const [], Map<int, List<RentPayment>> payments = const {}, List<Reminder>? reminders, String occupancy = 'rented'}) => World(
      tenancies: tenancies,
      rentPayments: payments,
      assets: w.assets,
      houses: {1: HouseProfile(assetId: 1, propertyType: 'landed', occupancy: occupancy)},
      vehicles: w.vehicles,
      reminders: reminders ?? w.reminders,
      records: w.records,
      odometer: w.odometer,
      vendors: w.vendors,
      documents: w.documents,
      settings: w.settings,
      costItems: w.costItems,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  final today = dayOnly(DateTime.now());
  final year = today.year;
  // A tenancy from January this year, rent due on the 1st, added to Kukira back then.
  final t = Tenancy(
    id: 1,
    assetId: 1,
    tenantName: 'Encik Hafiz',
    startDate: DateTime(year, 1, 1),
    rent: 1800,
    dueDay: 1,
    deposit: 5400,
    createdAt: DateTime(year - 1, 12, 20),
  );
  RentPayment pay(int m, DateTime on) => RentPayment(id: m, tenancyId: 1, month: year * 100 + m, paidOn: on, amount: 1800);

  /// What month [m] of this year says it is, to a screen reader.
  String? said(WidgetTester tester, int m) =>
      tester.widget<Semantics>(find.descendant(of: find.byKey(rentMonthKey(year * 100 + m)), matching: find.byType(Semantics)).first).properties.label;

  testWidgets('the rent page shows the tenant, the year and each month by what happened', (tester) async {
    setPhone(tester, height: 1600);
    final w = withRent(fakeWorld(), tenancies: [t], payments: {
      1: [pay(1, DateTime(year, 1, 1)), pay(2, DateTime(year, 2, 9))],
    });
    await tester.pumpWidget(harness(const RentScreen(assetId: 1), w));
    await tester.pumpAndSettle();
    expect(find.text('Encik Hafiz'), findsOneWidget);
    expect(find.text(s.tenancyActive), findsOneWidget);
    expect(find.text(s.receivedIn(year)), findsOneWidget);
    expect(find.text(s.rm(3600)), findsOneWidget, reason: 'two months received');

    expect(said(tester, 1), '${s.monthYear(year * 100 + 1)}: ${s.monthStateName('paid')}');
    expect(said(tester, 2), '${s.monthYear(year * 100 + 2)}: ${s.monthStateName('late')}', reason: 'paid on the 9th, due on the 1st');
    expect(said(tester, 12), '${s.monthYear(year * 100 + 12)}: ${s.monthStateName(today.month == 12 && today.day > 1 ? 'unpaid' : 'upcoming')}');
    expect(find.text(s.legendUnpaid), findsOneWidget);
  });

  testWidgets('a month is marked paid from its sheet, with the full rent and today as the defaults', (tester) async {
    setPhone(tester, height: 1600);
    final db = AppDb(NativeDatabase.memory());
    final house = (await tester.runAsync(() async {
      final h = await db.createAsset(category: 'house', nickname: 'Rumah', propertyType: 'landed');
      await db.into(db.tenancies).insert(TenanciesCompanion.insert(assetId: h, startDate: Value(DateTime(year, 1, 1)), rent: const Value(1800), dueDay: const Value(1)));
      return h;
    }))!;
    final w = (await tester.runAsync(db.loadWorld))!;
    await tester.pumpWidget(harness(const RentScreen(assetId: 1), w, db: db));
    await tester.pumpAndSettle();
    expect(house, 1);
    final month = monthKey(today);
    await tester.tap(find.byKey(rentMonthKey(month)));
    await tester.pumpAndSettle();
    expect(find.text(s.rentForMonth(s.monthYear(month))), findsOneWidget);
    expect(find.widgetWithText(TextField, '1800'), findsOneWidget);
    await tester.tap(find.text(s.markPaid));
    await tester.pumpAndSettle();
    final p = (await tester.runAsync(() => db.select(db.rentPayments).get()))!.single;
    await tester.runAsync(db.close);
    expect(p.month, month);
    expect(p.amount, 1800);
    expect(dayOnly(p.paidOn), today);
  });

  group('the tenancy form', () {
    testWidgets('takes the rent day from a grid, and refuses a rent that is not a number', (tester) async {
      setPhone(tester, height: 2000);
      await tester.pumpWidget(harness(const TenancyFormScreen(assetId: 1), withRent(fakeWorld())));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DayOfMonthField));
      await tester.pumpAndSettle();
      expect(find.text('31'), findsOneWidget);
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      expect(find.text(s.rentDueDay(12)), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, s.rentAmountLabel), '18oo');
      final save = find.text(s.saveTenancy);
      await tester.scrollUntilVisible(save, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(save);
      await tester.pump();
      expect(find.text(s.costInvalid), findsOneWidget);
    });

    testWidgets('saves a new tenancy with its reminders', (tester) async {
      setPhone(tester, height: 2000);
      final db = AppDb(NativeDatabase.memory());
      await tester.runAsync(() => db.createAsset(category: 'house', nickname: 'Rumah', propertyType: 'landed'));
      final w = (await tester.runAsync(db.loadWorld))!;
      await tester.pumpWidget(harness(
        Builder(builder: (c) => TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const TenancyFormScreen(assetId: 1))), child: const Text('open'))),
        w,
        db: db,
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, s.tenantName), 'Puan Aini');
      await tester.enterText(find.widgetWithText(TextField, s.rentAmountLabel), '1,500');
      final save = find.text(s.saveTenancy);
      await tester.scrollUntilVisible(save, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final (ten, rems) = (await tester.runAsync(() async => (await db.select(db.tenancies).getSingle(), await db.select(db.reminders).get())))!;
      await tester.runAsync(db.close);
      expect(ten.tenantName, 'Puan Aini');
      expect(ten.rent, 1500);
      expect(ten.startDate, today, reason: 'starts today unless changed');
      expect(rems.map((r) => r.autoSource), contains(autoRent));
    });
  });

  group('the house', () {
    testWidgets('shows its rent, and what is owed, on its overview', (tester) async {
      setPhone(tester, height: 3200);
      final owing = t.copyWith(createdAt: DateTime(year - 1, 12, 1));
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), withRent(fakeWorld(), tenancies: [owing])));
      await tester.pumpAndSettle();
      expect(find.text(s.rentRowTitle), findsOneWidget);
      final owed = owedMonths(owing, const [], today: today);
      if (owed > 0) expect(find.text(s.monthsCount(owed)), findsOneWidget);
    });

    testWidgets('rented out with no tenant yet invites one', (tester) async {
      setPhone(tester, height: 3200);
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), withRent(fakeWorld())));
      await tester.pumpAndSettle();
      expect(find.text(s.rentRowNone), findsOneWidget);
    });
  });

  testWidgets('a rent reminder offers to mark the month paid, and to open the rent page', (tester) async {
    setPhone(tester, height: 1200);
    final month = oldestOwed(t, const [], today: today)!;
    final r = fakeReminder(id: 9, assetId: 1, title: s.rentUnpaidTitle(s.monthYear(month)), autoSource: autoRent, due: rentDueOn(month, 1).add(const Duration(days: 7)));
    await tester.pumpWidget(harness(
      Builder(builder: (c) => TextButton(onPressed: () => showReminderSheet(c, 9), child: const Text('open'))),
      withRent(fakeWorld(), tenancies: [t], reminders: [r]),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(s.markMonthPaid(s.monthYear(month))), findsOneWidget);
    expect(find.text(s.openRent), findsOneWidget);
    expect(find.text(s.markDone), findsNothing, reason: 'it is answered on the tenancy');
  });
}
