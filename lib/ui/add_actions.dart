// "Tambah": what can be added, and the sheet that offers it. The rules (which actions,
// which asset) are kept apart from how they are shown, so the bottom sheet used on a phone
// now and the menu by the navigation rail planned for wide screens (0.2.8) share them.

import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/auto_sync.dart';
import '../domain/renewal.dart';
import '../domain/rules.dart';
import '../l10n/strings.dart';
import 'add_asset.dart';
import 'assets.dart';
import 'common.dart';
import 'documents.dart';
import 'forms.dart';
import 'renew.dart';

enum AddKind { maintenance, defect, payment, renovation, incident, odometer, reminder, document }

/// What can be added to an asset of [category], most common first. Every record kind the
/// record form allows for the category (kindsFor) is here, so none is out of reach.
List<AddKind> addKindsFor(String category) => category == 'house'
    ? const [AddKind.maintenance, AddKind.defect, AddKind.payment, AddKind.renovation, AddKind.incident, AddKind.reminder, AddKind.document]
    : const [AddKind.maintenance, AddKind.payment, AddKind.incident, AddKind.odometer, AddKind.reminder, AddKind.document];

IconData addKindIcon(AddKind k) => switch (k) {
      AddKind.odometer => Icons.speed_outlined,
      AddKind.reminder => Icons.notifications_none,
      AddKind.document => Icons.description_outlined,
      _ => kindIcon(k.name),
    };

/// The asset "Tambah" starts on: the one whose page is open, or the only one. With several
/// and none open, null: the user picks, and nothing is added to an asset they did not choose.
int? addStartAsset(World w, int? assetId) => assetId ?? (w.assets.length == 1 ? w.assets.single.id : null);

/// Opens the form (or the odometer dialog) for [k] on asset [assetId].
Future<void> runAddAction(BuildContext context, AddKind k, int assetId) async {
  switch (k) {
    case AddKind.odometer:
      await showOdometerDialog(context, assetId);
    case AddKind.reminder:
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ReminderFormScreen(assetId: assetId)));
    case AddKind.document:
      await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentFormScreen(assetId: assetId)));
    default:
      await Navigator.push(context, MaterialPageRoute(builder: (_) => RecordFormScreen(assetId: assetId, kind: k.name)));
  }
}

// ---------------------------------------------------------------- suggestions

/// The reminders worth acting on from Tambah: overdue, then due soon, in Today's order, at
/// most [max]. With [assetId], only that asset's.
List<Reminder> addSuggestions(World w, {int? assetId, int max = 3}) {
  final due = w.listed.where((r) {
    if (r.done || (assetId != null && r.assetId != assetId)) return false;
    final st = remStatus(r, w);
    return st == RStatus.overdue || st == RStatus.dueSoon;
  }).toList()
    ..sort(remOrder(w));
  return due.take(max).toList();
}

/// How a suggestion is acted on: road tax and insurance open their renewal; the DLP and the
/// monthly odometer reading open the reminder itself, which knows how to update them;
/// anything else opens a record that marks the reminder done when saved.
enum SuggestionAction { record, reminder, renew }

SuggestionAction suggestionAction(Reminder r) => switch (r.autoSource) {
      autoRoadTax || autoInsurance => SuggestionAction.renew,
      null when r.category != 'odometer' => SuggestionAction.record,
      _ => SuggestionAction.reminder,
    };

/// The suggestions as rows, at most [max]: road tax and insurance of the same vehicle that
/// end close together share one row, which renews both.
List<(Reminder, Reminder?)> suggestionRows(World w, List<Reminder> list, {int max = 3}) {
  final rows = <(Reminder, Reminder?)>[];
  final used = <int>{};
  for (final r in list) {
    if (used.contains(r.id)) continue;
    used.add(r.id);
    Reminder? pair;
    if (suggestionAction(r) == SuggestionAction.renew) {
      final want = r.autoSource == autoRoadTax ? autoInsurance : autoRoadTax;
      final v = w.vehicles[r.assetId];
      final p = list.where((x) => x.assetId == r.assetId && x.autoSource == want && !used.contains(x.id)).firstOrNull;
      if (p != null && v != null && renewTogether(v.roadTaxExpiry, v.insuranceExpiry)) {
        pair = p;
        used.add(p.id);
      }
    }
    rows.add((r, pair));
    if (rows.length == max) break;
  }
  return rows;
}

RenewKind _renewKind(Reminder r) => r.autoSource == autoRoadTax ? RenewKind.roadTax : RenewKind.insurance;

/// "Rekod tukar minyak enjin", "Perbaharui cukai jalan".
String suggestionTitle(Str s, Reminder r) => switch (r.autoSource) {
      'roadTax' => s.renewRoadTax,
      'insurance' => s.renewInsurance,
      _ => suggestionAction(r) == SuggestionAction.record ? s.recordThis(r.title) : r.title,
    };

