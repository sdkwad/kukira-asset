import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/rules.dart';
import '../services/notifications.dart';
import 'add_asset.dart';
import 'common.dart';
import 'forms.dart';

String assetSubtitle(BuildContext context, Asset a, World w) {
  final s = context.s;
  if (a.category == 'house') {
    final h = w.houses[a.id];
    final parts = [s.ptypeName(h?.propertyType ?? 'landed'), if (h?.council != null) h!.council!];
    return parts.join(' · ');
  }
  final v = w.vehicles[a.id];
  final mm = [v?.make, v?.model].whereType<String>().join(' ');
  return mm.isEmpty ? s.categoryName(a.category) : mm;
}

DateTime? dlpEnd(World w, int assetId) {
  final h = w.houses[assetId];
  if (h == null || h.vpDate == null) return null;
  return h.dlpEndOverride ?? dlpEndFrom(h.vpDate!);
}

class Plate extends StatelessWidget {
  const Plate(this.text, {super.key, this.big = false});
  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: big ? 12 : 7, vertical: big ? 4 : 1),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(big ? 7 : 5)),
        child: Text(
          text,
          style: TextStyle(color: const Color(0xFFF4F4F4), fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: big ? 20 : 12, fontFamily: 'monospace'),
        ),
      );
}

// ================================================================ list

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final q = _q.trim().toLowerCase();
      Widget body;
      if (q.isEmpty) {
        body = Column(children: [
          for (final a in w.assets) ...[_AssetCard(a, w), const SizedBox(height: 10)],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.add),
            label: Text(s.addAsset),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAssetScreen())),
          ),
        ]);
      } else {
        final as = w.assets.where((a) => '${a.nickname} ${w.vehicles[a.id]?.plate ?? ''} ${assetSubtitle(context, a, w)}'.toLowerCase().contains(q)).toList();
        final rs = w.reminders.where((r) => !r.done && r.title.toLowerCase().contains(q)).toList();
        final recs = w.records.where((r) => '${r.title} ${r.vendorName ?? ''} ${r.area ?? ''} ${r.notes ?? ''}'.toLowerCase().contains(q)).toList();
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle(s.assetsTab, count: as.length),
          CardList([
            for (final a in as)
              ListTile(
                leading: AssetAvatar(a.category, size: 36),
                title: Text(a.nickname),
                subtitle: Text(assetSubtitle(context, a, w)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssetDetailScreen(assetId: a.id))),
              ),
          ], empty: s.noMatch),
          SectionTitle(s.remindersTab, count: rs.length),
          CardList([for (final r in rs) ReminderTile(r, w, onTap: () => showReminderSheet(context, r.id))], empty: s.noMatch),
          SectionTitle(s.recordsTitle, count: recs.length),
          CardList([for (final r in recs) RecordTile(r, w, showAsset: true)], empty: s.noMatch),
        ]);
      }
      return Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
              child: Text(s.assetsTab, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            SearchBar(
              hintText: s.searchHint,
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 14),
            body,
          ]),
        ),
      );
    });
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard(this.a, this.w);
  final Asset a;
  final World w;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final next = (w.reminders.where((r) => !r.done && r.assetId == a.id).toList()..sort(remOrder(w))).firstOrNull;
    final end = dlpEnd(w, a.id);
    final left = end == null ? null : daysBetween(today(), end);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssetDetailScreen(assetId: a.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AssetAvatar(a.category, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.nickname, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (w.vehicles[a.id] != null) ...[Plate(w.vehicles[a.id]!.plate), const SizedBox(width: 6)],
                    Flexible(child: Text(assetSubtitle(context, a, w), style: TextStyle(color: muted, fontSize: 13))),
                  ]),
                ]),
              ),
              Icon(Icons.chevron_right, color: muted),
            ]),
            const Divider(height: 22),
            if (next == null)
              Text(s.noRemindersYet, style: TextStyle(color: muted))
            else
              Row(children: [
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${s.nextLabel}: '),
                    TextSpan(text: next.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: '\n${dueText(s, next, w)}', style: TextStyle(color: muted, fontSize: 13)),
                  ])),
                ),
                StatusPill(remStatus(next, w)),
              ]),
            if (left != null && left > 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.construction_outlined, size: 16, color: muted),
                const SizedBox(width: 6),
                Expanded(child: Text(s.dlpDaysLeftShort(left), style: TextStyle(fontSize: 13, color: muted))),
                const EstTag(),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

