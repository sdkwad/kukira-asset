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

/// Thrown when a backup opened with the right passphrase is damaged or cut short: a chunk
/// does not match its seal, or the last one is missing.
class DamagedBackup implements Exception {}

/// A finished backup file, written into [SecureFiles.outgoing]. [missing] counts documents
/// and photos that could not be read and are therefore not in it. [discard] removes it once
/// it has been saved or shared.
class BackupFile {
  BackupFile(this.file, this.missing);
  final File file;
  final int missing;

  String get name => file.uri.pathSegments.last;

  Future<void> discard() async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Emptied at the next start anyway.
    }
  }
}

class BackupContents {
  BackupContents(this.created, this.tables, this.files, {this.schema}) : _source = null;
  BackupContents._(this.created, this.tables, this.files, this.schema, this._source);
  final DateTime created;
  final Map<String, dynamic> tables;

  /// Database schema of the app that made the backup. Null for backups made before 0.2.2.
  final int? schema;

  /// Formats 1 and 2: the decrypted documents and photos by file name. Empty for format 3,
  /// whose files are read from the backup file one at a time ([eachFile]).
  final Map<String, Uint8List> files;

  final _Chunked? _source;

  int count(String table) => ((tables[table] as List?) ?? const []).length;

  int get photoCount => ((tables['documents'] as List?) ?? const []).where((d) => (d as Map)['docType'] == 'photo').length;

  /// Hands every document and photo in the backup to [use], one at a time. For format 3 the
  /// backup file is read again a chunk at a time, every chunk checked against its seal, and
  /// this throws [DamagedBackup] or [NotABackup] if any part is wrong, including the end.
  Future<void> eachFile(Future<void> Function(String name, Uint8List bytes) use) async {
    final src = _source;
    if (src == null) {
      for (final e in files.entries) {
        await use(e.key, e.value);
      }
      return;
    }
    await src.eachFile(use);
  }
}

/// The parts of a format 3 file needed to read it again.
class _Chunked {
  _Chunked(this.file, this.key, this.prefix, this.size, this.start);
  final File file;
  final List<int> key;
  final List<int> prefix;
  final int size;
  final int start;

  Future<T> read<T>(Future<T> Function(_ChunkReader r) job) async {
    final raf = await file.open();
    try {
      return await job(_ChunkReader(raf, key, prefix, size, start, await raf.length() - start));
    } finally {
      await raf.close();
    }
  }

  Future<void> eachFile(Future<void> Function(String name, Uint8List bytes) use) => read((r) async {
        await r.take(await r.u32()); // the records, read when the backup was opened
        while (!r.atEnd) {
          final nameBytes = await r.take(await r.u16());
          final String name;
          try {
            name = utf8.decode(nameBytes);
          } on FormatException {
            throw NotABackup();
          }
          if (!SecureFiles.isSafeName(name)) throw NotABackup();
          await use(name, await r.take(await r.u32()));
        }
      });
}

/// The nonce of chunk [index]: the backup's 8-byte prefix and the index. The index
/// 0xFFFFFFFF is kept for the passphrase check.
List<int> _chunkNonce(List<int> prefix, int index) {
  final n = Uint8List(12)..setRange(0, 8, prefix);
  ByteData.sublistView(n).setUint32(8, index);
  return n;
}

const _checkIndex = 0xFFFFFFFF;
final _checkAad = utf8.encode('kukira-check');

// The sealing and opening run on another isolate. They are top-level functions, so what is
// sent there holds only these values, never the file being written or read.

Future<Uint8List> _sealChunk(Uint8List plain, List<int> key, List<int> nonce, List<int> aad) => Isolate.run(() async {
      final box = await AesGcm.with256bits().encrypt(plain, secretKey: SecretKey(key), nonce: nonce, aad: aad);
      return (BytesBuilder(copy: false)
            ..add(box.cipherText)
            ..add(box.mac.bytes))
          .takeBytes();
    });

