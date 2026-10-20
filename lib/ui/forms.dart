import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/presets.dart';
import '../domain/rules.dart';
import 'common.dart';

// ================================================================ reminder sheet

Future<void> showReminderSheet(BuildContext context, int reminderId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => WorldView(builder: (c, w) {
      final s = c.s;
      final r = w.reminders.where((x) => x.id == reminderId).firstOrNull;
      if (r == null) return const SizedBox(height: 120);
      final a = w.asset(r.assetId);
      final st = remStatus(r, w);
      final first = firstNotice(r.info);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(r.title, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [AssetAvatar(a?.category ?? 'house', size: 24), const SizedBox(width: 8), Text(a?.nickname ?? '')]),
            const SizedBox(height: 14),
            Facts([
              (s.statusWord, '${s.statusLabel(st)} · ${dueText(s, r, w)}'),
              (s.ruleWord, ruleText(s, r)),
              if (first != null && r.info.usesDate) (s.notifyWord, s.notifyOn(s.dShort(first))),
              if (r.lastCompleted != null) (s.lastDoneWord, s.dLong(r.lastCompleted!)),
            ]),
            if (r.estimated) ...[
              const SizedBox(height: 10),
              NoteBox(s.estimatedNote(r.note ?? '', r.confirmWith ?? s.theAuthority), warn: true),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(s.markDone),
              onPressed: () async {
                final odo = w.odoOf(r.assetId);
                final n = await c.db.completeReminder(r, today: today(), odometer: odo);
                if (!sheet.mounted) return;
                Navigator.pop(sheet);
                if (!context.mounted) return;
                await _showDoneDialog(context, r, n);
              },
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
                    if (!sheet.mounted) return;
                    Navigator.pop(sheet);
                    if (context.mounted) snack(context, s.snoozedMsg(s.dLong(until)));
                  },
                ),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: Text(s.editReminder),
              onPressed: () {
                Navigator.pop(sheet);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ReminderFormScreen(editId: r.id)));
              },
            ),
          ]),
        ),
      );
    }),
  );
}

Future<void> _showDoneDialog(BuildContext context, Reminder r, NextDue n) async {
  final s = context.s;
  final addDetails = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.check_circle_outline),
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

class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({super.key, this.assetId, this.editId});
  final int? assetId;
  final int? editId;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<ReminderFormScreen> {
  final _title = TextEditingController();
  final _dueKm = TextEditingController();
  final _everyKm = TextEditingController();
  int? _assetId;
  String _rule = 'fixed';
  DateTime? _due;
  int _months = 6;
  int _lead = 7;
  int _leadKm = 1000;
  String? _template;
  String _category = 'other';
  String _repeatFrom = 'completion';
  bool _estimated = false;
  String? _note;
  String? _confirm;
  String _source = 'manual';
  bool _loaded = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _dueKm.dispose();
    _everyKm.dispose();
    super.dispose();
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
      _months = e.repeatMonths ?? 6;
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
    } else {
      _assetId = widget.assetId ?? (w.assets.isEmpty ? null : w.assets.first.id);
    }
  }

  void _applyTemplate(Preset p, World w) {
    final s = context.s;
    final odo = _assetId == null ? null : w.odoOf(_assetId!);
    setState(() {
      _template = p.key;
      _title.text = p.title(s);
      _rule = p.rule;
      _months = p.repeatMonths ?? 6;
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
    });
  }

  Future<void> _save(World w) async {
    final s = context.s;
    final usesDate = _rule != 'mileage';
    final usesKm = _rule == 'mileage' || _rule == 'either';
    final repeats = _rule == 'repeat' || _rule == 'either';
    if (_title.text.trim().isEmpty) return setState(() => _error = s.errTitle);
    if (usesDate && _due == null) return setState(() => _error = s.errDate);
    final odo = w.odoOf(_assetId!) ?? 0;
    final everyKm = parseInt(_everyKm.text);
    var dueKm = parseInt(_dueKm.text);
    if (usesKm && dueKm == null && everyKm != null) dueKm = odo + everyKm;
    if (usesKm && dueKm == null) return setState(() => _error = s.errKm);
    final c = RemindersCompanion(
      assetId: Value(_assetId!),
      title: Value(_title.text.trim()),
      category: Value(_category),
      ruleType: Value(_rule),
      dueDate: Value(usesDate ? _due : null),
      dueOdometer: Value(usesKm ? dueKm : null),
      repeatMonths: Value(repeats ? _months : null),
      repeatKm: Value(usesKm ? everyKm : null),
      repeatFrom: Value(_repeatFrom),
      leadDays: Value(_lead),
      leadKm: Value(_leadKm),
      source: Value(_source),
      estimated: Value(_estimated),
      note: Value(_note),
      confirmWith: Value(_confirm),
      snoozedUntil: const Value(null),
      done: const Value(false),
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
      final a = _assetId == null ? null : w.asset(_assetId!);
      if (a == null) return Scaffold(appBar: AppBar(), body: Center(child: Text(s.addAssetFirst)));
      final vehicle = a.category != 'house';
      final ptype = w.houses[a.id]?.propertyType;
      final rules = ['fixed', 'repeat', if (vehicle) 'mileage', if (vehicle) 'either'];
      if (!rules.contains(_rule)) _rule = 'fixed';
      final usesDate = _rule != 'mileage';
      final usesKm = _rule == 'mileage' || _rule == 'either';
      final repeats = _rule == 'repeat' || _rule == 'either';
      final odo = w.odoOf(a.id);
      return Scaffold(
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
            DateField(label: _rule == 'either' ? s.orByDate : s.dueDate, value: _due, clearable: false, onChanged: (d) => setState(() => _due = d)),
          ],
          if (repeats) ...[
            const SizedBox(height: 14),
            FieldLabel(s.every),
            ChoiceRow<int>(options: const [1, 3, 6, 12], value: _months, label: s.monthsLabel, onChanged: (v) => setState(() => _months = v)),
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
          FilledButton(onPressed: () => _save(w), child: Text(widget.editId == null ? s.saveReminder : s.saveChanges)),
        ]),
      );
    });
  }
}