// ================================================================ detail

class AssetDetailScreen extends StatelessWidget {
  const AssetDetailScreen({super.key, required this.assetId});
  final int assetId;

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final a = w.asset(assetId);
      if (a == null) return Scaffold(appBar: AppBar(), body: Center(child: Text(s.assetDeleted)));
      final end = dlpEnd(w, a.id);
      final showDefects = a.category == 'house' && end != null && daysBetween(today(), end) > 0;
      final tabs = [s.overviewTab, s.upkeepTab, s.remindersTab, if (showDefects) s.defectsTab];
      return DefaultTabController(
        key: ValueKey(tabs.length),
        length: tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: Text(a.nickname),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => a.category == 'house' ? HouseEditScreen(assetId: a.id) : VehicleEditScreen(assetId: a.id)));
                  } else if (v == 'delete') {
                    final ok = await confirm(context, title: s.deleteAssetQ(a.nickname), body: s.deleteAssetBody, ok: s.delete, danger: true);
                    if (ok && context.mounted) {
                      await context.db.deleteAsset(a.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(s.editDetails)),
                  PopupMenuItem(value: 'delete', child: Text(s.deleteAsset)),
                ],
              ),
            ],
            bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in tabs) Tab(text: t)]),
          ),
          body: TabBarView(children: [
            _Overview(a, w),
            _Upkeep(a, w),
            _Reminders(a, w),
            if (showDefects) _Defects(a, w),
          ]),
        ),
      );
    });
  }
}

