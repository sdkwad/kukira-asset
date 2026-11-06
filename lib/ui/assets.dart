import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/auto_sync.dart';
import '../domain/lists.dart';
import '../domain/presets.dart';
import '../domain/renewal.dart';
import '../domain/rent.dart';
import '../domain/rules.dart';
import '../l10n/strings.dart';
import '../services/auto_reminders.dart';
import '../services/error_log.dart';
import '../services/files.dart';
import '../services/notifications.dart';
import '../services/renewal.dart';
import 'add_actions.dart';
import 'add_asset.dart';
import 'combo.dart';
import 'common.dart';
import 'documents.dart';
import 'forms.dart';
import 'inspection.dart';
import 'renew.dart';
import 'rent.dart';

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

/// The tribunal deadline for defects of house [assetId] while it is still to come.
DateTime? _tribunal(World w, int assetId) {
  final h = w.houses[assetId];
  return h == null ? null : activeTribunalDeadline(vp: h.vpDate, override: h.dlpEndOverride, source: h.source, today: today());
}

class Plate extends StatelessWidget {
  const Plate(this.text, {super.key, this.big = false});
  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: big ? 12 : 7, vertical: big ? 4 : 1),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(big ? 7 : 5),
          // A black plate on a dark background needs an edge to be seen.
          border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: const Color(0xFF6B6B6B)) : null,
        ),
        child: Text(
          text,
          style: TextStyle(color: const Color(0xFFF4F4F4), fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: big ? 20 : 12, fontFamily: 'monospace'),
        ),
      );
}

/// The asset photo across the top of a card or page. Only used when the asset has a photo;
/// without one, screens show the small category avatar instead of a decorative placeholder.
class AssetBanner extends StatelessWidget {
  const AssetBanner(this.a, {super.key, this.height = 96});
  final Asset a;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height, width: double.infinity, child: SecureImage(a.photoPath!, cacheWidth: 900));
}

// ================================================================ list

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  String _q = '';
  int? _picked;

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final q = _q.trim().toLowerCase();
      // On a wide screen the asset picked from the list opens beside it, not over it.
      final twoPanes = windowSize(context) == WindowSize.expanded && w.assets.isNotEmpty;
      final picked = w.asset(_picked ?? -1)?.id ?? w.assets.firstOrNull?.id;
      Widget body;
      if (q.isEmpty) {
        body = Column(children: [
          for (final a in w.assets) ...[
            _AssetCard(a, w, selected: twoPanes && a.id == picked, onOpen: twoPanes ? () => setState(() => _picked = a.id) : null),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.add),
            label: Text(s.addAsset),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAssetScreen())),
          ),
        ]);
      } else {
        body = SearchResults(q, w);
      }
      final list = ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, KSpace.fabClearance), children: [
        PageTitle(s.assetsTab),
        SearchBar(
          hintText: s.searchHint,
          leading: const Icon(Icons.search),
          elevation: const WidgetStatePropertyAll(0),
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 14),
        body,
      ]);
      if (!twoPanes || picked == null) return SafeScaffold(floatingActionButton: const AddButton(), body: SafeArea(child: list));
      final k = context.tokens;
      return SafeScaffold(
        maxWidth: null,
        body: SafeArea(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 400, child: list),
            VerticalDivider(width: 1, thickness: 1, color: k.line),
            Expanded(child: AssetDetailScreen(key: ValueKey(picked), assetId: picked, embedded: true)),
          ]),
        ),
      );
    });
  }
}

/// Assets, reminders, records and documents matching [q] (lower case), in that order.
/// Shown under the search on Assets and on the search screen opened from Today.
class SearchResults extends StatelessWidget {
  const SearchResults(this.q, this.w, {super.key});
  final String q;
  final World w;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final as = w.assets.where((a) => '${a.nickname} ${w.vehicles[a.id]?.plate ?? ''} ${assetSubtitle(context, a, w)}'.toLowerCase().contains(q)).toList();
    final rs = w.listed.where((r) => !r.done && r.title.toLowerCase().contains(q)).toList();
    final recs = w.records.where((r) => '${r.title} ${r.vendorName ?? ''} ${r.area ?? ''} ${r.notes ?? ''}'.toLowerCase().contains(q)).toList();
    final docs = w.files.where((d) => '${d.title} ${s.docTypeName(d.docType)}'.toLowerCase().contains(q)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(s.assetsTab, count: as.length),
      CardList([
        for (final a in as)
          AppRow(
            leading: AssetAvatar(a.category, size: 36),
            title: a.nickname,
            meta: assetSubtitle(context, a, w),
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
}

/// Search across everything, opened from the search button on Today.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return WorldView(builder: (context, w) {
      final q = _q.trim().toLowerCase();
      return SafeScaffold(
        appBar: AppBar(
          title: TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(hintText: s.searchHint, border: InputBorder.none),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
          if (q.isEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(4, 20, 4, 0), child: Text(s.searchPrompt, style: KText.meta.copyWith(color: context.tokens.textMuted)))
          else
            SearchResults(q, w),
        ]),
      );
    });
  }
}

/// How much of the card's colour lies over a photo where text sits on it: the photo shows at
/// a quarter of its strength there. At that cover the main text colour keeps at least 6:1
/// contrast even over a black (light mode) or white (dark mode) photo; the muted and status
/// colours do not, so text on a photo uses the main colour and statuses get their own chip.
const photoVeil = 0.75;

/// A photo across the whole card, under a veil of the card's colour that holds at
/// [photoVeil] where the text is and thins out to nothing at the right edge: the photo shows
/// at full strength on the right and at a quarter of it under the text.
class PhotoFade extends StatelessWidget {
  const PhotoFade({super.key, required this.photo, required this.color, this.holdTo = 0.55, this.opacity = 1});
  final String photo;
  final Color color;

  /// The veil holds its full cover up to this fraction of the width, then thins out.
  final double holdTo;

  /// Fades the photo and its veil out together (the asset page header as it shrinks). Each
  /// is drawn with this alpha instead of under an Opacity widget, which would draw the whole
  /// header into an offscreen layer on every frame of the scroll.
  final double opacity;

  /// The veil's cover at [x], a fraction of the width from the left.
  double coverAt(double x) => x <= holdTo ? photoVeil : photoVeil * (1 - (x - holdTo) / (1 - holdTo));

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Stack(fit: StackFit.expand, children: [
          SecureImage(photo, cacheWidth: 1080, opacity: opacity),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: photoVeil * opacity), color.withValues(alpha: photoVeil * opacity), color.withValues(alpha: 0)],
                stops: [0, holdTo, 1],
              ),
            ),
          ),
        ]),
      );
}

/// How much of a photo card's width the text may use: all of it under the full veil.
const photoTextWidth = 0.52;

class _AssetCard extends StatelessWidget {
  const _AssetCard(this.a, this.w, {this.selected = false, this.onOpen});
  final Asset a;
  final World w;

  /// The asset open beside the list (wide screens).
  final bool selected;