// ================================================================ record form

class RecordFormScreen extends StatefulWidget {
  const RecordFormScreen({super.key, this.assetId, this.kind = 'maintenance', this.linkedReminderId});
  final int? assetId;
  final String kind;
  final int? linkedReminderId;

  @override
  State<RecordFormScreen> createState() => _RecordFormState();
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
  bool _claim = false;
  bool _markDone = true;
  bool _loaded = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _cost, _vendor, _area, _odo, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(World w) {
    if (_loaded) return;
    _loaded = true;
    _assetId = widget.assetId ?? (w.assets.isEmpty ? null : w.assets.first.id);
    final link = widget.linkedReminderId == null ? null : w.reminders.where((r) => r.id == widget.linkedReminderId).firstOrNull;
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
    if (widget.linkedReminderId != null) return w.reminders.where((r) => r.id == widget.linkedReminderId).firstOrNull;
    if (_kind == 'defect' || _cat == null) return null;
    return w.reminders
        .where((r) => !r.done && r.assetId == _assetId && r.category == _cat && remStatus(r, w) != RStatus.upcoming)
        .firstOrNull;
  }

  Future<void> _save(World w) async {
    final s = context.s;
    if (_title.text.trim().isEmpty) return setState(() => _error = s.errDescription);
    final a = w.asset(_assetId!)!;
    final db = context.db;
    final match = _match(w);
    final odo = parseInt(_odo.text);
    final msgs = <String>[_kind == 'defect' ? s.defectAdded : s.recordSaved];
    final cost = double.tryParse(_cost.text.replaceAll(',', '').trim());
    await db.addRecord(RecordsCompanion(
      assetId: Value(a.id),
      kind: Value(_kind),
      category: Value(_cat),
      title: Value(_title.text.trim()),
      date: Value(_date),
      cost: Value(cost),
      vendorName: Value(nn(_vendor.text)),
      area: Value(nn(_area.text)),
      notes: Value(nn(_notes.text)),
      odometer: Value(odo),
      warrantyEnd: Value(_warranty),
      status: Value(_kind == 'defect' ? (_reported ? 'in_progress' : 'open') : (_kind == 'incident' ? 'open' : null)),
      reportedToDeveloper: Value(_kind == 'defect' && _reported ? today() : null),
      insuranceClaim: Value(_kind == 'incident' ? _claim : null),
      linkedReminderId: Value(match?.id),
    ));
    final cur = w.odoOf(a.id);
    var newOdo = cur;
    if (a.category != 'house' && odo != null && (cur == null || odo > cur)) {
      await db.addOdometer(a.id, odo, _date);
      newOdo = odo;
    }
    if (match != null && widget.linkedReminderId == null && _markDone) {
      final n = await db.completeReminder(match, today: today(), odometer: newOdo);
      msgs.add(s.alsoMarkedDone(match.title, n.done ? null : (n.due != null ? s.dLong(n.due!) : s.km(n.dueKm ?? 0))));
    }
    if (_warranty != null) {
      await db.addReminder(RemindersCompanion(
        assetId: Value(a.id),
        title: Value(s.warrantyEnds(_title.text.trim())),
        ruleType: const Value('fixed'),
        dueDate: Value(_warranty),
        leadDays: const Value(30),
      ));
      msgs.add(s.warrantyReminderAdded);
    }
    if (!mounted) return;
    Navigator.pop(context);
    snack(context, msgs.join(' '));
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      _load(w);
      final s = context.s;
      final a = _assetId == null ? null : w.asset(_assetId!);
      if (a == null) return Scaffold(appBar: AppBar(), body: Center(child: Text(s.addAssetFirst)));
      final kinds = kindsFor(a.category);
      if (!kinds.contains(_kind)) _kind = 'maintenance';
      final cats = categoriesFor(a.category, _kind);
      if (_cat == null || !cats.contains(_cat)) _cat = cats.first;
      final vehicle = a.category != 'house';
      final defect = _kind == 'defect';
      final match = _match(w);
      return Scaffold(
        appBar: AppBar(title: Text(defect ? s.newDefect : s.newRecord)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          DropdownButtonFormField<int>(
            value: a.id,
            decoration: InputDecoration(labelText: s.asset, border: const OutlineInputBorder()),
            items: [for (final x in w.assets) DropdownMenuItem(value: x.id, child: Text(x.nickname))],
            onChanged: widget.linkedReminderId != null ? null : (v) => setState(() => _assetId = v),
          ),
          const SizedBox(height: 14),
          FieldLabel(s.kind),
          ChoiceRow<String>(options: kinds, value: _kind, label: s.kindName, onChanged: (v) => setState(() {
                _kind = v;
                _cat = null;
                _markDone = true;
              })),
          const SizedBox(height: 12),
          FieldLabel(s.category),
          ChoiceRow<String>(options: cats, value: _cat, label: s.catName, onChanged: (v) => setState(() {
                _cat = v;
                _markDone = true;
              })),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: defect ? s.whatFound : s.whatDone, hintText: defect ? s.defectHint : s.recordHint, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          DateField(label: s.date, value: _date, clearable: false, onChanged: (d) => setState(() => _date = d ?? _date)),
          const SizedBox(height: 14),
          if (defect)
            TextField(controller: _area, decoration: InputDecoration(labelText: s.area, hintText: s.areaHint, border: const OutlineInputBorder()))
          else
            TextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.totalCost, prefixText: 'RM ', border: const OutlineInputBorder()),
            ),
          if (defect) CheckboxListTile(contentPadding: EdgeInsets.zero, value: _reported, title: Text(s.alreadyReported), onChanged: (v) => setState(() => _reported = v ?? false)),
          if (_kind == 'incident') CheckboxListTile(contentPadding: EdgeInsets.zero, value: _claim, title: Text(s.madeClaim), onChanged: (v) => setState(() => _claim = v ?? false)),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(s.moreDetails),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              if (!defect) ...[
                TextField(controller: _vendor, decoration: InputDecoration(labelText: vehicle ? s.workshop : s.vendor, border: const OutlineInputBorder())),
                const SizedBox(height: 12),
              ],
              if (vehicle) ...[
                TextField(
                  controller: _odo,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.odometerKm, hintText: w.odoOf(a.id)?.toString(), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
              ] else if (!defect) ...[
                TextField(controller: _area, decoration: InputDecoration(labelText: s.area, hintText: s.areaHint, border: const OutlineInputBorder())),
                const SizedBox(height: 12),
              ],
              if (!defect && _kind != 'payment') ...[
                DateField(label: s.warrantyEndLabel, value: _warranty, onChanged: (d) => setState(() => _warranty = d)),
                Padding(padding: const EdgeInsets.only(top: 4, bottom: 12), child: Text(s.warrantyHelp, style: Theme.of(context).textTheme.bodySmall)),
              ],
              TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(labelText: s.notes, border: const OutlineInputBorder())),
              const SizedBox(height: 8),
              NoteBox(s.photosLater),
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: () => _save(w), child: Text(defect ? s.saveDefect : s.saveRecord)),
        ]),
      );
    });
  }
}
