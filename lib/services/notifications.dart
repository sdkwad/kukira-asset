import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/db.dart';
import '../domain/rules.dart';
import '../l10n/strings.dart';
import 'error_log.dart';

class RebuildInfo {
  const RebuildInfo({required this.at, required this.count, this.nextAt, this.nextTitle});
  final DateTime at;
  final int count;
  final DateTime? nextAt;
  final String? nextTitle;
}

/// Local notifications. Best-effort only: the Today screen is the guaranteed view.
/// Uses inexact alarms (no SCHEDULE_EXACT_ALARM) delivered around 9:00 am.
class Notifier {
  static final plugin = FlutterLocalNotificationsPlugin();
  static const _testId = 9000;
  static const _mileageId = 9100;
  static const _backupId = 8000;

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
    await plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('ic_notification')));
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<bool> enabled() async {
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (e) {
      ErrorLog.record('notifications.enabled', e);
      return false;
    }
  }

  static Future<bool> request() async {
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (e) {
      ErrorLog.record('notifications.request', e);
      return false;
    }
  }

  static NotificationDetails _details(Str s) => NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          s.channelName,
          channelDescription: s.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

  /// Reminder notifications scheduled at a time; the refresh notice and the backup nudge
  /// make 50.
  static const windowSize = 48;
  static const _refreshId = 8100;
  static const _noteBase = 1000000;

  /// The notification id for slot [slot] (see PlannedNote.slot) of reminder [reminderId].
  /// The same notification keeps the same id when the schedule is rebuilt.
  static int noteId(int reminderId, int slot) => _noteBase + reminderId * 10 + slot;

  /// The reminder a notification id belongs to, or null for other notifications.
  static int? reminderOfNote(int id) => id >= _noteBase ? (id - _noteBase) ~/ 10 : null;

  /// Whether a notification already in the tray should stay there: its reminder still
  /// exists, is not done or snoozed, and is overdue or due soon.
  static bool keepShown(Reminder? r, {required DateTime today, int? odometer}) {
    if (r == null || r.done) return false;
    if (r.snoozedUntil != null && dayOnly(r.snoozedUntil!).isAfter(dayOnly(today))) return false;
    final st = statusOf(r.info, today: today, odometer: odometer);
    return st == RStatus.overdue || st == RStatus.dueSoon;
  }

  /// Schedules the next notifications from the database, then cancels scheduled ones that
  /// are no longer wanted. Notifications already in the tray stay, unless [keepShown] says
  /// their reminder has been dealt with.
  static Future<RebuildInfo> rebuild(World w, Str s) async {
    final now = DateTime.now();
    final live = w.reminders.where((r) => !r.done).toList();
    final infos = live.map((r) => r.info).toList();
    final plan = planNotes(infos, now: now, hour: w.notifyHour, minute: w.notifyMinute, limit: windowSize);
    final refreshAt = refreshNoticeAt(infos, now: now, hour: w.notifyHour, minute: w.notifyMinute, limit: windowSize);
    final details = _details(s);
    final wanted = <int>{};
    for (final n in plan) {
      final r = live[n.index];
      final name = w.asset(r.assetId)?.nickname ?? '';
      final body = switch (n.kind) {
        'lead' => s.noteLead(name, s.dShort(r.dueDate!)),
        'due' => s.noteDue(name),
        'overdue' => s.noteOverdue(name),
        _ => s.noteSnooze(name),
      };
      final id = noteId(r.id, n.slot);
      wanted.add(id);
      await _schedule(id, r.title, body, n.at, details);
    }
    var scheduled = plan.length;
    // More reminders than fit: ask to open the app the day after the last one.
    if (refreshAt != null) {
      wanted.add(_refreshId);
      await _schedule(_refreshId, s.refreshNoteTitle, s.refreshNoteBody, refreshAt, details);
      scheduled++;
    }
    // Backup nudge 30 days after the last backup (or after the first asset was added).
    var backupDue = false;
    if (w.assets.isNotEmpty) {
      final base = w.lastBackup ?? w.assets.first.createdAt;
      final d = base.add(const Duration(days: 30));
      final at = DateTime(d.year, d.month, d.day, w.notifyHour, w.notifyMinute);
      if (at.isAfter(now)) {
        wanted.add(_backupId);
        await _schedule(_backupId, s.backupNudgeTitle, s.backupNudgeBody, at, details);
        scheduled++;
      } else {
        backupDue = true;
      }
    }
    await _cancelStale(w, wanted, today: now, keepBackupNudge: backupDue);
    return RebuildInfo(
      at: now,
      count: scheduled,
      nextAt: plan.isEmpty ? null : plan.first.at,
      nextTitle: plan.isEmpty ? null : live[plan.first.index].title,
    );
  }

  static Future<void> _cancelStale(World w, Set<int> wanted, {required DateTime today, required bool keepBackupNudge}) async {
    try {
      for (final p in await plugin.pendingNotificationRequests()) {
        if (!wanted.contains(p.id) && p.id != _testId && p.id != _mileageId) await plugin.cancel(p.id);
      }
      for (final a in await plugin.getActiveNotifications()) {
        final id = a.id;
        if (id == null) continue;
        final rid = reminderOfNote(id);
        final r = rid == null ? null : w.reminders.where((x) => x.id == rid).firstOrNull;
        final drop = rid != null ? !keepShown(r, today: today, odometer: r == null ? null : w.odoOf(r.assetId)) : id == _backupId && !keepBackupNudge;
        if (drop) await plugin.cancel(id);
      }
    } catch (e) {
      ErrorLog.record('notifications.cancel', e);
    }
  }

  static Future<void> _schedule(int id, String title, String body, DateTime at, NotificationDetails d) async {
    try {
      await plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        d,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      ErrorLog.record('notifications.schedule', e);
      // A failed schedule must never break the app. Today still shows the reminder.
    }
  }

  static Future<void> test(Str s) => plugin.show(_testId, s.testNoteTitle, s.testNoteBody, _details(s));

  static Future<void> mileage(Str s, String title, String body) => plugin.show(_mileageId, title, body, _details(s));
}
