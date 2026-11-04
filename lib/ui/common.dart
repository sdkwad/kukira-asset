import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/rules.dart';
import '../l10n/strings.dart';
import '../services/notifications.dart';
import 'tokens.dart';

export 'tokens.dart';

// ---------------------------------------------------------------- scope

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.db,
    required this.s,
    required this.lang,
    required this.world,
    required this.notif,
    required this.rebuildInfo,
    required this.setLang,
    required this.rebuildNow,
    required this.lockChanged,
    required this.lockNow,
    this.lockMode = 'none',
    required super.child,
  });

  final AppDb db;
  final Str s;
  final String lang;
  final ValueNotifier<World?> world;

  /// null = not known yet
  final ValueNotifier<bool?> notif;
  final ValueNotifier<RebuildInfo?> rebuildInfo;
  final void Function(String lang) setLang;
  final Future<void> Function() rebuildNow;

  /// Re-reads the lock setting after it was turned on or off.
  final VoidCallback lockChanged;

  /// Shows the lock screen now.
  final VoidCallback lockNow;

  /// none | pin | pin_bio (Vault.lockMode).
  final String lockMode;

  static AppScope of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => old.s != s || old.db != db || old.lang != lang || old.lockMode != lockMode;
}

extension AppContext on BuildContext {
  AppScope get app => AppScope.of(this);
  Str get s => AppScope.of(this).s;
  AppDb get db => AppScope.of(this).db;
}

/// Rebuilds whenever any table changes.
class WorldView extends StatelessWidget {
  const WorldView({super.key, required this.builder});
  final Widget Function(BuildContext context, World w) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<World?>(
        valueListenable: context.app.world,
        builder: (c, w, _) => w == null ? const SafeScaffold(body: Center(child: CircularProgressIndicator())) : builder(c, w),
      );
}

// ---------------------------------------------------------------- wide screens

/// Material window size classes: a phone (compact), a large phone on its side, a small
/// tablet or an unfolded phone (medium), a tablet (expanded).
enum WindowSize { compact, medium, expanded }

WindowSize windowSize(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= 840 ? WindowSize.expanded : (w >= 600 ? WindowSize.medium : WindowSize.compact);
}

/// How wide a page of text and fields gets on a wide screen.
const readableWidth = 760.0;

/// The part of the window beside the navigation rail. The rail has its own Tambah button,
/// so the pages there do not show their floating one as well.
class RailScope extends InheritedWidget {
  const RailScope({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RailScope>() != null;

  @override
  bool updateShouldNotify(RailScope oldWidget) => false;
}

/// Keeps [child] at most [maxWidth] wide, centred, on a wide screen. Narrower than that (a
/// phone) it is left exactly as it was.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, this.maxWidth = readableWidth, required this.child});
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => box.maxWidth <= maxWidth
            ? child
            : Align(
                alignment: Alignment.topCenter,
                child: SizedBox(width: maxWidth, height: box.maxHeight.isFinite ? box.maxHeight : null, child: child),
              ),
      );
}

/// A Scaffold whose body stays clear of the system bars. With Android's edge-to-edge
/// layout the 3-button navigation bar otherwise covers the last field and the Save button.
/// On a wide screen the body keeps to [maxWidth] (null: the full width).
class SafeScaffold extends StatelessWidget {
  const SafeScaffold({super.key, this.appBar, this.body, this.floatingActionButton, this.backgroundColor, this.maxWidth = readableWidth});
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final content = body ?? const SizedBox.shrink();
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      body: SafeArea(top: appBar == null, child: maxWidth == null ? content : ReadableWidth(maxWidth: maxWidth!, child: content)),
    );
  }
}

// ---------------------------------------------------------------- reminder helpers

DateTime today() => dayOnly(DateTime.now());

RStatus remStatus(Reminder r, World w) => statusOf(r.info, today: today(), odometer: w.odoOf(r.assetId));

