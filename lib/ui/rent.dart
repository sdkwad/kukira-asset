// The rent of a let house (0.3, F3): the tenant, the year at a glance, twelve months in
// colour, and every earlier tenancy. Money and dates stay on the phone, encrypted.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/rent.dart';
import '../domain/rules.dart';
import '../services/error_log.dart';
import '../services/rent.dart';
import 'assets.dart' show DayOfMonthField;
import 'common.dart';

Future<void> openRent(BuildContext context, int assetId) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => RentScreen(assetId: assetId)));

/// Colours of a month in the grid, from the design tokens.
(Color bg, Color fg, IconData icon) monthLook(BuildContext context, MonthState st) {
  final k = context.tokens;
  return switch (st) {
    MonthState.paid => (k.tonal, k.onTonal, Icons.check),
    MonthState.late => (k.dueSoonBg, k.dueSoon, Icons.schedule),
    MonthState.unpaid => (k.overdueBg, k.overdue, Icons.close),
    MonthState.upcoming => (k.surface, k.textMuted, Icons.calendar_today_outlined),
    MonthState.untracked || MonthState.outside => (k.background, k.textMuted, Icons.remove),
  };
}

class RentScreen extends StatefulWidget {
  const RentScreen({super.key, required this.assetId});
  final int assetId;