/// Throws [SecretBoxAuthenticationError] unless [check] is the seal of an empty message under
/// [key], which means the passphrase is right.
Future<void> _openCheck(List<int> key, List<int> prefix, List<int> check) => Isolate.run(() async {
      await AesGcm.with256bits().decrypt(SecretBox(const <int>[], nonce: _chunkNonce(prefix, _checkIndex), mac: Mac(check)), secretKey: SecretKey(key), aad: _checkAad);
    });

/// Throws [SecretBoxAuthenticationError] when [sealed] does not match its seal.
Future<Uint8List> _openChunk(Uint8List sealed, List<int> key, List<int> nonce, List<int> aad) => Isolate.run(() async {
      final n = sealed.length;
      final box = SecretBox(Uint8List.sublistView(sealed, 0, n - 16), nonce: nonce, mac: Mac(Uint8List.sublistView(sealed, n - 16)));
      final clear = await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(key), aad: aad);
      return clear is Uint8List ? clear : Uint8List.fromList(clear);
    });

/// Seals plaintext a chunk at a time and writes it to [_out]. Only the chunk being sealed is
/// held in memory.
class _ChunkWriter {
  _ChunkWriter(this._out, this._key, this._prefix, this._size);
  final RandomAccessFile _out;
  final List<int> _key;
  final List<int> _prefix;
  final int _size;
  final _buf = BytesBuilder();
  var _index = 0;

  Future<void> add(List<int> data) async {
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);
    var o = 0;
    // A chunk is sealed only once more than a chunk is waiting, so the last one is always
    // left for [close], which marks it as last.
    while (_buf.length + (bytes.length - o) > _size) {
      final fill = _size - _buf.length;
      _buf.add(Uint8List.sublistView(bytes, o, o + fill));
      o += fill;
      await _seal(_buf.takeBytes(), last: false);
    }
    _buf.add(Uint8List.sublistView(bytes, o));
  }

  Future<void> u16(int v) => add((ByteData(2)..setUint16(0, v)).buffer.asUint8List());
  Future<void> u32(int v) => add((ByteData(4)..setUint32(0, v)).buffer.asUint8List());

  Future<void> close() => _seal(_buf.takeBytes(), last: true);

  Future<void> _seal(Uint8List plain, {required bool last}) async {
    await _out.writeFrom(await _sealChunk(plain, _key, _chunkNonce(_prefix, _index++), [last ? 1 : 0]));
  }
}

/// Reads and opens the chunks of a format 3 file in order. Every chunk is checked against
/// its seal before any of it is used, and the file must end with the chunk marked as last.
class _ChunkReader {
  _ChunkReader(this._raf, this._key, this._prefix, this._size, this._start, this._length);
  final RandomAccessFile _raf;
  final List<int> _key;
  final List<int> _prefix;
  final int _size;
  final int _start;
  final int _length;
  var _index = 0;
  var _pos = 0;
  Uint8List _cur = Uint8List(0);
  var _curPos = 0;

  /// Every chunk has been read and the plaintext used up.
  bool get atEnd => _pos >= _length && _curPos >= _cur.length;

  /// Plaintext still to come, at most: a sealed chunk is never shorter than its plaintext.
  int get _left => (_length - _pos) + (_cur.length - _curPos);

  Future<void> _next() async {
    final sealedSize = _size + 16;
    final remaining = _length - _pos;
    // The backup goes on past the end of the file: cut short.
    if (remaining <= 0) throw DamagedBackup();
    final last = remaining <= sealedSize;
    final n = last ? remaining : sealedSize;
    // The last chunk always holds at least one byte, plus its 16-byte seal.
    if (n < 17) throw DamagedBackup();
    await _raf.setPosition(_start + _pos);
    final sealed = await _raf.read(n);
    if (sealed.length != n) throw DamagedBackup();
    _pos += n;
    try {
      _cur = await _openChunk(sealed, _key, _chunkNonce(_prefix, _index++), [last ? 1 : 0]);
    } on SecretBoxAuthenticationError {
      throw DamagedBackup();
    }
    _curPos = 0;
  }