IconData _suggestionIcon(Reminder r) => switch (r.autoSource) {
      'roadTax' || 'insurance' => Icons.sell_outlined,
      'dlp' => Icons.construction_outlined,
      'rent' => Icons.key_outlined,
      'tribunal' => Icons.gavel,
      _ => r.category == 'odometer' ? Icons.speed_outlined : Icons.build_outlined,
    };

/// Opens what a suggestion leads to, from the screen the sheet was opened on. With a [pair]
/// (road tax and insurance together) the renewal starts with both.
Future<void> runSuggestion(BuildContext context, Reminder r, {Reminder? pair}) async {
  switch (suggestionAction(r)) {
    case SuggestionAction.renew:
      await openRenewal(context, r.assetId, _renewKind(r), both: pair != null);
    case SuggestionAction.reminder:
      await showReminderSheet(context, r.id);
    case SuggestionAction.record:
      await Navigator.push(context, MaterialPageRoute(builder: (_) => RecordFormScreen(assetId: r.assetId, completesReminderId: r.id)));
  }
}

/// One suggestion: what to do, for which asset (when the sheet is for everything) and how
/// late or near it is, in its colour.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow(this.r, this.w, {this.pair, required this.showAsset, required this.onTap});
  final Reminder r;

  /// The other cover, when road tax and insurance are renewed together.
  final Reminder? pair;
  final World w;
  final bool showAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final k = context.tokens;
    final (status0, tone) = shortDue(s, r, w);
    final p = pair;
    final sameDay = p != null && r.dueDate != null && p.dueDate != null && dayOnly(r.dueDate!) == dayOnly(p.dueDate!);
    final status = sameDay ? '$status0 · ${s.bothEndOn(s.dShort(r.dueDate!))}' : status0;
    final (bg, fg) = tone == Tone.overdue ? (k.overdueBg, k.overdue) : (k.dueSoonBg, k.dueSoon);
    final muted = KText.meta.copyWith(color: k.textMuted);
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KSpace.rowMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(_suggestionIcon(r), size: 20, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p == null ? suggestionTitle(s, r) : s.renewBoth, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.row.copyWith(color: k.text)),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(children: [
                      if (showAsset) TextSpan(text: '${w.asset(r.assetId)?.nickname ?? ''} · '),
                      TextSpan(text: status, style: TextStyle(color: fg, fontWeight: FontWeight.w500)),
                      if (!showAsset && suggestionAction(r) == SuggestionAction.record) TextSpan(text: ' · ${s.marksReminderDone}'),
                    ]),
                    style: muted,
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// What the user chose in the sheet: an action on an asset, a suggestion (with the other
/// cover when renewing both), or (all null) a new asset.
class _Choice {
  const _Choice(this.kind, this.assetId, [this.suggestion, this.pair]);
  final AddKind? kind;
  final int? assetId;
  final Reminder? suggestion;
  final Reminder? pair;
}

/// Opens "Tambah" for [assetId] (an asset's page) or for everything. With no asset yet the
/// only thing to add is an asset, so its form opens directly.
Future<void> showAddSheet(BuildContext context, {int? assetId}) async {
  final w = context.app.world.value;
  if (w == null) return;
  if (w.assets.isEmpty) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAssetScreen()));
    return;
  }
  // The sheet only chooses; the form opens from this screen after the sheet has closed.
  final c = await showModalBottomSheet<_Choice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddSheet(start: addStartAsset(w, assetId)),
  );
  if (c == null || !context.mounted) return;
  if (c.suggestion != null) {
    await runSuggestion(context, c.suggestion!, pair: c.pair);
  } else if (c.kind == null) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAssetScreen()));
  } else {
    await runAddAction(context, c.kind!, c.assetId!);
  }
}

/// The floating "Tambah" button. Hidden until there is an asset: before that, the screen's
/// own "Add your first asset" button is the one action.
class AddButton extends StatelessWidget {
  const AddButton({super.key, this.assetId});

  /// The asset whose page this is, if any.
  final int? assetId;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<World?>(
        valueListenable: context.app.world,
        // Beside the navigation rail, the rail's own Tambah is the one for everything.
        builder: (c, w, _) => (w?.assets.isEmpty ?? true) || (assetId == null && RailScope.of(c))
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                // Several of these live in the tab stack at once; no hero animation between them.
                heroTag: null,
                icon: const Icon(Icons.add),
                label: Text(c.s.add),
                onPressed: () => showAddSheet(c, assetId: assetId),
              ),
      );
}