  @override
  State<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends State<RentScreen> {
  int? _picked;
  int? _year;

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final a = w.asset(widget.assetId);
      if (a == null) return SafeScaffold(appBar: AppBar());
      final all = w.tenancies.where((t) => t.assetId == a.id).toList();
      final cur = currentTenancy(all, a.id);
      final t = all.where((x) => x.id == _picked).firstOrNull ?? cur ?? all.firstOrNull;
      final today = dayOnly(DateTime.now());
      return SafeScaffold(
        appBar: AppBar(title: Text(s.rentTitle(a.nickname))),
        floatingActionButton: cur == null
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: Text(s.addTenancy),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TenancyFormScreen(assetId: a.id))),
              )
            : null,
        body: t == null
            ? ListView(padding: const EdgeInsets.all(16), children: [NoteBox(s.rentNoTenancy, icon: Icons.key_outlined)])
            : _body(context, w, t, all, today),
      );
    });
  }

  Widget _body(BuildContext context, World w, Tenancy t, List<Tenancy> all, DateTime today) {
    final s = context.s;
    final k = context.tokens;
    final pays = w.rentPayments[t.id] ?? const <RentPayment>[];
    final running = t.endedOn == null;
    final years = _years(t, today);
    final year = years.contains(_year) ? _year! : (years.contains(today.year) ? today.year : years.last);
    final y = rentYear(t, pays, year, today: today);
    final history = all.where((x) => x.id != t.id).toList();
    final stamp = t.stampedOn;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, KSpace.fabClearance), children: [
      // ---- the tenant
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.tenantName ?? s.tenantUnnamed, style: KText.subtitle.copyWith(color: k.text)),
                  const SizedBox(height: 2),
                  Text(_period(context, t), style: KText.meta.copyWith(color: k.textMuted)),
                ]),
              ),
              StatusLabel(running ? s.tenancyActive : s.tenancyEnded, running ? Tone.done : Tone.expired),
              _menu(context, t),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 20, runSpacing: 8, children: [
              _fact(context, s.rentWord, t.rent == null ? s.notSet : s.rm(t.rent!)),
              _fact(context, s.depositWord, t.deposit == null ? s.notSet : s.rm(t.deposit!)),
              _fact(context, s.stampWord, stamp != null ? s.dShort(stamp) : (t.signedOn == null ? s.notSet : s.stampNotYet), tone: stamp == null && t.signedOn != null ? Tone.dueSoon : null),
              if (t.tenantPhone != null) _fact(context, s.phoneWord, t.tenantPhone!),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 12),

      // ---- the year at a glance
      Row(children: [
        Expanded(child: _metric(context, s.receivedIn(year), s.rm(y.received))),
        const SizedBox(width: 8),
        Expanded(child: _metric(context, s.owedWord, y.owedAmount != null ? s.rm(y.owedAmount!) : s.monthsCount(y.owedMonths), danger: y.owedMonths > 0)),
        const SizedBox(width: 8),
        Expanded(child: _metric(context, s.nextDueWord, y.nextDue == null ? '–' : s.dShort(y.nextDue!))),
      ]),
      const SizedBox(height: 16),

      // ---- twelve months
      Row(children: [
        IconButton(
          tooltip: s.previousYear,
          icon: const Icon(Icons.chevron_left),
          onPressed: years.first < year ? () => setState(() => _year = year - 1) : null,
        ),
        Text('$year', style: KText.row.copyWith(color: k.text)),
        IconButton(
          tooltip: s.nextYear,
          icon: const Icon(Icons.chevron_right),
          onPressed: years.last > year ? () => setState(() => _year = year + 1) : null,
        ),
        const Spacer(),
        Flexible(child: Text(s.paidOfDue(y.paidMonths, y.dueMonths), style: KText.meta.copyWith(color: k.textMuted), textAlign: TextAlign.end)),
      ]),
      const SizedBox(height: 4),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 520 ? 6 : 4;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.25,
          children: [
            for (var m = 1; m <= 12; m++) _MonthCell(key: rentMonthKey(year * 100 + m), t: t, month: year * 100 + m, paid: paymentFor(pays, year * 100 + m), today: today),
          ],
        );
      }),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 6, children: [
        for (final (st, label) in [(MonthState.paid, s.legendPaid), (MonthState.late, s.legendLate), (MonthState.unpaid, s.legendUnpaid), (MonthState.upcoming, s.legendUpcoming)])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: monthLook(context, st).$1, borderRadius: BorderRadius.circular(3), border: Border.all(color: monthLook(context, st).$2.withValues(alpha: 0.5))),
            ),
            const SizedBox(width: 6),
            Text(label, style: KText.meta.copyWith(color: k.textMuted)),
          ]),
      ]),

      // ---- earlier tenancies, kept for good
      if (history.isNotEmpty) ...[
        SectionTitle(s.tenancyHistory),
        CardList([
          for (final h in history)
            AppRow(
              leading: const IconAvatar(Icons.person_outline),
              title: h.tenantName ?? s.tenantUnnamed,
              meta: _period(context, h),
              status: Text(_paidCount(w, h, today), style: KText.status.copyWith(color: k.textMuted)),
              onTap: () => setState(() {
                _picked = h.id;
                _year = null;
              }),
            ),
        ]),
      ],
      if (t.endedOn != null && currentTenancy(all, t.assetId) == null) ...[
        const SizedBox(height: 12),
        NoteBox(s.rentNewTenancyHint),
      ],
    ]);
  }

  /// The years a tenancy has months in, up to this one (or its end).
  List<int> _years(Tenancy t, DateTime today) {
    final from = (t.startDate ?? t.createdAt).year;
    final end = t.endedOn ?? t.endDate;
    final to = end == null ? today.year : (end.year < today.year ? end.year : today.year).clamp(from, 9999);
    return [for (var y = from; y <= (to < from ? from : to); y++) y];
  }

  String _period(BuildContext context, Tenancy t) {
    final s = context.s;
    final p = s.tenancyPeriod(t.startDate == null ? null : s.dLong(t.startDate!), (t.endedOn ?? t.endDate) == null ? null : s.dLong((t.endedOn ?? t.endDate)!));
    return t.dueDay == null ? p : '$p · ${s.rentDueDay(t.dueDay!)}';
  }

  String _paidCount(World w, Tenancy t, DateTime today) {
    final pays = w.rentPayments[t.id] ?? const <RentPayment>[];
    var due = 0;
    var paid = 0;
    final from = t.startDate;
    final last = lastMonth(t);
    if (from == null) return context.s.monthsPaid(pays.length, pays.length);
    for (var m = monthKey(from); m <= (last ?? monthKey(today)); m = nextMonth(m)) {
      final st = monthState(t, m, paymentFor(pays, m), today: today);
      if (st == MonthState.paid || st == MonthState.late) paid++;
      if (st == MonthState.paid || st == MonthState.late || st == MonthState.unpaid) due++;
    }
    return context.s.monthsPaid(paid, due);
  }

  Widget _fact(BuildContext context, String label, String value, {Tone? tone}) {
    final k = context.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: KText.meta.copyWith(color: k.textMuted)),
      Text(value, style: KText.status.copyWith(color: tone == null ? k.text : toneColor(context, tone))),
    ]);
  }

  Widget _metric(BuildContext context, String label, String value, {bool danger = false}) {
    final k = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: k.surface, borderRadius: BorderRadius.circular(KSpace.controlRadius), border: Border.all(color: k.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: KText.meta.copyWith(color: k.textMuted), maxLines: 2),
        const SizedBox(height: 2),
        // An amount is shrunk to fit rather than cut short.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: KText.row.copyWith(color: danger ? k.overdue : k.text), maxLines: 1),
        ),
      ]),
    );
  }

  Widget _menu(BuildContext context, Tenancy t) {
    final s = context.s;
    final db = context.db;
    return PopupMenuButton<String>(
      tooltip: s.moreOptions,
      onSelected: (v) async {
        try {
          switch (v) {
            case 'edit':
              await Navigator.push(context, MaterialPageRoute(builder: (_) => TenancyFormScreen(assetId: t.assetId, editId: t.id)));
            case 'stamped':
              await markStamped(db, s, t, on: DateTime.now());
              if (context.mounted) snack(context, s.stampedSaved);
            case 'end':
              if (!await confirm(context, title: s.endTenancyQ, body: s.endTenancyBody, ok: s.endTenancyAction)) return;
              await endTenancy(db, s, t, on: DateTime.now());
              if (context.mounted) snack(context, s.tenancyEndedSaved);
            case 'deposit':
              await settleDeposit(db, s, t, on: DateTime.now());
              if (context.mounted) snack(context, s.depositSettledSaved);
            case 'delete':
              if (!await confirm(context, title: s.deleteTenancyQ, body: s.cannotUndo, ok: s.delete, danger: true)) return;
              await deleteTenancy(db, s, t);
              setState(() => _picked = null);
          }
        } catch (e) {
          ErrorLog.record('rent.menu', e);
          if (context.mounted) snack(context, s.couldNotSave);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'edit', child: Text(s.editTenancy)),
        if (t.signedOn != null && t.stampedOn == null) PopupMenuItem(value: 'stamped', child: Text(s.markStampedAction)),
        if (t.endedOn == null) PopupMenuItem(value: 'end', child: Text(s.endTenancyAction)),
        if (t.endedOn != null && (t.deposit ?? 0) > 0 && t.depositReturnedOn == null) PopupMenuItem(value: 'deposit', child: Text(s.settleDepositAction)),
        PopupMenuItem(value: 'delete', child: Text(s.deleteTenancy)),
      ],
    );
  }
}

