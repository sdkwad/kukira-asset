import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  setUp(() async {
    await useTempStorage();
    SecureFiles.reset();
  });

  test('format 2: a backup restores to exactly the same records', () async {
    final a = await sampleDb(autoSource: 'roadTax');
    final file = await Backup.create(a, pass);
    expect(file.missing, 0);

    final c = await Backup.open(file.bytes, pass);
    expect(c.schema, AppDb.latestSchema);
    expect(c.count('assets'), 1);
    expect(c.count('costItems'), 2);

    final b = AppDb(NativeDatabase.memory());
    await Backup.restore(b, c);
    expect(await b.exportTables(), await a.exportTables());
    await a.close();
    await b.close();
  });

  test('a wrong passphrase opens nothing', () async {
    final a = await sampleDb();
    final file = await Backup.create(a, pass);
    await expectLater(Backup.open(file.bytes, 'wrong passphrase'), throwsA(isA<WrongPassphrase>()));
    await expectLater(Backup.open(Uint8List.fromList(utf8.encode('hello')), pass), throwsA(isA<NotABackup>()));
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

  test('documents that cannot be read are counted, and the rest is still backed up', () async {
    final a = await sampleDb();
    final car = (await a.select(a.assets).getSingle()).id;
    final kept = await SecureFiles.save(a, Uint8List.fromList([1, 2, 3]), 'pdf');
    await a.addDocument(DocumentsCompanion.insert(assetId: car, filePath: kept, title: 'Geran', docType: 'ownership'));
    await a.addDocument(DocumentsCompanion.insert(assetId: car, filePath: 'gone.pdf', title: 'Insurance', docType: 'insurance'));

    final file = await Backup.create(a, pass);
    expect(file.missing, 1);
    final c = await Backup.open(file.bytes, pass);
    expect(c.files.keys.toList(), [kept]);
    expect(c.files[kept], [1, 2, 3]);
    expect(c.count('documents'), 2);
    await a.close();
  });
}
