// Loopholes found in the 0.2.8 audit, and what closes them.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Table, Column;
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/auto_sync.dart';
import 'package:kukira_asset/domain/renewal.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/backup.dart';
import 'package:kukira_asset/services/auto_reminders.dart';
import 'package:kukira_asset/services/files.dart';
import 'package:kukira_asset/services/record_save.dart';
import 'package:kukira_asset/services/renewal.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/documents.dart';
import 'package:kukira_asset/ui/forms.dart';
import 'package:kukira_asset/ui/rent.dart';

import 'helpers.dart';

const pass = 'correct horse battery';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  late Directory root;
  setUp(() async {
    root = await useTempStorage();
    SecureFiles.reset();
  });

  group('stored file names', () {
    test('only names the app could have made are used', () async {
      final db = AppDb(NativeDatabase.memory());
      final made = await SecureFiles.save(db, Uint8List.fromList([1]), 'jpeg');
      expect(SecureFiles.isSafeName(made), isTrue);
      for (final ok in ['house.jpg', '1-f.pdf', 'photo-1', 'ab_cd.heic']) {
        expect(SecureFiles.isSafeName(ok), isTrue, reason: ok);
      }
      for (final bad in ['', '../kukira.db', 'a/b.pdf', r'a\b.pdf', '..', '.hidden', 'x..pdf', 'name with space.pdf']) {
        expect(SecureFiles.isSafeName(bad), isFalse, reason: bad);
      }
      await db.close();
    });

    test('a name that points elsewhere is never written or read', () async {
      final db = AppDb(NativeDatabase.memory());
      await expectLater(SecureFiles.saveNamed(db, '../../escaped', Uint8List.fromList([1])), throwsArgumentError);
      await expectLater(SecureFiles.read(db, '../kukira'), throwsArgumentError);
      await SecureFiles.delete('../kukira'); // does nothing, and does not throw
      expect(File('${root.path}/escaped.enc').existsSync(), isFalse);
      expect(File('${root.path}/support/escaped.enc').existsSync(), isFalse);
      await db.close();
    });
  });

  group('a backup someone else made', () {
    Map<String, dynamic> body({List<Map<String, dynamic>> documents = const []}) => {
          'created': DateTime(2026, 11, 1).toIso8601String(),
          'schema': AppDb.latestSchema,
          'tables': {
            'assets': [
              {'id': 1, 'nickname': 'Myvi', 'category': 'car', 'createdAt': 0, 'updatedAt': 0},
            ],
            'documents': documents,
          },
        };

    test('with a file name that points outside the files folder is refused', () async {
      final bytes = await Backup.pack(body(), {'../../shared_prefs/x': Uint8List.fromList([1])}, pass);
      await expectLater(Backup.open(bytes, pass), throwsA(isA<NotABackup>()));
    });

    test('with a document that points outside the files folder is refused', () async {
      final bytes = await Backup.pack(body(documents: [
        {'id': 1, 'assetId': 1, 'filePath': '../kukira', 'title': 'x', 'docType': 'other', 'addedAt': 0},
      ]), const {}, pass);
      await expectLater(Backup.open(bytes, pass), throwsA(isA<NotABackup>()));
    });

    test('asking for days of key stretching is refused before any is done', () async {
      final good = await Backup.pack(body(), const {}, pass);
      final magic = utf8.encode('KUKIRA2\n');
      final nl = good.indexOf(10, magic.length);
      final header = jsonDecode(utf8.decode(good.sublist(magic.length, nl))) as Map<String, dynamic>;
      header['iterations'] = 1 << 40;
      final forged = Uint8List.fromList([...magic, ...utf8.encode(jsonEncode(header)), 10, ...good.sublist(nl + 1)]);
      final watch = Stopwatch()..start();
      await expectLater(Backup.open(forged, pass), throwsA(isA<NotABackup>()));
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('our own backups still open', () async {
      final c = await Backup.open(await Backup.pack(body(), {'abc123.pdf': Uint8List.fromList([7])}, pass), pass);
      expect(c.files.keys, ['abc123.pdf']);
    });
  });

  test('deleting a record keeps the documents filed with it, no longer linked', () async {
    final db = AppDb(NativeDatabase.memory());
    final car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
    final rec = await db.addRecord(RecordsCompanion.insert(assetId: car, kind: 'payment', title: 'Insurance renewal', date: DateTime(2026, 11, 3)));
    final policy = await db.addDocument(DocumentsCompanion.insert(assetId: car, filePath: 'p.pdf', title: 'Policy', docType: 'insurance', linkedRecordId: Value(rec)));
    final photo = await db.addDocument(DocumentsCompanion.insert(assetId: car, filePath: 'q.jpg', title: 'Photo', docType: 'photo', linkedRecordId: Value(rec)));
    await db.unlinkDocuments(rec);
    await db.deleteRecord(rec);
    final docs = {for (final d in await db.select(db.documents).get()) d.id: d};
    expect(docs[policy]!.linkedRecordId, isNull, reason: 'kept as a document of the asset');
    expect(docs[photo]!.linkedRecordId, rec, reason: 'photos are deleted with the record by the screen, not unlinked');
    await db.close();
  });

  group('forms', () {
    final s = strFor('en');
    World with1(World w, {HouseProfile? house, List<Asset>? assets}) => World(
          assets: assets ?? w.assets,
          houses: house == null ? w.houses : {1: house},
          vehicles: w.vehicles,
          reminders: w.reminders,
          records: w.records,
          odometer: w.odometer,
          vendors: w.vendors,
          documents: w.documents,
          settings: w.settings,
          costItems: w.costItems,
        );

    for (final typed in ['1o0', '-5']) {
      testWidgets('a record cost of "$typed" is pointed out, not saved as no cost', (tester) async {
        setPhone(tester, height: 2400);
        await tester.pumpWidget(harness(const RecordFormScreen(assetId: 2), fakeWorld()));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, s.totalCost), typed);
        await tester.tap(find.text(s.saveRecord));
        await tester.pump();
        expect(find.text(s.costInvalid), findsOneWidget);
        expect(find.byType(RecordFormScreen), findsOneWidget);
      });
    }

    // Since 0.3 the tenancy is kept on its own form (lib/ui/rent.dart).
    testWidgets('a tenancy cannot end before it starts', (tester) async {
      setPhone(tester, height: 3200);
      final t = Tenancy(id: 1, assetId: 1, startDate: DateTime(2027, 3, 1), endDate: DateTime(2027, 1, 1), createdAt: DateTime(2026, 11, 1));
      final base = fakeWorld();
      final w = World(
        tenancies: [t],
        assets: base.assets,
        houses: base.houses,
        vehicles: base.vehicles,
        reminders: base.reminders,
        records: base.records,
        odometer: base.odometer,
        vendors: base.vendors,
        documents: base.documents,
        settings: base.settings,
        costItems: base.costItems,
      );
      await tester.pumpWidget(harness(const TenancyFormScreen(assetId: 1, editId: 1), w));
      await tester.pumpAndSettle();
      final save = find.text(s.saveTenancy);
      await tester.scrollUntilVisible(save, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(save);
      await tester.pump();
      expect(find.text(s.endBeforeStart), findsOneWidget);
    });

    testWidgets('the menu button keeps its backdrop only over the photo', (tester) async {
      setPhone(tester, height: 1600);
      final jpg = File('test/fixtures/house.jpg').readAsBytesSync();
      SecureImage.debugImage = (_) => MemoryImage(jpg);
      addTearDown(() => SecureImage.debugImage = null);
      final base = fakeWorld();
      final w = with1(base, assets: [base.assets[0].copyWith(photoPath: const Value('house.jpg')), base.assets[1]]);
      await tester.pumpWidget(harness(const AssetDetailScreen(assetId: 1), w));
      await tester.pumpAndSettle();
      Color? backdrop() =>
          (tester.widget<DecoratedBox>(find.ancestor(of: find.byType(PopupMenuButton<String>), matching: find.byType(DecoratedBox)).first).decoration as BoxDecoration).color;
      expect(backdrop(), isNotNull);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(backdrop(), isNull, reason: 'the header has shrunk to a plain bar');
    });
  });

  test('a renewal moves the reminder that is saved, even if the form was opened before it changed', () async {
    final s = strFor('en');
    final db = AppDb(NativeDatabase.memory());
    final car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
    final stale = await db.loadWorld();
    // Set after the form opened: a road tax date and its reminder.
    await db.updateVehicle(car, VehicleProfilesCompanion(roadTaxExpiry: Value(DateTime(2026, 11, 12))));
    await db.addReminder(RemindersCompanion.insert(
      assetId: car,
      title: 'Road tax renewal',
      ruleType: 'fixed',
      dueDate: Value(DateTime(2026, 11, 12)),
      autoSource: const Value(autoRoadTax),
    ));
    await applyRenewal(db, s, stale, car, [RenewInput(kind: RenewKind.roadTax, start: DateTime(2026, 11, 13), end: DateTime(2027, 11, 12))], today: DateTime(2026, 11, 3));
    final linked = (await db.select(db.reminders).get()).where((r) => r.autoSource == autoRoadTax).toList();
    expect(linked, hasLength(1), reason: 'the existing reminder moved, not a second one made');
    expect(linked.single.dueDate, DateTime(2027, 11, 12));
    await db.close();
  });

  testWidgets('a document moved to another asset takes its reminder along and leaves the old record', (tester) async {
    final s = strFor('en');
    setPhone(tester, height: 2000);
    final db = AppDb(NativeDatabase.memory());
    final ids = (await tester.runAsync(() async {
      final house = await db.createAsset(category: 'house', nickname: 'Setia Alam house', propertyType: 'landed');
      final car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
      final rec = await db.addRecord(RecordsCompanion.insert(assetId: car, kind: 'payment', title: 'Insurance renewal', date: DateTime(2026, 11, 3)));
      final rem = await db.addReminder(RemindersCompanion.insert(assetId: car, title: 'Policy expires', ruleType: 'fixed', dueDate: Value(DateTime(2027, 11, 12))));
      final doc = await db.addDocument(DocumentsCompanion.insert(
        assetId: car,
        filePath: 'p.pdf',
        title: 'Policy',
        docType: 'insurance',
        expiry: Value(DateTime(2027, 11, 12)),
        linkedReminderId: Value(rem),
        linkedRecordId: Value(rec),
      ));
      return (house, rem, doc);
    }))!;
    final w = (await tester.runAsync(db.loadWorld))!;
    await tester.pumpWidget(harness(
      Builder(builder: (c) => TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DocumentFormScreen(editId: ids.$3))), child: const Text('open'))),
      w,
      db: db,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setia Alam house').last);
    await tester.pumpAndSettle();
    final save = find.text(s.saveDocument);
    await tester.scrollUntilVisible(save, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final (doc, rem) = (await tester.runAsync(() async => (
          await (db.select(db.documents)..where((t) => t.id.equals(ids.$3))).getSingle(),
          await (db.select(db.reminders)..where((t) => t.id.equals(ids.$2))).getSingle(),
        )))!;
    await tester.runAsync(db.close);
    expect(doc.assetId, ids.$1);
    expect(rem.assetId, ids.$1, reason: 'the expiry reminder goes with the document');
    expect(doc.linkedRecordId, isNull, reason: 'the record stays with the car');
  });

  test('a service entered late counts the next one from the day it was done', () async {
    final s = strFor('en');
    final db = AppDb(NativeDatabase.memory());
    final car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
    final oil = await db.addReminder(RemindersCompanion.insert(
      assetId: car,
      title: 'Engine oil',
      ruleType: 'repeat',
      category: const Value('oil'),
      dueDate: Value(DateTime(2026, 10, 1)),
      repeatMonths: const Value(6),
    ));
    final w = await db.loadWorld();
    await saveRecord(
      db,
      s,
      w,
      RecordInput(assetId: car, kind: 'maintenance', category: 'oil', title: 'Oil change', date: DateTime(2026, 10, 1), completes: w.reminders.firstWhere((r) => r.id == oil)),
      warranty: planWarranty(const [], reminderId: null, oldDate: null, newDate: null, today: DateTime(2026, 10, 20)),
      overwriteWarranty: true,
      today: DateTime(2026, 10, 20),
      msgs: [],
    );
    final r = await (db.select(db.reminders)..where((t) => t.id.equals(oil))).getSingle();
    expect(r.lastCompleted, DateTime(2026, 10, 1));
    expect(r.dueDate, DateTime(2027, 4, 1), reason: 'six months from the service, not from the day it was typed in');
    await db.close();
  });
}