class _Overview extends StatelessWidget {
  const _Overview(this.a, this.w);
  final Asset a;
  final World w;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final children = <Widget>[];
    void edit() => Navigator.push(context, MaterialPageRoute(builder: (_) => a.category == 'house' ? HouseEditScreen(assetId: a.id) : VehicleEditScreen(assetId: a.id)));
    if (a.category == 'house') {
      final h = w.houses[a.id]!;
      children.add(Facts([
        (s.propertyType, s.ptypeName(h.propertyType)),
        if (h.source != null) (s.boughtAs, s.sourceName(h.source!)),
        if (h.vpDate != null) (s.vpDate, s.dLong(h.vpDate!)),
        if (h.spaDate != null) (s.spaDate, s.dLong(h.spaDate!)),
        if (h.titleStatus != null) (s.titleStatus, s.titleName(h.titleStatus!)),
        if (h.council != null) (s.council, h.council!),
        if (h.state != null) (s.state, h.state!),
        if (h.occupancy != null) (s.occupancy, s.occupancyName(h.occupancy!)),
        if (h.address != null) (s.address, h.address!),
        if (h.contact != null) (s.contact, h.contact!),
        if (a.notes != null) (s.notes, a.notes!),
      ]));
      final end = dlpEnd(w, a.id);
      if (end != null) {
        final left = daysBetween(today(), end);
        final total = daysBetween(h.vpDate!, end);
        final gone = daysBetween(h.vpDate!, today()).clamp(0, total);
        children.add(const SizedBox(height: 12));
        if (left > 0) {
          children.add(Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.dlpTitle.toUpperCase(), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Text.rich(TextSpan(children: [
                  TextSpan(text: '$left ', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                  TextSpan(text: s.dlpDaysLeft),
                ])),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: total == 0 ? 1.0 : gone / total, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: Text('VP ${s.dShort(h.vpDate!)}', style: Theme.of(context).textTheme.bodySmall)),
                  Text(s.endsAbout(s.dLong(end)), style: Theme.of(context).textTheme.bodySmall),
                ]),
                const SizedBox(height: 10),
                NoteBox(s.dlpNote, warn: true),
                if (h.source == 'subsale') ...[const SizedBox(height: 8), NoteBox(s.dlpSubsaleNote)],
              ]),
            ),
          ));
        } else {
          children.add(NoteBox(s.dlpEnded(s.dLong(end))));
        }
      } else if (h.source != 'subsale') {
        children.add(const SizedBox(height: 12));
        children.add(NoteBox(s.addVpForDlp));
      }
      if (h.propertyType == 'strata') {
        children.add(const SizedBox(height: 12));
        children.add(NoteBox(s.strataInsuranceNote, icon: Icons.shield_outlined));
      }
    } else {
      final v = w.vehicles[a.id]!;
      final o = w.odometer[a.id];
      children.addAll([
        Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Plate(v.plate, big: true))),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            leading: const Icon(Icons.speed_outlined, size: 32),
            title: Text(o == null ? s.odoNotSet : s.km(o.km), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            subtitle: Text(o == null ? s.odoAddFirst : s.odoLastUpdated(s.ago(o.date))),
            trailing: FilledButton.tonal(onPressed: () => showOdometerDialog(context, a.id), child: Text(s.update)),
          ),
        ),
        const SizedBox(height: 12),
        Facts([
          if (v.make != null || v.model != null) (s.vehicle, [v.make, v.model, v.year?.toString()].whereType<String>().join(' ')),
          (s.roadTaxExpiry, v.roadTaxExpiry == null ? s.notSet : s.dLong(v.roadTaxExpiry!)),
          (s.insuranceExpiry, v.insuranceExpiry == null ? s.notSet : s.dLong(v.insuranceExpiry!)),
          if (v.insuranceProvider != null) (s.insurer, v.insuranceProvider!),
          if (v.policyNo != null) (s.policyNo, v.policyNo!),
          if (v.warrantyExpiry != null || v.warrantyKm != null)
            (s.warranty, [if (v.warrantyExpiry != null) s.dLong(v.warrantyExpiry!), if (v.warrantyKm != null) s.km(v.warrantyKm!)].join(s.orWord)),
          if (v.condition != null) (s.boughtAs, s.conditionName(v.condition!)),
          if (a.notes != null) (s.notes, a.notes!),
        ]),
      ]);
    }
    children.addAll([
      const SizedBox(height: 12),
      OutlinedButton.icon(icon: const Icon(Icons.edit_outlined), label: Text(s.editDetails), onPressed: edit),
    ]);
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}

class RecordTile extends StatelessWidget {
  const RecordTile(this.r, this.w, {super.key, this.showAsset = false});
  final UpkeepRecord r;
  final World w;
  final bool showAsset;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final meta = [
      s.dLong(r.date),
      '${s.kindName(r.kind)}${r.category != null ? ' · ${s.catName(r.category!)}' : ''}',
      if (r.cost != null) s.rm(r.cost!),
      if (r.odometer != null) s.km(r.odometer!),
      if (r.vendorName != null) r.vendorName!,
      if (showAsset) w.asset(r.assetId)?.nickname ?? '',
    ].join(' · ');
    return ListTile(
      leading: Icon(r.kind == 'payment' ? Icons.receipt_long_outlined : r.kind == 'incident' ? Icons.report_gmailerrorred_outlined : Icons.build_outlined),
      title: Text(r.title),
      subtitle: Text(meta),
      onTap: () => _showRecordSheet(context, r),
    );
  }
}

