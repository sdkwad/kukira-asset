import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/rules.dart';
import '../services/notifications.dart';
import 'add_actions.dart';
import 'add_asset.dart';
import 'assets.dart';
import 'common.dart';
import 'forms.dart';
import 'more.dart';

/// What needs doing, and nothing else: a summary sentence, what is overdue and what is due in
/// 30 days, odometer readings that are getting old. When nothing is due it says so calmly and
/// shows what comes next, instead of a row of empty sections.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final k = context.tokens;
      final t = today();
      void go(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      final header = Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 0, 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.weekdayDate(t), style: KText.meta.copyWith(color: k.textMuted)),
              const SizedBox(height: 2),
              Semantics(header: true, child: Text(s.today, style: KText.screenTitle.copyWith(color: k.text))),
            ]),
          ),
          if (w.assets.isNotEmpty) IconButton(tooltip: s.search, icon: const Icon(Icons.search), onPressed: () => go(const SearchScreen())),
        ]),
      );

      if (w.assets.isEmpty) {
        final theme = Theme.of(context);
        return Scaffold(
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              header,
              const SizedBox(height: 24),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [AssetAvatar('house', size: 44), SizedBox(width: 8), AssetAvatar('car', size: 44), SizedBox(width: 8), AssetAvatar('motorcycle', size: 44)]),
                    const SizedBox(height: 16),
                    Text(s.emptyTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(s.emptyBody),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(s.addFirstAsset),
                      onPressed: () => go(const AddAssetScreen()),
                    ),
                    const SizedBox(height: 12),
                    Text(s.offlineNote, style: theme.textTheme.bodySmall),
                  ]),
                ),
              ),
            ]),
          ),
        );
      }

      final live = w.reminders.where((r) => !r.done).toList();
      final over = live.where((r) => remStatus(r, w) == RStatus.overdue).toList()..sort(remOrder(w));
      final soon = live.where((r) => remStatus(r, w) == RStatus.dueSoon).toList()..sort(remOrder(w));
      final later = live.where((r) => remStatus(r, w) == RStatus.upcoming).toList()..sort(remOrder(w));
      final stale = w.assets.where((a) {
        if (a.category == 'house') return false;
        // The monthly odometer reminder already asks for this reading when it is listed above.
        if ([...over, ...soon].any((r) => r.assetId == a.id && r.category == 'odometer')) return false;
        final hasKm = live.any((r) => r.assetId == a.id && r.info.usesKm);
        if (!hasKm) return false;
        final o = w.odometer[a.id];
        return o == null || daysBetween(o.date, t) > 30;
      }).toList();
      final completed = w.reminders.where((r) => r.lastCompleted != null && daysBetween(r.lastCompleted!, t) <= 30).toList()
        ..sort((a, b) => b.lastCompleted!.compareTo(a.lastCompleted!));
      final lastBackup = w.lastBackup;
      final needBackup = live.isNotEmpty && (lastBackup == null || daysBetween(lastBackup, t) > 30);
      final calm = over.isEmpty && soon.isEmpty;

      void open(Reminder r) => showReminderSheet(context, r.id);
      Widget odoRow(Asset a) {
        final o = w.odometer[a.id];
        return AppRow(
          leading: AssetAvatar(a.category, size: 36),
          title: calm ? s.odoRowTitle(a.nickname) : a.nickname,
          meta: o == null ? s.odoNeverShort : '${s.km(o.km)} · ${s.ago(o.date)}',
          trailing: TextButton(onPressed: () => showOdometerDialog(context, a.id), child: Text(s.update)),
          onTap: () => showOdometerDialog(context, a.id),
        );
      }

      // Things to set right before anything else: notifications off, no recent backup.
      final notices = ValueListenableBuilder<bool?>(
        valueListenable: context.app.notif,
        builder: (c, on, _) {
          final rows = [
            if (on == false)
              AppRow(
                leading: const IconAvatar(Icons.notifications_off_outlined, warn: true),
                title: s.notifOffTitle,
                meta: s.notifOffSub,
                trailing: TextButton(onPressed: () => askNotifications(context), child: Text(s.allow)),
                onTap: () => askNotifications(context),
              ),
            if (needBackup)
              AppRow(
                leading: const IconAvatar(Icons.save_alt_outlined, warn: true),
                title: lastBackup == null ? s.noBackupTitle : s.oldBackupTitle(s.ago(lastBackup)),
                meta: lastBackup == null ? s.noBackupSub : s.oldBackupSub,
                trailing: TextButton(onPressed: () => go(const BackupScreen()), child: Text(s.backUp)),
                onTap: () => go(const BackupScreen()),
              ),
          ];
          return rows.isEmpty ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top: 12), child: CardList(rows));
        },
      );

      final lead = KText.subtitle.copyWith(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400, color: k.label);
      final children = <Widget>[header];
      if (!calm) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Text.rich(
            TextSpan(children: [
              for (final (part, st) in s.todaySummary(over.length, soon.length, w.assets.length))
                TextSpan(text: part, style: st == null ? null : TextStyle(color: statusColors(context, st).$2, fontWeight: FontWeight.w500)),
            ]),
            style: lead,
          ),
        ));
        children.add(notices);
        if (over.isNotEmpty) {
          children.addAll([SectionTitle(s.needsAction, count: over.length), CardList([for (final r in over) ReminderTile(r, w, onTap: () => open(r))])]);
        }
        if (soon.isNotEmpty) {
          children.addAll([SectionTitle(s.next30, count: soon.length), CardList([for (final r in soon) ReminderTile(r, w, onTap: () => open(r))])]);
        }
        if (stale.isNotEmpty) children.addAll([SectionTitle(s.odoReadings), CardList([for (final a in stale) odoRow(a)])]);
      } else {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: k.tonal, shape: BoxShape.circle),
              child: Icon(live.isEmpty ? Icons.notifications_none : Icons.check, color: k.onTonal),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(live.isEmpty ? s.noRemindersCalm : s.allClear, style: KText.subtitle.copyWith(color: k.text)),
                const SizedBox(height: 2),
                Text(live.isEmpty ? s.noRemindersCalmBody : s.allClearBody, style: lead),
              ]),
            ),
          ]),
        ));
        children.add(notices);
        if (stale.isNotEmpty) children.addAll([SectionTitle(s.doNow), CardList([for (final a in stale) odoRow(a)])]);
        if (later.isNotEmpty) children.addAll([SectionTitle(s.comingUp), CardList([for (final r in later.take(3)) ReminderTile(r, w, onTap: () => open(r))])]);
      }
      if (completed.isNotEmpty) {
        children.addAll([
          SectionTitle(s.recentlyDone),
          CardList([
            for (final r in completed.take(5))
              AppRow(
                leading: const IconAvatar(Icons.check_circle_outline),
                title: r.title,
                meta: '${w.asset(r.assetId)?.nickname ?? ''} · ${s.doneAgo(s.ago(r.lastCompleted!))}',
              ),
          ]),
        ]);
      }
      if (live.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => go(const AllRemindersScreen()), child: Text(s.allReminders(live.length))),
          ),
        ));
      }
      if (lastBackup != null && !needBackup) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Text(s.lastBackupAt('${s.dShort(lastBackup)}, ${s.hm(lastBackup.hour, lastBackup.minute)}'), style: KText.meta.copyWith(color: k.textMuted)),
        ));
      }

      return Scaffold(
        floatingActionButton: const AddButton(),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, KSpace.fabClearance), children: children),
        ),
      );
    });
  }
}

/// Asks for the notification permission and refreshes the shared state.
Future<void> askNotifications(BuildContext context) async {
  final s = context.s;
  final app = context.app;
  final ok = await Notifier.request();
  final on = await Notifier.enabled();
  app.notif.value = on;
  await app.rebuildNow();
  if (!context.mounted) return;
  if (!ok && !on) {
    snack(context, s.notifDeniedHelp);
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }
}