int remSortKey(Reminder r, World w) {
  if (r.snoozedUntil != null && r.snoozedUntil!.isAfter(today())) return r.snoozedUntil!.millisecondsSinceEpoch;
  var k = 1 << 52;
  if (r.info.usesDate && r.dueDate != null) k = r.dueDate!.millisecondsSinceEpoch;
  final odo = w.odoOf(r.assetId);
  if (r.info.usesKm && r.dueOdometer != null && odo != null) {
    // Roughly 40 km a day, only to sort mileage items among dated ones.
    final est = today().add(Duration(days: ((r.dueOdometer! - odo) / 40).round())).millisecondsSinceEpoch;
    if (est < k) k = est;
  }
  return k;
}

int Function(Reminder, Reminder) remOrder(World w) {
  const rank = {RStatus.overdue: 0, RStatus.dueSoon: 1, RStatus.upcoming: 2, RStatus.done: 3};
  return (a, b) {
    final c = rank[remStatus(a, w)]!.compareTo(rank[remStatus(b, w)]!);
    return c != 0 ? c : remSortKey(a, w).compareTo(remSortKey(b, w));
  };
}

String dueText(Str s, Reminder r, World w) {
  final t = today();
  if (r.snoozedUntil != null && r.snoozedUntil!.isAfter(t)) return s.snoozedUntil(s.dShort(r.snoozedUntil!));
  final odo = w.odoOf(r.assetId);
  String kmText() {
    if (r.dueOdometer == null) return '';
    if (odo == null) return s.dueAtKm(s.km(r.dueOdometer!));
    final left = r.dueOdometer! - odo;
    return left <= 0 ? s.kmPast(s.km(-left), s.km(r.dueOdometer!)) : s.kmToGo(s.km(left), s.km(r.dueOdometer!));
  }

  String dateText() {
    if (r.dueDate == null) return '';
    final n = daysBetween(t, r.dueDate!);
    if (n < 0) return s.daysOverdue(-n, s.dShort(r.dueDate!));
    if (n == 0) return s.dueToday;
    if (n == 1) return s.dueTomorrow;
    return s.dueIn(s.dShort(r.dueDate!), n);
  }

  switch (r.ruleType) {
    case 'mileage':
      return kmText();
    case 'either':
      if (odo != null && r.dueOdometer != null && r.dueOdometer! <= odo) return kmText();
      if (r.dueDate != null && daysBetween(t, r.dueDate!) < 0) return dateText();
      final kmPart = r.dueOdometer == null ? null : (odo == null ? s.km(r.dueOdometer!) : s.kmLeft(s.km(r.dueOdometer! - odo)));
      final datePart = r.dueDate == null ? null : s.dShort(r.dueDate!);
      if (kmPart != null && datePart != null) return s.whicheverFirst(kmPart, datePart);
      return kmPart ?? dateText();
    default:
      return dateText();
  }
}

/// The few words on the right of a reminder row: how late it is, or how long to go, on
/// whichever measure (date or km) is nearer. The tone comes from the same status rules.
(String, Tone) shortDue(Str s, Reminder r, World w) {
  final t = today();
  final tone = toneOf(remStatus(r, w));
  if (r.snoozedUntil != null && r.snoozedUntil!.isAfter(t)) return (s.snoozedUntil(s.dShort(r.snoozedUntil!)), tone);
  final odo = w.odoOf(r.assetId);
  final days = r.info.usesDate && r.dueDate != null ? daysBetween(t, r.dueDate!) : null;
  final kmLeft = r.info.usesKm && r.dueOdometer != null && odo != null ? r.dueOdometer! - odo : null;
  // The same levels as statusOf: 2 overdue, 1 due soon, 0 upcoming. A tie shows the date.
  final soonDays = r.leadDays > dueSoonDays ? r.leadDays : dueSoonDays;
  final dateLevel = days == null ? -1 : (days < 0 ? 2 : (days <= soonDays ? 1 : 0));
  final kmLevel = kmLeft == null ? -1 : (kmLeft <= 0 ? 2 : (kmLeft <= r.leadKm ? 1 : 0));
  final byKm = kmLeft != null && (days == null || kmLevel > dateLevel);
  if (byKm) return (kmLeft <= 0 ? s.lateKm(s.km(-kmLeft)) : s.kmToGoShort(s.km(kmLeft)), tone);
  if (days != null) {
    if (days < 0) return (s.lateDays(-days), tone);
    if (days == 0) return (s.dueToday, tone);
    if (days == 1) return (s.dueTomorrow, tone);
    return (s.inDays(days), tone);
  }
  // A mileage reminder before the first odometer reading.
  return (r.dueOdometer == null ? '' : s.km(r.dueOdometer!), tone);
}