/// The key of month [month]'s cell in the grid.
Key rentMonthKey(int month) => ValueKey('rent-month-$month');

class _MonthCell extends StatelessWidget {
  const _MonthCell({super.key, required this.t, required this.month, required this.paid, required this.today});
  final Tenancy t;
  final int month;
  final RentPayment? paid;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final st = monthState(t, month, paid, today: today);
    final (bg, fg, icon) = monthLook(context, st);
    final outside = st == MonthState.outside;
    return Semantics(
      button: !outside,
      label: '${s.monthYear(month)}: ${s.monthStateName(st.name)}',
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KSpace.controlRadius), side: BorderSide(color: fg.withValues(alpha: 0.35))),
        child: InkWell(
          borderRadius: BorderRadius.circular(KSpace.controlRadius),
          onTap: outside ? null : () => showMonthSheet(context, t, month),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(s.monthsShort[month % 100 - 1], style: KText.status.copyWith(color: fg)),
            const SizedBox(height: 2),
            Icon(icon, size: 16, color: fg),
          ]),
        ),
      ),
    );
  }
}

/// The action a rent reminder offers in its sheet: mark the owed month paid, mark the
/// agreement stamped, or mark the deposit settled. Null for the end of the agreement, which
/// is dealt with on the rent page.
(String, Future<void> Function())? rentReminderAction(BuildContext context, World w, Reminder r) {
  final s = context.s;
  final db = context.db;
  final all = w.tenancies.where((t) => t.assetId == r.assetId).toList();
  final cur = currentTenancy(all, r.assetId);
  switch (r.autoSource) {
    case autoRent when cur != null:
      final owed = oldestOwed(cur, w.rentPayments[cur.id] ?? const [], today: DateTime.now());
      if (owed == null) return null;
      final label = s.monthYear(owed);
      return (s.markMonthPaid(label), () async {
        await markPaid(db, s, cur, owed, paidOn: DateTime.now());
        if (context.mounted) snack(context, s.rentMarked(label));
      });
    case autoRentStamp when cur != null:
      return (s.markStampedAction, () async {
        await markStamped(db, s, cur, on: DateTime.now());
        if (context.mounted) snack(context, s.stampedSaved);
      });
    case autoDeposit:
      final ended = all.where((t) => t.endedOn != null).toList()..sort((a, b) => b.endedOn!.compareTo(a.endedOn!));
      if (ended.isEmpty) return null;
      return (s.settleDepositAction, () async {
        await settleDeposit(db, s, ended.first, on: DateTime.now());
        if (context.mounted) snack(context, s.depositSettledSaved);
      });
    default:
      return null;
  }
}

