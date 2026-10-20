import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/rules.dart';
import '../l10n/strings.dart';
import '../services/notifications.dart';

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

  static AppScope of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => old.s != s || old.db != db || old.lang != lang;
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
        builder: (c, w, _) => w == null ? const Scaffold(body: Center(child: CircularProgressIndicator())) : builder(c, w),
      );
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

String ruleText(Str s, Reminder r) {
  switch (r.ruleType) {
    case 'fixed':
      return s.ruleOnce;
    case 'repeat':
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

class AssetAvatar extends StatelessWidget {
  const AssetAvatar(this.category, {super.key, this.size = 40});
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(catIcon(category), color: c.onPrimaryContainer, size: size * 0.55),
    );
  }
}

(Color, Color) statusColors(BuildContext context, RStatus st) {
  final c = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (st) {
    case RStatus.overdue:
      return (c.errorContainer, c.onErrorContainer);
    case RStatus.dueSoon:
      return dark ? (const Color(0xFF382B14), const Color(0xFFF0B550)) : (const Color(0xFFFAEDD3), const Color(0xFF7A4600));
    case RStatus.upcoming:
      return (c.secondaryContainer, c.onSecondaryContainer);
    case RStatus.done:
      return (c.primaryContainer, c.onPrimaryContainer);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final RStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusColors(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(context.s.statusLabel(status), style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class EstTag extends StatelessWidget {
  const EstTag({super.key});

  @override
  Widget build(BuildContext context) {
    final (_, fg) = statusColors(context, RStatus.dueSoon);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(border: Border.all(color: fg), borderRadius: BorderRadius.circular(5)),
      child: Text(context.s.estShort, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.count});
  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final st = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(children: [
        Expanded(child: Text(text.toUpperCase(), style: st)),
        if (count != null) Text('$count', style: st),
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

class ReminderTile extends StatelessWidget {
  const ReminderTile(this.r, this.w, {super.key, required this.onTap, this.showAsset = true});
  final Reminder r;
  final World w;
  final VoidCallback onTap;
  final bool showAsset;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final st = remStatus(r, w);
    final a = w.asset(r.assetId);
    final stripe = st == RStatus.overdue || st == RStatus.dueSoon ? statusColors(context, st).$2 : Colors.transparent;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: stripe, width: 3))),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(children: [
          AssetAvatar(a?.category ?? 'house', size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (r.estimated) const EstTag(),
              ]),
              const SizedBox(height: 2),
              Text(
                showAsset ? '${a?.nickname ?? ''} · ${dueText(s, r, w)}' : dueText(s, r, w),
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          StatusPill(st),
        ]),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.text, this.action, this.onAction, this.warn = false});
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (bg, fg) = warn ? statusColors(context, RStatus.dueSoon) : (c.secondaryContainer, c.onSecondaryContainer);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: fg, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: TextStyle(color: c.onSurface)),
            if (action != null)
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: onAction,
                child: Text(action!),
              ),
          ]),
        ),
      ]),
    );
  }
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
  const Facts(this.rows, {super.key});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
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
      ),
    );
  }
}

class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.clearable = true});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
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
          border: const OutlineInputBorder(),
          suffixIcon: value != null && clearable
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
