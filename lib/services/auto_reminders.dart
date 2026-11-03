import 'package:drift/drift.dart' show Value;

import '../data/db.dart';
import '../domain/auto_sync.dart';
import '../l10n/strings.dart';

/// One planned change to the reminder linked to a date field.
class AutoChange {
  const AutoChange(this.source, this.plan, this.existing);
  final String source;
  final AutoPlan plan;
  final Reminder? existing;
}

Reminder? linkedReminder(Iterable<Reminder> reminders, int assetId, String source) =>
    reminders.where((r) => r.assetId == assetId && r.autoSource == source).firstOrNull;

LinkedState? linkedState(Reminder? r) => r == null ? null : LinkedState(due: r.dueDate, done: r.done, snoozedUntil: r.snoozedUntil);

AutoChange planChange(Iterable<Reminder> reminders, int assetId, String source,
    {required DateTime? oldDate, required DateTime? newDate, required DateTime today}) {
  final r = linkedReminder(reminders, assetId, source);
  return AutoChange(source, planAuto(oldDate: oldDate, newDate: newDate, existing: linkedState(r), today: today), r);
}

String autoTitle(Str s, String source) => switch (source) {
      autoRoadTax => s.presetTitle('roadTax'),
      autoInsurance => s.presetTitle('vehicleInsurance'),
      _ => s.dlpReminderTitle,
    };

String _category(String source) => switch (source) {
      autoRoadTax => 'road_tax',
      autoInsurance => 'insurance_premium',
      _ => 'dlp',
    };

int _lead(String source) => switch (source) {
      autoRoadTax => 14,
      _ => 30,
    };

/// Applies the plans and returns one message per change for the user.
/// With [overwriteManual] false, plans that would reopen a completed reminder or
/// clear a snooze are skipped and reported as kept.
Future<List<String>> applyAuto(AppDb db, Str s, int assetId, List<AutoChange> changes, {bool overwriteManual = true}) async {
  final msgs = <String>[];
  for (final c in changes) {
    final p = c.plan;
    final title = c.existing?.title ?? autoTitle(s, c.source);
    switch (p.kind) {
      case AutoKind.none:
        break;
      case AutoKind.create:
        final dlp = c.source == autoDlp;
        await db.addReminder(RemindersCompanion(
          assetId: Value(assetId),
          title: Value(title),
          category: Value(_category(c.source)),
          ruleType: const Value('fixed'),
          dueDate: Value(p.due),
          leadDays: Value(_lead(c.source)),
          source: const Value('auto'),
          estimated: Value(dlp),
          note: Value(dlp ? s.dlpAutoNote : null),
          confirmWith: Value(dlp ? s.yourSpa : null),
          autoSource: Value(c.source),
        ));
        msgs.add(s.autoCreated(title, s.dLong(p.due!)));
      case AutoKind.update:
        if (p.needsConfirm && !overwriteManual) {
          msgs.add(s.autoKept(title));
          break;
        }
        await db.updateReminder(
          c.existing!.id,
          RemindersCompanion(dueDate: Value(p.due), done: const Value(false), snoozedUntil: const Value(null)),
        );
        msgs.add(s.autoUpdated(title, s.dLong(p.due!)));
      case AutoKind.delete:
        await db.deleteReminder(c.existing!.id);
        msgs.add(s.autoRemoved(title));
    }
  }
  return msgs;
}

/// Saves an asset's fields ([saveFields]) and the changes to their linked reminders in one
/// transaction, so a failure never leaves a date saved without its reminder following it.
Future<List<String>> saveFieldsWithAuto(AppDb db, Str s, int assetId, List<AutoChange> changes,
        {required bool overwriteManual, required Future<void> Function() saveFields}) =>
    db.transaction(() async {
      await saveFields();
      return applyAuto(db, s, assetId, changes, overwriteManual: overwriteManual);
    });

// ---------------------------------------------------------------- warranty

/// The reminder that follows a record's warranty end date, linked by
/// Records.warrantyReminderId. Uses the same rules as road tax and insurance (planAuto).
AutoChange planWarranty(Iterable<Reminder> reminders,
    {required int? reminderId, required DateTime? oldDate, required DateTime? newDate, required DateTime today}) {
  final r = reminderId == null ? null : reminders.where((x) => x.id == reminderId).firstOrNull;
  return AutoChange('warranty', planAuto(oldDate: oldDate, newDate: newDate, existing: linkedState(r), today: today), r);
}

/// Applies a [planWarranty] change for a record titled [recordTitle] and returns the
/// reminder id to store on the record (null when there is none). Adds a message to [msgs].
Future<int?> applyWarranty(AppDb db, Str s, AutoChange c,
    {required int assetId, required String recordTitle, required bool overwriteManual, required List<String> msgs}) async {
  final p = c.plan;
  final existing = c.existing;
  final title = s.warrantyEnds(recordTitle);
  switch (p.kind) {
    case AutoKind.none:
      // The reminder's title follows the record's even when the date stays the same.
      if (existing != null && existing.title != title) {
        await db.updateReminder(existing.id, RemindersCompanion(title: Value(title)));
      }
      return existing?.id;
    case AutoKind.create:
      final id = await db.addReminder(RemindersCompanion(
        assetId: Value(assetId),
        title: Value(title),
        ruleType: const Value('fixed'),
        dueDate: Value(p.due),
        leadDays: const Value(30),
      ));
      msgs.add(s.warrantyReminderAdded);
      return id;
    case AutoKind.update:
      if (p.needsConfirm && !overwriteManual) {
        msgs.add(s.autoKept(existing!.title));
        return existing.id;
      }
      await db.updateReminder(
        existing!.id,
        RemindersCompanion(title: Value(title), dueDate: Value(p.due), done: const Value(false), snoozedUntil: const Value(null)),
      );
      msgs.add(s.autoUpdated(title, s.dLong(p.due!)));
      return existing.id;
    case AutoKind.delete:
      await db.deleteReminder(existing!.id);
      msgs.add(s.autoRemoved(existing.title));
      return null;
  }
}