/// Marks one month paid (date and amount), or takes a payment back.
Future<void> showMonthSheet(BuildContext context, Tenancy t, int month) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => _MonthSheet(t: t, month: month, outer: context),
  );
}

class _MonthSheet extends StatefulWidget {
  const _MonthSheet({required this.t, required this.month, required this.outer});
  final Tenancy t;
  final int month;
  final BuildContext outer;

  @override
  State<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends State<_MonthSheet> {
  late DateTime _on = dayOnly(DateTime.now());
  late final _amount = TextEditingController(text: widget.t.rent == null ? '' : _plain(widget.t.rent!));

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _done(String msg) {
    if (mounted) Navigator.pop(context);
    if (widget.outer.mounted) snack(widget.outer, msg);
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final k = context.tokens;
      final t = w.tenancies.where((x) => x.id == widget.t.id).firstOrNull ?? widget.t;
      final paid = paymentFor(w.rentPayments[t.id] ?? const [], widget.month);
      final due = rentDueOn(widget.month, t.dueDay);
      final label = s.monthYear(widget.month);
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s.rentForMonth(label), style: KText.title.copyWith(color: k.text)),
            const SizedBox(height: 4),
            Text(s.rentDueOnLine(s.dLong(due)), style: KText.meta.copyWith(color: k.textMuted)),
            const SizedBox(height: 16),
            if (paid != null) ...[
              Facts([
                (s.paidOnLabel, s.dLong(paid.paidOn)),
                if (paid.amount != null) (s.amountLabel, s.rm(paid.amount!)),
              ]),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.undo),
                label: Text(s.unmarkPaid),
                onPressed: () async {
                  await unmarkPaid(context.db, s, t, widget.month);
                  _done(s.rentUnmarked(label));
                },
              ),
            ] else ...[
              DateField(label: s.paidOnLabel, value: _on, clearable: false, onChanged: (d) => setState(() => _on = d ?? _on)),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.amountLabel, prefixText: 'RM ', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SaveButton(
                onPressed: () async {
                  final text = _amount.text.replaceAll(',', '').trim();
                  final amount = text.isEmpty ? null : double.tryParse(text);
                  if (text.isNotEmpty && (amount == null || amount < 0)) {
                    snack(context, s.costInvalid);
                    return;
                  }
                  try {
                    await markPaid(context.db, s, t, widget.month, paidOn: _on, amount: amount);
                  } catch (e) {
                    ErrorLog.record('rent.pay', e);
                    if (context.mounted) snack(context, s.couldNotSave);
                    return;
                  }
                  _done(s.rentMarked(label));
                },
                child: Text(s.markPaid),
              ),
            ],
          ]),
        ),
      );
    });
  }
}

class TenancyFormScreen extends StatefulWidget {
  const TenancyFormScreen({super.key, required this.assetId, this.editId});
  final int assetId;
  final int? editId;

