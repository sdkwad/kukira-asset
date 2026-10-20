import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/db.dart';
import '../domain/rules.dart';
import '../l10n/strings.dart';

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
    } catch (_) {
      return false;
    }
  }

  static Future<bool> request() async {
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
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

  /// Cancels everything and schedules the next (at most) 50 notifications from the database.
  static Future<RebuildInfo> rebuild(World w, Str s) async {
    final now = DateTime.now();
    final live = w.reminders.where((r) => !r.done).toList();
    final plan = planNotes(live.map((r) => r.info).toList(), now: now, hour: w.notifyHour, minute: w.notifyMinute, limit: 49);
    try {
      await plugin.cancelAll();
    } catch (_) {}
    final details = _details(s);
    var id = 0;
    for (final n in plan) {
      final r = live[n.index];
      final name = w.asset(r.assetId)?.nickname ?? '';
      final body = switch (n.kind) {
        'lead' => s.noteLead(name, s.dShort(r.dueDate!)),
        'due' => s.noteDue(name),
        'overdue' => s.noteOverdue(name),
        _ => s.noteSnooze(name),
      };
      await _schedule(id++, r.title, body, n.at, details);
    }
    // Backup nudge 30 days after the last backup (or after the first asset was added).
    var scheduled = plan.length;
    if (w.assets.isNotEmpty) {
      final base = w.lastBackup ?? w.assets.first.createdAt;
      final d = base.add(const Duration(days: 30));
      final at = DateTime(d.year, d.month, d.day, w.notifyHour, w.notifyMinute);
      if (at.isAfter(now)) {
        await _schedule(_backupId, s.backupNudgeTitle, s.backupNudgeBody, at, details);
        scheduled++;
      }
    }
    return RebuildInfo(
      at: now,
      count: scheduled,
      nextAt: plan.isEmpty ? null : plan.first.at,
      nextTitle: plan.isEmpty ? null : live[plan.first.index].title,
    );
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
    } catch (_) {
      // A failed schedule must never break the app. Today still shows the reminder.
    }
  }

  static Future<void> test(Str s) => plugin.show(_testId, s.testNoteTitle, s.testNoteBody, _details(s));

  static Future<void> mileage(Str s, String title, String body) => plugin.show(_mileageId, title, body, _details(s));
}
