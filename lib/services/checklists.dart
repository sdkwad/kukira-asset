// Checklists used again and again (0.3, F7), such as before going back to the kampung.

import 'package:drift/drift.dart' show Value;

import '../data/db.dart';
import '../domain/rules.dart';
import '../l10n/strings.dart';

/// The ready-made lists: before a long drive, and before leaving the house for a while.
const checklistTemplates = ['tripCar', 'tripHouse'];

/// Makes a list titled [title] with [labels], kept with [assetId] when given.
Future<int> createChecklist(AppDb db, {required String title, int? assetId, required List<String> labels}) => db.transaction(() async {
      final id = await db.into(db.checklists).insert(ChecklistsCompanion(title: Value(title), assetId: Value(assetId)));
      for (final (i, l) in labels.indexed) {
        await db.into(db.checklistItems).insert(ChecklistItemsCompanion(checklistId: Value(id), label: Value(l), position: Value(i)));
      }
      return id;
    });

Future<void> setItemChecked(AppDb db, ChecklistItem item, bool checked) =>
    (db.update(db.checklistItems)..where((x) => x.id.equals(item.id))).write(ChecklistItemsCompanion(checked: Value(checked)));

Future<void> addChecklistItem(AppDb db, Checklist list, String label, {required int position}) =>
    db.into(db.checklistItems).insert(ChecklistItemsCompanion(checklistId: Value(list.id), label: Value(label.trim()), position: Value(position)));

Future<void> removeChecklistItem(AppDb db, ChecklistItem item) => (db.delete(db.checklistItems)..where((x) => x.id.equals(item.id))).go();

/// Clears every tick for the next trip, and remembers when the list was last used.
Future<void> restartChecklist(AppDb db, Checklist list) => db.transaction(() async {
      await (db.update(db.checklistItems)..where((x) => x.checklistId.equals(list.id))).write(const ChecklistItemsCompanion(checked: Value(false)));
      await (db.update(db.checklists)..where((x) => x.id.equals(list.id))).write(ChecklistsCompanion(lastUsed: Value(dayOnly(DateTime.now()))));
    });

Future<void> deleteChecklist(AppDb db, Checklist list) => (db.delete(db.checklists)..where((x) => x.id.equals(list.id))).go();

/// A reminder to go through the list on [on] (a trip date changes every year, so the owner
/// picks it). Kept on the list's asset, or the first asset. False when there is no asset.
Future<bool> remindChecklist(AppDb db, Str s, World w, Checklist list, DateTime on) async {
  final assetId = list.assetId ?? w.assets.firstOrNull?.id;
  if (assetId == null) return false;
  await db.addReminder(RemindersCompanion(
    assetId: Value(assetId),
    title: Value(s.checklistReminderTitle(list.title)),
    category: const Value('checklist'),
    ruleType: const Value('fixed'),
    dueDate: Value(dayOnly(on)),
    leadDays: const Value(1),
  ));
  return true;
}
