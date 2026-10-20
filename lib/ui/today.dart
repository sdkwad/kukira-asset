import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/rules.dart';
import '../services/notifications.dart';
import 'add_asset.dart';
import 'assets.dart';
import 'common.dart';
import 'forms.dart';
import 'more.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final t = today();
      final theme = Theme.of(context);
      final header = Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.weekdayDate(t).toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(s.today, style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );

      if (w.assets.isEmpty) {
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
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAssetScreen())),
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
      final stale = w.assets.where((a) {
        if (a.category == 'house') return false;
        final hasKm = live.any((r) => r.assetId == a.id && r.info.usesKm);
        if (!hasKm) return false;
        final o = w.odometer[a.id];
        return o == null || daysBetween(o.date, t) > 30;
      }).toList();
      final completed = w.reminders.where((r) => r.lastCompleted != null && daysBetween(r.lastCompleted!, t) <= 30).toList()
        ..sort((a, b) => b.lastCompleted!.compareTo(a.lastCompleted!));
      final lastBackup = w.lastBackup;

      return Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
            header,
            ValueListenableBuilder<bool?>(
              valueListenable: context.app.notif,
              builder: (c, on, _) => on == false
                  ? InfoBanner(
                      icon: Icons.notifications_off_outlined,
                      warn: true,
                      text: s.notifOffBanner,
                      action: s.allowNotifications,
                      onAction: () => askNotifications(context),
                    )
                  : const SizedBox.shrink(),
            ),
            if (live.isNotEmpty && (lastBackup == null || daysBetween(lastBackup, t) > 30))
              InfoBanner(
                icon: Icons.save_alt_outlined,
                text: lastBackup == null ? s.noBackupBanner : s.oldBackupBanner(s.ago(lastBackup)),
                action: s.backUpNow,
                onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
              ),
            SectionTitle(s.overdue, count: over.length),
            CardList([for (final r in over) ReminderTile(r, w, onTap: () => showReminderSheet(context, r.id))], empty: s.nothingOverdue),
            SectionTitle(s.dueSoonTitle, count: soon.length),
            CardList([
              for (final r in soon) ReminderTile(r, w, onTap: () => showReminderSheet(context, r.id)),
              for (final a in stale)
                ListTile(
                  leading: const Icon(Icons.speed_outlined),
                  title: Text(s.updateOdoTitle(a.nickname)),
                  subtitle: Text(w.odometer[a.id] == null ? s.odoNever : s.odoLastUpdated(s.ago(w.odometer[a.id]!.date))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showOdometerDialog(context, a.id),
                ),
            ], empty: s.nothingSoon),
            SectionTitle(s.recentlyDone),
            CardList([
              for (final r in completed.take(5))
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(r.title),
                  subtitle: Text('${w.asset(r.assetId)?.nickname ?? ''} · ${s.doneAgo(s.ago(r.lastCompleted!))}'),
                ),
            ], empty: s.nothingDone),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.list_alt_outlined),
                label: Text(s.allReminders(live.length)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllRemindersScreen())),
              ),
            ),
          ]),
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
  if (!ok && !on) snack(context, s.notifDeniedHelp);
}
