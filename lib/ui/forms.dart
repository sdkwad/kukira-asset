import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/auto_sync.dart';
import '../domain/presets.dart';
import '../domain/renewal.dart';
import '../domain/rules.dart';
import '../services/auto_reminders.dart';
import '../services/error_log.dart';
import '../services/record_save.dart';
import 'add_actions.dart';
import 'assets.dart';
import 'combo.dart';
import 'common.dart';
import 'documents.dart';
import 'renew.dart';

// ================================================================ reminder sheet

Future<void> showReminderSheet(BuildContext context, int reminderId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => ReminderDetail(reminderId: reminderId, sheet: sheet, host: context),
  );
}

/// A reminder, how it stands and what can be done with it: in a sheet on a phone, in the
/// pane beside Today's list on a wide screen.
class ReminderDetail extends StatelessWidget {
  const ReminderDetail({super.key, required this.reminderId, this.sheet, this.host});
  final int reminderId;

  /// The sheet this is shown in, closed before an action. Null in a pane.
  final BuildContext? sheet;

  /// The screen under the sheet, which actions open from once the sheet has closed. Null
  /// in a pane, which opens them itself.
  final BuildContext? host;

  @override
  Widget build(BuildContext outer) => WorldView(builder: (c, w) {
      final s = c.s;
      final context = host ?? outer;
      final inSheet = sheet != null;
      void close() {
        final sh = sheet;
        if (sh != null && sh.mounted) Navigator.pop(sh);
      }

      final r = w.reminders.where((x) => x.id == reminderId).firstOrNull;
      if (r == null) return inSheet ? const SizedBox(height: 120) : Center(child: Text(s.pickReminder));
      final a = w.asset(r.assetId);
      final st = remStatus(r, w);
      // The next notification this reminder will get, from the same plan as the real schedule
      // (not the first one, which may be long past for an overdue reminder).
      final next = planNotes([r.info], now: DateTime.now(), hour: w.notifyHour, minute: w.notifyMinute, limit: 1).firstOrNull?.at;
      final odoReminder = r.category == 'odometer';
      // Road tax and insurance follow the vehicle's date: renewing sets the next one.
      final renewKind = switch (r.autoSource) { autoRoadTax => RenewKind.roadTax, autoInsurance => RenewKind.insurance, _ => null };
      Future<void> markDone() async {
        close();
        if (odoReminder) {
          final saved = await showOdometerDialog(context, r.assetId);
          if (!saved || !context.mounted) return;
          final now = context.app.world.value!;
          final fresh = now.reminders.where((x) => x.id == r.id).firstOrNull ?? r;
          await context.db.completeReminder(fresh, today: today(), odometer: now.odoOf(r.assetId));
          return;
        }
        final n = await context.db.completeReminder(r, today: today(), odometer: w.odoOf(r.assetId));
        if (context.mounted) await _showDoneDialog(context, r, n);
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: inSheet ? const EdgeInsets.fromLTRB(20, 0, 20, 20) : const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(r.title, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [AssetAvatar(a?.category ?? 'house', size: 24), const SizedBox(width: 8), Text(a?.nickname ?? '')]),
            const SizedBox(height: 14),
            Facts([
              // An overdue reminder's due text already says it is overdue.
              (s.statusWord, st == RStatus.overdue ? dueText(s, r, w) : '${s.statusLabel(st)} · ${dueText(s, r, w)}'),
              (s.ruleWord, ruleText(s, r)),
              if (r.info.usesDate && r.dueDate != null)
                (s.notifyWord, next == null ? s.noMoreNotifications : s.notifyOnAt(s.dShort(next), s.hm(next.hour, next.minute))),
              if (r.lastCompleted != null) (s.lastDoneWord, s.dLong(r.lastCompleted!)),
            ]),
            if (r.estimated) ...[
              const SizedBox(height: 10),
              NoteBox(s.estimatedNote(r.note ?? '', r.confirmWith ?? s.theAuthority), warn: true),
            ],
            const SizedBox(height: 16),
            if (renewKind != null) ...[
              FilledButton.icon(
                icon: const Icon(Icons.autorenew),
                label: Text(s.renew),
                onPressed: () {
                  close();
                  final v = w.vehicles[r.assetId];
                  openRenewal(context, r.assetId, renewKind, both: v != null && renewTogether(v.roadTaxExpiry, v.insuranceExpiry));
                },
              ),
              Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: markDone, child: Text(s.markDoneOnly))),
            ] else
              FilledButton.icon(
                icon: Icon(odoReminder ? Icons.speed : Icons.check),
                label: Text(odoReminder ? s.updateOdometer : s.markDone),
                onPressed: markDone,
              ),
            const SizedBox(height: 12),
            FieldLabel(s.snooze),
            Wrap(spacing: 8, children: [
              for (final d in [1, 3, 7])
                ActionChip(
                  label: Text(s.snoozeDays(d)),
                  onPressed: () async {
                    final until = today().add(Duration(days: d));
                    await c.db.snooze(r.id, until);
                    close();
                    if (context.mounted) snack(context, s.snoozedMsg(s.dLong(until)));
                  },
                ),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: Text(s.editReminder),
              onPressed: () {
                close();
                Navigator.push(context, MaterialPageRoute(builder: (_) => ReminderFormScreen(editId: r.id)));
              },
            ),
          ]),
        ),
      );
    });
}

