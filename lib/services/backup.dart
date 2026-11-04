import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:share_plus/share_plus.dart';

import '../data/db.dart';
import 'error_log.dart';
import 'files.dart';

/// Thrown when the passphrase does not open the file.
class WrongPassphrase implements Exception {}

/// Thrown when the file is not a Kukira backup.
class NotABackup implements Exception {}

/// Thrown when the backup was made by a newer version of Kukira (a newer database schema).
/// Restoring it here would silently drop the fields this version doesn't know.
class NewerBackup implements Exception {}

/// A finished backup file. [missing] counts documents and photos that could not be read
/// and are therefore not in it.
class BackupFile {
  BackupFile(this.bytes, this.missing);
  final Uint8List bytes;
  final int missing;
}

class BackupContents {
  BackupContents(this.created, this.tables, this.files, {this.schema});
  final DateTime created;
  final Map<String, dynamic> tables;

  /// Database schema of the app that made the backup. Null for backups made before 0.2.2.
  final int? schema;

  /// Decrypted documents and photos by file name.
  final Map<String, Uint8List> files;

  int count(String table) => ((tables[table] as List?) ?? const []).length;

  int get photoCount => ((tables['documents'] as List?) ?? const []).where((d) => (d as Map)['docType'] == 'photo').length;
}

/// One encrypted file holding all records, documents and photos. The key comes from a
/// passphrase the user chooses (PBKDF2-HMAC-SHA256), and everything is sealed with AES-256-GCM.
///
/// Format 2 (binary): "KUKIRA2\n" + header JSON + "\n" + ciphertext.
/// The plaintext is: uint32 length + gzip(JSON body) + repeated (uint16 name length, name, uint32 length, bytes).
/// The JSON body is {created, schema, tables}; `schema` was added in 0.2.2 and sits inside
/// the encrypted part so it cannot be altered.
/// Format 1 (0.1.0, JSON envelope, no files) can still be restored.
class Backup {
  static const format = 'kukira-backup';
  static const iterations = 150000;
  static final _magic = utf8.encode('KUKIRA2\n');

  static String fileName(DateTime d) =>
      'kukira-backup-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.kukira';

  /// The most key-stretching rounds a backup may ask for. The header is read before the
  /// passphrase is checked, so a made-up file must not be able to ask for days of work.
  /// (Kukira itself uses [iterations]; older test files used fewer, which is still allowed.)
  static const maxIterations = 2000000;

  static int _iterationsOf(Object? v) {
    if (v is! int || v < 1 || v > maxIterations) throw NotABackup();
    return v;
  }

  /// Every file a backup brings or names must be one the app could have made.
  static void _checkNames(Map<String, dynamic> tables, Iterable<String> files) {
    final named = [
      for (final d in (tables['documents'] as List?) ?? const []) (d as Map)['filePath'],
      for (final a in (tables['assets'] as List?) ?? const []) (a as Map)['photoPath'],
    ];
    for (final n in [...files, ...named]) {
      if (n == null) continue;
      if (n is! String || !SecureFiles.isSafeName(n)) throw NotABackup();
    }
  }