/// Tambah at the top of the navigation rail on a wide screen. Hidden until there is an
/// asset, like the floating button.
class RailAddButton extends StatelessWidget {
  const RailAddButton({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<World?>(
        valueListenable: context.app.world,
        builder: (c, w, _) => (w?.assets.isEmpty ?? true)
            ? const SizedBox(height: 56)
            : Column(mainAxisSize: MainAxisSize.min, children: [
                FloatingActionButton(
                  heroTag: null,
                  elevation: 0,
                  tooltip: c.s.add,
                  onPressed: () => showAddSheet(c),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 4),
                Text(c.s.add, style: TextStyle(fontSize: 12, color: c.tokens.label)),
              ]),
      );
}

class _AddSheet extends StatefulWidget {
  const _AddSheet({required this.start});
  final int? start;

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  late int? _asset = widget.start;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final k = context.tokens;
    return ValueListenableBuilder<World?>(
      valueListenable: context.app.world,
      builder: (context, w, _) {
        final a = w == null || _asset == null ? null : w.asset(_asset!);
        // One more than shown, so a road tax and insurance pair still leaves room for others.
        final suggested = w == null ? const <(Reminder, Reminder?)>[] : suggestionRows(w, addSuggestions(w, assetId: a?.id, max: 4));
        Widget suggestions() => CardList([
              for (final (r, pair) in suggested)
                _SuggestionRow(r, w!, pair: pair, showAsset: a == null, onTap: () => Navigator.pop(context, _Choice(null, null, r, pair))),
            ]);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(s.add, style: KText.title.copyWith(color: k.text))),
              if (w != null && a == null) ...[
                if (suggested.isNotEmpty) ...[SectionTitle(s.suggested), suggestions()],
                SectionTitle(suggested.isEmpty ? s.whichAsset : s.orPickAsset),
                AssetChoice(
                  w: w,
                  onPick: (id) => setState(() => _asset = id),
                  extra: [
                    AppRow(
                      leading: const IconAvatar(Icons.add, tonal: true),
                      title: s.newAsset,
                      meta: s.addAssetHint,
                      onTap: () => Navigator.pop(context, const _Choice(null, null)),
                    ),
                  ],
                ),
              ] else if (a != null) ...[
                _ForAsset(a: a, w: w!, onChange: () => setState(() => _asset = null)),
                if (suggested.isNotEmpty) ...[
                  SectionTitle(s.suggested),
                  suggestions(),
                  SectionTitle(s.otherForAsset(a.nickname)),
                ] else
                  const SizedBox(height: 8),
                _ActionGrid(
                  category: a.category,
                  onPick: (kind) => Navigator.pop(context, _Choice(kind, a.id)),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}

/// "For Myvi WXY 4821 · Change asset" at the top of the actions.
class _ForAsset extends StatelessWidget {
  const _ForAsset({required this.a, required this.w, required this.onChange});
  final Asset a;
  final World w;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final k = context.tokens;
    final plate = w.vehicles[a.id]?.plate;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Row(children: [
        // Wraps rather than overflows with a long name or large text.
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(s.forAsset, style: TextStyle(fontSize: 14, color: k.label)),
            Text(a.nickname, style: KText.row.copyWith(color: k.text)),
            if (plate != null) Plate(plate),
          ]),
        ),
        TextButton(onPressed: onChange, child: Text(s.changeAsset)),
      ]),
    );
  }
}

/// The actions for one asset, two to a row with equal heights.
class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.category, required this.onPick});
  final String category;
  final ValueChanged<AddKind> onPick;

  @override
  Widget build(BuildContext context) {
    final kinds = addKindsFor(category);
    return Column(children: [
      for (var i = 0; i < kinds.length; i += 2)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _Tile(kinds[i], category, onPick)),
              const SizedBox(width: 8),
              Expanded(child: i + 1 < kinds.length ? _Tile(kinds[i + 1], category, onPick) : const SizedBox.shrink()),
            ]),
          ),
        ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.kind, this.category, this.onPick);
  final AddKind kind;
  final String category;
  final ValueChanged<AddKind> onPick;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return Material(
      color: k.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KSpace.groupRadius), side: BorderSide(color: k.line)),
      child: InkWell(
        onTap: () => onPick(kind),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              IconAvatar(addKindIcon(kind), size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.s.addActionName(kind.name, category),
                  style: TextStyle(fontSize: 14, height: 18 / 14, fontWeight: FontWeight.w500, color: k.text),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The user's assets as rows to pick from, with any [extra] rows (such as "New asset") in
/// the same group. Used by "Tambah" and by a form opened without an asset.
class AssetChoice extends StatelessWidget {
  const AssetChoice({super.key, required this.w, required this.onPick, this.extra = const []});
  final World w;
  final ValueChanged<int> onPick;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return CardList([
      for (final a in w.assets)
        AppRow(
          leading: AssetAvatar(a.category, size: 36),
          title: a.nickname,
          titleTag: w.vehicles[a.id] == null ? null : Plate(w.vehicles[a.id]!.plate),
          meta: s.categoryName(a.category),
          onTap: () => onPick(a.id),
        ),
      ...extra,
    ]);
  }
}

/// The body of a form opened without an asset while there are several: it asks which one
/// instead of quietly using the first.
class AssetChoiceScreen extends StatelessWidget {
  const AssetChoiceScreen({super.key, required this.title, required this.w, required this.onPick});
  final String title;
  final World w;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => SafeScaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
          SectionTitle(context.s.whichAsset),
          AssetChoice(w: w, onPick: onPick),
        ]),
      );
}
