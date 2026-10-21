import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/auto_sync.dart';
import '../domain/presets.dart';
import '../services/auto_reminders.dart';
import 'assets.dart';
import 'common.dart';
import 'more.dart';
import 'today.dart';

/// First asset in three taps: type, nickname plus one question, done.
/// Then two or three suggested reminders that each need only a date.
class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});

  @override
  State<AddAssetScreen> createState() => _AddAssetState();
}

class _AddAssetState extends State<AddAssetScreen> {
  final _watch = Stopwatch()..start();
  final _name = TextEditingController();
  final _plate = TextEditingController();
  int _step = 1;
  String _cat = 'house';
  String _ptype = 'landed';
  int? _newId;
  bool? _firstEver;
  final Map<String, DateTime?> _picks = {};
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final s = context.s;
    if (_name.text.trim().isEmpty) return setState(() => _error = s.errNickname);
    if (_cat != 'house' && _plate.text.trim().isEmpty) return setState(() => _error = s.errPlate);
    _firstEver ??= context.app.world.value?.assets.isEmpty ?? true;
    final id = await context.db.createAsset(
      category: _cat,
      nickname: _name.text.trim(),
      propertyType: _ptype,
      plate: _plate.text.trim().toUpperCase(),
    );
    setState(() {
      _newId = id;
      _step = 3;
      _error = null;
    });
  }

  String _elapsed() {
    final sec = _watch.elapsed.inSeconds;
    return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _savePicks() async {
    final s = context.s;
    final db = context.db;
    final sug = suggestionsFor(_cat, _ptype);
    if (_picks.values.any((d) => d == null)) return setState(() => _error = s.errPickDates);
    for (final p in sug.where((p) => _picks.containsKey(p.key))) {
      final due = _picks[p.key]!;
      if (p.profileField != null) {
        // Road tax and insurance: set the vehicle date; its linked reminder follows.
        final source = p.profileField == 'roadTax' ? autoRoadTax : autoInsurance;
        await db.updateVehicle(
          _newId!,
          source == autoRoadTax ? VehicleProfilesCompanion(roadTaxExpiry: Value(due)) : VehicleProfilesCompanion(insuranceExpiry: Value(due)),
        );
        await applyAuto(db, s, _newId!, [AutoChange(source, planAuto(oldDate: null, newDate: due, existing: null, today: today()), null)]);
        continue;
      }
      await db.addReminder(RemindersCompanion(
        assetId: Value(_newId!),
        title: Value(p.title(s)),
        category: Value(p.category),
        ruleType: Value(p.rule),
        dueDate: Value(due),
        repeatMonths: Value(p.repeatMonths),
        repeatFrom: Value(p.repeatFrom),
        leadDays: Value(p.leadDays),
        source: Value(p.estimated ? 'preset' : 'template'),
        estimated: Value(p.estimated),
        note: Value(p.note(s)),
        confirmWith: Value(p.confirm(s)),
      ));
    }
    _finish(_picks.isNotEmpty);
  }

  void _finish(bool savedReminders) {
    _watch.stop();
    final s = context.s;
    if (_firstEver == true && savedReminders) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SetupDoneScreen(name: _name.text.trim(), elapsed: _elapsed())));
    } else {
      final id = _newId!;
      final msg = s.addedIn(_name.text.trim(), _elapsed());
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AssetDetailScreen(assetId: id)));
      snack(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    Widget body;
    switch (_step) {
      case 1:
        body = ListView(padding: const EdgeInsets.all(16), children: [
          Text(s.stepOf(1, 2), style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(s.whatAdding, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          for (final c in ['house', 'car', 'motorcycle']) ...[
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: AssetAvatar(c, size: 48),
                title: Text(s.categoryName(c), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(s.categoryHint(c)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() {
                  _cat = c;
                  _step = 2;
                }),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(s.onlyNameNeeded, style: theme.textTheme.bodySmall),
        ]);
      case 2:
        final house = _cat == 'house';
        body = ListView(padding: const EdgeInsets.all(16), children: [
          Text(s.stepOf(2, 2), style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(s.nameYour(_cat), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: s.nickname, hintText: s.nicknameHint(_cat), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          if (house) ...[
            FieldLabel(s.propertyType),
            for (final p in ['landed', 'strata', 'strata_landed'])
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: p,
                groupValue: _ptype,
                title: Text(s.ptypeName(p)),
                subtitle: Text(s.ptypeHint(p)),
                onChanged: (v) => setState(() => _ptype = v!),
              ),
            Text(s.ptypeWhy, style: theme.textTheme.bodySmall),
          ] else
            TextField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: s.plate, hintText: 'VKE 2231', border: const OutlineInputBorder()),
            ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), child: Text(s.back))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: _create, child: Text(s.done))),
          ]),
        ]);
      default:
        final sug = suggestionsFor(_cat, _ptype);
        body = ListView(padding: const EdgeInsets.all(16), children: [
          Text(s.optional.toUpperCase(), style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(s.suggestedReminders, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(s.tickAndDate),
          const SizedBox(height: 12),
          for (final p in sug) ...[
            Card(
              margin: EdgeInsets.zero,
              child: Column(children: [
                CheckboxListTile(
                  value: _picks.containsKey(p.key),
                  title: Row(children: [Flexible(child: Text(p.title(s))), if (p.estimated) const EstTag()]),
                  subtitle: Text(p.hint(s)),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _picks[p.key] = p.defaultDue?.call(today());
                    } else {
                      _picks.remove(p.key);
                    }
                    _error = null;
                  }),
                ),
                if (_picks.containsKey(p.key))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: DateField(label: s.dueDate, value: _picks[p.key], clearable: false, onChanged: (d) => setState(() => _picks[p.key] = d)),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          if (_cat == 'house' && _ptype == 'strata') NoteBox(s.strataInsuranceNote, icon: Icons.shield_outlined),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _finish(false), child: Text(s.skip))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: _picks.isEmpty ? () => _finish(false) : _savePicks, child: Text(s.saveN(_picks.length)))),
          ]),
        ]);
    }
    return PopScope(
      canPop: _step != 3,
      child: SafeScaffold(appBar: AppBar(title: Text(s.addAsset), automaticallyImplyLeading: _step != 3), body: body),
    );
  }
}

/// Shown once, after the very first reminder is saved: offers notifications and a backup.
class SetupDoneScreen extends StatelessWidget {
  const SetupDoneScreen({super.key, required this.name, required this.elapsed});
  final String name;
  final String elapsed;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return SafeScaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 32),
          Icon(Icons.check_circle, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(s.isSetUp(name), textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(s.addedInKeepSafe(elapsed), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ValueListenableBuilder<bool?>(
            valueListenable: context.app.notif,
            builder: (c, on, _) => CardList([
              ListTile(
                leading: Icon(on == true ? Icons.notifications_active_outlined : Icons.notifications_none),
                title: Text(s.notifications),
                subtitle: Text(on == true ? s.allowed : s.notifPitch),
                trailing: on == true ? const Icon(Icons.check) : FilledButton.tonal(onPressed: () => askNotifications(context), child: Text(s.allow)),
              ),
              ListTile(
                leading: const Icon(Icons.save_alt_outlined),
                title: Text(s.backupFile),
                subtitle: Text(s.backupPitch),
                trailing: FilledButton.tonal(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
                  child: Text(s.backUp),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: Text(s.goToToday)),
        ]),
      ),
    );
  }
}
