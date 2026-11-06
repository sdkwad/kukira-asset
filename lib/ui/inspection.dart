// The room-by-room check of a house (0.3, F4), and sending the defect list to the developer.

import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/inspection.dart';
import '../services/error_log.dart';
import '../services/inspection.dart';
import 'common.dart';
import 'forms.dart';

/// On the defects tab: the checks made so far, and starting a new one.
class InspectionsCard extends StatelessWidget {
  const InspectionsCard(this.a, this.w, {super.key});
  final Asset a;
  final World w;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final list = w.inspections.where((x) => x.assetId == a.id).toList();
    final ptype = w.houses[a.id]?.propertyType;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(s.inspectionTitle, count: list.length),
      if (list.isNotEmpty)
        CardList([
          for (final i in list)
            AppRow(
              leading: const IconAvatar(Icons.fact_check_outlined),
              title: s.inspectionKindName(i.kind),
              meta: '${s.dLong(i.date)} · ${_progressText(context, i, ptype)}',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InspectionScreen(inspectionId: i.id))),
            ),
        ]),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.fact_check_outlined),
        label: Text(s.startInspection),
        onPressed: () => startInspectionFlow(context, a, ptype),
      ),
    ]);
  }

  String _progressText(BuildContext context, Inspection i, String? ptype) {
    final p = progressOf(inspectionRooms(bedrooms: i.bedrooms, bathrooms: i.bathrooms, propertyType: ptype), _results(w, i));
    return context.s.inspectionProgress(p.checked, p.total, p.defects);
  }
}

Map<String, String> _results(World w, Inspection i) => {
      for (final c in w.inspectionChecks[i.id] ?? const <InspectionCheck>[])
        if (c.result != null) '${c.room}|${c.item}': c.result!,
    };

/// Asks what kind of check and how many rooms, then opens it.
Future<void> startInspectionFlow(BuildContext context, Asset a, String? ptype) async {
  final s = context.s;
  final picked = await showModalBottomSheet<(String, int, int)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => _StartSheet(propertyType: ptype),
  );
  if (picked == null || !context.mounted) return;
  try {
    final id = await startInspection(context.db, a.id, kind: picked.$1, bedrooms: picked.$2, bathrooms: picked.$3);
    if (context.mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => InspectionScreen(inspectionId: id)));
  } catch (e) {
    ErrorLog.record('inspection.start', e);
    if (context.mounted) snack(context, s.couldNotSave);
  }
}

class _StartSheet extends StatefulWidget {
  const _StartSheet({required this.propertyType});
  final String? propertyType;

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> {
  String _kind = 'vp';
  late int _beds = widget.propertyType == 'strata' ? 2 : 3;
  int _baths = 2;

  Widget _count(String label, int value, ValueChanged<int> onChanged) {
    final s = context.s;
    return Row(children: [
      Expanded(child: Text(label, style: KText.row)),
      IconButton(tooltip: s.fewer, icon: const Icon(Icons.remove_circle_outline), onPressed: value > 1 ? () => onChanged(value - 1) : null),
      SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center, style: KText.row)),
      IconButton(tooltip: s.more, icon: const Icon(Icons.add_circle_outline), onPressed: value < 8 ? () => onChanged(value + 1) : null),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.inspectionStartTitle, style: KText.title),
          const SizedBox(height: 12),
          ChoiceRow<String>(options: const ['vp', 'dlp'], value: _kind, label: s.inspectionKindName, onChanged: (v) => setState(() => _kind = v)),
          const SizedBox(height: 12),
          _count(s.bedroomsLabel, _beds, (v) => setState(() => _beds = v)),
          _count(s.bathroomsLabel, _baths, (v) => setState(() => _baths = v)),
          const SizedBox(height: 8),
          Text(s.inspectionHint, style: KText.meta.copyWith(color: context.tokens.textMuted)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(context, (_kind, _beds, _baths)), child: Text(s.startInspection)),
        ]),
      ),
    );
  }
}

class InspectionScreen extends StatelessWidget {
  const InspectionScreen({super.key, required this.inspectionId});
  final int inspectionId;