  static Future<List<int>> _derive(String pass, List<int> salt, int iter) => Isolate.run(() async {
        final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iter, bits: 256);
        final k = await kdf.deriveKeyFromPassword(password: pass, nonce: salt);
        return k.extractBytes();
      });

  static Future<BackupFile> create(AppDb db, String pass) async {
    final tables = await db.exportTables();
    final files = <String, Uint8List>{};
    final names = <String>{
      for (final d in tables['documents']!) d['filePath'] as String,
      for (final a in tables['assets']!)
        if (a['photoPath'] != null) a['photoPath'] as String,
    };
    var missing = 0;
    for (final n in names) {
      try {
        files[n] = await SecureFiles.read(db, n);
      } catch (e) {
        ErrorLog.record('backup.missingFile', e);
        // A missing file should not stop the backup of everything else, but the user is told.
        missing++;
      }
    }
    final body = {'created': DateTime.now().toIso8601String(), 'schema': AppDb.latestSchema, 'tables': tables};
    return BackupFile(await pack(body, files, pass), missing);
  }

  /// Seals a backup body and its files into the format 2 layout.
  static Future<Uint8List> pack(Map<String, dynamic> body, Map<String, Uint8List> files, String pass) async {
    final json = gzip.encode(utf8.encode(jsonEncode(body)));
    final b = BytesBuilder(copy: false);
    void u32(int v) => b.add((ByteData(4)..setUint32(0, v)).buffer.asUint8List());
    void u16(int v) => b.add((ByteData(2)..setUint16(0, v)).buffer.asUint8List());
    u32(json.length);
    b.add(json);
    files.forEach((name, bytes) {
      final n = utf8.encode(name);
      u16(n.length);
      b.add(n);
      u32(bytes.length);
      b.add(bytes);
    });
    final plain = b.takeBytes();

    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final key = await _derive(pass, salt, iterations);
    final box = await Isolate.run(() => AesGcm.with256bits().encrypt(plain, secretKey: SecretKey(key)));
    final header = utf8.encode(jsonEncode({
      'format': format,
      'version': 2,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
    }));
    final out = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(header)
      ..addByte(10)
      ..add(box.cipherText);
    return out.takeBytes();
  }

  static bool _startsWithMagic(Uint8List bytes) {
    if (bytes.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  static Future<BackupContents> open(Uint8List bytes, String pass) async {
    if (_startsWithMagic(bytes)) return _openV2(bytes, pass);
    return _openV1(bytes, pass);
  }

  static Future<BackupContents> _openV2(Uint8List bytes, String pass) async {
    final start = _magic.length;
    final nl = bytes.indexOf(10, start);
    if (nl < 0) throw NotABackup();
    Map<String, dynamic> h;
    try {
      h = jsonDecode(utf8.decode(bytes.sublist(start, nl))) as Map<String, dynamic>;
    } catch (_) {
      throw NotABackup();
    }
    if (h['format'] != format) throw NotABackup();
    final iterations = _iterationsOf(h['iterations']);
    final List<int> salt;
    final SecretBox box;
    try {
      salt = base64Decode(h['salt'] as String);
      box = SecretBox(
        Uint8List.sublistView(bytes, nl + 1),
        nonce: base64Decode(h['nonce'] as String),
        mac: Mac(base64Decode(h['mac'] as String)),
      );
    } catch (_) {
      throw NotABackup();
    }
    final key = await _derive(pass, salt, iterations);
    List<int> clear;
    try {
      clear = await Isolate.run(() => AesGcm.with256bits().decrypt(box, secretKey: SecretKey(key)));
    } on SecretBoxAuthenticationError {
      throw WrongPassphrase();
    }
    final data = clear is Uint8List ? clear : Uint8List.fromList(clear);
    final Map<String, dynamic> body;
    final files = <String, Uint8List>{};
    try {
      final view = ByteData.sublistView(data);
      var o = 0;
      final jsonLen = view.getUint32(o);
      o += 4;
      body = jsonDecode(utf8.decode(gzip.decode(data.sublist(o, o + jsonLen)))) as Map<String, dynamic>;
      o += jsonLen;
      while (o < data.length) {
        final nLen = view.getUint16(o);
        o += 2;
        final name = utf8.decode(data.sublist(o, o + nLen));
        o += nLen;
        final len = view.getUint32(o);
        o += 4;
        files[name] = Uint8List.sublistView(data, o, o + len);
        o += len;
      }
    } catch (_) {
      // Opened with the right passphrase but not laid out as a backup.
      throw NotABackup();
    }
    final schema = body['schema'];
    if (schema != null && schema is! int) throw NotABackup();
    if (schema is int && schema > AppDb.latestSchema) throw NewerBackup();
    final tables = body['tables'];
    final created = DateTime.tryParse('${body['created']}');
    if (tables is! Map<String, dynamic> || created == null) throw NotABackup();
    _checkNames(tables, files.keys);
    return BackupContents(created, tables, files, schema: schema as int?);
  }

  static Future<BackupContents> _openV1(Uint8List bytes, String pass) async {
    Map<String, dynamic> env;
    try {
      env = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw NotABackup();
    }
    if (env['format'] != format) throw NotABackup();
    final key = SecretKey(await _derive(pass, base64Decode(env['salt'] as String), _iterationsOf(env['iterations'])));
    final box = SecretBox(
      base64Decode(env['data'] as String),
      nonce: base64Decode(env['nonce'] as String),
      mac: Mac(base64Decode(env['mac'] as String)),
    );
    List<int> clear;
    try {
      clear = await AesGcm.with256bits().decrypt(box, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw WrongPassphrase();
    }
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(gzip.decode(clear))) as Map<String, dynamic>;
    } catch (_) {
      throw NotABackup();
    }
    final tables = body['tables'];
    final created = DateTime.tryParse('${body['created']}');
    if (tables is! Map<String, dynamic> || created == null) throw NotABackup();
    _checkNames(tables, const []);
    return BackupContents(created, tables, const {});
  }

  /// Replaces everything on the phone with the backup, files included.
  ///
  /// Safe if the app is stopped part way or the backup cannot be applied: the backup's
  /// files are written first, next to the current ones, then the records are swapped in
  /// one transaction, and only then are files no record uses any more removed. Until that
  /// transaction commits, the phone keeps its current records and every file they use.
  /// (File names are random and a stored file never changes, so a backup file with the
  /// same name as a current one holds the same content.)
  static Future<void> restore(AppDb db, BackupContents c) async {
    SecureFiles.reset();
    try {
      for (final e in c.files.entries) {
        await SecureFiles.saveNamed(db, e.key, e.value);
      }
      // Older backups (and those from 0.2.1, which did not record a schema) may hold
      // reminders without their link to a date field. See linkExistingAutoReminders.
      await db.replaceAll(c.tables, linkOldReminders: (c.schema ?? 0) < AppDb.latestSchema);
    } finally {
      await SecureFiles.removeUnused(await db.fileNamesInUse());
    }
  }

  /// Opens the phone's share sheet so the user picks where the file goes.
  /// The copy for the share target is cleared with the other temporary files.
  static Future<bool> share(Uint8List bytes, String name) async {
    final f = await SecureFiles.writeTemp(name, bytes);
    final res = await Share.shareXFiles(
      [XFile(f.path, mimeType: 'application/octet-stream', name: name)],
      subject: name,
    );
    return res.status != ShareResultStatus.dismissed;
  }

  /// Android's own save dialog (see MainActivity.kt).
  static const saveChannel = MethodChannel('kukira/save');

  static const _phoneProviders = {
    'com.android.externalstorage.documents',
    'com.android.providers.downloads.documents',
    'com.android.providers.media.documents',
  };
  static const _cloudProviders = ['com.google.android.apps.docs', 'skydrive', 'onedrive', 'dropbox'];

  /// Where a file saved through Android's save dialog went, from the authority of the
  /// document provider that took it: 'folder' for a folder on the phone (internal storage,
  /// SD card, Downloads), 'cloud' for Google Drive, OneDrive or Dropbox, and 'other' for any
  /// other app, about which nothing is claimed.
  static String placeOf(String authority) {
    final a = authority.toLowerCase();
    if (_phoneProviders.contains(a)) return 'folder';
    if (_cloudProviders.any(a.contains)) return 'cloud';
    return 'other';
  }

  /// Saves through Android's own save dialog, whose places are the folders on the phone and
  /// the installed cloud apps. The app that owns the place takes the file (a cloud app does
  /// the upload), so Kukira itself never goes online. Returns where the file went, as
  /// [placeOf] tells it from the dialog's answer rather than from what was picked in
  /// Kukira, or null when the owner backed out.
  static Future<String?> saveWithDialog(Uint8List bytes, String name) async {
    final authority = await saveChannel.invokeMethod<String>('createDocument', {'name': name, 'bytes': bytes});
    return authority == null ? null : placeOf(authority);
  }

  static Future<Uint8List?> pick() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (r == null || r.files.isEmpty) return null;
      final f = r.files.single;
      if (f.bytes != null) return f.bytes;
      if (f.path != null) return await File(f.path!).readAsBytes();
      return null;
    } finally {
      // The file picker leaves a copy of the picked file in the cache.
      await SecureFiles.clearPickerCopies();
    }
  }
}