Future<void> _showRecordSheet(BuildContext context, UpkeepRecord r) {
  final s = context.s;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(r.title, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Facts([
            (s.date, s.dLong(r.date)),
            (s.kind, s.kindName(r.kind)),
            if (r.category != null) (s.category, s.catName(r.category!)),
            if (r.cost != null) (s.totalCost, s.rm(r.cost!)),
            if (r.vendorName != null) (s.vendor, r.vendorName!),
            if (r.area != null) (s.area, r.area!),
            if (r.odometer != null) (s.odometerKm, s.km(r.odometer!)),
            if (r.warrantyEnd != null) (s.warrantyEndLabel, s.dLong(r.warrantyEnd!)),
            if (r.insuranceClaim == true) (s.madeClaim, s.yes),
            if (r.notes != null) (s.notes, r.notes!),
          ]),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: Text(s.deleteRecord),
            onPressed: () async {
              final ok = await confirm(c, title: s.deleteRecordQ, body: s.cannotUndo, ok: s.delete, danger: true);
              if (!ok || !c.mounted) return;
              await c.db.deleteRecord(r.id);
              if (c.mounted) Navigator.pop(c);
            },
          ),
        ]),
      ),
    ),
  );
}

class _Upkeep extends StatelessWidget {
  const _Upkeep(this.a, this.w);
  final Asset a;
  final World w;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final rs = w.records.where((r) => r.assetId == a.id && r.kind != 'defect').toList();
    final year = today().year;
    final spent = rs.where((r) => r.date.year == year).fold<double>(0, (t, r) => t + (r.cost ?? 0));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [Expanded(child: Text(s.spentThisYear(year))), Text(s.rm(spent), style: const TextStyle(fontWeight: FontWeight.w700))]),
      const SizedBox(height: 12),
      CardList([for (final r in rs) RecordTile(r, w)], empty: s.noRecordsYet),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: Text(s.addRecord),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecordFormScreen(assetId: a.id))),
      ),
    ]);
  }
}

class _Reminders extends StatelessWidget {
  const _Reminders(this.a, this.w);
  final Asset a;
  final World w;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final rs = w.reminders.where((r) => r.assetId == a.id && !r.done).toList()..sort(remOrder(w));
    return ListView(padding: const EdgeInsets.all(16), children: [
      CardList([for (final r in rs) ReminderTile(r, w, showAsset: false, onTap: () => showReminderSheet(context, r.id))], empty: s.noRemindersYet),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: Text(s.addReminder),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReminderFormScreen(assetId: a.id))),
      ),
    ]);
  }
}

class _Defects extends StatelessWidget {
  const _Defects(this.a, this.w);
  final Asset a;
  final World w;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final end = dlpEnd(w, a.id)!;
    final left = daysBetween(today(), end);
    final ds = w.records.where((r) => r.assetId == a.id && r.kind == 'defect').toList();
    Widget group(String status, String label) {
      final g = ds.where((r) => (r.status ?? 'open') == status).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(label, count: g.length),
        CardList([
          for (final r in g)
            ListTile(
              leading: const Icon(Icons.construction_outlined),
              title: Text(r.title),
              subtitle: Text([
                if (r.area != null) r.area!,
                s.foundOn(s.dShort(r.date)),
                r.reportedToDeveloper == null ? s.notReportedYet : s.reportedOn(s.dShort(r.reportedToDeveloper!)),
              ].join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDefectSheet(context, r.id),
            ),
        ], empty: s.none),
      ]);
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '$left ', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
              TextSpan(text: s.dlpDaysLeftEnds(s.dLong(end))),
            ])),
            const SizedBox(height: 10),
            NoteBox(s.defectReportNote, warn: true),
          ]),
        ),
      ),
      group('open', s.defectOpen),
      group('in_progress', s.defectInProgress),
      group('done', s.defectFixed),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: Text(s.addDefect),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecordFormScreen(assetId: a.id, kind: 'defect'))),
      ),
    ]);
  }
}