Future<void> _showDoneDialog(BuildContext context, Reminder r, NextDue n) async {
  final s = context.s;
  final still = MediaQuery.of(context).disableAnimations;
  final addDetails = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: CircleAvatar(
          radius: 30,
          backgroundColor: Theme.of(c).colorScheme.primaryContainer,
          child: Icon(Icons.check_rounded, size: 36, color: Theme.of(c).colorScheme.onPrimaryContainer),
        ),
      ),
      title: Text(s.markedDone),
      content: Text(nextText(s, n, r)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.notNow)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.addCostDetails)),
      ],
    ),
  );
  if (addDetails == true && context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RecordFormScreen(assetId: r.assetId, linkedReminderId: r.id)));
  }
}

// ================================================================ reminder form

/// Whether saving a reminder with these values gives it a new schedule (rule, date,
/// distance or repeat). Only then is a reminder that was done or snoozed brought back. The
/// old reminder is read the way the form saves one: only the fields its rule uses count
/// (a preset may have stored a repeat on a one-off reminder).
bool changesSchedule(Reminder old,
    {required String rule, DateTime? due, int? dueKm, int? months, int? days, int? everyKm, required String repeatFrom}) {
  if (old.ruleType != rule || old.repeatFrom != repeatFrom) return true;
  final usesDate = rule != 'mileage';
  final usesKm = rule == 'mileage' || rule == 'either';
  final repeats = rule == 'repeat' || rule == 'either';
  return (usesDate ? old.dueDate : null) != due ||
      (usesKm ? old.dueOdometer : null) != dueKm ||
      (repeats ? old.repeatMonths : null) != months ||
      (repeats ? old.repeatDays : null) != days ||
      (usesKm ? old.repeatKm : null) != everyKm;
}