  /// The next [n] bytes of plaintext. More than the file can still hold means it was cut short.
  Future<Uint8List> take(int n) async {
    if (n < 0) throw NotABackup();
    if (n > _left) throw DamagedBackup();
    if (n <= _cur.length - _curPos) {
      final r = Uint8List.sublistView(_cur, _curPos, _curPos + n);
      _curPos += n;
      return r;
    }
    final b = BytesBuilder();
    var need = n;
    while (need > 0) {
      if (_curPos >= _cur.length) await _next();
      final here = min(need, _cur.length - _curPos);
      b.add(Uint8List.sublistView(_cur, _curPos, _curPos + here));
      _curPos += here;
      need -= here;
    }
    return b.takeBytes();
  }

  Future<int> u16() async => ByteData.sublistView(await take(2)).getUint16(0);
  Future<int> u32() async => ByteData.sublistView(await take(4)).getUint32(0);
}

/// One encrypted file holding all records, documents and photos. The key comes from a
/// passphrase the user chooses (PBKDF2-HMAC-SHA256), and everything is sealed with AES-256-GCM.
///
/// The plaintext is: uint32 length + gzip(JSON body) + repeated (uint16 name length, name,
/// uint32 length, bytes). The JSON body is {created, schema, tables}; `schema` was added in
/// 0.2.2 and sits inside the encrypted part so it cannot be altered.
///
/// Format 3 (0.2.8 build 16, what [create] writes): "KUKIRA3\n" + header JSON + "\n" + chunks.
/// The plaintext is cut into chunks of `chunk` bytes, each sealed on its own: the nonce is the
/// header's 8-byte `nonce` and the chunk's number, and the last chunk has AAD [1], the others
/// [0], so a chunk cannot be moved, dropped or the file cut short without it showing. A chunk
/// is its ciphertext and its 16-byte MAC. The header's `check` is the MAC of an empty message
/// (chunk number 0xFFFFFFFF, AAD "kukira-check"), so a wrong passphrase is told at once. A
/// backup is written and read a chunk at a time, so neither making nor restoring one needs
/// the whole file in memory, and no part of it is used before its seal is checked.
///
/// Format 2 (0.2.0 to 0.2.8 build 15): "KUKIRA2\n" + header JSON + "\n" + one ciphertext of
/// the whole plaintext. Format 1 (0.1.0, JSON envelope, no files). Both can still be restored.
class Backup {
  static const format = 'kukira-backup';
  static const iterations = 150000;
  static final _magic = utf8.encode('KUKIRA2\n');
  static final _magic3 = utf8.encode('KUKIRA3\n');

  /// Plaintext bytes per chunk in format 3.
  static const chunkSize = 1 << 20;
  static const _minChunk = 4096;
  static const _maxChunk = 16 << 20;

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

  /// Writes a backup of everything into [SecureFiles.outgoing] in format 3, one file and one
  /// chunk at a time, so even a large backup never has to fit in memory. [chunk] is for tests.
  static Future<BackupFile> create(AppDb db, String pass, {int chunk = chunkSize}) async {
    final tables = await db.exportTables();
    final names = <String>{
      for (final d in tables['documents']!) d['filePath'] as String,
      for (final a in tables['assets']!)
        if (a['photoPath'] != null) a['photoPath'] as String,
    };
    var missing = 0;
    Stream<(String, Uint8List)> files() async* {
      for (final n in names) {
        final Uint8List bytes;
        try {
          // Not kept in the picture cache: a backup reads every file once.
          bytes = await SecureFiles.read(db, n, keep: false);
        } catch (e) {
          ErrorLog.record('backup.missingFile', e);
          // A missing file should not stop the backup of everything else, but the user is told.
          missing++;
          continue;
        }
        yield (n, bytes);
      }
    }

    final body = {'created': DateTime.now().toIso8601String(), 'schema': AppDb.latestSchema, 'tables': tables};
    final f = await SecureFiles.outgoing(fileName(DateTime.now()));
    await _write3(f, body, files(), pass, chunk);
    return BackupFile(f, missing);
  }