  /// Opens the asset beside the list instead of on its own page.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final k = context.tokens;
    final live = w.listed.where((r) => !r.done && r.assetId == a.id).toList()..sort(remOrder(w));
    final next = live.firstOrNull;
    final moreOverdue = live.where((r) => remStatus(r, w) == RStatus.overdue).length - (next != null && remStatus(next, w) == RStatus.overdue ? 1 : 0);
    final v = w.vehicles[a.id];
    final o = w.odometer[a.id];
    final photo = a.photoPath;
    // Over a photo only the main text colour reads in every case (see photoVeil).
    final meta = KText.meta.copyWith(color: photo == null ? k.textMuted : k.text);
    final makeYear = [v?.make, v?.year?.toString()].whereType<String>().join(' · ');
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(a.nickname, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.subtitle.copyWith(color: k.text)),
      const SizedBox(height: 2),
      if (v != null)
        Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Plate(v.plate),
          Text(makeYear.isEmpty ? s.categoryName(a.category) : makeYear, style: meta),
        ])
      else
        Text(assetSubtitle(context, a, w), style: meta),
      const SizedBox(height: 10),
      if (next == null)
        Text(s.noRemindersYet, style: meta)
      else ...[
        Text(next.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, height: 20 / 14, color: k.text)),
        const SizedBox(height: 2),
        Builder(builder: (context) {
          final (st, tone) = shortDue(s, next, w);
          return StatusLabel(st, tone, boxed: photo != null);
        }),
        if (moreOverdue > 0) Text(s.moreOverdue(moreOverdue), style: meta),
      ],
      if (v != null && o != null) ...[const SizedBox(height: 4), Text('${s.km(o.km)} · ${s.ago(o.date)}', style: meta)],
    ]);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: selected
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(KSpace.groupRadius), side: BorderSide(color: k.primary, width: 2))
          : null,
      child: InkWell(
        onTap: onOpen ?? () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssetDetailScreen(assetId: a.id))),
        child: photo == null
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AssetAvatar(a.category, size: 44),
                  const SizedBox(width: 12),
                  Expanded(child: text),
                ]),
              )
            : ConstrainedBox(
                // Full width: in the asset list's column it would otherwise shrink to its text.
                constraints: const BoxConstraints(minHeight: 136, minWidth: double.infinity),
                child: Stack(children: [
                  Positioned.fill(child: PhotoFade(photo: photo, color: k.surface)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: FractionallySizedBox(widthFactor: photoTextWidth, alignment: Alignment.topLeft, child: text),
                  ),
                ]),
              ),
      ),
    );
  }
}

// ================================================================ detail

class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({super.key, required this.assetId, this.embedded = false});
  final int assetId;

  /// Shown beside the asset list on a wide screen rather than as a page of its own: it has
  /// no page to close, so deleting the asset leaves the list to pick another.
  final bool embedded;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailState();
}

class _AssetDetailState extends State<AssetDetailScreen> {
  // The kind of record the Records tab shows (null: all). Held here so the overview can
  // open the defect list there.
  final _recordKind = ValueNotifier<String?>(null);

  /// The photo header has shrunk to a plain title bar, where the menu button needs no
  /// backdrop of its own.
  bool _shrunk = false;

  @override
  void dispose() {
    _recordKind.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final k = context.tokens;
      final a = w.asset(widget.assetId);
      if (a == null) return SafeScaffold(appBar: AppBar(), body: Center(child: Text(s.assetDeleted)));
      // The same four tabs for every asset and every stage, so they never move. Defects are
      // records: they are listed under Records, and the overview links to them while the DLP runs.
      final tabs = [s.overviewTab, s.upkeepTab, s.remindersTab, s.documentsTab];
      final photo = a.photoPath;
      final menu = PopupMenuButton<String>(
        tooltip: s.moreOptions,
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
              if (context.mounted && !widget.embedded) Navigator.pop(context);
            }
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(s.editDetails)),
          PopupMenuItem(value: 'delete', child: Text(s.deleteAsset)),
        ],
      );
      return DefaultTabController(
        length: tabs.length,
        child: SafeScaffold(
          // The tabs keep their own readable width, in two columns where there is room.
          maxWidth: null,
          floatingActionButton: AddButton(assetId: a.id),
          body: NotificationListener<ScrollUpdateNotification>(
            // The page's own scroll (depth 0), not a tab's list: shrunk once the header is.
            onNotification: (n) {
              if (n.depth == 0 && photo != null) {
                final shrunk = n.metrics.pixels >= n.metrics.maxScrollExtent - 1;
                if (shrunk != _shrunk) setState(() => _shrunk = shrunk);
              }
              return false;
            },
            child: NestedScrollView(
            headerSliverBuilder: (context, scrolled) => [
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverAppBar(
                  pinned: true,
                  forceElevated: scrolled,
                  // With a photo the page opens on it, and it shrinks to a small one by the
                  // name as the page scrolls; without one it is a plain title bar.
                  expandedHeight: photo == null ? null : _heroHeight + kTextTabBarHeight,
                  title: photo == null ? Text(a.nickname) : null,
                  flexibleSpace: photo == null ? null : _Hero(a, w),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      // Over a photo the button gets a backdrop so it can be seen.
                      child: DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: photo == null || _shrunk ? null : k.surface.withValues(alpha: 0.88)),
                        child: menu,
                      ),
                    ),
                  ],
                  bottom: FitTabBar(tabs: tabs),
                ),
              ),
            ],
            body: TabBarView(children: [
              _Overview(a, w, _recordKind),
              _Records(a, w, _recordKind),
              _Reminders(a, w),
              _Documents(a, w),
            ]),
            ),
          ),
        ),
      );
    });
  }
}

const _heroHeight = 208.0;

/// The asset photo across the top of its page, faded from the right like its card, with the
/// name over the solid part. As the page scrolls it fades into a small photo by the name.
class _Hero extends StatelessWidget {
  const _Hero(this.a, this.w);
  final Asset a;
  final World w;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final bar = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    // 1 when fully open, 0 when only the title bar and tabs are left.
    final open = bar == null || bar.maxExtent == bar.minExtent ? 1.0 : ((bar.currentExtent - bar.minExtent) / (bar.maxExtent - bar.minExtent)).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, box) {
      return Stack(fit: StackFit.expand, children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: kTextTabBarHeight,
          child: Stack(fit: StackFit.expand, children: [
            PhotoFade(photo: a.photoPath!, color: k.background, holdTo: 0.66, opacity: open),
            // The text ends by 64% of the width, still under the full veil: a name such as
            // "Rumah Setia Alam" fits one line on a 360 dp phone. Only this small block of text
            // fades through an Opacity layer, and only while the header is part open.
            Positioned(
              left: 20,
              right: box.maxWidth * 0.36,
              bottom: 14,
              child: Opacity(opacity: open, child: _Identity(a, w, large: true)),
            ),
          ]),
        ),
        Positioned(
          left: 56,
          right: 56,
          top: 0,
          height: kToolbarHeight,
          child: IgnorePointer(
            child: Opacity(
              opacity: 1 - open,
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(9), child: SecureImage(a.photoPath!, size: 32, cacheWidth: 120)),
                const SizedBox(width: 10),
                Expanded(child: Text(a.nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.title.copyWith(color: k.text))),
              ]),
            ),
          ),
        ),
      ]);
    });
  }
}

/// What the asset is: the model and plate of a vehicle, the type and place of a house.
class _Identity extends StatelessWidget {
  const _Identity(this.a, this.w, {this.large = false});
  final Asset a;
  final World w;

