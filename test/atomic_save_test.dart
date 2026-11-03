import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/files.dart';
import 'package:kukira_asset/ui/forms.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('FileChanges', () {
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

    bool stored(String name) => File('${root.path}/support/files/$name.enc').existsSync();

    test('after a save, the new file is kept and the replaced one is gone', () async {
      final oldName = await SecureFiles.save(db, Uint8List.fromList([1]), 'jpg');
      final files = FileChanges(db)..remove(oldName);
      final newName = await files.add(Uint8List.fromList([2]), 'jpg');
      await files.commit(() async {
        await db.addDocument(DocumentsCompanion.insert(assetId: car, filePath: newName, title: 'photo', docType: 'photo'));
      });

      expect(stored(newName), isTrue);
      expect(stored(oldName), isFalse);
      expect((await db.select(db.documents).get()).single.filePath, newName);
    });

    test('a failed save keeps the old file, removes the new one and writes no rows', () async {
      final oldName = await SecureFiles.save(db, Uint8List.fromList([1]), 'jpg');
      final files = FileChanges(db)..remove(oldName);
      final newName = await files.add(Uint8List.fromList([2]), 'jpg');

      await expectLater(
        files.commit(() async {
          await db.addRecord(RecordsCompanion.insert(assetId: car, kind: 'maintenance', title: 'Service', date: DateTime(2026, 11, 1)));
          await db.addDocument(DocumentsCompanion.insert(assetId: car, filePath: newName, title: 'photo', docType: 'photo'));
          throw StateError('the phone ran out of space');
        }),
        throwsStateError,
      );

      expect(stored(newName), isFalse);
      expect(stored(oldName), isTrue);
      expect(await db.select(db.records).get(), isEmpty, reason: 'the record before the failure is rolled back too');
      expect(await db.select(db.documents).get(), isEmpty);
    });
  });

  testWidgets('saving a record through the form writes it in one transaction', (tester) async {
    setPhone(tester, height: 3000);
    final s = strFor('en');
    final db = AppDb(NativeDatabase.memory());
    await tester.runAsync(() async {
      await db.createAsset(category: 'house', nickname: 'Setia Alam house', propertyType: 'landed');
      await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
    });
    await tester.pumpWidget(harness(
      Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const RecordFormScreen(assetId: 2))),
          child: const Text('open'),
        ),
      ),
      fakeWorld(),
      db: db,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, s.whatDone), 'Service 40,000 km');
    final save = find.text(s.saveRecord);
    await tester.scrollUntilVisible(save, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final records = await tester.runAsync(() => db.select(db.records).get());
    expect(records!.single.title, 'Service 40,000 km');
    expect(find.text('open'), findsOneWidget, reason: 'the form closed after saving');
    await tester.runAsync(db.close);
  });
}
