import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/db.dart';
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
      } catch (_) {
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
    final key = await _derive(pass, base64Decode(h['salt'] as String), h['iterations'] as int);
    final box = SecretBox(
      Uint8List.sublistView(bytes, nl + 1),
      nonce: base64Decode(h['nonce'] as String),
      mac: Mac(base64Decode(h['mac'] as String)),
    );
    List<int> clear;
    try {
      clear = await Isolate.run(() => AesGcm.with256bits().decrypt(box, secretKey: SecretKey(key)));
    } on SecretBoxAuthenticationError {
      throw WrongPassphrase();
    }
    final data = clear is Uint8List ? clear : Uint8List.fromList(clear);
    final view = ByteData.sublistView(data);
    var o = 0;
    final jsonLen = view.getUint32(o);
    o += 4;
    final body = jsonDecode(utf8.decode(gzip.decode(data.sublist(o, o + jsonLen)))) as Map<String, dynamic>;
    o += jsonLen;
    final files = <String, Uint8List>{};
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
    final schema = body['schema'] as int?;
    if (schema != null && schema > AppDb.latestSchema) throw NewerBackup();
    return BackupContents(DateTime.parse(body['created'] as String), body['tables'] as Map<String, dynamic>, files, schema: schema);
  }

  static Future<BackupContents> _openV1(Uint8List bytes, String pass) async {
    Map<String, dynamic> env;
    try {
      env = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw NotABackup();
    }
    if (env['format'] != format) throw NotABackup();
    final key = SecretKey(await _derive(pass, base64Decode(env['salt'] as String), env['iterations'] as int));
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
    final body = jsonDecode(utf8.decode(gzip.decode(clear))) as Map<String, dynamic>;
    return BackupContents(DateTime.parse(body['created'] as String), body['tables'] as Map<String, dynamic>, const {});
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
      // Backups from before schema 3 (and from 0.2.1, which did not record it) may hold
      // road tax and insurance reminders without their link to the date field.
      await db.replaceAll(c.tables, linkOldReminders: (c.schema ?? 0) < 3);
    } finally {
      await SecureFiles.removeUnused(await db.fileNamesInUse());
    }
  }

  /// Opens the phone's share sheet so the user picks where the file goes.
  static Future<bool> share(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, name));
    await f.writeAsBytes(bytes, flush: true);
    final res = await Share.shareXFiles(
      [XFile(f.path, mimeType: 'application/octet-stream', name: name)],
      subject: name,
    );
    return res.status != ShareResultStatus.dismissed;
  }

  /// Saves into a folder the user picks on the phone.
  static Future<bool> saveToFolder(Uint8List bytes, String name) async {
    final path = await FilePicker.platform.saveFile(fileName: name, bytes: bytes);
    return path != null;
  }

  static Future<Uint8List?> pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (r == null || r.files.isEmpty) return null;
    final f = r.files.single;
    if (f.bytes != null) return f.bytes;
    if (f.path != null) return File(f.path!).readAsBytes();
    return null;
  }
}
