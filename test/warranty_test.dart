import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/auto_sync.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/auto_reminders.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  final today = DateTime(2026, 11, 2);
  final may = DateTime(2027, 5, 1);
  final june = DateTime(2027, 6, 1);

  late AppDb db;
  late int house;
  setUp(() async {
    db = AppDb(NativeDatabase.memory());
    house = await db.createAsset(category: 'house', nickname: 'Setia Alam house', propertyType: 'landed');
  });
  tearDown(() => db.close());

  /// Saves the warranty part of a record the way the record form does, and returns the link.
  Future<int?> save({required int? link, required DateTime? oldDate, required DateTime? newDate, String title = 'Aircond servicing', bool overwrite = true}) async {
    final c = planWarranty(await db.select(db.reminders).get(), reminderId: link, oldDate: oldDate, newDate: newDate, today: today);
    return applyWarranty(db, s, c, assetId: house, recordTitle: title, overwriteManual: overwrite, msgs: []);
  }

  Future<List<Reminder>> reminders() => db.select(db.reminders).get();

  test('setting, changing and clearing the warranty date keeps one linked reminder', () async {
    final id = await save(link: null, oldDate: null, newDate: may);
    expect((await reminders()).single.dueDate, may);
    expect((await reminders()).single.title, s.warrantyEnds('Aircond servicing'));

    // Before 0.2.3 this edit left the reminder at the old date.
    expect(await save(link: id, oldDate: may, newDate: june), id);
    expect((await reminders()).single.dueDate, june);

    // Saving again with the same date never makes a second one.
    expect(await save(link: id, oldDate: june, newDate: june), id);
    expect(await reminders(), hasLength(1));

    expect(await save(link: id, oldDate: june, newDate: null), isNull);
    expect(await reminders(), isEmpty);
  });

  test('renaming the record renames its warranty reminder', () async {
    final id = await save(link: null, oldDate: null, newDate: may);
    await save(link: id, oldDate: may, newDate: may, title: 'Aircond full service');
    expect((await reminders()).single.title, s.warrantyEnds('Aircond full service'));
  });

  test('a completed warranty reminder is only reopened when the user agrees', () async {
    final id = await save(link: null, oldDate: null, newDate: may);
    await db.updateReminder(id!, const RemindersCompanion(done: Value(true)));

    final c = planWarranty(await reminders(), reminderId: id, oldDate: may, newDate: june, today: today);
    expect(c.plan.needsConfirm, isTrue);

    await save(link: id, oldDate: may, newDate: june, overwrite: false);
    expect((await reminders()).single.done, isTrue);
    expect((await reminders()).single.dueDate, may);

    await save(link: id, oldDate: may, newDate: june, overwrite: true);
    expect((await reminders()).single.done, isFalse);
    expect((await reminders()).single.dueDate, june);
  });

  test('a warranty reminder the user deleted does not come back, and the record forgets it', () async {
    final id = await save(link: null, oldDate: null, newDate: may);
    final rec = await db.addRecord(RecordsCompanion.insert(
      assetId: house,
      kind: 'maintenance',
      title: 'Aircond servicing',
      date: DateTime(2026, 11, 1),
      warrantyEnd: Value(may),
      warrantyReminderId: Value(id),
    ));
    await db.deleteReminder(id!);
    final link = (await (db.select(db.records)..where((t) => t.id.equals(rec))).getSingle()).warrantyReminderId;
    expect(link, isNull, reason: 'the foreign key clears the link');

    expect(await save(link: link, oldDate: may, newDate: may), isNull);
    expect(await reminders(), isEmpty);
    expect(planWarranty(const [], reminderId: null, oldDate: may, newDate: may, today: today).plan.kind, AutoKind.none);
  });
}
