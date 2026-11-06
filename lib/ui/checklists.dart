// Checklists used again and again (0.3, F7): before a long drive back to the kampung, and
// before leaving the house for a while.

import 'package:flutter/material.dart';

import '../data/db.dart';
import '../services/checklists.dart';
import '../services/error_log.dart';
import 'common.dart';

class ChecklistsScreen extends StatelessWidget {
  const ChecklistsScreen({super.key});

  @override
  Widget build(BuildContext context) => WorldView(builder: (context, w) {
        final s = context.s;
        return SafeScaffold(
          appBar: AppBar(title: Text(s.checklistsTitle)),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: Text(s.newChecklist),
            onPressed: () => _newChecklist(context, w),
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, KSpace.fabClearance), children: [
            if (w.checklists.isEmpty) NoteBox(s.checklistsEmpty, icon: Icons.checklist),
            CardList([
              for (final c in w.checklists)
                AppRow(
                  leading: const IconAvatar(Icons.checklist),
                  title: c.title,
                  meta: [
                    s.checkedCount((w.checklistItems[c.id] ?? const []).where((i) => i.checked).length, (w.checklistItems[c.id] ?? const []).length),
                    if (c.assetId != null && w.asset(c.assetId!) != null) w.asset(c.assetId!)!.nickname,
                    if (c.lastUsed != null) s.lastUsedOn(s.dShort(c.lastUsed!)),
                  ].join(' · '),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChecklistScreen(checklistId: c.id))),
                ),
            ]),
          ]),
        );
      });

  Future<void> _newChecklist(BuildContext context, World w) async {
    final s = context.s;
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final t in checklistTemplates)
            ListTile(
              leading: Icon(t == 'tripCar' ? Icons.directions_car_outlined : Icons.home_outlined),
              title: Text(s.checklistTemplateTitle(t)),
              subtitle: Text(s.checklistTemplateHint(t)),
              onTap: () => Navigator.pop(c, t),
            ),
          ListTile(leading: const Icon(Icons.edit_note), title: Text(s.checklistBlank), onTap: () => Navigator.pop(c, 'blank')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (pick == null || !context.mounted) return;
    // A car list goes with a vehicle, a house list with a house, when there is just one.
    final kind = pick == 'tripCar' ? (Asset a) => a.category != 'house' : (Asset a) => a.category == 'house';
    final fits = pick == 'blank' ? <Asset>[] : w.assets.where(kind).toList();
    try {
      final id = await createChecklist(
        context.db,
        title: pick == 'blank' ? s.checklistBlank : s.checklistTemplateTitle(pick),
        assetId: fits.length == 1 ? fits.single.id : null,
        labels: pick == 'blank' ? const [] : s.checklistTemplateItems(pick),
      );
      if (context.mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => ChecklistScreen(checklistId: id)));
    } catch (e) {
      ErrorLog.record('checklist.create', e);
      if (context.mounted) snack(context, s.couldNotSave);
    }
  }
}

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key, required this.checklistId});
  final int checklistId;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final _add = TextEditingController();

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WorldView(builder: (context, w) {
        final s = context.s;
        final k = context.tokens;
        final db = context.db;
        final list = w.checklists.where((c) => c.id == widget.checklistId).firstOrNull;
        if (list == null) return SafeScaffold(appBar: AppBar());
        final items = w.checklistItems[list.id] ?? const <ChecklistItem>[];
        final done = items.where((i) => i.checked).length;
        return SafeScaffold(
          appBar: AppBar(
            title: Text(list.title),
            actions: [
              IconButton(
                tooltip: s.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (!await confirm(context, title: s.deleteChecklistQ, body: s.cannotUndo, ok: s.delete, danger: true)) return;
                  await deleteChecklist(db, list);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            Text(s.checkedCount(done, items.length), style: KText.row.copyWith(color: k.text)),
            const SizedBox(height: 8),
            ProgressLine(items.isEmpty ? 0 : done / items.length),
            const SizedBox(height: 12),
            if (items.isNotEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  for (final i in items)
                    CheckboxListTile(
                      value: i.checked,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(i.label, style: i.checked ? TextStyle(color: k.textMuted, decoration: TextDecoration.lineThrough) : null),
                      secondary: IconButton(tooltip: s.removeItem, icon: const Icon(Icons.close), onPressed: () => removeChecklistItem(db, i)),
                      onChanged: (v) => setItemChecked(db, i, v ?? false),
                    ),
                ]),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _add,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: s.addItem, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.add)),
              onSubmitted: (v) async {
                if (v.trim().isEmpty) return;
                await addChecklistItem(db, list, v, position: items.length);
                _add.clear();
              },
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: Text(s.restartChecklist),
                  onPressed: done == 0
                      ? null
                      : () async {
                          await restartChecklist(db, list);
                          if (context.mounted) snack(context, s.checklistRestarted);
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.alarm_add_outlined),
                  label: Text(s.remindMe),
                  onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: today().add(const Duration(days: 7)), firstDate: today(), lastDate: DateTime(2100));
                    if (d == null || !context.mounted) return;
                    final ok = await remindChecklist(db, s, w, list, d);
                    if (context.mounted) snack(context, ok ? s.checklistReminded(s.dLong(d)) : s.addAssetFirst);
                  },
                ),
              ),
            ]),
            if (list.lastUsed != null) ...[
              const SizedBox(height: 8),
              Text(s.lastUsedOn(s.dLong(list.lastUsed!)), style: KText.meta.copyWith(color: k.textMuted)),
            ],
          ]),
        );
      });
}
