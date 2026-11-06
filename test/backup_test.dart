import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/services/backup.dart';
import 'package:kukira_asset/services/files.dart';

import 'helpers.dart';

const pass = 'correct horse battery';

/// A car with an unlinked road tax reminder, a record with a cost breakdown and a vendor.
Future<AppDb> sampleDb({String? autoSource}) async {
  final db = AppDb(NativeDatabase.memory());
  final car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
  await db.addReminder(RemindersCompanion.insert(
    assetId: car,
    title: 'Road tax renewal',
    ruleType: 'fixed',
    category: const Value('road_tax'),
    dueDate: Value(DateTime(2026, 11, 3)),
    autoSource: Value(autoSource),
  ));
  final v = await db.addVendor(VendorsCompanion.insert(name: 'Bengkel Ah Seng', phone: const Value('012-3456789')));
  final rec = await db.addRecord(RecordsCompanion.insert(
    assetId: car,
    kind: 'maintenance',
    title: 'Service 40,000 km',
    date: DateTime(2026, 9, 14),
    cost: const Value(180.5),
    vendorId: Value(v),
  ));
  await db.setCostItems(rec, [('Oil', 120.0), ('Filter', 60.5)]);
  return db;
}

Future<List<Reminder>> linked(AppDb db, String source) =>
    (db.select(db.reminders)..where((t) => t.autoSource.equals(source))).get();

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  late Directory storage;
  setUp(() async {
    storage = await useTempStorage();
    SecureFiles.reset();
  });

  /// File names currently in the encrypted files folder.
  List<String> stored() {
    final d = Directory('${storage.path}/support/files');
    return d.existsSync() ? (d.listSync().map((e) => e.uri.pathSegments.last).toList()..sort()) : [];
  }

  Future<String> attach(AppDb db, String title, List<int> bytes) async {
    final car = (await db.select(db.assets).get()).first.id;
    final name = await SecureFiles.save(db, Uint8List.fromList(bytes), 'pdf');
    await db.addDocument(DocumentsCompanion.insert(assetId: car, filePath: name, title: title, docType: 'other'));
    return name;
  }

  group('restore on a phone that already has data', () {
    test('brings back the backup files and removes files nothing uses any more', () async {
      final phone = await sampleDb();
      final geran = await attach(phone, 'Geran', [1, 1, 1]);
      final backup = await Backup.openFile((await Backup.create(phone, pass)).file, pass);

      // After the backup: a new document, and a leftover from an interrupted write.
      final later = await attach(phone, 'Later receipt', [2, 2, 2]);
      File('${storage.path}/support/files/stale.pdf.enc.tmp').writeAsBytesSync([9]);

      await Backup.restore(phone, backup);

      expect((await phone.select(phone.documents).get()).map((d) => d.title), ['Geran']);
      expect(await SecureFiles.read(phone, geran), [1, 1, 1]);
      expect(stored(), ['$geran.enc']);
      expect(stored().contains('$later.enc'), isFalse);
      await phone.close();
    });

    test('a backup that cannot be applied changes nothing', () async {
      final phone = await sampleDb();
      final geran = await attach(phone, 'Geran', [1, 1, 1]);
      final before = await phone.exportTables();

      // A record without a title cannot be inserted, so the transaction fails part way.
      final broken = Map<String, dynamic>.from(before)
        ..['records'] = [
          {'id': 9, 'assetId': 1, 'kind': 'maintenance', 'date': 0},
        ];
      final body = {'created': DateTime(2026, 10, 1).toIso8601String(), 'schema': AppDb.latestSchema, 'tables': broken};
      final c = await Backup.open(await Backup.pack(body, {'incoming.pdf': Uint8List.fromList([7])}, pass), pass);

      await expectLater(Backup.restore(phone, c), throwsA(anything));

      expect(await phone.exportTables(), before);
      expect(await SecureFiles.read(phone, geran), [1, 1, 1]);
      expect(stored(), ['$geran.enc']);
      await phone.close();
    });
  });

  test('format 3: a backup restores to exactly the same records', () async {
    final a = await sampleDb(autoSource: 'roadTax');
    final file = await Backup.create(a, pass);
    expect(file.missing, 0);

    final c = await Backup.openFile(file.file, pass);
    expect(c.schema, AppDb.latestSchema);
    expect(c.count('assets'), 1);
    expect(c.count('costItems'), 2);

    final b = AppDb(NativeDatabase.memory());
    await Backup.restore(b, c);
    expect(await b.exportTables(), await a.exportTables());
    await a.close();
    await b.close();
  });

  test('format 2 (0.2.0 to 0.2.8 build 15): a backup still restores to exactly the same records', () async {
    final a = await sampleDb(autoSource: 'roadTax');
    final body = {'created': DateTime(2026, 10, 30).toIso8601String(), 'schema': AppDb.latestSchema, 'tables': await a.exportTables()};
    final f = File('${storage.path}/old.kukira')..writeAsBytesSync(await Backup.pack(body, {'abc.pdf': Uint8List.fromList([4, 5])}, pass));

    final c = await Backup.openFile(f, pass);
    expect(c.files.keys, ['abc.pdf']);
    final b = AppDb(NativeDatabase.memory());
    await Backup.restore(b, c);
    expect(await b.exportTables(), await a.exportTables());
    await a.close();
    await b.close();
  });

  test('a wrong passphrase opens nothing', () async {
    final a = await sampleDb();
    final file = await Backup.create(a, pass);
    await expectLater(Backup.openFile(file.file, 'wrong passphrase'), throwsA(isA<WrongPassphrase>()));
    await expectLater(Backup.open(Uint8List.fromList(utf8.encode('hello')), pass), throwsA(isA<NotABackup>()));
    final hello = File('${storage.path}/hello.kukira')..writeAsStringSync('hello');
    await expectLater(Backup.openFile(hello, pass), throwsA(isA<NotABackup>()));
    await a.close();
  });

  test('a backup from a newer schema is refused, not half-restored', () async {
    final a = await sampleDb();
    final body = {'created': DateTime(2027).toIso8601String(), 'schema': AppDb.latestSchema + 1, 'tables': await a.exportTables()};
    final bytes = await Backup.pack(body, const {}, pass);
    await expectLater(Backup.open(bytes, pass), throwsA(isA<NewerBackup>()));
    await a.close();
  });

  test('restoring a 0.2 backup (no schema) links road tax and insurance reminders once', () async {
    final a = await sampleDb();
    final body = {'created': DateTime(2026, 10, 1).toIso8601String(), 'tables': await a.exportTables()};
    final c = await Backup.open(await Backup.pack(body, const {}, pass), pass);
    expect(c.schema, isNull);

    final b = AppDb(NativeDatabase.memory());
    await Backup.restore(b, c);
    expect((await linked(b, 'roadTax')).single.title, 'Road tax renewal');

    // Running the link again (a second restore, or an upgrade) never links a second reminder.
    await b.addReminder(RemindersCompanion.insert(
      assetId: (await b.select(b.assets).getSingle()).id,
      title: 'Road tax (spare)',
      ruleType: 'fixed',
      category: const Value('road_tax'),
    ));
    await b.linkExistingAutoReminders();
    expect((await linked(b, 'roadTax')).single.title, 'Road tax renewal');
    await a.close();
    await b.close();
  });

  test('format 1 (0.1.0) backups still restore', () async {
    final a = await sampleDb();
    final tables = await a.exportTables();
    tables.remove('costItems');
    final plain = gzip.encode(utf8.encode(jsonEncode({'created': DateTime(2026, 5, 1).toIso8601String(), 'tables': tables})));
    final salt = List<int>.generate(16, (i) => i);
    const iterations = 1000;
    final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256).deriveKeyFromPassword(password: pass, nonce: salt);
    final box = await AesGcm.with256bits().encrypt(plain, secretKey: key);
    final v1 = utf8.encode(jsonEncode({
      'format': Backup.format,
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'data': base64Encode(box.cipherText),
    }));

    final c = await Backup.open(Uint8List.fromList(v1), pass);
    final b = AppDb(NativeDatabase.memory());
    await Backup.restore(b, c);
    expect((await b.select(b.records).getSingle()).title, 'Service 40,000 km');
    expect((await linked(b, 'roadTax')), hasLength(1));
    await a.close();
    await b.close();
  });

  test('tenancies, rent, room checks and checklists (schema 6) go into a backup and come back', () async {
    final a = await sampleDb();
    final car = (await a.select(a.assets).getSingle()).id;
    final house = await a.createAsset(category: 'house', nickname: 'Rumah Setia Alam', propertyType: 'landed');
    await a.updateHouse(house, HouseProfilesCompanion(cccDate: Value(DateTime(2025, 1, 10)), septicTank: const Value(true), insidePbt: const Value(true)));
    final ten = await a.into(a.tenancies).insert(TenanciesCompanion.insert(
      assetId: house,
      tenantName: const Value('Encik Hafiz'),
      startDate: Value(DateTime(2026, 1, 1)),
      rent: const Value(1800),
      dueDay: const Value(5),
    ));
    await a.into(a.rentPayments).insert(RentPaymentsCompanion.insert(tenancyId: ten, month: 202601, paidOn: DateTime(2026, 1, 5), amount: const Value(1800)));
    final rec = await a.addRecord(RecordsCompanion.insert(assetId: house, kind: 'defect', title: 'Retak siling dapur', date: DateTime(2025, 1, 20)));
    final ins = await a.into(a.inspections).insert(InspectionsCompanion.insert(assetId: house, kind: 'vp', date: DateTime(2025, 1, 20)));
    await a.into(a.inspectionChecks).insert(InspectionChecksCompanion.insert(inspectionId: ins, room: 'Dapur', item: 'Siling', result: const Value('defect'), recordId: Value(rec)));
    final list = await a.into(a.checklists).insert(ChecklistsCompanion.insert(title: 'Balik kampung', assetId: Value(car)));
    await a.into(a.checklistItems).insert(ChecklistItemsCompanion.insert(checklistId: list, label: 'Tekanan tayar'));

    final c = await Backup.openFile((await Backup.create(a, pass)).file, pass);
    expect(c.count('tenancies'), 1);
    final b = AppDb(NativeDatabase.memory());
    await Backup.restore(b, c);
    final mine = await a.exportTables();
    final back = await b.exportTables();
    for (final t in ['tenancies', 'rentPayments', 'inspections', 'inspectionChecks', 'checklists', 'checklistItems']) {
      expect(back[t], mine[t], reason: t);
      expect(back[t], isNotEmpty, reason: t);
    }
    // House fields are kept with the house.
    final h = (await b.loadWorld()).houses[house]!;
    expect(h.cccDate, DateTime(2025, 1, 10));
    expect(h.septicTank, isTrue);
    await a.close();
    await b.close();
  });

  test('documents that cannot be read are counted, and the rest is still backed up', () async {
    final a = await sampleDb();
    final car = (await a.select(a.assets).getSingle()).id;
    final kept = await SecureFiles.save(a, Uint8List.fromList([1, 2, 3]), 'pdf');
    await a.addDocument(DocumentsCompanion.insert(assetId: car, filePath: kept, title: 'Geran', docType: 'ownership'));
    await a.addDocument(DocumentsCompanion.insert(assetId: car, filePath: 'gone.pdf', title: 'Insurance', docType: 'insurance'));

    final file = await Backup.create(a, pass);
    expect(file.missing, 1);
    final c = await Backup.openFile(file.file, pass);
    final got = <String, Uint8List>{};
    await c.eachFile((name, bytes) async => got[name] = bytes);
    expect(got.keys.toList(), [kept]);
    expect(got[kept], [1, 2, 3]);
    expect(c.count('documents'), 2);
    await a.close();
  });
}