  /// Writes a format 3 backup of [body] and [files] into [SecureFiles.outgoing], so tests can
  /// make any backup, as [pack] does for format 2.
  static Future<File> pack3(Map<String, dynamic> body, Map<String, Uint8List> files, String pass, {int chunk = chunkSize}) async {
    final f = await SecureFiles.outgoing('made-by-test.kukira');
    await _write3(f, body, Stream.fromIterable([for (final e in files.entries) (e.key, e.value)]), pass, chunk);
    return f;
  }

  static Future<void> _write3(File f, Map<String, dynamic> body, Stream<(String, Uint8List)> files, String pass, int chunk) async {
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final prefix = List<int>.generate(8, (_) => rnd.nextInt(256));
    final key = await _derive(pass, salt, iterations);
    final check = await _check(key, prefix);
    final header = utf8.encode(jsonEncode({
      'format': format,
      'version': 3,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(prefix),
      'chunk': chunk,
      'check': base64Encode(check),
    }));
    try {
      final raf = await f.open(mode: FileMode.write);
      try {
        await raf.writeFrom(_magic3);
        await raf.writeFrom(header);
        await raf.writeByte(10);
        final w = _ChunkWriter(raf, key, prefix, chunk);
        final json = gzip.encode(utf8.encode(jsonEncode(body)));
        await w.u32(json.length);
        await w.add(json);
        await for (final (name, bytes) in files) {
          final nameBytes = utf8.encode(name);
          await w.u16(nameBytes.length);
          await w.add(nameBytes);
          await w.u32(bytes.length);
          await w.add(bytes);
        }
        await w.close();
        await raf.flush();
      } finally {
        await raf.close();
      }
    } catch (_) {
      await BackupFile(f, 0).discard();
      rethrow;
    }
  }

  /// The seal of an empty message under [key]. Kept in the header, it tells a wrong
  /// passphrase at once, before any chunk is read.
  static Future<List<int>> _check(List<int> key, List<int> prefix) => Isolate.run(() async {
        final box = await AesGcm.with256bits().encrypt(const <int>[], secretKey: SecretKey(key), nonce: _chunkNonce(prefix, _checkIndex), aad: _checkAad);
        return box.mac.bytes;
      });

  /// Seals a backup body and its files into the format 2 layout, as 0.2.0 to 0.2.8 build 15
  /// made them. Kept so tests can make backups as those versions did.
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