  /// In the photo header: with the name, which the title bar does not show there.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final k = context.tokens;
    final v = w.vehicles[a.id];
    final h = w.houses[a.id];
    // In the photo header the lines sit on the photo, where only the main colour reads.
    final meta = KText.meta.copyWith(color: large ? k.text : k.textMuted);
    final String line1;
    final Widget line2;
    if (v != null) {
      final mm = [v.make, v.model].whereType<String>().join(' ');
      line1 = mm.isEmpty ? s.categoryName(a.category) : mm;
      line2 = Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Plate(v.plate),
        Text([if (v.year != null) '${v.year}', s.categoryName(a.category)].join(' · '), style: meta),
      ]);
    } else {
      line1 = s.ptypeName(h?.propertyType ?? 'landed');
      final place = [h?.state, h?.council].whereType<String>().join(' · ');
      line2 = Text(place.isEmpty ? s.categoryName(a.category) : place, style: meta);
    }
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (large) Text(a.nickname, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.screenTitle.copyWith(color: k.text)),
      Text(line1, style: large ? meta : KText.subtitle.copyWith(color: k.text)),
      SizedBox(height: large ? 2 : 4),
      line2,
    ]);
    if (large) return text;
    return Row(children: [AssetAvatar(a.category, size: 52), const SizedBox(width: 14), Expanded(child: text)]);
  }
}

/// A tab's content inside the scrolling page header (NestedScrollView).
class _TabScroll extends StatelessWidget {
  const _TabScroll(this.name, this.children, {this.side = const []});
  final String name;
  final List<Widget> children;

  /// Beside [children] where the tab is wide enough for two columns, under them otherwise.
  final List<Widget> side;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final two = side.isNotEmpty && box.maxWidth >= _twoColumnsFrom;
        final content = two ? _twoColumnsMax : readableWidth;
        final gutter = box.maxWidth > content + 32 ? (box.maxWidth - content) / 2 : 16.0;
        final items = two
            ? [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
                  const SizedBox(width: 24),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: side)),
                ]),
              ]
            : [...children, ...side];
        return CustomScrollView(
          key: PageStorageKey<String>(name),
          slivers: [
            SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
            // Room at the bottom for the Tambah button over it.
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, KSpace.fabClearance),
              sliver: SliverList(delegate: SliverChildListDelegate(items)),
            ),
          ],
        );
      });
}

/// From how wide an asset's overview is laid out in two columns, and how wide it then gets.
const _twoColumnsFrom = 880.0;
const _twoColumnsMax = 1120.0;

/// What a reminder needs, as words for a sentence: "lewat 6 hari", "tamat 12 Nov".
(String, Tone) statusPhrase(Str s, Reminder r, World w) {
  final (text, tone) = shortDue(s, r, w);
  final lower = text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
  // Due soon on a date: when it ends, or in how many days ("Road tax ends 12 Nov").
  final days = r.dueDate == null ? null : daysBetween(today(), r.dueDate!);
  final onDate = tone == Tone.dueSoon && r.info.usesDate && days != null && days > 1 && text == s.inDays(days);
  if (!onDate) return (lower, tone);
  return (r.autoSource != null || r.category == 'document' ? s.endsOn(s.dShort(r.dueDate!)) : s.inDaysPhrase(days), tone);
}

class _Overview extends StatelessWidget {
  const _Overview(this.a, this.w, this.recordKind);
  final Asset a;
  final World w;
  final ValueNotifier<String?> recordKind;

  /// On a house, dues and cover go under Status with the DLP; the rest is upkeep.
  static const _houseDues = {'cukai_tanah', 'cukai_petak', 'cukai_taksiran', 'maintenance_charge', 'sinking_fund', 'insurance_premium'};

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final k = context.tokens;
    final house = a.category == 'house';
    final v = w.vehicles[a.id];
    final h = w.houses[a.id];
    final t = today();
    final live = w.listed.where((r) => r.assetId == a.id && !r.done).toList()..sort(remOrder(w));
    void tab(int i, [String? kind]) {
      recordKind.value = kind;
      DefaultTabController.of(context).animateTo(i);
    }

    void edit() => Navigator.push(context, MaterialPageRoute(builder: (_) => house ? HouseEditScreen(assetId: a.id) : VehicleEditScreen(assetId: a.id)));
    void open(Reminder r) => showReminderSheet(context, r.id);
    final lead = KText.subtitle.copyWith(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400, color: k.label);
    final children = <Widget>[];

    // Who this is, when there is no photo header to say it.
    if (a.photoPath == null) children.add(Padding(padding: const EdgeInsets.only(bottom: 14), child: _Identity(a, w)));