/// When a reminder is due, for the second line of its row: "ends 12 Nov", "by 28 Oct or
/// 50,120 km". How late or near it is goes on the right ([shortDue]), so it is not said twice.
String dueDetail(Str s, Reminder r, World w) {
  if (r.snoozedUntil != null && r.snoozedUntil!.isAfter(today()) && r.dueDate != null) return s.dueOn(s.dShort(r.dueDate!));
  final km = r.dueOdometer == null ? null : s.km(r.dueOdometer!);
  final date = r.dueDate == null ? null : s.dShort(r.dueDate!);
  switch (r.ruleType) {
    case 'mileage':
      return km == null ? '' : s.atKm(km);
    case 'either':
      if (date != null && km != null) return s.limitEither(date, km);
      return km != null ? s.atKm(km) : s.dueOn(date ?? '');
    default:
      if (date == null) return '';
      // A date that comes from the asset or a document is an expiry.
      final expiry = r.autoSource != null || r.category == 'document';
      if (r.autoSource == 'insurance') {
        final insurer = w.vehicles[r.assetId]?.insuranceProvider;
        if (insurer != null) return '$insurer · ${s.endsOn(date)}';
      }
      return expiry ? s.endsOn(date) : s.dueOn(date);
  }
}

String ruleText(Str s, Reminder r) {
  switch (r.ruleType) {
    case 'fixed':
      return s.ruleOnce;
    case 'repeat':
      if ((r.repeatDays ?? 0) > 0 && (r.repeatMonths ?? 0) == 0) return s.ruleEveryDays(r.repeatDays!, r.repeatFrom == 'due');
      return s.ruleEveryMonths(r.repeatMonths ?? 0, r.repeatFrom == 'due');
    case 'mileage':
      return s.ruleEveryKm(s.km(r.repeatKm ?? 0));
    default:
      return s.ruleEither(s.km(r.repeatKm ?? 0), r.repeatMonths ?? 0);
  }
}

String nextText(Str s, NextDue n, Reminder r) {
  if (n.done) return s.oneOffDone;
  final parts = <String>[
    if (n.dueKm != null && r.info.usesKm) s.km(n.dueKm!),
    if (n.due != null && r.info.usesDate) s.dLong(n.due!),
  ];
  return s.nextOne(parts.join(s.orWord), r.repeatFrom == 'due');
}

// ---------------------------------------------------------------- small widgets

IconData catIcon(String category) => switch (category) {
      'car' => Icons.directions_car_outlined,
      'motorcycle' => Icons.two_wheeler_outlined,
      _ => Icons.home_outlined,
    };

/// A neutral icon tile at the start of a row. Icons tell types apart; colour is kept for status.
class IconAvatar extends StatelessWidget {
  const IconAvatar(this.icon, {super.key, this.size = 36, this.tonal = false, this.warn = false});
  final IconData icon;
  final double size;

  /// The brand tint, for an action that creates something new.
  final bool tonal;

  /// The due-soon tint, for something that needs doing (no backup yet).
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final (bg, fg) = warn ? (k.dueSoonBg, k.dueSoon) : (tonal ? (k.tonal, k.onTonal) : (k.iconBg, k.iconFg));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(icon, color: fg, size: size * 0.55),
    );
  }
}

class AssetAvatar extends StatelessWidget {
  const AssetAvatar(this.category, {super.key, this.size = 40});
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) => IconAvatar(catIcon(category), size: size);
}

/// Background and foreground for a status: tinted boxes (banners, the Today tiles) use both,
/// rows use only the foreground through [StatusLabel].
(Color, Color) statusColors(BuildContext context, RStatus st) {
  final k = context.tokens;
  return switch (st) {
    RStatus.overdue => (k.overdueBg, k.overdue),
    RStatus.dueSoon => (k.dueSoonBg, k.dueSoon),
    RStatus.upcoming => (k.iconBg, k.textMuted),
    RStatus.done => (k.tonal, k.onTonal),
  };
}