class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({super.key, this.assetId, this.editId, this.templateKey});
  final int? assetId;
  final int? editId;

  /// Start a new reminder from this preset (see presetByKey).
  final String? templateKey;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<ReminderFormScreen> {
  final _title = TextEditingController();
  final _dueKm = TextEditingController();
  final _everyKm = TextEditingController();
  final _customN = TextEditingController(text: '2');
  int? _assetId;
  String _rule = 'fixed';
  DateTime? _due;
  int _months = 6; // -1 = custom
  String _unit = 'month'; // day | week | month | year (custom only)
  int _lead = 7;
  int _leadKm = 1000;
  String? _template;
  String _category = 'other';
  String _repeatFrom = 'completion';
  bool _estimated = false;
  String? _note;
  String? _confirm;
  String _source = 'manual';
  String? _autoSource;
  bool _loaded = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _dueKm, _everyKm, _customN]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setRepeat(int? months, int? days) {
    if (days != null && days > 0 && (months ?? 0) == 0) {
      _months = -1;
      if (days % 7 == 0) {
        _unit = 'week';
        _customN.text = '${days ~/ 7}';
      } else {
        _unit = 'day';
        _customN.text = '$days';
      }
    } else if (months != null && ![1, 3, 6, 12].contains(months)) {
      _months = -1;
      if (months % 12 == 0) {
        _unit = 'year';
        _customN.text = '${months ~/ 12}';
      } else {
        _unit = 'month';
        _customN.text = '$months';
      }
    } else {
      _months = months ?? 6;
    }
  }

  void _load(World w) {
    if (_loaded) return;
    _loaded = true;
    final e = widget.editId == null ? null : w.reminders.where((x) => x.id == widget.editId).firstOrNull;
    if (e != null) {
      _assetId = e.assetId;
      _title.text = e.title;
      _rule = e.ruleType;
      _due = e.dueDate;
      _setRepeat(e.repeatMonths, e.repeatDays);
      _lead = e.leadDays;
      _leadKm = e.leadKm;
      _dueKm.text = e.dueOdometer?.toString() ?? '';
      _everyKm.text = e.repeatKm?.toString() ?? '';
      _category = e.category ?? 'other';
      _repeatFrom = e.repeatFrom;
      _estimated = e.estimated;
      _note = e.note;
      _confirm = e.confirmWith;
      _source = e.source;
      _autoSource = e.autoSource;
    } else {
      _assetId = addStartAsset(w, widget.assetId);
      final p = widget.templateKey == null ? null : presetByKey(widget.templateKey!);
      if (p != null && _assetId != null) _fill(p, w);
    }
  }

  void _applyTemplate(Preset p, World w) => setState(() => _fill(p, w));

  void _fill(Preset p, World w) {
    final s = context.s;
    final odo = _assetId == null ? null : w.odoOf(_assetId!);
    {
      _template = p.key;
      _title.text = p.title(s);
      _rule = p.rule;
      _setRepeat(p.repeatMonths ?? 6, null);
      _everyKm.text = p.repeatKm?.toString() ?? '';
      _dueKm.text = (p.repeatKm != null && odo != null) ? '${odo + p.repeatKm!}' : '';
      _due = p.defaultDue?.call(today()) ?? _due;
      _lead = p.leadDays;
      _leadKm = p.leadKm;
      _category = p.category;
      _repeatFrom = p.repeatFrom;
      _estimated = p.estimated;
      _note = p.note(s);
      _confirm = p.confirm(s);
      _source = p.estimated ? 'preset' : 'template';
      _error = null;
    }
  }

  /// (months, days) from the repeat choice.
  (int?, int?) _repeat() {
    if (_months != -1) return (_months, null);
    final n = parseInt(_customN.text) ?? 0;
    if (n <= 0) return (null, null);
    return switch (_unit) {
      'day' => (null, n),
      'week' => (null, n * 7),
      'year' => (n * 12, null),
      _ => (n, null),
    };
  }

  Future<void> _save(World w) async {
    final s = context.s;
    final usesDate = _rule != 'mileage';
    final usesKm = _rule == 'mileage' || _rule == 'either';
    final repeats = _rule == 'repeat' || _rule == 'either';
    if (_title.text.trim().isEmpty) return setState(() => _error = s.errTitle);
    if (usesDate && _due == null) return setState(() => _error = s.errDate);
    final (months, days) = _repeat();
    if (repeats && months == null && days == null) return setState(() => _error = s.errRepeat);
    final odo = w.odoOf(_assetId!) ?? 0;
    final everyKm = parseInt(_everyKm.text);
    var dueKm = parseInt(_dueKm.text);
    if (usesKm && dueKm == null && everyKm != null) dueKm = odo + everyKm;
    if (usesKm && dueKm == null) return setState(() => _error = s.errKm);
    // Editing only the title, notes or lead time keeps a reminder done or snoozed. A new
    // date, distance or repeat is a new schedule, so it brings the reminder back.
    final old = widget.editId == null ? null : w.reminders.where((x) => x.id == widget.editId).firstOrNull;
    final rescheduled = old == null ||
        changesSchedule(old,
            rule: _rule,
            due: usesDate ? _due : null,
            dueKm: usesKm ? dueKm : null,
            months: repeats ? months : null,
            days: repeats ? days : null,
            everyKm: usesKm ? everyKm : null,
            repeatFrom: _repeatFrom);
    final c = RemindersCompanion(
      assetId: Value(_assetId!),
      title: Value(_title.text.trim()),
      category: Value(_category),
      ruleType: Value(_rule),
      dueDate: Value(usesDate ? _due : null),
      dueOdometer: Value(usesKm ? dueKm : null),
      repeatMonths: Value(repeats ? months : null),
      repeatDays: Value(repeats ? days : null),
      repeatKm: Value(usesKm ? everyKm : null),
      repeatFrom: Value(_repeatFrom),
      leadDays: Value(_lead),
      leadKm: Value(_leadKm),
      source: Value(_source),
      estimated: Value(_estimated),
      note: Value(_note),
      confirmWith: Value(_confirm),
      snoozedUntil: rescheduled ? const Value(null) : const Value.absent(),
      done: rescheduled ? const Value(false) : const Value.absent(),
    );
    final db = context.db;
    if (widget.editId == null) {
      await db.addReminder(c);
    } else {
      await db.updateReminder(widget.editId!, c);
    }
    if (!mounted) return;
    final when = usesDate && _due != null ? _due!.subtract(Duration(days: _lead)) : null;
    final msg = when == null
        ? s.savedMileage
        : widget.editId == null
            ? s.savedNotifyOn(s.dLong(when))
            : s.updatedNotifyOn(s.dLong(when));
    Navigator.pop(context);
    snack(context, msg);
  }

  Future<void> _delete() async {
    final s = context.s;
    final ok = await confirm(context, title: s.deleteReminderQ, body: s.deleteReminderBody, ok: s.delete, danger: true);
    if (!ok || !mounted) return;
    await context.db.deleteReminder(widget.editId!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      _load(w);
      final s = context.s;
      if (_assetId == null && w.assets.isNotEmpty) return AssetChoiceScreen(title: s.newReminder, w: w, onPick: (id) => setState(() => _assetId = id));
      final a = _assetId == null ? null : w.asset(_assetId!);
      if (a == null) return SafeScaffold(appBar: AppBar(), body: Center(child: Text(s.addAssetFirst)));
      final vehicle = a.category != 'house';
      final ptype = w.houses[a.id]?.propertyType;
      final rules = ['fixed', 'repeat', if (vehicle) 'mileage', if (vehicle) 'either'];
      if (!rules.contains(_rule)) _rule = 'fixed';
      final usesDate = _rule != 'mileage';
      final usesKm = _rule == 'mileage' || _rule == 'either';
      final repeats = _rule == 'repeat' || _rule == 'either';
      final odo = w.odoOf(a.id);
      return SafeScaffold(
        appBar: AppBar(
          title: Text(widget.editId == null ? s.newReminder : s.editReminder),
          actions: [
            if (widget.editId != null) IconButton(icon: const Icon(Icons.delete_outline), tooltip: s.delete, onPressed: _delete),
          ],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          if (widget.editId == null) ...[
            DropdownButtonFormField<int>(
              value: a.id,
              decoration: InputDecoration(labelText: s.asset, border: const OutlineInputBorder()),
              items: [for (final x in w.assets) DropdownMenuItem(value: x.id, child: Text(x.nickname))],
              onChanged: (v) => setState(() {
                _assetId = v;
                _template = null;
              }),
            ),
            const SizedBox(height: 14),
            FieldLabel(s.startFromTemplate),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in templatesFor(a.category, ptype))
                ChoiceChip(label: Text(p.title(s)), selected: _template == p.key, onSelected: (_) => _applyTemplate(p, w)),
            ]),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.title, hintText: s.titleHint, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          FieldLabel(s.when),
          ChoiceRow<String>(options: rules, value: _rule, label: s.ruleName, onChanged: (v) => setState(() => _rule = v)),
          if (usesDate) ...[
            const SizedBox(height: 14),
            DateField(
              label: _rule == 'either' ? s.orByDate : s.dueDate,
              value: _due,
              clearable: false,
              enabled: _autoSource == null,
              onChanged: (d) => setState(() => _due = d),
            ),
            if (_autoSource != null) ...[const SizedBox(height: 8), NoteBox(s.autoLinkedNote(s.autoFieldName(_autoSource!)), icon: Icons.link)],
          ],
          if (repeats) ...[
            const SizedBox(height: 14),
            FieldLabel(s.every),
            ChoiceRow<int>(
              options: const [1, 3, 6, 12, -1],
              value: _months,
              label: (v) => v == -1 ? s.customRepeat : s.monthsLabel(v),
              onChanged: (v) => setState(() => _months = v),
            ),
            if (_months == -1) ...[
              const SizedBox(height: 10),
              Row(children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _customN,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.every, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceRow<String>(
                    options: const ['day', 'week', 'month', 'year'],
                    value: _unit,
                    label: s.unitName,
                    onChanged: (v) => setState(() => _unit = v),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 4),
            Text(_repeatFrom == 'due' ? s.countFromDue : s.countFromDone, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (usesKm) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _dueKm,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.dueAtKmLabel, hintText: odo == null ? null : '${odo + 5000}', border: const OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _everyKm,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.everyKmLabel, border: const OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(odo == null ? s.odoUnknown : s.odoNow(s.km(odo)), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            FieldLabel(s.remindKmBefore),
            ChoiceRow<int>(options: const [300, 500, 1000, 2000], value: _leadKm, label: (v) => s.km(v), onChanged: (v) => setState(() => _leadKm = v)),
          ],
          if (usesDate) ...[
            const SizedBox(height: 14),
            FieldLabel(s.remindMe),
            ChoiceRow<int>(options: const [0, 3, 7, 14, 30], value: _lead, label: s.leadLabel, onChanged: (v) => setState(() => _lead = v)),
          ],
          if (_estimated) ...[
            const SizedBox(height: 14),
            NoteBox(s.estimatedNote(_note ?? '', _confirm ?? s.theAuthority), warn: true),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          SaveButton(onPressed: () => _save(w), child: Text(widget.editId == null ? s.saveReminder : s.saveChanges)),
        ]),
      );
    });
  }
}