    // In a sentence or two: what needs attention now.
    final urgent = live.where((r) => remStatus(r, w) == RStatus.overdue || remStatus(r, w) == RStatus.dueSoon).toList();
    final defects = w.records.where((r) => r.assetId == a.id && r.kind == 'defect').toList();
    final end = house ? dlpEnd(w, a.id) : null;
    final inDlp = end != null && daysBetween(t, end) > 0;
    final unreported = defects.where((r) => r.reportedToDeveloper == null && r.status != 'done').length;
    final spans = <InlineSpan>[];
    for (final r in urgent.take(2)) {
      final (phrase, tone) = statusPhrase(s, r, w);
      spans.addAll([
        TextSpan(text: '${r.title} '),
        TextSpan(text: phrase, style: TextStyle(color: toneColor(context, tone), fontWeight: FontWeight.w500)),
        const TextSpan(text: '. '),
      ]);
    }
    if (urgent.length > 2) spans.add(TextSpan(text: '${s.andMoreDue(urgent.length - 2)} '));
    if (inDlp && unreported > 0) spans.add(TextSpan(text: s.defectsUnreported(unreported)));
    children.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text.rich(TextSpan(children: spans.isEmpty ? [TextSpan(text: s.statusNone)] : spans), style: lead),
    ));

    // Status: what keeps the asset legal and covered.
    final state = <Widget>[];
    if (v != null) {
      final o = w.odometer[a.id];
      final monthly = live.where((r) => r.category == 'odometer').firstOrNull;
      state.addAll([
        AppRow(
          leading: const IconAvatar(Icons.speed_outlined),
          title: o == null ? s.odoNotSet : s.km(o.km),
          meta: o == null ? s.odoAddFirst : s.odoMeta(s.ago(o.date)),
          trailing: TextButton(onPressed: () => showOdometerDialog(context, a.id), child: Text(s.update)),
          onTap: () => showOdometerDialog(context, a.id),
        ),
        AppRow(
          leading: const IconAvatar(Icons.event_repeat_outlined),
          title: s.monthlyOdoReminder,
          meta: s.monthlyOdoReminderSub,
          trailing: Switch(
            value: monthly != null,
            onChanged: (on) async {
              final db = context.db;
              if (on) {
                await db.addReminder(RemindersCompanion(
                  assetId: Value(a.id),
                  title: Value(s.updateOdoTitle(a.nickname)),
                  category: const Value('odometer'),
                  ruleType: const Value('repeat'),
                  dueDate: Value(DateTime(t.year, t.month + 1, 1)),
                  repeatMonths: const Value(1),
                  leadDays: const Value(0),
                ));
              } else {
                await db.deleteReminder(monthly!.id);
              }
            },
          ),
        ),
        _expiry(context, s.catName('road_tax'), Icons.receipt_long_outlined, v.roadTaxExpiry, autoRoadTax, null, edit),
        _expiry(context, s.insuranceWord, Icons.shield_outlined, v.insuranceExpiry, autoInsurance, v.insuranceProvider, edit),
      ]);
    }
    if (house && h != null) {
      if (end != null) {
        final left = daysBetween(t, end);
        final total = daysBetween(h.vpDate!, end);
        final gone = daysBetween(h.vpDate!, t).clamp(0, total);
        state.add(AppRow(
          leading: const IconAvatar(Icons.construction_outlined),
          title: s.dlpRowTitle,
          titleTag: h.dlpEndOverride == null ? const EstTag() : null,
          status: left > 0 ? StatusLabel(s.inDays(left), left < 90 ? Tone.dueSoon : Tone.upcoming) : StatusLabel(s.expired, Tone.expired),
          // Never a fact: who to confirm the date with is part of the line (SPEC rule 5).
          meta: h.dlpEndOverride == null ? s.dlpRowMeta(s.dLong(end)) : s.dlpRowMetaOwn(s.dLong(end)),
          action: left <= 0
              ? null
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ProgressLine(total == 0 ? 1 : gone / total),
                  const SizedBox(height: 10),
                  FilledButton.tonal(onPressed: () => tab(1, 'defect'), child: Text(s.defectsAction(defects.length, unreported))),
                ]),
          onTap: () => tab(1, 'defect'),
        ));
      } else if (h.source != 'subsale') {
        state.add(AppRow(leading: const IconAvatar(Icons.construction_outlined), title: s.dlpRowTitle, meta: s.addVpForDlp, trailing: const Icon(Icons.chevron_right), onTap: edit));
      }
      // Once the DLP has ended, defects can still be claimed at the Tribunal for a year.
      final deadline = activeTribunalDeadline(vp: h.vpDate, override: h.dlpEndOverride, source: h.source, today: t);
      if (end != null && daysBetween(t, end) <= 0 && deadline != null) {
        final left = daysBetween(t, deadline);
        state.add(AppRow(
          leading: const IconAvatar(Icons.gavel),
          title: s.tribunalRowTitle,
          titleTag: const EstTag(),
          status: StatusLabel(s.inDays(left), left < 90 ? Tone.dueSoon : Tone.upcoming),
          meta: s.tribunalRowMeta(s.dLong(deadline)),
          onTap: () => tab(1, 'defect'),
        ));
      }
      for (final r in live.where((r) => _houseDues.contains(r.category))) {
        state.add(ReminderTile(r, w, showAsset: false, icon: Icons.receipt_long_outlined, onTap: () => open(r)));
      }
    }
    if (house && h != null) {
      final tens = w.tenancies.where((x) => x.assetId == a.id).toList();
      if (h.occupancy == 'rented' || tens.isNotEmpty) {
        final cur = currentTenancy(tens, a.id);
        final pays = cur == null ? const <RentPayment>[] : (w.rentPayments[cur.id] ?? const <RentPayment>[]);
        final now = monthKey(t);
        final owed = cur == null ? 0 : owedMonths(cur, pays, today: t);
        state.add(AppRow(
          leading: const IconAvatar(Icons.key_outlined),
          title: s.rentRowTitle,
          status: owed > 0 ? StatusLabel(s.monthsCount(owed), Tone.overdue) : null,
          meta: cur == null ? s.rentRowNone : s.rentRowMeta(cur.tenantName ?? s.tenantUnnamed, s.monthStateName(monthState(cur, now, paymentFor(pays, now), today: t).name)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openRent(context, a.id),
        ));
      }
    }
    if (state.isNotEmpty) children.addAll([SectionTitle(s.stateTitle), CardList(state)]);
    if (house && h != null && h.source == 'subsale' && inDlp) children.addAll([const SizedBox(height: 8), NoteBox(s.dlpSubsaleNote)]);
    if (house && h?.propertyType == 'strata') children.addAll([const SizedBox(height: 8), NoteBox(s.strataInsuranceNote, icon: Icons.shield_outlined)]);

    // Upkeep: the other reminders, most urgent first. Linked dates are shown above.
    final upkeep = live.where((r) => !(house && _houseDues.contains(r.category)) && r.autoSource == null && r.category != 'odometer').toList();
    if (upkeep.isNotEmpty) {
      children.addAll([
        SectionTitle(s.kindName('maintenance'), link: s.seeAll(upkeep.length), onLink: () => tab(2)),
        CardList([for (final r in upkeep.take(3)) ReminderTile(r, w, showAsset: false, onTap: () => open(r))]),
      ]);
    }

    // The latest records, with this year's spending.
    final recs = w.records.where((r) => r.assetId == a.id).toList()..sort((x, y) => y.date.compareTo(x.date));
    final spent = recs.where((r) => r.date.year == t.year).fold<double>(0, (sum, r) => sum + (r.cost ?? 0));
    // On a wide screen the records and details are the second column.
    final side = <Widget>[
      SectionTitle(s.recordsYear(t.year, s.rm(spent)), link: recs.isEmpty ? null : s.seeAll(recs.length), onLink: () => tab(1)),
      CardList([for (final r in recs.take(3)) RecordTile(r, w)], empty: s.noRecordsYet),
      SectionTitle(s.detailsTitle),
      _Details(a, w, edit),
    ];
    return _TabScroll('overview', children, side: side);
  }

  /// A date the asset carries (road tax, insurance), with the reminder that follows it.
  Widget _expiry(BuildContext context, String title, IconData icon, DateTime? date, String source, String? extra, VoidCallback edit) {
    final s = context.s;
    final kind = source == autoRoadTax ? RenewKind.roadTax : RenewKind.insurance;
    final v = w.vehicles[a.id];
    final both = v != null && renewTogether(v.roadTaxExpiry, v.insuranceExpiry);
    if (date == null) {
      return AppRow(
        leading: IconAvatar(icon),
        title: title,
        meta: s.notSet,
        trailing: TextButton(onPressed: () => openRenewal(context, a.id, kind), child: Text(s.renew)),
        onTap: edit,
      );
    }
    final r = w.reminders.where((x) => x.assetId == a.id && x.autoSource == source && !x.done).firstOrNull;
    final days = daysBetween(today(), date);
    final (st, tone) = r != null ? shortDue(s, r, w) : (days < 0 ? (s.expired, Tone.expired) : (s.inDays(days), Tone.upcoming));
    final cover = currentCoverRecord(w, a.id, kind);
    final ends = extra == null ? s.endsCap(s.dLong(date)) : '$extra · ${s.endsOn(s.dLong(date))}';
    return AppRow(
      leading: IconAvatar(icon),
      title: title,
      status: StatusLabel(st, tone),
      meta: cover == null ? ends : '$ends · ${s.monthsCount(coverMonths(cover.coverStart!, cover.coverEnd!))}',
      // Renew shows once the end is near; until then it is in the reminder.
      action: days <= renewSoonDays ? FilledButton.tonal(onPressed: () => openRenewal(context, a.id, kind, both: both), child: Text(s.renew)) : null,
      onTap: r != null ? () => showReminderSheet(context, r.id) : edit,
    );
  }
}