/// How a status reads: each has its own colour and icon, and always a word.
/// [inProgress] is a defect the developer is repairing: neutral, like upcoming.
enum Tone { overdue, dueSoon, upcoming, inProgress, done, expired }

Tone toneOf(RStatus st) => switch (st) {
      RStatus.overdue => Tone.overdue,
      RStatus.dueSoon => Tone.dueSoon,
      RStatus.upcoming => Tone.upcoming,
      RStatus.done => Tone.done,
    };

/// The chip behind a boxed status: its tinted background, or the card colour.
Color toneBackground(BuildContext context, Tone tone) {
  final k = context.tokens;
  return switch (tone) {
    Tone.overdue => k.overdueBg,
    Tone.dueSoon => k.dueSoonBg,
    _ => k.surface,
  };
}

Color toneColor(BuildContext context, Tone tone) {
  final k = context.tokens;
  return switch (tone) {
    Tone.overdue => k.overdue,
    Tone.dueSoon => k.dueSoon,
    Tone.upcoming || Tone.inProgress => k.textMuted,
    Tone.done => k.done,
    Tone.expired => k.expired,
  };
}

/// A thin bar for how much of an interval has gone (km since the last service).
class ProgressLine extends StatelessWidget {
  const ProgressLine(this.fraction, {super.key, this.color});
  final double fraction;
  final Color? color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: fraction.clamp(0.0, 1.0),
          minHeight: 4,
          color: color ?? context.tokens.textMuted,
          backgroundColor: context.tokens.divider,
        ),
      );
}

/// A status as coloured text with an icon, never colour alone. [StatusLabel.of] uses the
/// standard word for a reminder status; the main constructor takes any text ("Expires 12 Nov").
/// Needs a bounded width (AppRow gives it one), so a long word wraps instead of overflowing.
class StatusLabel extends StatelessWidget {
  const StatusLabel(String this.text, this.tone, {super.key, this.boxed = false}) : status = null;
  StatusLabel.of(RStatus this.status, {super.key, this.boxed = false})
      : text = null,
        tone = toneOf(status);

  final String? text;
  final RStatus? status;
  final Tone tone;

  /// On its own small chip, for a status drawn over a photo, where its colour alone would
  /// not read.
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    final icon = switch (tone) {
      Tone.overdue => Icons.error_outline,
      Tone.dueSoon => Icons.schedule,
      Tone.upcoming => Icons.event_outlined,
      Tone.inProgress => Icons.pending_outlined,
      Tone.done => Icons.check_circle_outline,
      Tone.expired => Icons.history,
    };
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      Flexible(child: Text(text ?? context.s.statusLabel(status!), style: KText.status.copyWith(color: color))),
    ]);
    if (!boxed) return row;
    return DecoratedBox(
      decoration: BoxDecoration(color: toneBackground(context, tone), borderRadius: BorderRadius.circular(6)),
      child: Padding(padding: const EdgeInsets.fromLTRB(6, 2, 8, 2), child: row),
    );
  }
}

/// [text] with the first place [query] appears marked, for search results.
TextSpan highlighted(String text, String? query, KukiraColors k) {
  final q = query?.trim() ?? '';
  final at = q.isEmpty ? -1 : text.toLowerCase().indexOf(q.toLowerCase());
  if (at < 0) return TextSpan(text: text);
  return TextSpan(children: [
    TextSpan(text: text.substring(0, at)),
    TextSpan(text: text.substring(at, at + q.length), style: TextStyle(backgroundColor: k.dueSoonBg, fontWeight: FontWeight.w700)),
    TextSpan(text: text.substring(at + q.length)),
  ]);
}