  @override
  State<TenancyFormScreen> createState() => _TenancyFormState();
}

class _TenancyFormState extends State<TenancyFormScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _rent = TextEditingController();
  final _deposit = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  int? _dueDay;
  DateTime? _signed;
  DateTime? _stamped;
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _rent, _deposit, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _plain(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2));

  void _load(World w) {
    if (_loaded) return;
    _loaded = true;
    final t = w.tenancies.where((x) => x.id == widget.editId).firstOrNull;
    if (t == null) {
      _start = dayOnly(DateTime.now());
      _dueDay = _start!.day.clamp(1, 28);
      return;
    }
    _name.text = t.tenantName ?? '';
    _phone.text = t.tenantPhone ?? '';
    _rent.text = _plain(t.rent);
    _deposit.text = _plain(t.deposit);
    _notes.text = t.notes ?? '';
    _start = t.startDate;
    _end = t.endDate;
    _dueDay = t.dueDay;
    _signed = t.signedOn;
    _stamped = t.stampedOn;
  }

  /// An empty amount is no amount; anything else must be a number of zero or more.
  static (bool, double?) _money(String text) {
    final t = text.replaceAll(',', '').trim();
    if (t.isEmpty) return (true, null);
    final v = double.tryParse(t);
    return (v != null && v >= 0 && v.isFinite, v);
  }

  Future<void> _save() async {
    final s = context.s;
    if (_start != null && _end != null && _end!.isBefore(_start!)) {
      snack(context, s.endBeforeStart);
      return;
    }
    final (rentOk, rent) = _money(_rent.text);
    final (depOk, deposit) = _money(_deposit.text);
    if (!rentOk || !depOk) {
      snack(context, s.costInvalid);
      return;
    }
    final c = TenanciesCompanion(
      tenantName: Value(nn(_name.text)),
      tenantPhone: Value(nn(_phone.text)),
      startDate: Value(_start),
      endDate: Value(_end),
      rent: Value(rent),
      dueDay: Value(_dueDay?.clamp(1, 28)),
      deposit: Value(deposit),
      signedOn: Value(_signed),
      stampedOn: Value(_stamped),
      notes: Value(nn(_notes.text)),
    );
    try {
      await saveTenancy(context.db, s, widget.assetId, c, id: widget.editId);
    } catch (e) {
      ErrorLog.record('rent.tenancy', e);
      if (mounted) snack(context, s.couldNotSave);
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    snack(context, s.tenancySaved);
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      _load(w);
      final s = context.s;
      final help = KText.meta.copyWith(color: context.tokens.textMuted);
      return SafeScaffold(
        appBar: AppBar(title: Text(widget.editId == null ? s.newTenancy : s.editTenancy)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: s.tenantName, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: s.tenantPhone, border: const OutlineInputBorder())),
          const SizedBox(height: 20),
          DateField(label: s.tenancyStart, value: _start, onChanged: (d) => setState(() => _start = d)),
          const SizedBox(height: 12),
          DateField(label: s.tenancyEnd, value: _end, onChanged: (d) => setState(() => _end = d)),
          const SizedBox(height: 12),
          DayOfMonthField(label: s.rentDue, value: _dueDay, onChanged: (v) => setState(() => _dueDay = v)),
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.rentDueHelp, style: help)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _rent,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.rentAmountLabel, prefixText: 'RM ', border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _deposit,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.depositWord, prefixText: 'RM ', border: const OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          DateField(label: s.signedOnLabel, value: _signed, onChanged: (d) => setState(() => _signed = d)),
          const SizedBox(height: 12),
          DateField(label: s.stampedOnLabel, value: _stamped, onChanged: (d) => setState(() => _stamped = d)),
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.stampHelp, style: help)),
          const SizedBox(height: 16),
          TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(labelText: s.notes, border: const OutlineInputBorder())),
          const SizedBox(height: 20),
          NoteBox(s.rentPrivacyNote, icon: Icons.lock_outline),
          const SizedBox(height: 16),
          SaveButton(onPressed: _save, child: Text(s.saveTenancy)),
        ]),
      );
    });
  }
}