/// Everything else about the asset, folded away: a one-line summary that opens the full list.
class _Details extends StatelessWidget {
  const _Details(this.a, this.w, this.edit);
  final Asset a;
  final World w;
  final VoidCallback edit;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final k = context.tokens;
    final List<(String, String)> facts;
    final String summary;
    final h = w.houses[a.id];
    final v = w.vehicles[a.id];
    final council = councilNamed(h?.council, state: h?.state)?.$1;
    final web = council?.web;
    if (h != null) {
      facts = [
        (s.propertyType, s.ptypeName(h.propertyType)),
        if (h.source != null) (s.boughtAs, s.sourceName(h.source!)),
        if (h.vpDate != null) (h.source == 'subsale' ? s.vpDateSubsale : s.vpDate, s.dLong(h.vpDate!)),
        if (h.spaDate != null) (s.spaDate, s.dLong(h.spaDate!)),
        if (h.titleStatus != null) (s.titleStatus, s.titleName(h.titleStatus!)),
        if (h.council != null) (s.council, h.council!),
        if (h.state != null) (s.state, h.state!),
        if (h.occupancy != null) (s.occupancy, s.occupancyName(h.occupancy!)),
        // The tenancy running now; ended ones are on the rent page.
        if (currentTenancy(w.tenancies, a.id) case final t?) ...[
          if (t.startDate != null || t.endDate != null)
            (s.tenancy, s.tenancyPeriod(t.startDate == null ? null : s.dLong(t.startDate!), t.endDate == null ? null : s.dLong(t.endDate!))),
          if (t.dueDay != null) (s.rentDue, s.rentDueDay(t.dueDay!)),
        ],
        if (h.address != null) (s.address, h.address!),
        if (h.contact != null) (s.contact, h.contact!),
        if (a.notes != null) (s.notes, a.notes!),
      ];
      summary = [
        if (h.titleStatus != null) s.titleName(h.titleStatus!),
        if (h.vpDate != null) s.vpOn(s.dShort(h.vpDate!)),
        if (h.occupancy != null) s.occupancyName(h.occupancy!),
      ].join(' · ');
    } else {
      facts = [
        if (v != null && (v.make != null || v.model != null)) (s.vehicle, [v.make, v.model, v.year?.toString()].whereType<String>().join(' ')),
        if (v?.cc != null) ('cc', '${v!.cc}'),
        if (v?.insuranceProvider != null) (s.insurer, v!.insuranceProvider!),
        if (v?.policyNo != null) (s.policyNo, v!.policyNo!),
        if (v != null && (v.warrantyExpiry != null || v.warrantyKm != null))
          (s.warranty, [if (v.warrantyExpiry != null) s.dLong(v.warrantyExpiry!), if (v.warrantyKm != null) s.km(v.warrantyKm!)].join(s.orWord)),
        if (v?.condition != null) (s.boughtAs, s.conditionName(v!.condition!)),
        if (v?.chassisNo != null) (s.chassisNo, v!.chassisNo!),
        if (v?.engineNo != null) (s.engineNo, v!.engineNo!),
        if (a.notes != null) (s.notes, a.notes!),
      ];
      summary = [
        if (v?.cc != null) '${v!.cc} cc',
        if (v?.warrantyExpiry != null) s.warrantyUntil2(s.dShort(v!.warrantyExpiry!)),
        if (v?.condition != null) s.conditionName(v!.condition!),
      ].join(' · ');
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // Its own storage key: without one it would read the tab's scroll offset as its state.
        key: const PageStorageKey<String>('details'),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(h != null ? s.houseDetails : s.vehicleDetails, style: KText.row.copyWith(color: k.text)),
        subtitle: summary.isEmpty ? null : Text(summary, style: KText.meta.copyWith(color: k.textMuted)),
        children: [
          if (facts.isNotEmpty) Facts(facts, bare: true),
          if (web != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(s.councilWebsite(council?.abbr)),
                onPressed: () => openWebsite(context, web),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(icon: const Icon(Icons.edit_outlined), label: Text(s.editDetails), onPressed: edit),
        ],
      ),
    );
  }
}

IconData kindIcon(String kind) => switch (kind) {
      'payment' => Icons.receipt_long_outlined,
      'incident' => Icons.report_gmailerrorred_outlined,
      'defect' => Icons.construction_outlined,
      'renovation' => Icons.format_paint_outlined,
      _ => Icons.build_outlined,
    };

class RecordTile extends StatelessWidget {
  const RecordTile(this.r, this.w, {super.key, this.showAsset = false});
  final UpkeepRecord r;
  final World w;
  final bool showAsset;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final photos = w.photosOf(r.id);
    final defect = r.kind == 'defect';
    final meta = [
      if (defect) ...[
        if (r.area != null) r.area!,
        s.foundOn(s.dShort(r.date)),
        r.reportedToDeveloper == null ? s.notReportedYet : s.reportedOn(s.dShort(r.reportedToDeveloper!)),
      ] else ...[
        s.dLong(r.date),
        '${s.kindName(r.kind)}${r.category != null ? ' · ${s.catName(r.category!)}' : ''}',
        if (r.odometer != null) s.km(r.odometer!),
        if (r.vendorName != null) r.vendorName!,
      ],
      if (showAsset) w.asset(r.assetId)?.nickname ?? '',
    ].join(' · ');
    Widget? status;
    if (defect) {
      final v = r.status ?? 'open';
      status = StatusLabel(s.defectStatusName(v), switch (v) { 'done' => Tone.done, 'in_progress' => Tone.inProgress, _ => Tone.dueSoon });
    } else if (r.cost != null) {
      status = Text(s.rm(r.cost!), style: KText.status.copyWith(color: context.tokens.text));
    }
    return AppRow(
      leading: photos.isNotEmpty
          ? ClipRRect(borderRadius: BorderRadius.circular(KSpace.controlRadius), child: SecureImage(photos.first.filePath, size: 36, cacheWidth: 150))
          : IconAvatar(kindIcon(r.kind)),
      title: r.title,
      status: status,
      meta: meta,
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
              if (r.coverStart != null && r.coverEnd != null) (s.coverPeriodWord, s.coverPeriod(s.dLong(r.coverStart!), s.dLong(r.coverEnd!))),
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
                    // The record, its photo rows and its warranty reminder go together; the
                    // photo files after.
                    final files = FileChanges(db);
                    await files.commit(() async {
                      for (final p in photos) {
                        await db.deleteDocument(p.id);
                        files.remove(p.filePath);
                      }
                      await db.unlinkDocuments(r.id);
                      await db.deleteRecord(r.id);
                      if (r.warrantyReminderId != null) await db.deleteReminder(r.warrantyReminderId!);
                    });
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

/// Every record of the asset, defects included, as a history: newest first, a line down the
/// left, each year with its count and total, and each record with what was bought or done.
/// A search finds a record by its items too ("battery"). Defects have their own list,
/// grouped by repair status.
class _Records extends StatefulWidget {
  const _Records(this.a, this.w, this.kind);
  final Asset a;
  final World w;
  final ValueNotifier<String?> kind;

  @override
  State<_Records> createState() => _RecordsState();
}

class _RecordsState extends State<_Records> {
  String _q = '';

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
        valueListenable: widget.kind,
        builder: (context, k, _) {
          final s = context.s;
          final a = widget.a;
          final w = widget.w;
          final all = w.records.where((r) => r.assetId == a.id).toList()..sort((x, y) => y.date.compareTo(x.date));
          final present = [for (final x in kindsFor(a.category)) if (x == k || all.any((r) => r.kind == x)) x];
          final filter = present.length > 1 || k != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ChoiceRow<String?>(
                    options: [null, ...present],
                    value: k,
                    label: (v) => v == null ? s.all : s.kindName(v),
                    onChanged: (v) => widget.kind.value = v,
                  ),
                )
              : null;
          if (k == 'defect') return _DefectList(a, w, filter: filter);
          final q = _q.trim().toLowerCase();
          bool matches(UpkeepRecord r) => [
                r.title,
                r.vendorName ?? '',
                r.area ?? '',
                r.notes ?? '',
                if (r.category != null) s.catName(r.category!),
                for (final i in w.costItems[r.id] ?? const <CostItem>[]) i.label,
              ].join(' ').toLowerCase().contains(q);
          final rs = all.where((r) => (k == null || r.kind == k) && (q.isEmpty || matches(r))).toList();
          final years = <int, List<UpkeepRecord>>{};
          for (final r in rs) {
            years.putIfAbsent(r.date.year, () => []).add(r);
          }
          return _TabScroll('records', [
            if (all.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: a.category == 'house' ? s.searchItemsHouse : s.searchItemsVehicle,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            if (filter != null) filter,
            if (rs.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                child: Text(all.isEmpty ? s.noRecordsYet : s.noMatch, style: KText.meta.copyWith(color: context.tokens.textMuted)),
              ),
            for (final MapEntry(key: year, value: list) in years.entries) ...[
              _YearMark(year: year, count: list.length, total: list.fold<double>(0, (t, r) => t + (r.cost ?? 0))),
              for (final r in list) _OnRail(child: RecordCard(r, w)),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(s.addRecord),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecordFormScreen(assetId: a.id, kind: k ?? 'maintenance'))),
            ),
          ]);
        },
      );
}

