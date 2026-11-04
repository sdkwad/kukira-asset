// Smoother app (0.2.7d): the database on its own isolate, notifications scheduled only when
// they change, and pictures decrypted once.

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/data/vault.dart';
import 'package:kukira_asset/services/files.dart';
import 'package:kukira_asset/services/notifications.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final key = List.filled(32, 'ab').join();

  group('database on its own isolate', () {
    late Directory dir;
    late File file;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('kukira_bg_');
      file = File('${dir.path}/kukira.db');
    });
    tearDown(() => dir.delete(recursive: true));

    test('opens, keeps what is written, and opens again with it', () async {
      final db = AppDb(Vault.connectInBackground(file, key, requireCipher: false));
      final id = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
      await db.setSetting('lang', 'ms');
      expect((await db.loadWorld()).assets.single.id, id);
      await db.close();

      final again = AppDb(Vault.connectInBackground(file, key, requireCipher: false));
      final w = await again.loadWorld();
      expect(w.assets.single.nickname, 'Myvi');
      expect(w.vehicles.values.single.plate, 'WXY 4821');
      expect(w.settings['lang'], 'ms');
      await again.close();
    });

    test('changes made there reach the screens that watch the records', () async {
      // Each step has its own limit, so a failure says which step it was.
      Future<void> until(String what, bool Function() ok) async {
        for (var i = 0; i < 250 && !ok(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        if (!ok()) fail('timed out: $what');
      }

      final db = AppDb(Vault.connectInBackground(file, key, requireCipher: false));
      final seen = <int>[];
      final sub = db.watchWorld().listen((w) => seen.add(w.assets.length));
      await until('the first load', () => seen.isNotEmpty);
      expect(seen.first, 0);
      await db.createAsset(category: 'house', nickname: 'Rumah', propertyType: 'landed');
      await until('the reload after a write', () => seen.contains(1));
      await db.setSetting('lang', 'en');
      await until('the reload after a second write', () => seen.length >= 3);

      // The app does not wait on its watcher when it lets go of a database either.
      sub.cancel().ignore();
      await db.close().timeout(const Duration(seconds: 10));
    });

    test('without SQLCipher it refuses to open rather than store records unencrypted', () async {
      // The computer running the tests has plain SQLite, so the check must fail here.
      final db = AppDb(Vault.connectInBackground(file, key));
      await expectLater(db.loadWorld(), throwsA(anything));
      try {
        await db.close();
      } catch (_) {
        // It never opened.
      }
    });
  });

  group('notifications', () {
    test('one is scheduled again only when it changed or Android no longer has it', () {
      final applied = {1000012: 'Road tax|in 7 days|2026-11-10T09:00:00.000'};
      expect(Notifier.needsSchedule(applied, {1000012}, 1000012, 'Road tax|in 7 days|2026-11-10T09:00:00.000'), isFalse);
      expect(Notifier.needsSchedule(applied, {1000012}, 1000012, 'Road tax|tomorrow|2026-11-16T09:00:00.000'), isTrue, reason: 'changed');
      expect(Notifier.needsSchedule(applied, const {}, 1000012, 'Road tax|in 7 days|2026-11-10T09:00:00.000'), isTrue, reason: 'no longer pending');
      expect(Notifier.needsSchedule(applied, {1000022}, 1000022, 'Insurance|due|2026-11-12T09:00:00.000'), isTrue, reason: 'never scheduled in this run');
    });
  });

  group('pictures', () {
    late AppDb db;
    setUp(() async {
      await useTempStorage();
      SecureFiles.reset();
      db = AppDb(NativeDatabase.memory());
    });
    tearDown(() => db.close());

    test('a decrypted picture stays in memory, so it can be drawn in the same frame', () async {
      final bytes = Uint8List.fromList(List.generate(2048, (i) => i % 251));
      final name = await SecureFiles.save(db, bytes, 'jpg');
      SecureFiles.reset();
      expect(SecureFiles.cached(name), isNull);
      expect(await SecureFiles.read(db, name), bytes);
      expect(SecureFiles.cached(name), bytes);
      await SecureFiles.delete(name);
      expect(SecureFiles.cached(name), isNull);
    });
  });
}