  static bool _starts(Uint8List bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  /// Opens a backup file. Format 3 is read a chunk at a time: here only up to the records,
  /// which the owner checks before restoring; its documents and photos are read when they
  /// are restored ([BackupContents.eachFile]). Older formats are read whole, as they were made.
  static Future<BackupContents> openFile(File f, String pass) async {
    final raf = await f.open();
    final Uint8List head;
    try {
      head = await raf.read(_magic3.length);
    } finally {
      await raf.close();
    }
    if (_starts(head, _magic3)) return _openV3(f, pass);
    return open(await f.readAsBytes(), pass);
  }

  /// Opens a format 1 or 2 backup held in memory.
  static Future<BackupContents> open(Uint8List bytes, String pass) async {
    if (_starts(bytes, _magic)) return _openV2(bytes, pass);
    return _openV1(bytes, pass);
  }

  static Future<BackupContents> _openV3(File f, String pass) async {
    final total = await f.length();
    final Uint8List head;
    final raf = await f.open();
    try {
      await raf.setPosition(_magic3.length);
      head = await raf.read(min(4096, total - _magic3.length));
    } finally {
      await raf.close();
    }
    final nl = head.indexOf(10);
    if (nl < 0) throw NotABackup();
    final Map<String, dynamic> h;
    try {
      h = jsonDecode(utf8.decode(head.sublist(0, nl))) as Map<String, dynamic>;
    } catch (_) {
      throw NotABackup();
    }
    if (h['format'] != format || h['version'] != 3) throw NotABackup();
    final iterations = _iterationsOf(h['iterations']);
    final chunk = h['chunk'];
    if (chunk is! int || chunk < _minChunk || chunk > _maxChunk) throw NotABackup();
    final List<int> salt;
    final List<int> prefix;
    final List<int> check;
    try {
      salt = base64Decode(h['salt'] as String);
      prefix = base64Decode(h['nonce'] as String);
      check = base64Decode(h['check'] as String);
    } catch (_) {
      throw NotABackup();
    }
    if (salt.isEmpty || prefix.length != 8 || check.length != 16) throw NotABackup();
    final key = await _derive(pass, salt, iterations);
    try {
      await _openCheck(key, prefix, check);
    } on SecretBoxAuthenticationError {
      throw WrongPassphrase();
    }
    final src = _Chunked(f, key, prefix, chunk, _magic3.length + nl + 1);
    final body = await src.read((r) async {
      final json = await r.take(await r.u32());
      try {
        return jsonDecode(utf8.decode(gzip.decode(json))) as Map<String, dynamic>;
      } catch (_) {
        throw NotABackup();
      }
    });
    return _contents(body, const {}, source: src);
  }

  /// Checks the body of an opened backup and what it names.
  static BackupContents _contents(Map<String, dynamic> body, Map<String, Uint8List> files, {_Chunked? source}) {
    final schema = body['schema'];
    if (schema != null && schema is! int) throw NotABackup();
    if (schema is int && schema > AppDb.latestSchema) throw NewerBackup();
    final tables = body['tables'];
    final created = DateTime.tryParse('${body['created']}');
    if (tables is! Map<String, dynamic> || created == null) throw NotABackup();
    _checkNames(tables, files.keys);
    return BackupContents._(created, tables, files, schema as int?, source);
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
    return _contents(body, files);
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
      // Format 3 is read from the file here, a chunk at a time, every chunk checked, and the
      // records are only swapped in once the whole file has proved good.
      await c.eachFile((name, bytes) => SecureFiles.saveNamed(db, name, bytes));
      // Older backups (and those from 0.2.1, which did not record a schema) may hold
      // reminders without their link to a date field. See linkExistingAutoReminders.
      await db.replaceAll(c.tables, linkOldReminders: (c.schema ?? 0) < AppDb.latestSchema);
    } finally {
      await SecureFiles.removeUnused(await db.fileNamesInUse());
    }
  }

  /// Opens the phone's share sheet so the user picks where the file goes. The share sheet
  /// takes its own copy, which is cleared with the other temporary files.
  static Future<bool> share(BackupFile b) async {
    final res = await Share.shareXFiles(
      [XFile(b.file.path, mimeType: 'application/octet-stream', name: b.name)],
      subject: b.name,
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
  /// The file goes to Android by its path and is copied there a piece at a time, so a large
  /// backup is never held in memory on either side.
  static Future<String?> saveWithDialog(BackupFile b) async {
    final authority = await saveChannel.invokeMethod<String>('createDocument', {'name': b.name, 'path': b.file.path});
    return authority == null ? null : placeOf(authority);
  }

  /// Lets the owner pick a backup file, and returns the file picker's copy of it (not its
  /// bytes: a large backup must not be read whole). The copy is read again when a format 3
  /// backup is restored; [SecureFiles.clearPickerCopies] removes it once that is done.
  static Future<File?> pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: false);
    final path = r?.files.singleOrNull?.path;
    return path == null ? null : File(path);
  }
}
