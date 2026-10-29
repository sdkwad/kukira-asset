import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:biometric_storage/biometric_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:sqlite3/sqlite3.dart';

import 'db.dart';

enum BootState { ready, locked, unreadable }

/// Result of trying to open the encrypted database at start-up.
class BootResult {
  const BootResult(this.state, [this.db]);
  final BootState state;
  final AppDb? db;
}

/// Thrown when the PIN does not unwrap the database key.
class WrongPin implements Exception {}

/// Opens the SQLCipher database. The random database key is kept in Android Keystore
/// (flutter_secure_storage). With the app lock on, the key is only stored wrapped by
/// the PIN, and optionally in a fingerprint-protected Keystore entry, so the lock
/// gates the key itself and not just the screen.
class Vault {
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  static const _keyName = 'kukira_db_key_v1';
  static const _wrappedName = 'kukira_db_key_wrapped_v1';
  static const _modeName = 'kukira_lock_mode';
  static const _bioName = 'kukira_bio_key_v1';
  static const _pinIterations = 120000;
  static bool _ready = false;
  static String? _currentKey;

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

  static Future<String?> _read(String name) async {
    try {
      return await _storage.read(key: name);
    } catch (_) {
      return null;
    }
  }

  /// none | pin | pin_bio
  static Future<String> lockMode() async => await _read(_modeName) ?? 'none';

  static Future<BootResult> open() async {
    await _setup();
    final f = await dbFile();
    final exists = await f.exists();
    final mode = await lockMode();
    if (mode != 'none') {
      if (!exists) {
        // A lock without a database (e.g. data cleared): start over unlocked.
        await _clearLock();
      } else {
        return const BootResult(BootState.locked);
      }
    }
    var key = await _read(_keyName);
    if (key == null) {
      if (exists) return const BootResult(BootState.unreadable);
      key = _newKey();
      await _storage.write(key: _keyName, value: key);
    } else if (exists && !_probe(f, key)) {
      return const BootResult(BootState.unreadable);
    }
    return BootResult(BootState.ready, _openDb(f, key));
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

  static AppDb _openDb(File f, String hex) {
    _currentKey = hex;
    return AppDb(NativeDatabase(f, setup: (raw) {
      raw.execute(_pragma(hex));
      final v = raw.select('PRAGMA cipher_version;');
      if (v.isEmpty) {
        throw StateError('SQLCipher is not loaded; refusing to open an unencrypted database.');
      }
    }));
  }

  // ---------------------------------------------------------------- PIN wrapping

  static Future<List<int>> _kek(String pin, List<int> salt) => Isolate.run(() async {
        final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: _pinIterations, bits: 256);
        return (await kdf.deriveKeyFromPassword(password: pin, nonce: salt)).extractBytes();
      });

  static Future<String> _wrap(String hex, String pin) async {
    final r = Random.secure();
    final salt = List<int>.generate(16, (_) => r.nextInt(256));
    final kek = await _kek(pin, salt);
    final box = await AesGcm.with256bits().encrypt(utf8.encode(hex), secretKey: SecretKey(kek));
    return jsonEncode({'salt': base64Encode(salt), 'box': base64Encode(box.concatenation())});
  }