Future<void> _showDefectSheet(BuildContext context, int recordId) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => WorldView(builder: (c, w) {
      final s = c.s;
      final r = w.records.where((x) => x.id == recordId).firstOrNull;
      if (r == null) return const SizedBox(height: 100);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(r.title, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Facts([
              (s.area, r.area ?? s.notSet),
              (s.found, s.dLong(r.date)),
              (s.reported, r.reportedToDeveloper == null ? s.notYet : s.dLong(r.reportedToDeveloper!)),
            ]),
            const SizedBox(height: 12),
            FieldLabel(s.statusWord),
            ChoiceRow<String>(
              options: const ['open', 'in_progress', 'done'],
              value: r.status ?? 'open',
              label: s.defectStatusName,
              onChanged: (v) => c.db.updateRecord(r.id, RecordsCompanion(status: Value(v))),
            ),
            const SizedBox(height: 12),
            if (r.reportedToDeveloper == null)
              FilledButton(
                onPressed: () async {
                  await c.db.updateRecord(r.id, RecordsCompanion(
                    reportedToDeveloper: Value(today()),
                    status: Value(r.status == null || r.status == 'open' ? 'in_progress' : r.status),
                  ));
                  if (c.mounted) snack(c, s.reportedToday);
                },
                child: Text(s.markReportedToday),
              ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: Text(s.deleteRecord),
              onPressed: () async {
                final ok = await confirm(c, title: s.deleteRecordQ, body: s.cannotUndo, ok: s.delete, danger: true);
                if (!ok || !c.mounted) return;
                await c.db.deleteRecord(r.id);
                if (sheet.mounted) Navigator.pop(sheet);
              },
            ),
          ]),
        ),
      );
    }),
  );
}

// ================================================================ odometer

