// The asset photo (0.2.7c): offered when the asset is added, and shown as one small row in
// Edit details. It is saved encrypted, and the asset is kept even if the photo is not.

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/asset_save.dart';
import 'package:kukira_asset/services/files.dart';
import 'package:kukira_asset/ui/add_asset.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/documents.dart';

import 'helpers.dart';

World withPhoto(World w, int assetId, String name) => World(
      assets: [for (final a in w.assets) a.id == assetId ? a.copyWith(photoPath: Value(name)) : a],
      houses: w.houses,
      vehicles: w.vehicles,
      reminders: w.reminders,
      records: w.records,
      odometer: w.odometer,
      vendors: w.vendors,
      documents: w.documents,
      settings: w.settings,
      costItems: w.costItems,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  final jpg = File('test/fixtures/moto.jpg').readAsBytesSync();

  group('saving', () {
    late Directory root;
    late AppDb db;
    setUp(() async {
      root = await useTempStorage();
      SecureFiles.reset();
      db = AppDb(NativeDatabase.memory());
    });
    tearDown(() => db.close());

    List<File> stored() => Directory('${root.path}/support/files').existsSync()
        ? Directory('${root.path}/support/files').listSync().whereType<File>().toList()
        : <File>[];

    test('the photo is encrypted into its own file and linked to the new asset', () async {
      final (id, saved) = await createAssetWithPhoto(db, category: 'motorcycle', nickname: 'EX5', plate: 'PKL 22', photo: Uint8List.fromList(jpg));
      expect(saved, isTrue);
      final a = await (db.select(db.assets)..where((t) => t.id.equals(id))).getSingle();
      expect(a.photoPath, isNotNull);
      final files = stored();
      expect(files, hasLength(1));
      expect(files.single.readAsBytesSync(), isNot(equals(jpg)), reason: 'never stored in the clear');
      SecureFiles.reset();
      expect(await SecureFiles.read(db, a.photoPath!), jpg);
    });

    test('without a photo the asset is created as before', () async {
      final (id, saved) = await createAssetWithPhoto(db, category: 'house', nickname: 'Rumah', propertyType: 'strata');
      expect(saved, isTrue);
      final a = await (db.select(db.assets)..where((t) => t.id.equals(id))).getSingle();
      expect(a.photoPath, isNull);
      expect(stored(), isEmpty);
    });
  });

  testWidgets('adding an asset offers a photo, which can be changed or taken out before saving', (tester) async {
    setPhone(tester, height: 1600);
    final asked = <String>[];
    debugPickFile = (source) async {
      asked.add(source);
      return Picked(Uint8List.fromList(jpg), 'jpg');
    };
    addTearDown(() => debugPickFile = null);
    await tester.pumpWidget(harness(const AddAssetScreen(), fakeWorld()));
    await tester.tap(find.text(s.categoryName('motorcycle')));
    await tester.pumpAndSettle();
    expect(find.text(s.assetPhoto), findsOneWidget);
    expect(find.text(s.assetPhotoHint), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, s.add));
    await tester.pumpAndSettle();
    expect(find.text(s.removePhoto), findsNothing, reason: 'nothing to remove yet');
    await tester.tap(find.text(s.camera));
    await tester.pumpAndSettle();
    expect(asked, ['camera']);
    expect(find.widgetWithText(TextButton, s.change), findsOneWidget);
    expect(find.descendant(of: find.byType(PhotoRow), matching: find.byType(Image)), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, s.change));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.removePhoto));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, s.add), findsOneWidget);
  });

  testWidgets('Edit details shows the photo as a small row, not a banner', (tester) async {
    setPhone(tester, height: 1600);
    SecureImage.debugImage = (_) => MemoryImage(Uint8List.fromList(jpg));
    addTearDown(() => SecureImage.debugImage = null);
    await tester.pumpWidget(harness(const VehicleEditScreen(assetId: 2), withPhoto(fakeWorld(), 2, 'photo-1')));
    await tester.pumpAndSettle();
    expect(find.byType(AssetBanner), findsNothing);
    expect(find.byType(PhotoRow), findsOneWidget);
    expect(find.widgetWithText(TextButton, s.change), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, s.change));
    await tester.pumpAndSettle();
    expect(find.text(s.camera), findsOneWidget);
    expect(find.text(s.gallery), findsOneWidget);
    expect(find.text(s.removePhoto), findsOneWidget);
  });
}