/// The list row of the design system. Line 1: the title, with the status on the right.
/// Line 2: the context, full width. An optional action sits under both, shown only when
/// there is something to do.
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    this.leading,
    required this.title,
    this.titleTag,
    this.status,
    this.meta,
    this.metaTag,
    this.action,
    this.trailing,
    this.onTap,
    this.highlight,
  });

  final Widget? leading;
  final String title;

  /// Search text to mark in the title, where it appears.
  final String? highlight;

  /// A small tag right after the title, such as the estimate tag or a number plate.
  final Widget? titleTag;
  final Widget? status;
  final String? meta;

  /// A small tag before the context line, such as the estimate tag for an estimated date.
  final Widget? metaTag;
  final Widget? action;

  /// At the far right, centred on the row (a button or a chevron).
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(
        builder: (context, box) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Flexible(child: Text.rich(highlighted(title, highlight, k), maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.row.copyWith(color: k.text))),
              if (titleTag != null) ...[const SizedBox(width: 6), Padding(padding: const EdgeInsets.only(top: 1), child: titleTag!)],
            ]),
          ),
          if (status != null) ...[
            const SizedBox(width: 8),
            // Line heights 20 and 18: one pixel down puts both on the same line. With large
            // text the status wraps rather than squeezing the title to nothing.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45),
              child: Padding(padding: const EdgeInsets.only(top: 1), child: status!),
            ),
          ],
        ]),
      ),
      if (meta != null && meta!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (metaTag != null) Padding(padding: const EdgeInsets.only(top: 2, right: 6), child: metaTag!),
            Flexible(child: Text(meta!, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.meta.copyWith(color: k.textMuted))),
          ]),
        ),
      if (action != null) Padding(padding: const EdgeInsets.only(top: 10), child: action!),
    ]);
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KSpace.rowMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(crossAxisAlignment: action == null ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(child: text),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ]),
          ),
        ),
      ),
    );
  }
}

/// A screen's own title at the top of a main tab.
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
        child: Row(children: [
          Expanded(child: Text(text, style: KText.screenTitle.copyWith(color: context.tokens.text))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Tabs that share the width equally when their labels fit, and scroll when they do not
/// (a narrow phone with large text), so a label is never cut off.
class FitTabBar extends StatelessWidget implements PreferredSizeWidget {
  const FitTabBar({super.key, required this.tabs});
  final List<String> tabs;

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
    final scaler = MediaQuery.textScalerOf(context);
    const pad = 8.0;
    return LayoutBuilder(builder: (context, box) {
      var widest = 0.0;
      for (final t in tabs) {
        final p = TextPainter(text: TextSpan(text: t, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
        if (p.width > widest) widest = p.width;
      }
      final fits = widest + 2 * pad <= box.maxWidth / tabs.length;
      return TabBar(
        isScrollable: !fits,
        tabAlignment: fits ? TabAlignment.fill : TabAlignment.start,
        labelPadding: fits ? const EdgeInsets.symmetric(horizontal: pad) : null,
        tabs: [for (final t in tabs) Tab(text: t)],
      );
    });
  }
}

/// "estimated": the date is a preset to confirm, not a fact.
class EstTag extends StatelessWidget {
  const EstTag({super.key, this.margin = const EdgeInsets.only(left: 6)});
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final (_, fg) = statusColors(context, RStatus.dueSoon);
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(border: Border.all(color: fg), borderRadius: BorderRadius.circular(5)),
      child: Text(context.s.estShort, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.count, this.link, this.onLink});
  final String text;
  final int? count;

  /// A text button at the right instead of the count ("All (6)").
  final String? link;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final st = KText.section.copyWith(color: context.tokens.label, fontFeatures: const [FontFeature.tabularFigures()]);
    return Padding(
      padding: EdgeInsets.fromLTRB(4, link == null ? 18 : 8, link == null ? 4 : 0, link == null ? 8 : 0),
      child: Row(children: [
        Expanded(child: Semantics(header: true, child: Text(text, style: st))),
        if (link != null)
          TextButton(onPressed: onLink, child: Text(link!))
        else if (count != null)
          Text('$count', style: st),
      ]),
    );
  }
}

/// A card holding rows separated by dividers.
class CardList extends StatelessWidget {
  const CardList(this.children, {super.key, this.empty});
  final List<Widget> children;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(empty ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(const Divider(height: 1));
      items.add(children[i]);
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }
}

/// A reminder as a row: how late or near on the right, when it is due below, so each is said once.
class ReminderTile extends StatelessWidget {
  const ReminderTile(this.r, this.w, {super.key, required this.onTap, this.showAsset = true, this.icon});
  final Reminder r;
  final World w;
  final VoidCallback onTap;

  /// With the asset's name and icon (mixed lists), or without (on the asset's own page).
  final bool showAsset;

  /// An icon for the row on the asset's page, where the asset icon would repeat itself.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final a = w.asset(r.assetId);
    final (status, tone) = shortDue(s, r, w);
    final detail = dueDetail(s, r, w);
    // How much of the km interval has gone since it was last done.
    final odo = w.odoOf(r.assetId);
    final every = r.repeatKm ?? 0;
    final used = r.info.usesKm && every > 0 && r.dueOdometer != null && odo != null ? (odo - (r.dueOdometer! - every)) / every : null;
    return AppRow(
      leading: icon != null ? IconAvatar(icon!) : (showAsset ? AssetAvatar(a?.category ?? 'house', size: 36) : null),
      action: used == null ? null : ProgressLine(used, color: tone == Tone.upcoming ? null : toneColor(context, tone)),
      title: r.title,
      // The tag is about the date, which is on the second line.
      metaTag: r.estimated ? const EstTag(margin: EdgeInsets.zero) : null,
      status: status.isEmpty ? null : StatusLabel(status, tone),
      meta: [if (showAsset) a?.nickname ?? '', if (detail.isNotEmpty) detail].join(' · '),
      onTap: onTap,
    );
  }
}

/// A filled button for saving. While [onPressed] runs it is disabled and shows a spinner,
/// so a quick double tap can never save twice.
class SaveButton extends StatefulWidget {
  const SaveButton({super.key, required this.onPressed, required this.child});
  final Future<void> Function()? onPressed;
  final Widget child;

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool _busy = false;

  Future<void> _run() async {
    // A second tap can arrive before the button rebuilds as disabled.
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: widget.onPressed == null || _busy ? null : _run,
        child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : widget.child,
      );
}

class NoteBox extends StatelessWidget {
  const NoteBox(this.text, {super.key, this.warn = false, this.icon});
  final String text;
  final bool warn;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (bg, fg) = warn ? statusColors(context, RStatus.dueSoon) : (c.surfaceContainerHighest, c.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon ?? (warn ? Icons.warning_amber_rounded : Icons.info_outline), size: 18, color: fg),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: c.onSurface))),
      ]),
    );
  }
}