Future<void> showOdometerDialog(BuildContext context, int assetId) async {
  final s = context.s;
  final w = context.app.world.value!;
  final a = w.asset(assetId)!;
  final cur = w.odoOf(assetId);
  final ctrl = TextEditingController(text: cur?.toString() ?? '');
  String? err;
  final km = await showDialog<int>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(s.odoDialogTitle(a.nickname)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (cur != null) Text(s.odoLast(s.km(cur), s.ago(w.odometer[assetId]!.date))),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: s.odometerKm, errorText: err, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Text(s.odoCheckNote, style: Theme.of(c).textTheme.bodySmall),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
          FilledButton(
            onPressed: () {
              final v = parseInt(ctrl.text);
              if (v == null || (cur != null && v < cur)) {
                set(() => err = s.odoTooLow(s.km(cur ?? 0)));
                return;
              }
              Navigator.pop(c, v);
            },
            child: Text(s.save),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
  if (km == null || !context.mounted) return;
  final before = {for (final r in w.reminders.where((r) => r.assetId == assetId && !r.done && r.info.usesKm)) r.id: statusOf(r.info, today: today(), odometer: cur)};
  await context.db.addOdometer(assetId, km, DateTime.now());
  final changed = <String>[];
  for (final r in w.reminders.where((r) => before.containsKey(r.id))) {
    final now = statusOf(r.info, today: today(), odometer: km);
    if (now != before[r.id] && (now == RStatus.overdue || now == RStatus.dueSoon)) {
      changed.add(s.nowStatus(r.title, s.statusLabel(now)));
    }
  }
  if (!context.mounted) return;
  if (changed.isEmpty) {
    snack(context, s.odoSaved(s.km(km)));
  } else {
    snack(context, changed.join(' '));
    if (context.app.notif.value == true) {
      await Notifier.mileage(s, s.mileageNoteTitle(a.nickname), changed.first);
    }
  }
}

// ================================================================ edit screens

class HouseEditScreen extends StatefulWidget {
  const HouseEditScreen({super.key, required this.assetId});
  final int assetId;

  @override
  State<HouseEditScreen> createState() => _HouseEditState();
}

class _HouseEditState extends State<HouseEditScreen> {
  final _name = TextEditingController();
  final _council = TextEditingController();
  final _state = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _notes = TextEditingController();
  String _ptype = 'landed';
  String? _source;
  String? _title;
  String? _occupancy;
  DateTime? _vp;
  DateTime? _spa;
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_name, _council, _state, _address, _contact, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final a = w.asset(widget.assetId);
      final h = w.houses[widget.assetId];
      if (a == null || h == null) return Scaffold(appBar: AppBar());
      if (!_loaded) {
        _loaded = true;
        _name.text = a.nickname;
        _notes.text = a.notes ?? '';
        _ptype = h.propertyType;
        _source = h.source;
        _title = h.titleStatus;
        _occupancy = h.occupancy;
        _vp = h.vpDate;
        _spa = h.spaDate;
        _council.text = h.council ?? '';
        _state.text = h.state ?? '';
        _address.text = h.address ?? '';
        _contact.text = h.contact ?? '';
      }
      return Scaffold(
        appBar: AppBar(title: Text(s.editDetails)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: s.nickname, border: const OutlineInputBorder())),
          const SizedBox(height: 14),
          FieldLabel(s.propertyType),
          ChoiceRow<String>(options: const ['landed', 'strata', 'strata_landed'], value: _ptype, label: s.ptypeName, onChanged: (v) => setState(() => _ptype = v)),
          const SizedBox(height: 14),
          FieldLabel(s.boughtAs),
          ChoiceRow<String>(options: const ['new_from_developer', 'subsale'], value: _source, label: s.sourceName, onChanged: (v) => setState(() => _source = v)),
          const SizedBox(height: 14),
          DateField(label: s.vpDate, value: _vp, onChanged: (d) => setState(() => _vp = d)),
          Padding(padding: const EdgeInsets.only(top: 4, bottom: 10), child: Text(s.vpHelp, style: Theme.of(context).textTheme.bodySmall)),
          DateField(label: s.spaDate, value: _spa, onChanged: (d) => setState(() => _spa = d)),
          const SizedBox(height: 14),
          FieldLabel(s.titleStatus),
          ChoiceRow<String>(options: const ['individual', 'master', 'strata_issued'], value: _title, label: s.titleName, onChanged: (v) => setState(() => _title = v)),
          const SizedBox(height: 14),
          FieldLabel(s.occupancy),
          ChoiceRow<String>(options: const ['owner', 'rented', 'vacant'], value: _occupancy, label: s.occupancyName, onChanged: (v) => setState(() => _occupancy = v)),
          const SizedBox(height: 14),
          TextField(controller: _council, decoration: InputDecoration(labelText: s.council, hintText: s.councilHint, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _state, decoration: InputDecoration(labelText: s.state, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _address, maxLines: 2, decoration: InputDecoration(labelText: s.address, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _contact, decoration: InputDecoration(labelText: s.contact, hintText: s.contactHint, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(labelText: s.notes, border: const OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              if (_name.text.trim().isEmpty) return;
              final db = context.db;
              await db.updateAsset(a.id, AssetsCompanion(nickname: Value(_name.text.trim()), notes: Value(nn(_notes.text))));
              await db.updateHouse(a.id, HouseProfilesCompanion(
                propertyType: Value(_ptype),
                source: Value(_source),
                vpDate: Value(_vp),
                spaDate: Value(_spa),
                titleStatus: Value(_title),
                occupancy: Value(_occupancy),
                council: Value(nn(_council.text)),
                state: Value(nn(_state.text)),
                address: Value(nn(_address.text)),
                contact: Value(nn(_contact.text)),
              ));
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(s.saveChanges),
          ),
        ]),
      );
    });
  }
}

class VehicleEditScreen extends StatefulWidget {
  const VehicleEditScreen({super.key, required this.assetId});
  final int assetId;

  @override
  State<VehicleEditScreen> createState() => _VehicleEditState();
}

class _VehicleEditState extends State<VehicleEditScreen> {
  final _name = TextEditingController();
  final _plate = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _cc = TextEditingController();
  final _insurer = TextEditingController();
  final _policy = TextEditingController();
  final _warrKm = TextEditingController();
  final _chassis = TextEditingController();
  final _engine = TextEditingController();
  final _notes = TextEditingController();
  String? _cond;
  DateTime? _roadTax;
  DateTime? _insExp;
  DateTime? _warr;
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_name, _plate, _make, _model, _year, _cc, _insurer, _policy, _warrKm, _chassis, _engine, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final a = w.asset(widget.assetId);
      final v = w.vehicles[widget.assetId];
      if (a == null || v == null) return Scaffold(appBar: AppBar());
      if (!_loaded) {
        _loaded = true;
        _name.text = a.nickname;
        _notes.text = a.notes ?? '';
        _plate.text = v.plate;
        _make.text = v.make ?? '';
        _model.text = v.model ?? '';
        _year.text = v.year?.toString() ?? '';
        _cc.text = v.cc?.toString() ?? '';
        _insurer.text = v.insuranceProvider ?? '';
        _policy.text = v.policyNo ?? '';
        _warrKm.text = v.warrantyKm?.toString() ?? '';
        _chassis.text = v.chassisNo ?? '';
        _engine.text = v.engineNo ?? '';
        _cond = v.condition;
        _roadTax = v.roadTaxExpiry;
        _insExp = v.insuranceExpiry;
        _warr = v.warrantyExpiry;
      }
      Widget tf(TextEditingController c, String label, {bool number = false}) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: c,
              keyboardType: number ? TextInputType.number : TextInputType.text,
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
            ),
          );
      return Scaffold(
        appBar: AppBar(title: Text(s.editDetails)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          tf(_name, s.nickname),
          tf(_plate, s.plate),
          Row(children: [Expanded(child: tf(_make, s.make)), const SizedBox(width: 10), Expanded(child: tf(_model, s.model))]),
          Row(children: [Expanded(child: tf(_year, s.year, number: true)), const SizedBox(width: 10), Expanded(child: tf(_cc, 'cc', number: true))]),
          FieldLabel(s.boughtAs),
          ChoiceRow<String>(options: const ['new', 'second_hand'], value: _cond, label: s.conditionName, onChanged: (x) => setState(() => _cond = x)),
          const SizedBox(height: 14),
          DateField(label: s.roadTaxExpiry, value: _roadTax, onChanged: (d) => setState(() => _roadTax = d)),
          const SizedBox(height: 12),
          DateField(label: s.insuranceExpiry, value: _insExp, onChanged: (d) => setState(() => _insExp = d)),
          const SizedBox(height: 12),
          tf(_insurer, s.insurer),
          tf(_policy, s.policyNo),
          NoteBox(s.expiryNoReminderNote),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(s.moreDetails),
            children: [
              DateField(label: s.warrantyUntil, value: _warr, onChanged: (d) => setState(() => _warr = d)),
              const SizedBox(height: 12),
              tf(_warrKm, s.warrantyKm, number: true),
              tf(_chassis, s.chassisNo),
              tf(_engine, s.engineNo),
            ],
          ),
          tf(_notes, s.notes),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              if (_name.text.trim().isEmpty || _plate.text.trim().isEmpty) return;
              final db = context.db;
              await db.updateAsset(a.id, AssetsCompanion(nickname: Value(_name.text.trim()), notes: Value(nn(_notes.text))));
              await db.updateVehicle(a.id, VehicleProfilesCompanion(
                plate: Value(_plate.text.trim().toUpperCase()),
                make: Value(nn(_make.text)),
                model: Value(nn(_model.text)),
                year: Value(parseInt(_year.text)),
                cc: Value(parseInt(_cc.text)),
                condition: Value(_cond),
                roadTaxExpiry: Value(_roadTax),
                insuranceExpiry: Value(_insExp),
                insuranceProvider: Value(nn(_insurer.text)),
                policyNo: Value(nn(_policy.text)),
                warrantyExpiry: Value(_warr),
                warrantyKm: Value(parseInt(_warrKm.text)),
                chassisNo: Value(nn(_chassis.text)),
                engineNo: Value(nn(_engine.text)),
              ));
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(s.saveChanges),
          ),
        ]),
      );
    });
  }
}
