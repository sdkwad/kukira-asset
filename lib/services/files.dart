import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/db.dart';

/// Documents and photos, stored encrypted (AES-256-GCM) in app-private storage.
/// The file key lives inside the encrypted database, so it is protected by the
/// database key (and by the app lock when that is on).
class SecureFiles {
  static Uint8List? _key;
  static final Map<String, Uint8List> _cache = {};

  static Future<Directory> _dir() async {
    final d = Directory(p.join((await getApplicationSupportDirectory()).path, 'files'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<Uint8List> _fileKey(AppDb db) async {
    if (_key != null) return _key!;
    var k = await db.getSetting('fileKey');
    if (k == null) {
      final r = Random.secure();
      k = base64Encode(List<int>.generate(32, (_) => r.nextInt(256)));
      await db.setSetting('fileKey', k);
    }
    return _key = base64Decode(k);
  }

  /// Forget the cached key, for example after a restore replaced the database.
  static void reset() {
    _key = null;
    _cache.clear();
  }

  static String _newName(String ext) {
    final r = Random.secure();
    final id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final clean = ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$id.${clean.isEmpty ? 'bin' : clean}';
  }

  static String extOf(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  static bool isImage(String name) => const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'].contains(extOf(name));

  /// Encrypts [bytes] into a new file and returns its name.
  static Future<String> save(AppDb db, Uint8List bytes, String ext) async {
    final name = _newName(ext);
    await saveNamed(db, name, bytes);
    return name;
  }

  static Future<void> saveNamed(AppDb db, String name, Uint8List bytes) async {
    final key = await _fileKey(db);
    final sealed = await Isolate.run(() async {
      final box = await AesGcm.with256bits().encrypt(bytes, secretKey: SecretKey(key));
      return box.concatenation();
    });
    final f = File(p.join((await _dir()).path, '$name.enc'));
    await f.writeAsBytes(sealed, flush: true);
  }

  static Future<Uint8List> read(AppDb db, String name) async {
    final hit = _cache[name];
    if (hit != null) return hit;
    final key = await _fileKey(db);
    final f = File(p.join((await _dir()).path, '$name.enc'));
    final sealed = await f.readAsBytes();
    final clear = await Isolate.run(() async {
      final box = SecretBox.fromConcatenation(sealed, nonceLength: 12, macLength: 16);
      return Uint8List.fromList(await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(key)));
    });
    if (clear.length < 3 * 1024 * 1024) {
      if (_cache.length > 40) _cache.remove(_cache.keys.first);
      _cache[name] = clear;
    }
    return clear;
  }

  static Future<void> delete(String name) async {
    _cache.remove(name);
    final f = File(p.join((await _dir()).path, '$name.enc'));
    if (await f.exists()) await f.delete();
  }

  static Future<void> deleteAll() async {
    _cache.clear();
    final d = await _dir();
    await for (final e in d.list()) {
      if (e is File) await e.delete();
    }
  }

  /// Decrypts to a temporary file so the phone's own viewer can open it.
  static Future<File> _temp(AppDb db, String name, String title) async {
    final bytes = await read(db, name);
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'view'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final safe = title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    final f = File(p.join(dir.path, '${safe.isEmpty ? 'kukira' : safe}.${extOf(name)}'));
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  /// Returns false when the phone has no app that can open the file.
  static Future<bool> openExternal(AppDb db, String name, String title) async {
    final f = await _temp(db, name, title);
    final r = await OpenFilex.open(f.path);
    return r.type == ResultType.done;
  }

  static Future<void> shareCopy(AppDb db, String name, String title) async {
    final f = await _temp(db, name, title);
    await Share.shareXFiles([XFile(f.path)], subject: title);
  }

  /// Removes decrypted copies left from viewing or sharing. Called at start-up.
  static Future<void> clearTemp() async {
    try {
      final dir = Directory(p.join((await getTemporaryDirectory()).path, 'view'));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