const _railWidth = 24.0;

/// The line down the left of the history, with a dot for each record.
class _OnRail extends StatelessWidget {
  const _OnRail({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return Stack(children: [
      Positioned(left: 7, top: 0, bottom: 0, child: Container(width: 2, color: k.line)),
      Positioned(
        left: 3,
        top: 22,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: k.background, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2)),
        ),
      ),
      Padding(padding: const EdgeInsets.only(left: _railWidth, top: 10), child: child),
    ]);
  }
}

/// A year on the history line: how many records and what they cost.
class _YearMark extends StatelessWidget {
  const _YearMark({required this.year, required this.count, required this.total});
  final int year;
  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final st = KText.section.copyWith(color: context.tokens.label, fontFeatures: const [FontFeature.tabularFigures()]);
    return Stack(children: [
      Positioned(left: 7, top: 20, bottom: 0, child: Container(width: 2, color: context.tokens.line)),
      Positioned(left: 4, top: 21, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: context.tokens.label, shape: BoxShape.circle))),
      Padding(
        padding: const EdgeInsets.fromLTRB(_railWidth, 16, 4, 0),
        child: Semantics(
          header: true,
          child: Row(children: [
            Expanded(child: Text(s.yearCount(year, count), style: st)),
            if (total > 0) Text(s.rm(total), style: st),
          ]),
        ),
      ),
    ]);
  }
}

/// One record in the history: its name and cost, when and where, and what was bought or done.
/// An unreported defect during the DLP can be marked reported from here.
class RecordCard extends StatelessWidget {
  const RecordCard(this.r, this.w, {super.key, this.showStatus = true});
  final UpkeepRecord r;
  final World w;

