// The second pass of the 0.2.8 audit: files stored by older versions, files picked without
// an extension, documents that cannot be opened, and where a backup really went.

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/backup.dart';
import 'package:kukira_asset/services/files.dart';
import 'package:kukira_asset/ui/documents.dart';
import 'package:kukira_asset/ui/more.dart';

import 'helpers.dart';

const pass = 'correct horse battery';

/// A name as 0.2.0 to 0.2.7 made it for a file picked without an extension: the file picker
/// gave the whole name ("Geran kenderaan Myvi WXY4821") as the extension.
const oldName = '0123456789abcdef0123456789abcdef.gerankenderaanmyviwxy4821';

final pdf = Uint8List.fromList([...'%PDF-1.7\n'.codeUnits, 1, 2, 3]);
final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 16]);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('files stored by older versions', () {
    setUp(() async {
      await useTempStorage();
      SecureFiles.reset();
    });

    test('a long made-up extension is still a name the app made, and its file opens', () async {
      expect(SecureFiles.isSafeName(oldName), isTrue);
      final db = AppDb(NativeDatabase.memory());
      await SecureFiles.saveNamed(db, oldName, pdf);
      SecureFiles.reset();
      expect(await SecureFiles.read(db, oldName), pdf);
      await db.close();
    });

    test('a backup that holds one still restores', () async {
      final body = {
        'created': DateTime(2026, 10, 30).toIso8601String(),
        'schema': 4,
        'tables': {
          'assets': [
            {'id': 1, 'nickname': 'Myvi', 'category': 'car', 'createdAt': 0, 'updatedAt': 0},
          ],
          'documents': [
            {'id': 1, 'assetId': 1, 'filePath': oldName, 'title': 'Geran', 'docType': 'geran', 'addedAt': 0},
          ],
        },
      };
      final c = await Backup.open(await Backup.pack(body, {oldName: pdf}, pass), pass);
      expect(c.files.keys, [oldName]);
    });

    test('names that point elsewhere are still refused', () {
      for (final bad in ['../kukira.db', 'a/b.pdf', r'a\b.pdf', '..', '.hidden', 'x..pdf', 'a.b.c', 'name with space.pdf', '${'a' * 32}.${'b' * 230}']) {
        expect(SecureFiles.isSafeName(bad), isFalse, reason: bad);
      }
    });

    test('the copy for a viewer gets the extension the viewer goes by, and a long title fits', () async {
      final db = AppDb(NativeDatabase.memory());
      await SecureFiles.saveNamed(db, oldName, pdf);
      final f = await SecureFiles.viewCopy(db, oldName, 'Geran kenderaan ${'sangat panjang ' * 30}');
      final base = f.uri.pathSegments.last;
      expect(base, endsWith('.pdf'));
      expect(base.length, lessThanOrEqualTo(64));
      expect(await f.readAsBytes(), pdf);
      await SecureFiles.clearTemp();
      await db.close();
    });
  });

  group('plain copies in the cache', () {
    test('the copies the pickers leave are removed, and nothing else', () async {
      final root = await useTempStorage();
      final tmp = '${root.path}/tmp';
      File mk(String rel) => File('$tmp/$rel')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);
      const uuid = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';
      final picked = [
        mk('file_picker/1730790000000/Geran kenderaan.pdf'),
        mk('scaled_IMG_2041.jpg'),
        mk('$uuid/IMG_2041.jpg'),
        mk('${uuid}8812736451.jpg'),
      ];
      final kept = [mk('view/Policy.pdf'), mk('notes.txt'), mk('flutter_engine/x')];

      await SecureFiles.clearPickerCopies();
      for (final f in picked) {
        expect(f.existsSync(), isFalse, reason: f.path);
      }
      expect(Directory('$tmp/file_picker').existsSync(), isFalse);
      expect(Directory('$tmp/$uuid').existsSync(), isFalse);
      for (final f in kept) {
        expect(f.existsSync(), isTrue, reason: f.path);
      }
    });

    test('a document handed to the share sheet is cleared like a viewer copy', () async {
      final root = await useTempStorage();
      final shared = Directory('${root.path}/tmp/share_plus')..createSync(recursive: true);
      final old = File('${shared.path}/Geran.pdf')..writeAsBytesSync([1]);
      old.setLastModifiedSync(DateTime.now().subtract(SecureFiles.tempLifetime + const Duration(minutes: 1)));
      final fresh = File('${shared.path}/Policy.pdf')..writeAsBytesSync([2]);

      await SecureFiles.clearTemp(olderThan: SecureFiles.tempLifetime);
      expect(old.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue, reason: 'the app it went to may still be reading it');

      await SecureFiles.clearTemp();
      expect(shared.existsSync(), isFalse);
    });
  });

  group('a file picked without an extension', () {
    setUp(() async {
      await useTempStorage();
      SecureFiles.reset();
    });

    test('is saved with the type its bytes show, or "bin"', () async {
      final db = AppDb(NativeDatabase.memory());
      final asPdf = await SecureFiles.save(db, pdf, 'Geran kenderaan Myvi WXY4821');
      expect(asPdf, endsWith('.pdf'));
      final unknown = await SecureFiles.save(db, Uint8List.fromList([1, 2, 3]), 'Geran kenderaan Myvi WXY4821');
      expect(unknown, endsWith('.bin'));
      for (final n in [asPdf, unknown]) {
        expect(SecureFiles.isSafeName(n), isTrue, reason: n);
      }
      // A known or short extension is kept as it came.
      expect(await SecureFiles.save(db, jpeg, 'jpeg'), endsWith('.jpeg'));
      expect(await SecureFiles.save(db, Uint8List.fromList([1]), 'docx'), endsWith('.docx'));
      await db.close();
    });

    test('the kinds of file Kukira takes in are told by their first bytes', () {
      Uint8List b(List<int> head) => Uint8List.fromList([...head, 0, 0, 0, 0, 0, 0, 0, 0]);
      expect(SecureFiles.sniff(pdf), 'pdf');
      expect(SecureFiles.sniff(jpeg), 'jpg');
      expect(SecureFiles.sniff(b([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])), 'png');
      expect(SecureFiles.sniff(b([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits])), 'webp');
      expect(SecureFiles.sniff(b('GIF89a'.codeUnits)), 'gif');
      expect(SecureFiles.sniff(b([0, 0, 0, 24, ...'ftypheic'.codeUnits])), 'heic');
      expect(SecureFiles.sniff(b([1, 2, 3])), isNull);
      expect(SecureFiles.sniff(Uint8List(0)), isNull);
      expect(SecureFiles.extFor('PDF', Uint8List(0)), 'pdf');
      expect(SecureFiles.extFor('', pdf), 'pdf');
    });
  });

  // Here the stored name is one that is refused; a missing or damaged file fails the same way.
  testWidgets('a document that cannot be opened or shared says so', (tester) async {
    final s = strFor('en');
    setPhone(tester, height: 1000);
    final w = fakeWorld();
    final world = World(
      assets: w.assets,
      houses: w.houses,
      vehicles: w.vehicles,
      reminders: w.reminders,
      records: w.records,
      odometer: w.odometer,
      vendors: w.vendors,
      documents: [AssetDocument(id: 1, assetId: 2, filePath: '../outside.pdf', title: 'Policy', docType: 'insurance', addedAt: DateTime(2026, 10, 1))],
      settings: w.settings,
      costItems: w.costItems,
    );
    await tester.pumpWidget(harness(
      // A Scaffold, so the message has somewhere to show.
      Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => showDocSheet(c, 1), child: const Text('show')))),
      world,
    ));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.open));
    await tester.pumpAndSettle();
    expect(find.text(s.fileNotOpened), findsOneWidget, reason: 'before, nothing happened at all');
    expect(find.text(s.open), findsNothing, reason: 'the sheet closes, so the message is not hidden behind it');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text(s.fileNotOpened), findsNothing);

    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.shareCopy));
    await tester.pumpAndSettle();
    expect(find.text(s.fileNotOpened), findsOneWidget);
    expect(find.text(s.shareCopy), findsNothing);
  });

  group('where a backup really went', () {
    test('is told from the place that took the file, not from the choice in Kukira', () {
      expect(Backup.placeOf('com.android.externalstorage.documents'), 'folder');
      expect(Backup.placeOf('com.android.providers.downloads.documents'), 'folder');
      expect(Backup.placeOf('com.google.android.apps.docs.storage'), 'cloud');
      expect(Backup.placeOf('com.microsoft.skydrive.content.StorageAccessProvider'), 'cloud');
      expect(Backup.placeOf('com.dropbox.product.android.dbapp.document_provider.documents'), 'cloud');
      expect(Backup.placeOf('com.example.filemanager.documents'), 'other', reason: 'nothing is claimed about an app it does not know');
    });

    testWidgets('the save dialog gets the file and answers where it went', (tester) async {
      final calls = <MethodCall>[];
      String? answer = 'com.google.android.apps.docs.storage';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(Backup.saveChannel, (c) async {
        calls.add(c);
        return answer;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(Backup.saveChannel, null));

      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(await Backup.saveWithDialog(bytes, 'kukira-backup-2026-11-05.kukira'), 'cloud');
      expect(calls.single.method, 'createDocument');
      expect(calls.single.arguments, {'name': 'kukira-backup-2026-11-05.kukira', 'bytes': bytes});

      answer = 'com.android.providers.downloads.documents';
      expect(await Backup.saveWithDialog(bytes, 'b.kukira'), 'folder');
      answer = null;
      expect(await Backup.saveWithDialog(bytes, 'c.kukira'), isNull, reason: 'backed out');
    });

    test('picking the cloud and saving on the phone is pointed out', () {
      final s = strFor('en');
      const name = 'kukira-backup-2026-11-05.kukira';
      expect(backupSavedMessage(s, name, missing: 0, wanted: 'cloud', place: 'folder'), s.backupOnPhoneNotCloud(name));
      expect(backupSavedMessage(s, name, missing: 0, wanted: 'cloud', place: 'cloud'), s.backupSaved(name));
      expect(backupSavedMessage(s, name, missing: 0, wanted: 'folder', place: 'folder'), s.backupSaved(name));
      expect(backupSavedMessage(s, name, missing: 2, wanted: 'cloud', place: 'folder'), s.backupSavedMissing(name, 2));
    });

    testWidgets('the backup page follows where the file went', (tester) async {
      final s = strFor('en');
      setPhone(tester, height: 1600);
      final when = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
      World at(String place) {
        final w = fakeWorld();
        return World(
          assets: w.assets,
          houses: w.houses,
          vehicles: w.vehicles,
          reminders: w.reminders,
          records: w.records,
          odometer: w.odometer,
          vendors: w.vendors,
          documents: w.documents,
          settings: {'lastBackup': when, 'lastBackupTo': place},
          costItems: w.costItems,
        );
      }

      // Somewhere Kukira does not know: neither "in the cloud" nor "only on this phone".
      await tester.pumpWidget(harness(const BackupScreen(), at('other')));
      await tester.pumpAndSettle();
      expect(find.textContaining(s.backupInCloud), findsNothing);
      expect(find.text(s.backupOnlyOnPhone), findsNothing);
    });
  });
}