  static Future<String> _unwrap(String wrapped, String pin) async {
    final m = jsonDecode(wrapped) as Map<String, dynamic>;
    final kek = await _kek(pin, base64Decode(m['salt'] as String));
    final box = SecretBox.fromConcatenation(base64Decode(m['box'] as String), nonceLength: 12, macLength: 16);
    try {
      return utf8.decode(await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(kek)));
    } on SecretBoxAuthenticationError {
      throw WrongPin();
    }
  }

  /// Unlocks with the PIN and opens the database. Throws [WrongPin].
  static Future<AppDb?> unlockWithPin(String pin) async {
    await _setup();
    final wrapped = await _read(_wrappedName);
    if (wrapped == null) return null;
    final hex = await _unwrap(wrapped, pin);
    final f = await dbFile();
    if (!_probe(f, hex)) return null;
    return _openDb(f, hex);
  }

  /// Checks the PIN without opening anything (used by the lock shown on resume).
  static Future<bool> checkPin(String pin) async {
    final wrapped = await _read(_wrappedName);
    if (wrapped == null) return false;
    try {
      await _unwrap(wrapped, pin);
      return true;
    } on WrongPin {
      return false;
    }
  }

  // ---------------------------------------------------------------- fingerprint

  static Future<bool> bioAvailable() async {
    try {
      return await BiometricStorage().canAuthenticate() == CanAuthenticateResponse.success;
    } catch (_) {
      return false;
    }
  }

  static Future<BiometricStorageFile> _bioFile(String title, String cancel) => BiometricStorage().getStorage(
        _bioName,
        promptInfo: PromptInfo(androidPromptInfo: AndroidPromptInfo(title: title, negativeButton: cancel)),
      );

  /// Reads the key through the fingerprint prompt. Returns null if cancelled or failed.
  static Future<String?> _bioRead(String title, String cancel) async {
    try {
      return await (await _bioFile(title, cancel)).read();
    } catch (_) {
      return null;
    }
  }

  static Future<AppDb?> unlockWithBio(String title, String cancel) async {
    await _setup();
    final hex = await _bioRead(title, cancel);
    if (hex == null) return null;
    final f = await dbFile();
    if (!_probe(f, hex)) return null;
    return _openDb(f, hex);
  }

  static Future<bool> checkBio(String title, String cancel) async => await _bioRead(title, cancel) == _currentKey;

  // ---------------------------------------------------------------- turning the lock on and off

  /// Turns on the lock: the key is stored only wrapped by [pin] (and in fingerprint storage when [bio]).
  static Future<bool> enableLock(String pin, {required bool bio, required String title, required String cancel}) async {
    final hex = _currentKey;
    if (hex == null) return false;
    await _storage.write(key: _wrappedName, value: await _wrap(hex, pin));
    var mode = 'pin';
    if (bio) {
      try {
        await (await _bioFile(title, cancel)).write(hex);
        mode = 'pin_bio';
      } catch (_) {
        mode = 'pin';
      }
    }
    await _storage.write(key: _modeName, value: mode);
    await _storage.delete(key: _keyName);
    return true;
  }

  static Future<bool> setBio(bool on, {required String title, required String cancel}) async {
    final hex = _currentKey;
    if (hex == null) return false;
    try {
      if (on) {
        await (await _bioFile(title, cancel)).write(hex);
        await _storage.write(key: _modeName, value: 'pin_bio');
      } else {
        await (await _bioFile(title, cancel)).delete();
        await _storage.write(key: _modeName, value: 'pin');
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Turns the lock off after the PIN has been checked.
  static Future<void> disableLock() async {
    final hex = _currentKey;
    if (hex == null) return;
    await _storage.write(key: _keyName, value: hex);
    await _clearLock();
  }

  static Future<void> _clearLock() async {
    try {
      await (await BiometricStorage().getStorage(_bioName)).delete();
    } catch (_) {}
    await _storage.delete(key: _wrappedName);
    await _storage.delete(key: _modeName);
  }

  /// Starts a new, empty database with a new key. The unreadable database, its files and
  /// any old key entries are set aside, never deleted, so nothing is lost for good if the
  /// key turns out to be readable after all (for example a secure storage hiccup).
  ///
  /// Throws if secure storage cannot be read: writing a new key then could overwrite the
  /// only copy of the old one.
  static Future<AppDb> resetAndOpen() async {
    await _setup();
    final stamp = _stamp(DateTime.now());
    for (final name in [_keyName, _wrappedName, _modeName]) {
      final old = await _storage.read(key: name);
      if (old != null) await _storage.write(key: '${name}_old_$stamp', value: old);
    }
    await _clearLock();
    final f = await dbFile();
    await setAside(f.parent, stamp);
    final key = _newKey();
    await _storage.write(key: _keyName, value: key);
    return _openDb(f, key);
  }

  static String _stamp(DateTime d) =>
      '${d.year}${_two(d.month)}${_two(d.day)}-${_two(d.hour)}${_two(d.minute)}${_two(d.second)}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// Moves the database files and the encrypted documents folder from [base] into
  /// `unreadable/<stamp>/`. Returns that folder, or null when there was nothing to move.
  static Future<Directory?> setAside(Directory base, String stamp) async {
    final names = ['kukira.db', 'kukira.db-wal', 'kukira.db-shm', 'kukira.db-journal'];
    final present = [
      for (final n in names)
        if (await File(p.join(base.path, n)).exists()) n,
    ];
    final files = Directory(p.join(base.path, 'files'));
    final hasFiles = await files.exists();
    if (present.isEmpty && !hasFiles) return null;
    var dest = Directory(p.join(base.path, 'unreadable', stamp));
    for (var i = 2; await dest.exists(); i++) {
      dest = Directory(p.join(base.path, 'unreadable', '$stamp-$i'));
    }
    await dest.create(recursive: true);
    for (final n in present) {
      await File(p.join(base.path, n)).rename(p.join(dest.path, n));
    }
    if (hasFiles) await files.rename(p.join(dest.path, 'files'));
    return dest;
  }
}