  /// False in the defect list, which is already grouped by status.
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final k = context.tokens;
    final defect = r.kind == 'defect';
    final photos = w.photosOf(r.id).length;
    final items = w.costItems[r.id] ?? const <CostItem>[];
    final meta = [
      // A payment or a defect says what it is; repairs and services are the usual case.
      if (r.kind == 'payment' || defect) s.kindName(r.kind),
      if (defect) ...[if (r.area != null) r.area!, s.foundOn(s.dShort(r.date))] else s.dShort(r.date),
      if (r.coverStart != null && r.coverEnd != null) s.coverPeriod(s.dShort(r.coverStart!), s.dShort(r.coverEnd!)),
      if (!defect && r.odometer != null) s.km(r.odometer!),
      if (!defect && r.area != null) r.area!,
      if (r.vendorName != null) r.vendorName!,
      if (photos > 0) s.photosCount(photos),
    ].join(' · ');
    Widget? status;
    if (defect && showStatus) {
      final v = r.status ?? 'open';
      final unreported = r.reportedToDeveloper == null && v == 'open';
      status = StatusLabel(unreported ? s.notReportedYet : s.defectStatusName(v), switch (v) { 'done' => Tone.done, 'in_progress' => Tone.inProgress, _ => Tone.dueSoon });
    } else if (r.cost != null) {
      status = Text(s.rm(r.cost!), style: KText.row.copyWith(color: k.text, fontFeatures: const [FontFeature.tabularFigures()]));
    }
    final end = dlpEnd(w, r.assetId);
    final canReport = defect && r.reportedToDeveloper == null && r.status != 'done' && end != null && daysBetween(today(), end) > 0;
    final shown = items.length <= 3 ? items : items.take(2).toList();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showRecordSheet(context, r.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LayoutBuilder(
              builder: (context, box) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.row.copyWith(color: k.text))),
                if (status != null) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45), child: Padding(padding: const EdgeInsets.only(top: 1), child: status)),
                ],
              ]),
            ),
            if (meta.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.meta.copyWith(color: k.textMuted)),
              ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: k.divider),
              const SizedBox(height: 6),
              for (final i in shown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.fromLTRB(2, 9, 8, 0), child: Container(width: 4, height: 4, decoration: BoxDecoration(color: k.textMuted, shape: BoxShape.circle))),
                    Expanded(child: Text(i.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, height: 22 / 14, color: k.text))),
                  ]),
                ),
              if (items.length > 3) Text(s.moreItems(items.length - 2), style: TextStyle(fontSize: 14, height: 22 / 14, color: k.textMuted)),
            ],
            if (canReport)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: FilledButton.tonal(
                  onPressed: () async {
                    // As in the record sheet: reported today, and being repaired unless already further on.
                    await context.db.updateRecord(r.id, RecordsCompanion(
                      reportedToDeveloper: Value(today()),
                      status: Value(r.status == null || r.status == 'open' ? 'in_progress' : r.status),
                    ));
                    if (context.mounted) snack(context, s.reportedToday);
                  },
                  child: Text(s.markReportedShort),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Reminders extends StatelessWidget {
  const _Reminders(this.a, this.w);
  final Asset a;
  final World w;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final rs = w.listed.where((r) => r.assetId == a.id && !r.done).toList()..sort(remOrder(w));
    return _TabScroll('reminders', [
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
    return _TabScroll('documents', [
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

/// Defects grouped by repair status, with the DLP reminder while it runs.
class _DefectList extends StatelessWidget {
  const _DefectList(this.a, this.w, {this.filter});
  final Asset a;
  final World w;
  final Widget? filter;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final end = dlpEnd(w, a.id);
    final left = end == null ? null : daysBetween(today(), end);
    final ds = w.records.where((r) => r.assetId == a.id && r.kind == 'defect').toList();
    Widget group(String status, String label) {
      final g = ds.where((r) => (r.status ?? 'open') == status).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(label, count: g.length),
        if (g.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(s.none, style: KText.meta.copyWith(color: context.tokens.textMuted)))
        else
          for (final r in g) Padding(padding: const EdgeInsets.only(bottom: 10), child: RecordCard(r, w, showStatus: false)),
      ]);
    }

    return _TabScroll('defects', [
      if (filter != null) filter!,
      if (end != null && left! > 0)
        NoteBox('$left ${s.dlpDaysLeftEnds(s.dLong(end))}. ${s.defectReportNote}', warn: true)
      else if (end != null)
        NoteBox([
          s.dlpEnded(s.dLong(end)),
          if (_tribunal(w, a.id) case final d?) s.dlpEndedTribunal(s.dLong(d)),
        ].join(' ')),
      InspectionsCard(a, w),
      group('open', s.defectOpen),
      group('in_progress', s.defectInProgress),
      group('done', s.defectFixed),
      const SizedBox(height: 12),
      SendDefectsButton(a, w),
      const SizedBox(height: 8),
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
      await Notifier.mileage(s, s.mileageNoteTitle(a.nickname), changed.first, hide: Notifier.hidesDetails(w.settings, context.app.lockMode));
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

/// Saves the fields and the linked-reminder changes together, then closes the screen with a summary.
Future<void> saveWithAutoReminders(BuildContext context, int assetId, List<AutoChange> changes, Future<void> Function() saveFields) async {
  final s = context.s;
  final db = context.db;
  final overwrite = await askAutoConflicts(context, changes);
  if (overwrite == null || !context.mounted) return;
  final List<String> msgs;
  try {
    msgs = await saveFieldsWithAuto(db, s, assetId, changes, overwriteManual: overwrite, saveFields: saveFields);
  } catch (e) {
    ErrorLog.record('asset.save', e);
    if (context.mounted) snack(context, s.couldNotSave);
    return;
  }
  if (!context.mounted) return;
  Navigator.pop(context);
  snack(context, msgs.isEmpty ? s.changesSaved : msgs.join(' '));
}

/// The asset photo as one row: a small picture, what it is for, and a button that offers the
/// camera, the gallery and, when there is one, removing it.
class PhotoRow extends StatelessWidget {
  const PhotoRow({super.key, required this.thumb, required this.onPick, this.onRemove});

  /// The picture, or null for none yet.
  final Widget? thumb;
  final void Function(String source) onPick;

  /// Null when there is no photo to remove.
  final VoidCallback? onRemove;

  Future<void> _choose(BuildContext context) async {
    final s = context.s;
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(s.camera), onTap: () => Navigator.pop(c, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(s.gallery), onTap: () => Navigator.pop(c, 'gallery')),
          if (onRemove != null) ListTile(leading: const Icon(Icons.delete_outline), title: Text(s.removePhoto), onTap: () => Navigator.pop(c, 'remove')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (v == null) return;
    if (v == 'remove') {
      onRemove?.call();
    } else {
      onPick(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final k = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _choose(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: thumb ?? ColoredBox(color: k.iconBg, child: Icon(Icons.add_a_photo_outlined, color: k.iconFg)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.assetPhoto, style: KText.row.copyWith(color: k.text)),
              const SizedBox(height: 2),
              Text(s.assetPhotoHint, style: KText.meta.copyWith(color: k.textMuted)),
            ]),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: () => _choose(context), child: Text(thumb == null ? s.add : s.change)),
        ]),
      ),
    );
  }
}

/// Pick, change or remove the photo of an asset that is already saved.
class AssetPhotoField extends StatelessWidget {
  const AssetPhotoField({super.key, required this.a});
  final Asset a;

  @override
  Widget build(BuildContext context) {
    Future<void> set(String src) async {
      final p = await pickFile(context, src);
      if (p == null || !context.mounted) return;
      final db = context.db;
      final name = await SecureFiles.save(db, p.bytes, p.ext);
      final old = a.photoPath;
      await db.updateAsset(a.id, AssetsCompanion(photoPath: Value(name)));
      if (old != null) await SecureFiles.delete(old);
    }

    final photo = a.photoPath;
    return PhotoRow(
      thumb: photo == null ? null : SecureImage(photo, cacheWidth: 200),
      onPick: set,
      onRemove: photo == null
          ? null
          : () async {
              await context.db.updateAsset(a.id, const AssetsCompanion(photoPath: Value(null)));
              await SecureFiles.delete(photo);
            },
    );
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
  DateTime? _ccc;
  bool _septic = false;
  bool? _insidePbt;

  /// Subsale only: whether the developer's 24-month DLP still runs. When it does not, the VP
  /// and DLP dates are not asked, and are cleared on save.
  bool _inDlp = false;

  /// Optional fields that were empty and have been opened with their "+" button.
  final Set<String> _opened = {};
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_name, _council, _state, _address, _contact, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The VP and DLP dates apply unless this is a subsale past the developer's DLP.
  bool get _asksVp => _source != 'subsale' || _inDlp;

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
        _ccc = h.cccDate;
        _inDlp = h.vpDate != null;
        _septic = h.septicTank == true;
        _insidePbt = h.insidePbt;
        _council.text = h.council ?? '';
        _state.text = h.state ?? '';
        _address.text = h.address ?? '';
        _contact.text = h.contact ?? '';
      }
      final theme = Theme.of(context);
      final k = context.tokens;
      final help = theme.textTheme.bodySmall;
      bool shown(String key, bool hasValue) => hasValue || _opened.contains(key);
      Widget addButton(String key, String label) => TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(label),
            onPressed: () => setState(() => _opened.add(key)),
          );
      final showSpa = shown('spa', _spa != null);
      final showAddress = shown('address', _address.text.isNotEmpty);
      final showContact = shown('contact', _contact.text.isNotEmpty);
      final showNotes = shown('notes', _notes.text.isNotEmpty);
      final rented = _occupancy == 'rented';
      return SafeScaffold(
        appBar: AppBar(title: Text(s.editDetails)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          AssetPhotoField(a: a),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: InputDecoration(labelText: s.nickname, border: const OutlineInputBorder())),
          const SizedBox(height: 14),
          FieldLabel(s.propertyType),
          ChoiceRow<String>(
            options: const ['landed', 'strata', 'strata_landed'],
            value: _ptype,
            label: s.ptypeName,
            onChanged: (v) => setState(() {
              _ptype = v;
              if (_title != null && !titleOptionsFor(v).contains(_title)) _title = null;
            }),
          ),
          const SizedBox(height: 14),
          // A condo or apartment is on the building's sewer; a landed house may have its own tank.
          if (_ptype != 'strata') ...[
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(children: [
                SwitchListTile(
                  value: _septic,
                  title: Text(s.septicQ, style: KText.row.copyWith(color: k.text)),
                  subtitle: Text(s.septicHelp),
                  onChanged: (v) => setState(() => _septic = v),
                ),
                if (_septic)
                  SwitchListTile(
                    value: _insidePbt != false,
                    title: Text(s.insidePbtQ, style: KText.row.copyWith(color: k.text)),
                    subtitle: Text(s.insidePbtHelp),
                    onChanged: (v) => setState(() => _insidePbt = v),
                  ),
              ]),
            ),
          ],
          FieldLabel(s.suggestedForType),
          Builder(builder: (context) {
            final open = templatesFor('house', _ptype, septicTank: _septic, insidePbt: _insidePbt, state: _state.text)
                .where((p) => !w.reminders.any((r) => r.assetId == a.id && !r.done && r.category == p.category))
                .toList();
            if (open.isEmpty) return Text(s.allSuggestedAdded, style: help);
            return Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in open)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(p.title(s)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReminderFormScreen(assetId: a.id, templateKey: p.key))),
                ),
            ]);
          }),

          // ---- purchase: the VP and DLP only when they can still apply
          const SizedBox(height: 20),
          FieldLabel(s.purchase),
          ChoiceRow<String>(options: const ['new_from_developer', 'subsale'], value: _source, label: s.sourceName, onChanged: (v) => setState(() => _source = v)),
          const SizedBox(height: 12),
          if (_source == 'subsale')
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: SwitchListTile(
                value: _inDlp,
                title: Text(s.stillInDlpQ, style: KText.row.copyWith(color: k.text)),
                subtitle: Text(s.stillInDlpHelp),
                onChanged: (v) => setState(() => _inDlp = v),
              ),
            ),
          if (_asksVp) ...[
            DateField(label: _source == 'subsale' ? s.vpDateSubsale : s.vpDate, value: _vp, onChanged: (d) => setState(() => _vp = d)),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(_source == 'subsale' ? s.vpHelpSubsale : s.vpHelp, style: help),
            ),
            if (_vp != null) ...[
              DateField(label: s.dlpEndOverrideLabel, value: _dlpOverride, onChanged: (d) => setState(() => _dlpOverride = d)),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 10),
                child: Text(s.dlpEndOverrideHelp(s.dLong(dlpEndFrom(_vp!))), style: help),
              ),
              NoteBox(s.autoSyncNoteDlp, icon: Icons.sync),
              if (_source != 'subsale') ...[
                const SizedBox(height: 8),
                NoteBox(s.autoSyncNoteTribunal(s.dLong(tribunalDeadlineFrom(_dlpOverride ?? dlpEndFrom(_vp!)))), icon: Icons.gavel),
              ],
              const SizedBox(height: 12),
            ],
            if (_source != 'subsale') ...[
              DateField(label: s.cccDateLabel, value: _ccc, onChanged: (d) => setState(() => _ccc = d)),
              Padding(padding: const EdgeInsets.only(top: 4, bottom: 10), child: Text(s.cccHelp, style: help)),
            ],
          ],
          if (showSpa)
            DateField(label: s.spaDate, value: _spa, onChanged: (d) => setState(() => _spa = d))
          else
            Align(alignment: Alignment.centerLeft, child: addButton('spa', s.spaShort)),

          // ---- title and council
          const SizedBox(height: 20),
          FieldLabel(s.titleAndCouncil),
          ChoiceRow<String>(options: titleOptionsFor(_ptype), value: _title, label: s.titleName, onChanged: (v) => setState(() => _title = v)),
          const SizedBox(height: 14),
          ComboField(controller: _state, label: s.state, options: stateOptions(), onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          ComboField(
            controller: _council,
            label: s.council,
            hint: s.councilHint,
            options: councilOptions(w, _state.text),
            source: s.councilListSource,
            trailing: councilLinkButton(context, _council.text, state: _state.text),
            onChanged: (_) => setState(() {}),
            onSelected: (o) {
              // Picked from every state's list: fill in the state too.
              final c = councilNamed(o.value);
              if (c != null && stateNamed(_state.text) == null) _state.text = c.$2;
            },
          ),

          // ---- occupancy, and the tenancy when it is rented out
          const SizedBox(height: 20),
          FieldLabel(s.occupancy),
          ChoiceRow<String>(options: const ['owner', 'rented', 'vacant'], value: _occupancy, label: s.occupancyName, onChanged: (v) => setState(() => _occupancy = v)),
          if (rented) ...[
            const SizedBox(height: 14),
            NoteBox(s.houseRentNote, icon: Icons.key_outlined),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(icon: const Icon(Icons.key_outlined), label: Text(s.manageRent), onPressed: () => openRent(context, a.id)),
            ),
          ],

          // ---- the rest, only when used
          const SizedBox(height: 20),
          FieldLabel(s.otherDetails),
          if (showAddress) ...[
            TextField(controller: _address, maxLines: 2, decoration: InputDecoration(labelText: s.address, border: const OutlineInputBorder())),
            const SizedBox(height: 12),
          ],
          if (showContact) ...[
            TextField(controller: _contact, decoration: InputDecoration(labelText: s.contact, hintText: s.contactHint, border: const OutlineInputBorder())),
            const SizedBox(height: 12),
          ],
          if (showNotes) ...[
            TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(labelText: s.notes, border: const OutlineInputBorder())),
            const SizedBox(height: 12),
          ],
          if (!showAddress || !showContact || !showNotes)
            Wrap(spacing: 4, children: [
              if (!showAddress) addButton('address', s.address),
              if (!showContact) addButton('contact', s.contactShort),
              if (!showNotes) addButton('notes', s.notes),
            ]),
          const SizedBox(height: 20),
          SaveButton(
            onPressed: () async {
              if (_name.text.trim().isEmpty) return;
              final db = context.db;
              final t = today();
              final vp = _asksVp ? _vp : null;
              final dlpOverride = vp == null ? null : _dlpOverride;
              final changes = [
                planChange(w.reminders, a.id, autoDlp,
                    oldDate: activeDlpEnd(vp: h.vpDate, override: h.dlpEndOverride, today: t),
                    newDate: activeDlpEnd(vp: vp, override: dlpOverride, today: t),
                    today: t),
                planChange(w.reminders, a.id, autoTribunal,
                    oldDate: activeTribunalDeadline(vp: h.vpDate, override: h.dlpEndOverride, source: h.source, today: t),
                    newDate: activeTribunalDeadline(vp: vp, override: dlpOverride, source: _source, today: t),
                    today: t),
              ];
              await saveWithAutoReminders(context, a.id, changes, () async {
                await db.updateAsset(a.id, AssetsCompanion(nickname: Value(_name.text.trim()), notes: Value(nn(_notes.text))));
                await db.updateHouse(a.id, HouseProfilesCompanion(
                  propertyType: Value(_ptype),
                  source: Value(_source),
                  vpDate: Value(vp),
                  dlpEndOverride: Value(dlpOverride),
                  cccDate: Value(_asksVp && _source != 'subsale' ? _ccc : h.cccDate),
                  spaDate: Value(_spa),
                  titleStatus: Value(_title),
                  occupancy: Value(_occupancy),
                  septicTank: Value(_ptype == 'strata' ? h.septicTank : _septic),
                  insidePbt: Value(_septic ? (_insidePbt ?? true) : h.insidePbt),
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

/// A day of the month (rent due on the 5th), picked from a grid of 1 to 31. It looks and
/// sizes like DateField, so it stays readable at large text sizes.
class DayOfMonthField extends StatelessWidget {
  const DayOfMonthField({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final s = context.s;
    final k = context.tokens;
    // 0 clears the day; null is a cancel.
    final picked = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 7 * 40,
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (var d = 1; d <= 31; d++)
                Semantics(
                  button: true,
                  selected: d == value,
                  label: s.rentDueDay(d),
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.pop(c, d),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: d == value ? k.primary : null, shape: BoxShape.circle),
                      child: Text('$d', style: TextStyle(color: d == value ? k.onPrimary : k.text, fontFeatures: const [FontFeature.tabularFigures()])),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (value != null) TextButton(onPressed: () => Navigator.pop(c, 0), child: Text(s.clear)),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
        ],
      ),
    );
    if (picked == null) return;
    onChanged(picked == 0 ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.expand_more)),
        child: Text(value == null ? s.notSet : s.rentDueDay(value!)),
      ),
    );
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
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ComboField(controller: _make, label: s.make, options: makeOptions(w, a.category), onChanged: (_) => setState(() {})),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ComboField(controller: _model, label: s.model, options: modelOptions(w, a.category, _make.text)),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ComboField(
                  controller: _year,
                  label: s.year,
                  options: yearComboOptions(),
                  keyboardType: TextInputType.number,
                  textCapitalization: TextCapitalization.none,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: tf(_cc, 'cc', number: true)),
          ]),
          FieldLabel(s.boughtAs),
          ChoiceRow<String>(options: const ['new', 'second_hand'], value: _cond, label: s.conditionName, onChanged: (x) => setState(() => _cond = x)),
          const SizedBox(height: 14),
          DateField(label: s.roadTaxExpiry, value: _roadTax, onChanged: (d) => setState(() => _roadTax = d)),
          const SizedBox(height: 12),
          DateField(label: s.insuranceExpiry, value: _insExp, onChanged: (d) => setState(() => _insExp = d)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ComboField(controller: _insurer, label: s.insurer, options: insurerOptions(w), source: s.insurerListSource),
          ),
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
          SaveButton(
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