class Facts extends StatelessWidget {
  const Facts(this.rows, {super.key, this.bare = false});
  final List<(String, String)> rows;

  /// Without its own card, inside another one.
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final list = Padding(
        padding: EdgeInsets.all(bare ? 0 : 14),
        child: Column(
          children: [
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 130, child: Text(k, style: TextStyle(color: muted))),
                  Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
                ]),
              ),
          ],
        ),
      );
    return bare ? list : Card(margin: EdgeInsets.zero, child: list);
  }
}

class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.clearable = true, this.enabled = true});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: !enabled
          ? null
          : () async {
              final d = await showDatePicker(
                context: context,
                initialDate: value ?? today(),
                firstDate: DateTime(1980),
                lastDate: DateTime(2100),
              );
              if (d != null) onChanged(d);
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          border: const OutlineInputBorder(),
          suffixIcon: value != null && clearable && enabled
              ? IconButton(icon: const Icon(Icons.close), tooltip: s.clear, onPressed: () => onChanged(null))
              : const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value == null ? s.pickDate : s.dLong(value!)),
      ),
    );
  }
}

/// Wrap of single-choice chips.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({super.key, required this.options, required this.value, required this.label, required this.onChanged});
  final List<T> options;
  final T? value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final o in options)
            ChoiceChip(label: Text(label(o)), selected: o == value, onSelected: (_) => onChanged(o)),
        ],
      );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
}

Future<bool> confirm(BuildContext context, {required String title, required String body, required String ok, bool danger = false}) async {
  final s = context.s;
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error, foregroundColor: Theme.of(c).colorScheme.onError) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Runs [job] behind a modal spinner.
Future<T> withProgress<T>(BuildContext context, String msg, Future<T> Function() job) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => PopScope(
      canPop: false,
      child: AlertDialog(content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 20), Expanded(child: Text(msg))])),
    ),
  );
  try {
    return await job();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

int? parseInt(String t) => int.tryParse(t.replaceAll(RegExp(r'[^0-9]'), ''));

String? nn(String t) => t.trim().isEmpty ? null : t.trim();