// ================================================================ record form

class RecordFormScreen extends StatefulWidget {
  const RecordFormScreen({super.key, this.assetId, this.kind = 'maintenance', this.linkedReminderId, this.completesReminderId, this.editId});
  final int? assetId;
  final String kind;

  /// A reminder already marked done that this record adds the details of.
  final int? linkedReminderId;

  /// A reminder this record is for (a Tambah suggestion): the form starts from it and, unless
  /// the box is unticked, saving marks it done.
  final int? completesReminderId;
  final int? editId;

  @override
  State<RecordFormScreen> createState() => _RecordFormState();
}

class _ItemRow {
  _ItemRow([String label = '', String amount = ''])
      : label = TextEditingController(text: label),
        amount = TextEditingController(text: amount);
  final TextEditingController label;
  final TextEditingController amount;
  void dispose() {
    label.dispose();
    amount.dispose();
  }
}

class _RecordFormState extends State<RecordFormScreen> {
  final _title = TextEditingController();
  final _cost = TextEditingController();
  final _vendor = TextEditingController();
  final _area = TextEditingController();
  final _odo = TextEditingController();
  final _notes = TextEditingController();
  int? _assetId;
  late String _kind = widget.kind;
  String? _cat;
  DateTime _date = today();
  DateTime? _warranty;
  bool _reported = false;
  DateTime? _reportedOn;
  bool _claim = false;
  bool _markDone = true;
  bool _itemised = false;
  final List<_ItemRow> _items = [];
  bool _saveVendor = true;
  List<AssetDocument> _photosBefore = [];
  final List<AssetDocument> _photosKept = [];
  final List<Picked> _photosAdded = [];
  String? _status;
  int? _linkedId;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _cost, _vendor, _area, _odo, _notes]) {
      c.dispose();
    }
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  void _load(World w) {
    if (_loaded) return;
    _loaded = true;
    final e = widget.editId == null ? null : w.records.where((r) => r.id == widget.editId).firstOrNull;
    if (e != null) {
      _assetId = e.assetId;
      _kind = e.kind;
      _cat = e.category;
      _title.text = e.title;
      _date = e.date;
      _cost.text = e.cost == null ? '' : _num(e.cost!);
      _vendor.text = e.vendorName ?? '';
      _area.text = e.area ?? '';
      _odo.text = e.odometer?.toString() ?? '';
      _notes.text = e.notes ?? '';
      _warranty = e.warrantyEnd;
      _reported = e.reportedToDeveloper != null;
      _reportedOn = e.reportedToDeveloper;
      _claim = e.insuranceClaim ?? false;
      _status = e.status;
      _linkedId = e.linkedReminderId;
      _markDone = false;
      final items = w.costItems[e.id] ?? const [];
      if (items.isNotEmpty) {
        _itemised = true;
        _items.addAll(items.map((i) => _ItemRow(i.label, _num(i.amount))));
      }
      _photosBefore = w.photosOf(e.id);
      _photosKept.addAll(_photosBefore);
      return;
    }
    _assetId = addStartAsset(w, widget.assetId);
    final from = widget.linkedReminderId ?? widget.completesReminderId;
    final link = from == null ? null : w.reminders.where((r) => r.id == from).firstOrNull;
    if (link != null) {
      _title.text = link.title;
      final a = w.asset(link.assetId);
      if (a != null && link.category != null) {
        for (final k in kindsFor(a.category)) {
          if (categoriesFor(a.category, k).contains(link.category)) {
            _kind = k;
            _cat = link.category;
            break;
          }
        }
      }
    }
  }

  Reminder? _match(World w) {
    if (widget.editId != null) return null;
    if (widget.linkedReminderId != null) return w.reminders.where((r) => r.id == widget.linkedReminderId).firstOrNull;
    if (widget.completesReminderId != null) return w.reminders.where((r) => r.id == widget.completesReminderId && !r.done).firstOrNull;
    if (_kind == 'defect' || _cat == null) return null;
    return w.reminders
        .where((r) => !r.done && r.assetId == _assetId && r.category == _cat && remStatus(r, w) != RStatus.upcoming)
        .firstOrNull;
  }

  // An empty title takes the name of the reminder this record completes ("Tukar minyak
  // enjin"), or else its category ("Minyak enjin").
  String _fallbackTitle(Reminder? match) =>
      match != null && (_markDone || widget.linkedReminderId != null) ? match.title : defaultRecordTitle(context.s, _kind, _cat);

  double? _itemsTotal() {
    var t = 0.0;
    var any = false;
    for (final i in _items) {
      final v = double.tryParse(i.amount.text.replaceAll(',', '').trim());
      if (v != null) {
        t += v;
        any = true;
      }
    }
    return any ? t : null;
  }

  /// A typed amount that is not a valid cost: not a number, or below zero. Empty is fine.
  static bool _badAmount(String text) {
    final t = text.replaceAll(',', '').trim();
    if (t.isEmpty) return false;
    final v = double.tryParse(t);
    return v == null || v < 0 || v.isNaN || v.isInfinite;
  }

  Future<void> _save(World w) async {
    final s = context.s;
    if (_kind != 'defect' && (_itemised ? _items.any((i) => _badAmount(i.amount.text)) : _badAmount(_cost.text))) {
      snack(context, s.costInvalid);
      return;
    }
    setState(() => _saving = true);
    final db = context.db;
    final defect = _kind == 'defect';
    final match = _match(w);

    // The warranty reminder follows the warranty date. As for road tax, ask before
    // reopening a reminder that was marked done or clearing a snooze.
    final old = widget.editId == null ? null : w.records.where((r) => r.id == widget.editId).firstOrNull;
    final warranty = planWarranty(w.reminders, reminderId: old?.warrantyReminderId, oldDate: old?.warrantyEnd, newDate: _warranty, today: today());
    final overwrite = await askAutoConflicts(context, [warranty]);
    if (overwrite == null || !mounted) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    final input = RecordInput(
      assetId: _assetId!,
      editId: widget.editId,
      kind: _kind,
      category: _cat,
      title: nn(_title.text) ?? _fallbackTitle(match),
      date: _date,
      cost: _itemised ? _itemsTotal() : double.tryParse(_cost.text.replaceAll(',', '').trim()),
      costItems: [
        if (_itemised)
          for (final i in _items)
            if (i.label.text.trim().isNotEmpty || i.amount.text.trim().isNotEmpty)
              (i.label.text.trim().isEmpty ? s.item : i.label.text.trim(), double.tryParse(i.amount.text.replaceAll(',', '').trim()) ?? 0),
      ],
      vendorName: nn(_vendor.text),
      addVendor: _saveVendor && !defect,
      area: nn(_area.text),
      notes: nn(_notes.text),
      odometer: parseInt(_odo.text),
      warrantyEnd: _warranty,
      status: defect
          ? (_status == 'done' ? 'done' : (_reported ? 'in_progress' : (_status ?? 'open')))
          : (_kind == 'incident' ? (_status ?? 'open') : null),
      reportedOn: defect && _reported ? (_reportedOn ?? today()) : null,
      insuranceClaim: _kind == 'incident' ? _claim : null,
      linkedReminderId: widget.editId != null ? _linkedId : match?.id,
      photosRemoved: _photosBefore.where((b) => !_photosKept.any((k) => k.id == b.id)).toList(),
      photosAdded: [for (final p in _photosAdded) (p.bytes, p.ext)],
      completes: match != null && widget.linkedReminderId == null && _markDone ? match : null,
    );
    final msgs = <String>[defect ? s.defectAdded : s.recordSaved];
    try {
      await saveRecord(db, s, w, input, warranty: warranty, overwriteWarranty: overwrite, today: today(), msgs: msgs);
    } catch (e) {
      ErrorLog.record('record.save', e);
      if (mounted) {
        setState(() => _saving = false);
        snack(context, s.couldNotSave);
      }
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    snack(context, widget.editId == null ? msgs.join(' ') : [s.changesSaved, ...msgs.skip(1)].join(' '));
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      _load(w);
      final s = context.s;
      final theme = Theme.of(context);
      if (_assetId == null && w.assets.isNotEmpty) {
        return AssetChoiceScreen(title: _kind == 'defect' ? s.newDefect : s.newRecord, w: w, onPick: (id) => setState(() => _assetId = id));
      }
      final a = _assetId == null ? null : w.asset(_assetId!);
      if (a == null) return SafeScaffold(appBar: AppBar(), body: Center(child: Text(s.addAssetFirst)));
      final kinds = kindsFor(a.category);
      if (!kinds.contains(_kind)) _kind = 'maintenance';
      final cats = categoriesFor(a.category, _kind);
      if (_cat == null || !cats.contains(_cat)) _cat = cats.first;
      final vehicle = a.category != 'house';
      final defect = _kind == 'defect';
      final match = _match(w);
      final editing = widget.editId != null;
      final total = _itemsTotal();
      final knownVendor = w.vendors.any((v) => v.name.toLowerCase() == _vendor.text.trim().toLowerCase());
      return SafeScaffold(
        appBar: AppBar(title: Text(editing ? (defect ? s.editDefect : s.editRecord) : (defect ? s.newDefect : s.newRecord))),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          DropdownButtonFormField<int>(
            value: a.id,
            decoration: InputDecoration(labelText: s.asset, border: const OutlineInputBorder()),
            items: [for (final x in w.assets) DropdownMenuItem(value: x.id, child: Text(x.nickname))],
            onChanged: widget.linkedReminderId != null || editing ? null : (v) => setState(() => _assetId = v),
          ),
          const SizedBox(height: 14),
          FieldLabel(s.kind),
          ChoiceRow<String>(options: kinds, value: _kind, label: s.kindName, onChanged: (v) => setState(() {
                _kind = v;
                _cat = null;
                _markDone = !editing;
              })),
          const SizedBox(height: 12),
          FieldLabel(s.category),
          ChoiceRow<String>(options: cats, value: _cat, label: s.catName, onChanged: (v) => setState(() {
                _cat = v;
                _markDone = !editing;
              })),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: defect ? s.whatFound : s.whatDone,
              hintText: defect ? s.defectHint : s.recordHint,
              helperText: s.titleIfEmpty(_fallbackTitle(match)),
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          DateField(label: s.date, value: _date, clearable: false, onChanged: (d) => setState(() => _date = d ?? _date)),
          const SizedBox(height: 14),
          if (defect) ...[
            ComboField(controller: _area, label: s.area, hint: s.areaHint, options: areaOptions(s, w), textCapitalization: TextCapitalization.sentences),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _reported, title: Text(s.alreadyReported), onChanged: (v) => setState(() => _reported = v ?? false)),
          ] else ...[
            if (!_itemised)
              TextField(
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.totalCost, prefixText: 'RM ', border: const OutlineInputBorder()),
              )
            else ...[
              FieldLabel(s.costBreakdown),
              for (final i in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: ComboField(
                        controller: i.label,
                        label: null,
                        hint: s.itemHint,
                        options: itemOptions(s, w, vehicle: vehicle),
                        textCapitalization: TextCapitalization.sentences,
                        listButton: false,
                        dense: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: i.amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(prefixText: 'RM ', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: s.remove,
                      onPressed: () => setState(() {
                        _items.remove(i);
                        i.dispose();
                      }),
                    ),
                  ]),
                ),
              Row(children: [
                TextButton.icon(icon: const Icon(Icons.add), label: Text(s.addItem), onPressed: () => setState(() => _items.add(_ItemRow()))),
                const Spacer(),
                Text('${s.totalCost}: ${s.rm(total ?? 0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  _itemised = !_itemised;
                  if (_itemised && _items.isEmpty) {
                    _items.addAll([_ItemRow(s.labour), _ItemRow(s.parts)]);
                    final c = double.tryParse(_cost.text.replaceAll(',', ''));
                    if (c != null) _items.first.amount.text = _num(c);
                  } else if (!_itemised && total != null) {
                    _cost.text = _num(total);
                  }
                }),
                child: Text(_itemised ? s.useSingleTotal : s.splitCost),
              ),
            ),
          ],
          if (_kind == 'incident') CheckboxListTile(contentPadding: EdgeInsets.zero, value: _claim, title: Text(s.madeClaim), onChanged: (v) => setState(() => _claim = v ?? false)),
          // The reading keeps mileage reminders right, so it is not tucked away under More details.
          if (vehicle) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _odo,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s.odometerKm, hintText: w.odoOf(a.id)?.toString(), border: const OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 8),
          PhotoEditor(existing: _photosKept, added: _photosAdded, onChanged: () => setState(() {})),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: editing,
            title: Text(s.moreDetails),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              if (!defect) ...[
                Autocomplete<Vendor>(
                  initialValue: TextEditingValue(text: _vendor.text),
                  displayStringForOption: (v) => v.name,
                  optionsBuilder: (t) {
                    final q = t.text.trim().toLowerCase();
                    if (q.isEmpty) return w.vendors;
                    return w.vendors.where((v) => v.name.toLowerCase().contains(q) || (v.trade ?? '').contains(q));
                  },
                  onSelected: (v) => setState(() => _vendor.text = v.name),
                  fieldViewBuilder: (c, ctrl, focus, onSubmit) => TextField(
                    controller: ctrl,
                    focusNode: focus,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (t) => setState(() => _vendor.text = t),
                    decoration: InputDecoration(labelText: vehicle ? s.workshop : s.vendor, hintText: s.vendorPickHint, border: const OutlineInputBorder()),
                  ),
                ),
                if (_vendor.text.trim().isNotEmpty && !knownVendor)
                  CheckboxListTile(contentPadding: EdgeInsets.zero, value: _saveVendor, title: Text(s.saveToVendorBook), onChanged: (v) => setState(() => _saveVendor = v ?? false)),
                const SizedBox(height: 12),
              ],
              if (!vehicle && !defect) ...[
                ComboField(controller: _area, label: s.area, hint: s.areaHint, options: areaOptions(s, w), textCapitalization: TextCapitalization.sentences),
                const SizedBox(height: 12),
              ],
              if (!defect && _kind != 'payment') ...[
                DateField(label: s.warrantyEndLabel, value: _warranty, onChanged: (d) => setState(() => _warranty = d)),
                Padding(padding: const EdgeInsets.only(top: 4, bottom: 12), child: Text(s.warrantyHelp, style: theme.textTheme.bodySmall)),
              ],
              TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(labelText: s.notes, border: const OutlineInputBorder())),
            ],
          ),
          if (match != null && !defect) ...[
            const SizedBox(height: 8),
            if (widget.linkedReminderId != null)
              NoteBox(s.linkedTo(match.title), icon: Icons.link)
            else
              Card(
                margin: EdgeInsets.zero,
                child: CheckboxListTile(
                  value: _markDone,
                  title: Text(s.looksLike(match.title)),
                  subtitle: Text(s.markDoneAndNext),
                  onChanged: (v) => setState(() => _markDone = v ?? false),
                ),
              ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : () => _save(w),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(editing ? s.saveChanges : (defect ? s.saveDefect : s.saveRecord)),
          ),
        ]),
      );
    });
  }
}
