import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/renewal.dart';
import '../domain/rules.dart';
import '../services/error_log.dart';
import '../services/renewal.dart';
import 'assets.dart';
import 'combo.dart';
import 'common.dart';
import 'documents.dart';

/// Opens the renewal of [kind] for vehicle [assetId]. [both] starts with the other cover
/// switched on too, when the two end close together.
Future<void> openRenewal(BuildContext context, int assetId, RenewKind kind, {bool both = false}) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => RenewScreen(assetId: assetId, kind: kind, both: both)));

/// One cover on the form, with what the owner changed.
class _Cover {
  _Cover(this.kind, RenewSuggestion sg, {String? insurer})
      : months = sg.months == 6 || sg.months == 12 ? sg.months : 0,
        start = sg.start,
        end = sg.end,
        fromHistory = sg.fromHistory,
        suggestedMonths = sg.months,
        insurer = TextEditingController(text: insurer ?? '');

  final RenewKind kind;

  /// 6 or 12, or 0 for another length (the end date is then set by hand).
  int months;
  DateTime start;
  DateTime end;
  final bool fromHistory;
  final int suggestedMonths;
  final cost = TextEditingController();
  final TextEditingController insurer;
  Picked? proof;

  bool get roadTax => kind == RenewKind.roadTax;

  void dispose() {
    cost.dispose();
    insurer.dispose();
  }
}

/// Renews road tax or insurance: how long, from and to when, the cost and a proof, all but
/// the dates optional. When both end close together the other can be renewed at the same
/// time, with dates of its own. The old period stays in the history and the reminder moves
/// to the new end.
class RenewScreen extends StatefulWidget {
  const RenewScreen({super.key, required this.assetId, required this.kind, this.both = false});
  final int assetId;
  final RenewKind kind;
  final bool both;

  @override
  State<RenewScreen> createState() => _RenewState();
}

class _RenewState extends State<RenewScreen> {
  final Map<RenewKind, _Cover> _covers = {};
  late bool _both = widget.both;
  String? _error;

  @override
  void dispose() {
    for (final c in _covers.values) {
      c.dispose();
    }
    super.dispose();
  }

  _Cover _cover(World w, VehicleProfile v, RenewKind k) => _covers[k] ??= _Cover(
        k,
        suggestRenewal(currentEnd: coverEndOf(v, k), lastStart: currentCoverRecord(w, widget.assetId, k)?.coverStart, today: today()),
        insurer: k == RenewKind.insurance ? v.insuranceProvider : null,
      );

  String _name(RenewKind k) => k == RenewKind.roadTax ? context.s.catName('road_tax') : context.s.insuranceWord;

