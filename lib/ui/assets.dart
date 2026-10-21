import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/auto_sync.dart';
import '../domain/rules.dart';
import '../services/auto_reminders.dart';
import '../services/files.dart';
import '../services/notifications.dart';
import 'add_asset.dart';
import 'common.dart';
import 'documents.dart';
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

/// Coloured header of an asset card: the asset photo, or the category colour with a large icon.
class AssetBanner extends StatelessWidget {
  const AssetBanner(this.a, {super.key, this.height = 96});
  final Asset a;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = catColors(context, a.category);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: a.photoPath != null
          ? SecureImage(a.photoPath!, cacheWidth: 900)
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [bg, Color.lerp(bg, fg, 0.18)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Stack(children: [
                Positioned(right: -10, bottom: -18, child: Icon(catIcon(a.category), size: height * 1.15, color: fg.withValues(alpha: 0.16))),
                Positioned(left: 16, bottom: 14, child: Icon(catIcon(a.category), size: 30, color: fg)),
              ]),
            ),
    );
  }
}

/// Days left in the DLP as a ring.
class DlpRing extends StatelessWidget {
  const DlpRing({super.key, required this.left, required this.fraction, this.size = 104});
  final int left;
  final double fraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final late = left < 90;
    final color = late ? statusColors(context, RStatus.dueSoon).$2 : theme.colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: 1 - fraction.clamp(0.0, 1.0),
            strokeWidth: 9,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$left', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1)),
          Text(context.s.daysWord, style: theme.textTheme.labelSmall),
        ]),
      ]),
    );
  }
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
          for (final a in w.assets) ...[_AssetCard(a, w), const SizedBox(height: 12)],
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
        final docs = w.files.where((d) => '${d.title} ${s.docTypeName(d.docType)}'.toLowerCase().contains(q)).toList();
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
          SectionTitle(s.documentsTab, count: docs.length),
          CardList([for (final d in docs) DocTile(d, w, showAsset: true)], empty: s.noMatch),
        ]);
      }
      return SafeScaffold(
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
    final live = w.reminders.where((r) => !r.done && r.assetId == a.id).toList()..sort(remOrder(w));
    final next = live.firstOrNull;
    final over = live.where((r) => remStatus(r, w) == RStatus.overdue).length;
    final end = dlpEnd(w, a.id);
    final left = end == null ? null : daysBetween(today(), end);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssetDetailScreen(assetId: a.id))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            AssetBanner(a),
            if (over > 0)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, borderRadius: BorderRadius.circular(99)),
                  child: Text(s.overdueCount(over), style: TextStyle(color: Theme.of(context).colorScheme.onError, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.nickname, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
              if (w.vehicles[a.id] != null && w.odometer[a.id] != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.speed_outlined, size: 16, color: muted),
                  const SizedBox(width: 6),
                  Text('${s.km(w.odometer[a.id]!.km)} · ${s.ago(w.odometer[a.id]!.date)}', style: TextStyle(fontSize: 13, color: muted)),
                ]),
              ],
            ]),
          ),
        ]),
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
      if (a == null) return SafeScaffold(appBar: AppBar(), body: Center(child: Text(s.assetDeleted)));
      final end = dlpEnd(w, a.id);
      final showDefects = a.category == 'house' && end != null && daysBetween(today(), end) > 0;
      final tabs = [s.overviewTab, s.upkeepTab, s.remindersTab, s.documentsTab, if (showDefects) s.defectsTab];
      return DefaultTabController(
        key: ValueKey(tabs.length),
        length: tabs.length,
        child: SafeScaffold(
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
                      final files = [...w.documents.where((d) => d.assetId == a.id).map((d) => d.filePath), if (a.photoPath != null) a.photoPath!];
                      await context.db.deleteAsset(a.id);
                      for (final f in files) {
                        await SecureFiles.delete(f);
                      }
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
            _Documents(a, w),
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
    final theme = Theme.of(context);
    final children = <Widget>[
      ClipRRect(borderRadius: BorderRadius.circular(16), child: AssetBanner(a, height: 120)),
      const SizedBox(height: 12),
    ];
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
                Row(children: [
                  DlpRing(left: left, fraction: total == 0 ? 1.0 : gone / total),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.dlpTitle.toUpperCase(), style: theme.textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Text(s.dlpDaysLeft, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(s.endsAbout(s.dLong(end)), style: theme.textTheme.bodySmall),
                      if (h.dlpEndOverride != null) Text(s.dlpSetByYou, style: theme.textTheme.bodySmall),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                NoteBox(h.dlpEndOverride != null ? s.dlpOverrideNote : s.dlpNote, warn: h.dlpEndOverride == null),
                if (h.source == 'subsale') ...[const SizedBox(height: 8), NoteBox(s.dlpSubsaleNote)],
                const SizedBox(height: 4),
                TextButton.icon(
                  icon: const Icon(Icons.construction_outlined),
                  label: Text(s.openDefectList(w.records.where((r) => r.assetId == a.id && r.kind == 'defect' && r.status != 'done').length)),
                  onPressed: () => DefaultTabController.of(context).animateTo(4),
                ),
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
      final monthly = w.reminders.where((r) => r.assetId == a.id && r.category == 'odometer' && !r.done).firstOrNull;
      children.addAll([
        Center(child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Plate(v.plate, big: true))),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
              leading: const Icon(Icons.speed_outlined, size: 32),
              title: Text(o == null ? s.odoNotSet : s.km(o.km), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text(o == null ? s.odoAddFirst : s.odoLastUpdated(s.ago(o.date))),
              trailing: FilledButton.tonal(onPressed: () => showOdometerDialog(context, a.id), child: Text(s.update)),
            ),
            SwitchListTile(
              value: monthly != null,
              title: Text(s.monthlyOdoReminder),
              subtitle: Text(s.monthlyOdoReminderSub),
              onChanged: (on) async {
                final db = context.db;
                if (on) {
                  await db.addReminder(RemindersCompanion(
                    assetId: Value(a.id),
                    title: Value(s.updateOdoTitle(a.nickname)),
                    category: const Value('odometer'),
                    ruleType: const Value('repeat'),
                    dueDate: Value(DateTime(today().year, today().month + 1, 1)),
                    repeatMonths: const Value(1),
                    leadDays: const Value(0),
                  ));
                } else {
                  await db.deleteReminder(monthly!.id);
                }
              },
            ),
          ]),
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
    final photos = w.photosOf(r.id);
    final meta = [
      s.dLong(r.date),
      '${s.kindName(r.kind)}${r.category != null ? ' · ${s.catName(r.category!)}' : ''}',
      if (r.cost != null) s.rm(r.cost!),
      if (r.odometer != null) s.km(r.odometer!),
      if (r.vendorName != null) r.vendorName!,
      if (showAsset) w.asset(r.assetId)?.nickname ?? '',
    ].join(' · ');
    return ListTile(
      leading: photos.isNotEmpty
          ? ClipRRect(borderRadius: BorderRadius.circular(8), child: SecureImage(photos.first.filePath, size: 44, cacheWidth: 150))
          : SizedBox(
              width: 44,
              child: Icon(r.kind == 'payment'
                  ? Icons.receipt_long_outlined
                  : r.kind == 'incident'
                      ? Icons.report_gmailerrorred_outlined
                      : r.kind == 'defect'
                          ? Icons.construction_outlined
                          : Icons.build_outlined),
            ),
      title: Text(r.title),
      subtitle: Text(meta),
      onTap: () => showRecordSheet(context, r.id),
    );
  }
}

Future<void> showRecordSheet(BuildContext context, int recordId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => WorldView(builder: (c, w) {
      final s = c.s;
      final r = w.records.where((x) => x.id == recordId).firstOrNull;
      if (r == null) return const SizedBox(height: 100);
      final items = w.costItems[r.id] ?? const [];
      final defect = r.kind == 'defect';
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(r.title, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            PhotoStrip(w.photosOf(r.id)),
            if (w.photosOf(r.id).isNotEmpty) const SizedBox(height: 12),
            Facts([
              (s.date, s.dLong(r.date)),
              (s.kind, s.kindName(r.kind)),
              if (r.category != null) (s.category, s.catName(r.category!)),
              for (final i in items) (i.label, s.rm(i.amount)),
              if (r.cost != null) (s.totalCost, s.rm(r.cost!)),
              if (r.vendorName != null) (s.vendor, r.vendorName!),
              if (r.area != null) (s.area, r.area!),
              if (r.odometer != null) (s.odometerKm, s.km(r.odometer!)),
              if (r.warrantyEnd != null) (s.warrantyEndLabel, s.dLong(r.warrantyEnd!)),
              if (defect) (s.reported, r.reportedToDeveloper == null ? s.notYet : s.dLong(r.reportedToDeveloper!)),
              if (r.insuranceClaim == true) (s.madeClaim, s.yes),
              if (r.notes != null) (s.notes, r.notes!),
            ]),
            if (defect) ...[
              const SizedBox(height: 12),
              FieldLabel(s.statusWord),
              ChoiceRow<String>(
                options: const ['open', 'in_progress', 'done'],
                value: r.status ?? 'open',
                label: s.defectStatusName,
                onChanged: (v) => c.db.updateRecord(r.id, RecordsCompanion(status: Value(v))),
              ),
              if (r.reportedToDeveloper == null) ...[
                const SizedBox(height: 8),
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
              ],
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(s.edit),
                  onPressed: () {
                    Navigator.pop(sheet);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RecordFormScreen(editId: r.id)));
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(s.delete),
                  onPressed: () async {
                    final ok = await confirm(c, title: s.deleteRecordQ, body: s.cannotUndo, ok: s.delete, danger: true);
                    if (!ok || !c.mounted) return;
                    final photos = w.photosOf(r.id);
                    final db = c.db;
                    for (final p in photos) {
                      await db.deleteDocument(p.id);
                      await SecureFiles.delete(p.filePath);
                    }
                    await db.deleteRecord(r.id);
                    if (sheet.mounted) Navigator.pop(sheet);
                  },
                ),
              ),
            ]),
          ]),
        ),
      );
    }),
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

