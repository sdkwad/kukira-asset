import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:sqlite3/sqlite3.dart';

import 'db.dart';

/// Result of trying to open the encrypted database at start-up.
class BootResult {
  const BootResult(this.db);
  final AppDb? db;

  /// The database file exists but this phone does not hold a key that opens it,
  /// for example after the OS moved files to a new phone. Show the restore screen.
  bool get unreadable => db == null;
}

/// Opens the SQLCipher database with a random key kept in Android Keystore.
class Vault {
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  static const _keyName = 'kukira_db_key_v1';
  static bool _ready = false;

  static Future<void> _setup() async {
    if (_ready) return;
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    // Must run on every isolate that opens the database. Kukira opens it on the main isolate only.
    sqlite_open.open.overrideFor(sqlite_open.OperatingSystem.android, openCipherOnAndroid);
    _ready = true;
  }

  static Future<File> dbFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'kukira.db'));
  }

  static String _pragma(String hex) => "PRAGMA key = \"x'$hex'\";";

  static String _newKey() {
    final r = Random.secure();
    return List.generate(32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<BootResult> open() async {
    await _setup();
    final f = await dbFile();
    String? key;
    try {
      key = await _storage.read(key: _keyName);
    } catch (_) {
      key = null;
    }
    final exists = await f.exists();
    if (key == null) {
      if (exists) return const BootResult(null);
      key = _newKey();
      await _storage.write(key: _keyName, value: key);
    } else if (exists && !_probe(f, key)) {
      return const BootResult(null);
    }
    return BootResult(_openDb(f, key));
  }

  static bool _probe(File f, String hex) {
    try {
      final db = sqlite3.open(f.path);
      try {
        db.execute(_pragma(hex));
        db.select('SELECT count(*) FROM sqlite_master;');
        return true;
      } finally {
        db.dispose();
      }
    } catch (_) {
      return false;
    }
  }

  static AppDb _openDb(File f, String hex) => AppDb(NativeDatabase(f, setup: (raw) {
        raw.execute(_pragma(hex));
        final v = raw.select('PRAGMA cipher_version;');
        if (v.isEmpty) {
          throw StateError('SQLCipher is not loaded; refusing to open an unencrypted database.');
        }
      }));

  /// Deletes the unreadable database and starts a new, empty one with a new key.
  static Future<AppDb> resetAndOpen() async {
    await _setup();
    final f = await dbFile();
    for (final x in [f, File('${f.path}-wal'), File('${f.path}-shm'), File('${f.path}-journal')]) {
      if (await x.exists()) await x.delete();
    }
    final key = _newKey();
    await _storage.write(key: _keyName, value: key);
    return _openDb(f, key);
  }
}