  Future<void> _pickProof(_Cover c) async {
    final s = context.s;
    final src = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (v, icon, label) in [
            ('camera', Icons.photo_camera_outlined, s.camera),
            ('gallery', Icons.photo_library_outlined, s.gallery),
            ('files', Icons.folder_outlined, s.filesPdf),
          ])
            ListTile(leading: Icon(icon), title: Text(label), onTap: () => Navigator.pop(sheet, v)),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (src == null || !mounted) return;
    final p = await pickFile(context, src);
    if (p != null && mounted) setState(() => c.proof = p);
  }

  Future<void> _save(World w, List<_Cover> covers) async {
    final s = context.s;
    final inputs = <RenewInput>[];
    for (final c in covers) {
      if (c.end.isBefore(c.start)) return setState(() => _error = s.endBeforeStart);
      final text = c.cost.text.replaceAll(',', '').trim();
      final cost = text.isEmpty ? null : double.tryParse(text);
      if (text.isNotEmpty && (cost == null || cost < 0)) return setState(() => _error = s.costInvalid);
      final p = c.proof;
      inputs.add(RenewInput(
        kind: c.kind,
        start: c.start,
        end: c.end,
        cost: cost,
        insurer: c.roadTax ? null : c.insurer.text,
        proof: p == null ? null : (p.bytes, p.ext),
      ));
    }
    setState(() => _error = null);
    final List<String> msgs;
    try {
      msgs = await applyRenewal(context.db, s, w, widget.assetId, inputs, today: today());
    } catch (e) {
      ErrorLog.record('renewal.save', e);
      if (mounted) snack(context, s.couldNotSave);
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    snack(context, msgs.join(' '));
  }

  Widget _fields(World w, _Cover c, {required bool heading}) {
    final s = context.s;
    final help = Theme.of(context).textTheme.bodySmall;
    void setStart(DateTime? d) {
      if (d == null) return;
      setState(() {
        c.start = dayOnly(d);
        if (c.months != 0) c.end = coverEnd(c.start, c.months);
      });
    }

    void setEnd(DateTime? d) {
      if (d == null) return;
      setState(() {
        c.end = dayOnly(d);
        c.months = c.end == coverEnd(c.start, 6) ? 6 : (c.end == coverEnd(c.start, 12) ? 12 : 0);
      });
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (heading) SectionTitle(_name(c.kind)),
      FieldLabel(s.coverLength),
      SegmentedButton<int>(
        segments: [
          ButtonSegment(value: 6, label: Text(s.monthsCount(6))),
          ButtonSegment(value: 12, label: Text(s.monthsCount(12))),
          ButtonSegment(value: 0, label: Text(s.otherLength)),
        ],
        selected: {c.months},
        onSelectionChanged: (v) => setState(() {
          c.months = v.first;
          if (c.months != 0) c.end = coverEnd(c.start, c.months);
        }),
      ),
      if (c.fromHistory) Padding(padding: const EdgeInsets.only(top: 4), child: Text(s.suggestedFromLast(c.suggestedMonths), style: help)),
      const SizedBox(height: 14),
      DateField(label: s.coverStartLabel, value: c.start, clearable: false, onChanged: setStart),
      const SizedBox(height: 12),
      DateField(label: s.coverNewEnd, value: c.end, clearable: false, onChanged: setEnd),
      Padding(padding: const EdgeInsets.only(top: 4), child: Text(c.roadTax ? s.renewHelpRoadTax : s.renewHelpInsurance, style: help)),
      const SizedBox(height: 14),
      if (!c.roadTax) ...[
        ComboField(controller: c.insurer, label: s.insurer, options: insurerOptions(w), source: s.insurerListSource),
        const SizedBox(height: 12),
      ],
      TextField(
        controller: c.cost,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: s.costOptional, prefixText: 'RM ', border: const OutlineInputBorder()),
      ),
      const SizedBox(height: 12),
      if (c.proof == null)
        OutlinedButton.icon(icon: const Icon(Icons.attach_file), label: Text(s.addProof), onPressed: () => _pickProof(c))
      else
        Align(
          alignment: Alignment.centerLeft,
          child: InputChip(
            avatar: const Icon(Icons.description_outlined, size: 18),
            label: Text(c.proof!.name ?? s.proofAttached, overflow: TextOverflow.ellipsis),
            onDeleted: () => setState(() => c.proof = null),
            deleteButtonTooltipMessage: s.remove,
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final a = w.asset(widget.assetId);
      final v = w.vehicles[widget.assetId];
      if (a == null || v == null) return SafeScaffold(appBar: AppBar());
      final main = _cover(w, v, widget.kind);
      final otherKind = widget.kind == RenewKind.roadTax ? RenewKind.insurance : RenewKind.roadTax;
      final canBoth = renewTogether(v.roadTaxExpiry, v.insuranceExpiry);
      final other = canBoth && _both ? _cover(w, v, otherKind) : null;
      final covers = [main, if (other != null) other];
      final now = coverEndOf(v, widget.kind);
      final String nowText;
      if (now == null) {
        nowText = s.notSet;
      } else {
        final n = daysBetween(today(), now);
        nowText = '${s.currentEnds(s.dLong(now))} · ${n > 0 ? s.inDays(n) : (n == 0 ? s.dueToday : s.lateDays(-n))}';
      }
      final rec = currentCoverRecord(w, widget.assetId, widget.kind);
      final history = rec != null
          ? s.renewKeepsPeriod(s.dLong(rec.coverStart!), s.dLong(rec.coverEnd!))
          : (now != null ? s.renewReplacesEnd(s.dLong(now)) : s.renewFirst);
      final otherEnd = coverEndOf(v, otherKind);
      return SafeScaffold(
        appBar: AppBar(leading: const CloseButton(), title: Text(widget.kind == RenewKind.roadTax ? s.renewRoadTax : s.renewInsurance)),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              CardList([
                AppRow(leading: AssetAvatar(a.category, size: 36), title: a.nickname, titleTag: Plate(v.plate), meta: nowText),
              ]),
              const SizedBox(height: 12),
              _fields(w, main, heading: other != null),
              if (canBoth && otherEnd != null) ...[
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: SwitchListTile(
                    value: _both,
                    title: Text(s.renewAlsoQ(_name(otherKind)), style: KText.row.copyWith(color: context.tokens.text)),
                    subtitle: Text(s.alsoEndsOn(_name(otherKind), a.nickname, s.dLong(otherEnd))),
                    onChanged: (x) => setState(() => _both = x),
                  ),
                ),
              ],
              if (other != null) ...[const SizedBox(height: 8), _fields(w, other, heading: true)],
              const SizedBox(height: 16),
              NoteBox(history, icon: Icons.history),
              if (_error != null)
                Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SaveButton(onPressed: () => _save(w, covers), child: Text(s.saveEndsOn(s.dLong(main.end)))),
          ),
        ]),
      );
    });
  }
}