class _Documents extends StatelessWidget {
  const _Documents(this.a, this.w);
  final Asset a;
  final World w;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ds = w.files.where((d) => d.assetId == a.id).toList()..sort((x, y) => y.addedAt.compareTo(x.addedAt));
    return ListView(padding: const EdgeInsets.all(16), children: [
      CardList([for (final d in ds) DocTile(d, w)], empty: s.noDocsForAsset),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        icon: const Icon(Icons.attach_file),
        label: Text(s.attachDocument),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentFormScreen(assetId: a.id))),
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
    final h = w.houses[a.id]!;
    final left = daysBetween(today(), end);
    final total = daysBetween(h.vpDate!, end);
    final gone = daysBetween(h.vpDate!, today()).clamp(0, total);
    final ds = w.records.where((r) => r.assetId == a.id && r.kind == 'defect').toList();
    Widget group(String status, String label) {
      final g = ds.where((r) => (r.status ?? 'open') == status).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(label, count: g.length),
        CardList([
          for (final r in g)
            ListTile(
              leading: w.photosOf(r.id).isNotEmpty
                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: SecureImage(w.photosOf(r.id).first.filePath, size: 44, cacheWidth: 150))
                  : const SizedBox(width: 44, child: Icon(Icons.construction_outlined)),
              title: Text(r.title),
              subtitle: Text([
                if (r.area != null) r.area!,
                s.foundOn(s.dShort(r.date)),
                r.reportedToDeveloper == null ? s.notReportedYet : s.reportedOn(s.dShort(r.reportedToDeveloper!)),
              ].join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showRecordSheet(context, r.id),
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
            Row(children: [
              DlpRing(left: left, fraction: total == 0 ? 1.0 : gone / total, size: 88),
              const SizedBox(width: 16),
              Expanded(child: Text(s.dlpDaysLeftEnds(s.dLong(end)))),
            ]),
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

// ================================================================ odometer

/// Returns true when a new reading was saved.
Future<bool> showOdometerDialog(BuildContext context, int assetId) async {
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
  if (km == null || !context.mounted) return false;
  final before = {for (final r in w.reminders.where((r) => r.assetId == assetId && !r.done && r.info.usesKm)) r.id: statusOf(r.info, today: today(), odometer: cur)};
  await context.db.addOdometer(assetId, km, DateTime.now());
  final changed = <String>[];
  for (final r in w.reminders.where((r) => before.containsKey(r.id))) {
    final now = statusOf(r.info, today: today(), odometer: km);
    if (now != before[r.id] && (now == RStatus.overdue || now == RStatus.dueSoon)) {
      changed.add(s.nowStatus(r.title, s.statusLabel(now)));
    }
  }
  if (!context.mounted) return true;
  if (changed.isEmpty) {
    snack(context, s.odoSaved(s.km(km)));
  } else {
    snack(context, changed.join(' '));
    if (context.app.notif.value == true) {
      await Notifier.mileage(s, s.mileageNoteTitle(a.nickname), changed.first);
    }
  }
  return true;
}

// ================================================================ edit screens

/// Explains linked reminders that were completed or snoozed and asks what to do.
/// Returns true to update them, false to keep them as they are, null to cancel saving.
Future<bool?> askAutoConflicts(BuildContext context, List<AutoChange> changes) {
  final s = context.s;
  final lines = <String>[
    for (final c in changes.where((c) => c.plan.needsConfirm))
      c.plan.reopens
          ? s.conflictReopen(c.existing!.title, s.dLong(c.plan.due!))
          : s.conflictSnooze(c.existing!.title, s.dLong(c.existing!.snoozedUntil!), s.dLong(c.plan.due!)),
  ];
  if (lines.isEmpty) return Future.value(true);
  return showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(s.conflictTitle),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(s.cancel)),
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(s.keepAsIs)),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(s.updateReminders)),
      ],
    ),
  );
}

