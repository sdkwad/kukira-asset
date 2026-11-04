// Large backups (0.2.8 build 16): format 3 is written and read a chunk at a time, every
// chunk sealed on its own, so neither making nor restoring a backup needs it all in memory,
// and no part of a backup is used before its seal is checked.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/services/backup.dart';
import 'package:kukira_asset/services/files.dart';

import 'helpers.dart';

const pass = 'correct horse battery';
const chunk = 4096;

Uint8List noise(int n, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

/// The body of a backup with one car and the given documents.
Map<String, dynamic> body(Map<String, String> docs, {int schema = AppDb.latestSchema}) => {
      'created': DateTime(2026, 11, 5).toIso8601String(),
      'schema': schema,
      'tables': {
        'assets': [
          {'id': 1, 'nickname': 'Myvi', 'category': 'car', 'createdAt': 0, 'updatedAt': 0},
        ],
        'documents': [
          for (final (i, e) in docs.entries.indexed)
            {'id': i + 1, 'assetId': 1, 'filePath': e.value, 'title': e.key, 'docType': 'other', 'addedAt': 0},
        ],
      },
    };

/// Where the chunks start in a format 3 file: after the magic and the header line.
int chunksStart(Uint8List file) => file.indexOf(10, 8) + 1;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  late Directory storage;
  setUp(() async {
    storage = await useTempStorage();
    SecureFiles.reset();
  });

  Future<Map<String, Uint8List>> filesOf(BackupContents c) async {
    final got = <String, Uint8List>{};
    await c.eachFile((name, bytes) async => got[name] = bytes);
    return got;
  }

  test('a phone backup is written in chunks and restores every record and file across chunk edges', () async {
    final a = AppDb(NativeDatabase.memory());
    final car = await a.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
    final wanted = {'Geran': noise(10000, 1), 'Polisi': noise(5000, 2), 'Resit': noise(4096, 3)};
    for (final e in wanted.entries) {
      final name = await SecureFiles.save(a, e.value, 'pdf');
      await a.addDocument(DocumentsCompanion.insert(assetId: car, filePath: name, title: e.key, docType: 'other'));
    }
    SecureFiles.reset();

    final made = await Backup.create(a, pass, chunk: chunk);
    expect(made.file.path, contains(SecureFiles.outgoingFolder));
    final raw = made.file.readAsBytesSync();
    expect(utf8.decode(raw.sublist(0, 8)), 'KUKIRA3\n');
    expect(raw.length - chunksStart(raw), greaterThan(4 * (chunk + 16)), reason: 'several chunks');
    for (final d in await a.select(a.documents).get()) {
      expect(SecureFiles.cached(d.filePath), isNull, reason: 'a backup does not fill the picture cache');
    }

    final c = await Backup.openFile(made.file, pass);
    expect(c.count('documents'), 3);
    expect(c.files, isEmpty, reason: 'documents are read when restoring, not when opening');
    final b = AppDb(NativeDatabase.memory());
    await Backup.restore(b, c);
    expect(await b.exportTables(), await a.exportTables());
    for (final d in await b.select(b.documents).get()) {
      expect(await SecureFiles.read(b, d.filePath), wanted[d.title], reason: d.title);
    }

    await made.discard();
    expect(made.file.existsSync(), isFalse);
    await a.close();
    await b.close();
  });

  test('a backup that ends exactly on a chunk edge, or a byte either side, reads back whole', () async {
    final docs = {'Geran': '0123456789abcdef0123456789abcdef.pdf'};
    final json = gzip.encode(utf8.encode(jsonEncode(body(docs))));
    final fixed = 4 + json.length + 2 + utf8.encode(docs.values.single).length + 4;
    for (final k in [1, 2]) {
      for (final d in [-1, 0, 1]) {
        final size = k * chunk - fixed + d;
        final bytes = noise(size, size);
        final f = await Backup.pack3(body(docs), {docs.values.single: bytes}, pass, chunk: chunk);
        final c = await Backup.openFile(f, pass);
        final got = await filesOf(c);
        expect(got[docs.values.single], bytes, reason: '$k chunks ${d >= 0 ? '+' : ''}$d');
      }
    }
  });

  test('a wrong passphrase is told before any chunk is read', () async {
    final f = await Backup.pack3(body({}), const {}, pass, chunk: chunk);
    // Even with every chunk damaged, the passphrase is what is wrong.
    final raw = f.readAsBytesSync();
    for (var i = chunksStart(raw); i < raw.length; i++) {
      raw[i] ^= 0xFF;
    }
    f.writeAsBytesSync(raw);
    await expectLater(Backup.openFile(f, 'wrong passphrase'), throwsA(isA<WrongPassphrase>()));
  });

  group('a damaged or cut-short backup', () {
    late AppDb phone;
    late String kept;
    late Map<String, List<Map<String, dynamic>>> before;
    setUp(() async {
      phone = AppDb(NativeDatabase.memory());
      final car = await phone.createAsset(category: 'car', nickname: 'Saga', plate: 'BMK 772');
      kept = await SecureFiles.save(phone, Uint8List.fromList([1, 1, 1]), 'pdf');
      await phone.addDocument(DocumentsCompanion.insert(assetId: car, filePath: kept, title: 'Mine', docType: 'other'));
      before = await phone.exportTables();
    });
    tearDown(() => phone.close());

    Future<File> backup() => Backup.pack3(body({'Geran': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf'}), {'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf': noise(3 * chunk, 7)}, pass, chunk: chunk);

    Future<void> expectUnchanged() async {
      expect(await phone.exportTables(), before);
      expect(await SecureFiles.read(phone, kept), [1, 1, 1]);
      expect(Directory('${storage.path}/support/files').listSync().map((e) => e.uri.pathSegments.last), ['$kept.enc'],
          reason: 'what the damaged backup brought is gone again');
    }

    test('is refused when a chunk was changed, and the phone keeps its records', () async {
      final f = await backup();
      final raw = f.readAsBytesSync();
      raw[chunksStart(raw) + chunk + 16 + 100] ^= 0x01; // a byte in the second chunk
      f.writeAsBytesSync(raw);
      final c = await Backup.openFile(f, pass); // the records are in the first chunk
      await expectLater(Backup.restore(phone, c), throwsA(isA<DamagedBackup>()));
      await expectUnchanged();
    });

    for (final (what, cut) in [('part of the last chunk', 100), ('the whole last chunk', -1)]) {
      test('is refused when $what is missing, and the phone keeps its records', () async {
        final f = await backup();
        final raw = f.readAsBytesSync();
        final start = chunksStart(raw);
        final full = (raw.length - start) ~/ (chunk + 16);
        final end = cut > 0 ? raw.length - cut : start + full * (chunk + 16);
        expect(end, lessThan(raw.length));
        f.writeAsBytesSync(raw.sublist(0, end));
        final c = await Backup.openFile(f, pass);
        await expectLater(Backup.restore(phone, c), throwsA(isA<DamagedBackup>()));
        await expectUnchanged();
      });
    }
  });

  group('a backup someone else made', () {
    test('naming a file outside the files folder in its chunks is refused', () async {
      final f = await Backup.pack3(body({}), {'../../shared_prefs/x': Uint8List.fromList([1])}, pass, chunk: chunk);
      final c = await Backup.openFile(f, pass);
      final phone = AppDb(NativeDatabase.memory());
      await expectLater(Backup.restore(phone, c), throwsA(isA<NotABackup>()));
      expect(File('${storage.path}/shared_prefs/x.enc').existsSync(), isFalse);
      expect(File('${storage.path}/support/shared_prefs/x.enc').existsSync(), isFalse);
      await phone.close();
    });

    test('naming one in its records is refused when opened', () async {
      final f = await Backup.pack3(body({'x': '../kukira'}), const {}, pass, chunk: chunk);
      await expectLater(Backup.openFile(f, pass), throwsA(isA<NotABackup>()));
    });

    test('from a newer schema is refused', () async {
      final f = await Backup.pack3(body({}, schema: AppDb.latestSchema + 1), const {}, pass, chunk: chunk);
      await expectLater(Backup.openFile(f, pass), throwsA(isA<NewerBackup>()));
    });

    for (final (what, change) in <(String, void Function(Map<String, dynamic>))>[
      ('days of key stretching', (h) => h['iterations'] = 1 << 40),
      ('a chunk too big to hold', (h) => h['chunk'] = 1 << 30),
      ('a chunk too small', (h) => h['chunk'] = 16),
      ('a short nonce', (h) => h['nonce'] = base64Encode([1, 2, 3])),
      ('another version', (h) => h['version'] = 4),
    ]) {
      test('asking for $what is refused before any work', () async {
        final f = await Backup.pack3(body({}), const {}, pass, chunk: chunk);
        final raw = f.readAsBytesSync();
        final nl = raw.indexOf(10, 8);
        final h = jsonDecode(utf8.decode(raw.sublist(8, nl))) as Map<String, dynamic>;
        change(h);
        f.writeAsBytesSync([...raw.sublist(0, 8), ...utf8.encode(jsonEncode(h)), ...raw.sublist(nl)]);
        final watch = Stopwatch()..start();
        await expectLater(Backup.openFile(f, pass), throwsA(isA<NotABackup>()));
        expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      });
    }
  });

  test('backups waiting to be saved are cleared at start-up', () async {
    final f = await SecureFiles.outgoing('kukira-backup-2026-11-05.kukira');
    f.writeAsBytesSync([1, 2, 3]);
    // Not by the sweep while the app runs: the save dialog may still be open.
    await SecureFiles.clearTemp(olderThan: Duration.zero);
    expect(f.existsSync(), isTrue);
    await SecureFiles.clearTemp();
    expect(f.existsSync(), isFalse);
  });
}
