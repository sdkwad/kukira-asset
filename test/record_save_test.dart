import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/auto_reminders.dart';
import 'package:kukira_asset/services/files.dart';
import 'package:kukira_asset/services/record_save.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  final today = DateTime(2026, 11, 3);

  late Directory root;
  late AppDb db;
  late int car;
  setUp(() async {
    root = await useTempStorage();
    SecureFiles.reset();
    db = AppDb(NativeDatabase.memory());
    car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
  });
  tearDown(() => db.close());

  AutoChange noWarranty() => planWarranty(const [], reminderId: null, oldDate: null, newDate: null, today: today);
  List<String> storedFiles() => Directory('${root.path}/support/files').existsSync()
      ? Directory('${root.path}/support/files').listSync().map((e) => e.uri.pathSegments.last).toList()
      : <String>[];

  test('a service record saves its vendor, cost breakdown, photo, odometer and marks the reminder done', () async {
    final oil = await db.addReminder(RemindersCompanion.insert(
      assetId: car,
      title: 'Engine oil',
      ruleType: 'repeat',
      category: const Value('engine_oil'),
      dueDate: Value(DateTime(2026, 11, 1)),
      repeatMonths: const Value(6),
    ));
    final w = await db.loadWorld();
    final msgs = <String>[];
    final id = await saveRecord(
      db,
      s,
      w,
      RecordInput(
        assetId: car,
        kind: 'maintenance',
        category: 'engine_oil',
        title: 'Service 50,000 km',
        date: today,
        cost: 245.5,
        costItems: const [('Oil', 180), ('Labour', 65.5)],
        vendorName: 'Bengkel Ah Seng',
        addVendor: true,
        odometer: 50120,
        photosAdded: [(Uint8List.fromList([1, 2]), 'jpg')],
        completes: w.reminders.firstWhere((r) => r.id == oil),
      ),
      warranty: noWarranty(),
      overwriteWarranty: true,
      today: today,
      msgs: msgs,
    );

    final after = await db.loadWorld();
    final rec = after.records.single;
    expect(rec.id, id);
    expect(rec.vendorId, after.vendors.single.id);
    expect(after.costItems[id]!.map((c) => c.label), ['Oil', 'Labour']);
    expect(after.odoOf(car), 50120);
    expect(after.photosOf(id), hasLength(1));
    expect(storedFiles(), hasLength(1));
    final next = after.reminders.single;
    expect(next.lastCompleted, today);
    expect(next.dueDate, DateTime(2027, 5, 3));
    expect(msgs.single, contains('Engine oil'));
  });

  test('a save that fails adds no vendor, keeps no new photo file and writes nothing', () async {
    final w = await db.loadWorld();
    await expectLater(
      saveRecord(
        db,
        s,
        w,
        RecordInput(
          assetId: 999, // no such asset: the record cannot be inserted
          kind: 'maintenance',
          title: 'Service',
          date: today,
          vendorName: 'New workshop',
          addVendor: true,
          photosAdded: [(Uint8List.fromList([1]), 'jpg')],
        ),
        warranty: noWarranty(),
        overwriteWarranty: true,
        today: today,
        msgs: [],
      ),
      throwsA(anything),
    );
    final after = await db.loadWorld();
    expect(after.records, isEmpty);
    expect(after.vendors, isEmpty);
    expect(after.documents, isEmpty);
    expect(storedFiles(), isEmpty);
  });

  test('editing a record removes the photos the user took out, after saving', () async {
    final w0 = await db.loadWorld();
    final id = await saveRecord(db, s, w0, RecordInput(assetId: car, kind: 'maintenance', title: 'Tyres', date: today, photosAdded: [(Uint8List.fromList([7]), 'jpg')]),
        warranty: noWarranty(), overwriteWarranty: true, today: today, msgs: []);
    final w1 = await db.loadWorld();
    final photo = w1.photosOf(id).single;
    await saveRecord(db, s, w1, RecordInput(assetId: car, editId: id, kind: 'maintenance', title: 'Tyres x4', date: today, photosRemoved: [photo]),
        warranty: noWarranty(), overwriteWarranty: true, today: today, msgs: []);

    final w2 = await db.loadWorld();
    expect(w2.records.single.title, 'Tyres x4');
    expect(w2.photosOf(id), isEmpty);
    expect(storedFiles(), isEmpty);
  });
}