/// Saves the fields, applies the linked-reminder changes, then closes the screen with a summary.
Future<void> saveWithAutoReminders(BuildContext context, int assetId, List<AutoChange> changes, Future<void> Function() saveFields) async {
  final s = context.s;
  final db = context.db;
  final overwrite = await askAutoConflicts(context, changes);
  if (overwrite == null || !context.mounted) return;
  await saveFields();
  final msgs = await applyAuto(db, s, assetId, changes, overwriteManual: overwrite);
  if (!context.mounted) return;
  Navigator.pop(context);
  snack(context, msgs.isEmpty ? s.changesSaved : msgs.join(' '));
}

/// Pick, change or remove the asset photo.
class AssetPhotoField extends StatelessWidget {
  const AssetPhotoField({super.key, required this.a});
  final Asset a;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    Future<void> set(String src) async {
      final p = await pickFile(context, src);
      if (p == null || !context.mounted) return;
      final db = context.db;
      final name = await SecureFiles.save(db, p.bytes, p.ext);
      final old = a.photoPath;
      await db.updateAsset(a.id, AssetsCompanion(photoPath: Value(name)));
      if (old != null) await SecureFiles.delete(old);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(borderRadius: BorderRadius.circular(16), child: AssetBanner(a, height: 120)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(icon: const Icon(Icons.photo_camera_outlined), label: Text(s.camera), onPressed: () => set('camera')),
        OutlinedButton.icon(icon: const Icon(Icons.photo_library_outlined), label: Text(s.gallery), onPressed: () => set('gallery')),
        if (a.photoPath != null)
          TextButton(
            onPressed: () async {
              final old = a.photoPath!;
              await context.db.updateAsset(a.id, const AssetsCompanion(photoPath: Value(null)));
              await SecureFiles.delete(old);
            },
            child: Text(s.removePhoto),
          ),
      ]),
    ]);
  }
}

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
  DateTime? _dlpOverride;
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
      if (a == null || h == null) return SafeScaffold(appBar: AppBar());
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
        _dlpOverride = h.dlpEndOverride;
        _council.text = h.council ?? '';
        _state.text = h.state ?? '';
        _address.text = h.address ?? '';
        _contact.text = h.contact ?? '';
      }
      return SafeScaffold(
        appBar: AppBar(title: Text(s.editDetails)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          AssetPhotoField(a: a),
          const SizedBox(height: 16),
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
          if (_vp != null) ...[
            DateField(label: s.dlpEndOverrideLabel, value: _dlpOverride, onChanged: (d) => setState(() => _dlpOverride = d)),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(s.dlpEndOverrideHelp(s.dLong(dlpEndFrom(_vp!))), style: Theme.of(context).textTheme.bodySmall),
            ),
            NoteBox(s.autoSyncNoteDlp, icon: Icons.sync),
            const SizedBox(height: 12),
          ],
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
              final t = today();
              final changes = [
                planChange(w.reminders, a.id, autoDlp,
                    oldDate: activeDlpEnd(vp: h.vpDate, override: h.dlpEndOverride, today: t),
                    newDate: activeDlpEnd(vp: _vp, override: _vp == null ? null : _dlpOverride, today: t),
                    today: t),
              ];
              await saveWithAutoReminders(context, a.id, changes, () async {
                await db.updateAsset(a.id, AssetsCompanion(nickname: Value(_name.text.trim()), notes: Value(nn(_notes.text))));
                await db.updateHouse(a.id, HouseProfilesCompanion(
                propertyType: Value(_ptype),
                source: Value(_source),
                vpDate: Value(_vp),
                dlpEndOverride: Value(_vp == null ? null : _dlpOverride),
                spaDate: Value(_spa),
                titleStatus: Value(_title),
                occupancy: Value(_occupancy),
                council: Value(nn(_council.text)),
                state: Value(nn(_state.text)),
                address: Value(nn(_address.text)),
                contact: Value(nn(_contact.text)),
              ));
              });
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
      if (a == null || v == null) return SafeScaffold(appBar: AppBar());
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
      return SafeScaffold(
        appBar: AppBar(title: Text(s.editDetails)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          AssetPhotoField(a: a),
          const SizedBox(height: 16),
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
          NoteBox(s.autoSyncNoteVehicle, icon: Icons.sync),
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
              final t = today();
              final changes = [
                planChange(w.reminders, a.id, autoRoadTax, oldDate: v.roadTaxExpiry, newDate: _roadTax, today: t),
                planChange(w.reminders, a.id, autoInsurance, oldDate: v.insuranceExpiry, newDate: _insExp, today: t),
              ];
              await saveWithAutoReminders(context, a.id, changes, () async {
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
              });
            },
            child: Text(s.saveChanges),
          ),
        ]),
      );
    });
  }
}