  @override
  Widget build(BuildContext context) => WorldView(builder: (context, w) {
        final s = context.s;
        final k = context.tokens;
        final ins = w.inspections.where((x) => x.id == inspectionId).firstOrNull;
        if (ins == null) return SafeScaffold(appBar: AppBar());
        final rooms = inspectionRooms(bedrooms: ins.bedrooms, bathrooms: ins.bathrooms, propertyType: w.houses[ins.assetId]?.propertyType);
        final results = _results(w, ins);
        final checks = {for (final c in w.inspectionChecks[ins.id] ?? const <InspectionCheck>[]) '${c.room}|${c.item}': c};
        final p = progressOf(rooms, results);
        return SafeScaffold(
          appBar: AppBar(title: Text(s.inspectionTitle)),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            Text(s.inspectionKindName(ins.kind), style: KText.title.copyWith(color: k.text)),
            const SizedBox(height: 2),
            Text(s.dLong(ins.date), style: KText.meta.copyWith(color: k.textMuted)),
            const SizedBox(height: 12),
            Text(s.inspectionProgress(p.checked, p.total, p.defects), style: KText.row.copyWith(color: k.text)),
            const SizedBox(height: 8),
            ProgressLine(p.total == 0 ? 0 : p.checked / p.total),
            const SizedBox(height: 8),
            Text(s.inspectionHint, style: KText.meta.copyWith(color: k.textMuted)),
            for (final room in rooms) ...[
              Builder(builder: (_) {
                final rp = progressOf([room], results);
                return SectionTitle(s.roomName(room), note: s.inspectionProgress(rp.checked, rp.total, rp.defects));
              }),
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  for (final item in roomItems(room))
                    _ItemRow(ins: ins, room: room, item: item, check: checks['$room|$item']),
                ]),
              ),
            ],
          ]),
        );
      });
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.ins, required this.room, required this.item, required this.check});
  final Inspection ins;
  final String room;
  final String item;
  final InspectionCheck? check;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final k = context.tokens;
    final result = check?.result;
    Future<void> set(String? v) async {
      try {
        await setCheck(context.db, s, ins, room, item, v);
      } catch (e) {
        ErrorLog.record('inspection.check', e);
        if (context.mounted) snack(context, s.couldNotSave);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(s.inspectionItemName(item), style: KText.row.copyWith(color: k.text))),
          SegmentedButton<String>(
            key: ValueKey('check-$room-$item'),
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.padded),
            segments: [
              ButtonSegment(value: 'ok', label: Text(s.resultOk)),
              ButtonSegment(value: 'defect', label: Text(s.resultDefect)),
              ButtonSegment(value: 'na', label: Text(s.resultNa)),
            ],
            selected: {if (result != null) result},
            onSelectionChanged: (v) => set(v.isEmpty ? null : v.first),
          ),
        ]),
        if (result == 'defect' && check?.recordId != null)
          TextButton.icon(
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text(s.addDefectDetails),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecordFormScreen(editId: check!.recordId))),
          ),
      ]),
    );
  }
}

/// Under the defect list: send the defects not fixed yet to the developer, after saying that
/// the text and photos leave the phone.
class SendDefectsButton extends StatelessWidget {
  const SendDefectsButton(this.a, this.w, {super.key});
  final Asset a;
  final World w;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final n = defectsToSend(w, a.id).length;
    if (n == 0) return const SizedBox.shrink();
    return FilledButton.tonalIcon(
      icon: const Icon(Icons.send_outlined),
      label: Text(s.sendDefects),
      onPressed: () async {
        final ok = await confirm(context, title: s.sendDefectsQ, body: s.sendDefectsBody(n), ok: s.sendDefectsAction);
        if (!ok || !context.mounted) return;
        final unreported = defectsToSend(w, a.id).where((d) => d.reportedToDeveloper == null).length;
        try {
          final sent = await sendDefectReport(context.db, s, w, a.id);
          if (sent && context.mounted && unreported > 0) snack(context, s.defectsSentSaved(unreported));
        } catch (e) {
          ErrorLog.record('inspection.send', e);
          if (context.mounted) snack(context, s.couldNotSave);
        }
      },
    );
  }
}
