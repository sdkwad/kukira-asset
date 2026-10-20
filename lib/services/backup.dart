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

/// Thrown when the passphrase does not open the file.
class WrongPassphrase implements Exception {}

/// Thrown when the file is not a Kukira backup.
class NotABackup implements Exception {}

class BackupContents {
  BackupContents(this.created, this.tables);
  final DateTime created;
  final Map<String, dynamic> tables;

  int count(String table) => ((tables[table] as List?) ?? const []).length;
}

/// One encrypted file holding all records. The key comes from a passphrase the
/// user chooses (PBKDF2-HMAC-SHA256), and the data is sealed with AES-256-GCM.
class Backup {
  static const format = 'kukira-backup';
  static const version = 1;
  static const iterations = 150000;

  static String fileName(DateTime d) =>
      'kukira-backup-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.kukira';

  static Future<List<int>> _derive(String pass, List<int> salt, int iter) => Isolate.run(() async {
        final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iter, bits: 256);
        final k = await kdf.deriveKeyFromPassword(password: pass, nonce: salt);
        return k.extractBytes();
      });

  static Future<Uint8List> create(AppDb db, String pass) async {
    final tables = await db.exportTables();
    final plain = utf8.encode(jsonEncode({'created': DateTime.now().toIso8601String(), 'tables': tables}));
    final packed = gzip.encode(plain);
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final key = SecretKey(await _derive(pass, salt, iterations));
    final box = await AesGcm.with256bits().encrypt(packed, secretKey: key);
    final env = {
      'format': format,
      'version': version,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'data': base64Encode(box.cipherText),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(env)));
  }

  static Future<BackupContents> open(Uint8List bytes, String pass) async {
    Map<String, dynamic> env;
    try {
      env = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw NotABackup();
    }
    if (env['format'] != format) throw NotABackup();
    final salt = base64Decode(env['salt'] as String);
    final key = SecretKey(await _derive(pass, salt, env['iterations'] as int));
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
    return BackupContents(DateTime.parse(body['created'] as String), body['tables'] as Map<String, dynamic>);
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
