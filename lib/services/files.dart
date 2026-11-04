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

/// The file side of one save that also changes the database.
///
/// New files are written (with [add]) before the database change; files the change
/// replaces are only marked (with [remove]). [commit] runs the change in one transaction,
/// then deletes the marked files. If the change fails, the new files are deleted again
/// and the marked ones are kept. So a failed save or a stopped app never leaves a record
/// pointing at a missing file, and never half-saves a record.
class FileChanges {
  FileChanges(this.db);
  final AppDb db;
  final _added = <String>[];
  final _removed = <String>[];

  Future<String> add(Uint8List bytes, String ext) async {
    final name = await SecureFiles.save(db, bytes, ext);
    _added.add(name);
    return name;
  }

  void remove(String name) => _removed.add(name);

  Future<T> commit<T>(Future<T> Function() change) async {
    final T result;
    try {
      result = await db.transaction(change);
    } catch (_) {
      for (final n in _added) {
        await SecureFiles.delete(n);
      }
      rethrow;
    }
    for (final n in _removed) {
      await SecureFiles.delete(n);
    }
    return result;
  }
}

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

  /// The key that encrypts documents and photos (also used for the error log).
  static Future<Uint8List> fileKey(AppDb db) => _fileKey(db);

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
    final clean = _clean(ext);
    return '$id.${clean.isEmpty || clean.length > maxExt ? 'bin' : clean}';
  }

  static String _clean(String ext) => ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// The longest extension a new file gets. Anything longer is the end of a name that had no
  /// extension: the file picker calls everything after the last dot (or the whole name) one.
  static const maxExt = 16;

  static const _knownTypes = ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'];

  /// The type of [bytes] read from their first bytes, for the kinds of file Kukira takes in
  /// (PDF and pictures); null for anything else.
  static String? sniff(Uint8List bytes) {
    bool at(int from, List<int> sig) {
      if (bytes.length < from + sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (bytes[from + i] != sig[i]) return false;
      }
      return true;
    }

    if (at(0, const [0x25, 0x50, 0x44, 0x46])) return 'pdf'; // %PDF
    if (at(0, const [0xFF, 0xD8, 0xFF])) return 'jpg';
    if (at(0, const [0x89, 0x50, 0x4E, 0x47])) return 'png';
    if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'webp';
    if (at(0, 'GIF8'.codeUnits)) return 'gif';
    if (at(4, 'ftyp'.codeUnits) && (at(8, 'heic'.codeUnits) || at(8, 'heix'.codeUnits) || at(8, 'mif1'.codeUnits))) return 'heic';
    return null;
  }

  /// The extension a file is stored (or handed to a viewer) with: the one it came with when
  /// that is a kind Kukira knows, else the kind its bytes show, else the one it came with if
  /// it is short enough to be an extension, else "bin". A PDF picked from a cloud drive
  /// often has no extension in its name, so its name alone says nothing.
  static String extFor(String claimed, Uint8List bytes) {
    final clean = _clean(claimed);
    if (_knownTypes.contains(clean)) return clean;
    return sniff(bytes) ?? (clean.isNotEmpty && clean.length <= maxExt ? clean : 'bin');
  }

  /// A name the app could have made: letters, digits, dashes and underscores, an optional
  /// extension, nothing that could point outside the files folder ("../"). Names come from
  /// the database and from backups, and a backup can be made by someone else. The extension
  /// may be long: before 0.2.8 a file picked without one kept the end of its name as one
  /// (up to what fits in a file name), and those files must still open and restore.
  static bool isSafeName(String name) => name.length <= 251 && RegExp(r'^[A-Za-z0-9_-]{1,80}(\.[A-Za-z0-9]{1,218})?$').hasMatch(name);

  static String _checked(String name) {
    if (!isSafeName(name)) throw ArgumentError.value(name, 'name', 'not a stored file name');
    return name;
  }

  static String extOf(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  static bool isImage(String name) => const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'].contains(extOf(name));

  /// Encrypts [bytes] into a new file and returns its name.
  static Future<String> save(AppDb db, Uint8List bytes, String ext) async {
    final name = _newName(extFor(ext, bytes));
    await saveNamed(db, name, bytes);
    return name;
  }

  static Future<void> saveNamed(AppDb db, String name, Uint8List bytes) async {
    _checked(name);
    final key = await _fileKey(db);
    final sealed = await Isolate.run(() async {
      final box = await AesGcm.with256bits().encrypt(bytes, secretKey: SecretKey(key));
      return box.concatenation();
    });
    // Written next to the final name and then renamed, so a stopped app never leaves a
    // half-written file under a name the database points to.
    final dir = (await _dir()).path;
    final tmp = File(p.join(dir, '$name.enc.tmp'));
    await tmp.writeAsBytes(sealed, flush: true);
    await tmp.rename(p.join(dir, '$name.enc'));
  }

  /// The decrypted bytes of [name] when they are in memory already, so a picture can be
  /// drawn in the same frame instead of after a decrypt.
  static Uint8List? cached(String name) => _cache[name];

  /// The decrypted bytes of stored file [name]. Small files are kept in memory for the next
  /// read, unless [keep] is false (a backup reads every file once).
  static Future<Uint8List> read(AppDb db, String name, {bool keep = true}) async {
    _checked(name);
    final hit = _cache[name];
    if (hit != null) return hit;
    final key = await _fileKey(db);
    final f = File(p.join((await _dir()).path, '$name.enc'));
    final sealed = await f.readAsBytes();
    final clear = await Isolate.run(() async {
      final box = SecretBox.fromConcatenation(sealed, nonceLength: 12, macLength: 16);
      return Uint8List.fromList(await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(key)));
    });
    if (keep && clear.length < 3 * 1024 * 1024) {
      if (_cache.length > 40) _cache.remove(_cache.keys.first);
      _cache[name] = clear;
    }
    return clear;
  }

  static Future<void> delete(String name) async {
    if (!isSafeName(name)) return;
    _cache.remove(name);
    final f = File(p.join((await _dir()).path, '$name.enc'));
    if (await f.exists()) await f.delete();
  }

  /// Deletes every stored file whose name is not in [inUse], and any leftover partial writes.
  static Future<void> removeUnused(Set<String> inUse) async {
    _cache.removeWhere((name, _) => !inUse.contains(name));
    final d = await _dir();
    await for (final e in d.list()) {
      if (e is! File) continue;
      final base = p.basename(e.path);
      final keep = base.endsWith('.enc') && inUse.contains(base.substring(0, base.length - 4));
      if (!keep) await e.delete();
    }
  }

  /// Decrypts to a temporary file so the phone's own viewer can open it. Named after the
  /// title, cut short so a long title still makes a valid file name, with the extension the
  /// viewer goes by (see [extFor]: a file stored before 0.2.8 may have a made-up one).
  static Future<File> viewCopy(AppDb db, String name, String title) async {
    final bytes = await read(db, name);
    var safe = title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    if (safe.length > 60) safe = safe.substring(0, 60).trim();
    return writeTemp('${safe.isEmpty ? 'kukira' : safe}.${extFor(extOf(name), bytes)}', bytes);
  }

  /// Writes a file for another app to read (a viewer, or a share target) into the folder
  /// that [clearTemp] empties, so it never stays behind.
  static Future<File> writeTemp(String fileName, Uint8List bytes) async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'view'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final f = File(p.join(dir.path, fileName));
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  /// Returns false when the phone has no app that can open the file.
  static Future<bool> openExternal(AppDb db, String name, String title) async {
    final f = await viewCopy(db, name, title);
    final r = await OpenFilex.open(f.path);
    return r.type == ResultType.done;
  }

  static Future<void> shareCopy(AppDb db, String name, String title) async {
    final f = await viewCopy(db, name, title);
    await Share.shareXFiles([XFile(f.path)], subject: title);
  }

  /// How long a decrypted copy may stay for the phone's viewer or a share target to read it.
  static const tempLifetime = Duration(minutes: 5);

  /// The folder a new backup file is written into before it is saved or shared. It holds
  /// only encrypted backups, and is not swept while the app runs (the save dialog may stay
  /// open for long): the file is removed after it is saved, and the folder at start-up.
  static const outgoingFolder = 'backup-out';

  static Future<File> outgoing(String fileName) async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, outgoingFolder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, fileName));
  }

  /// The folders that hold decrypted copies for another app: Kukira's own, for the viewer
  /// and the share sheet, and the one the share sheet copies every shared file into
  /// (share_plus empties it only at the next share, so a shared document stayed there).
  static const handOverFolders = ['view', 'share_plus'];

  /// Removes decrypted copies left from viewing or sharing: all of them at start-up, and
  /// with [olderThan] only those at least that old, so a viewer or share target that is
  /// still reading a fresh copy is not cut off.
  static Future<void> clearTemp({Duration? olderThan}) async {
    final String tmp;
    try {
      tmp = (await getTemporaryDirectory()).path;
    } catch (_) {
      return;
    }
    for (final folder in [...handOverFolders, if (olderThan == null) outgoingFolder]) {
      try {
        final dir = Directory(p.join(tmp, folder));
        if (!await dir.exists()) continue;
        if (olderThan == null) {
          await dir.delete(recursive: true);
          continue;
        }
        final cutoff = DateTime.now().subtract(olderThan);
        await for (final e in dir.list(recursive: true)) {
          if (e is File && (await e.lastModified()).isBefore(cutoff)) await e.delete();
        }
      } catch (_) {}
    }
  }

  static final _pickerCopy = RegExp(r'^(file_picker$|scaled_|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})');

  /// Removes the plain copies the pickers leave in the cache, none of which they remove
  /// themselves: the file picker copies each picked file into "file_picker", and the photo
  /// picker copies a gallery photo into a folder named with a UUID, takes a camera photo
  /// into a UUID-named file and makes a "scaled_" copy. Kukira keeps only its encrypted
  /// file, so these go as soon as the picked bytes are read, and at start-up.
  static Future<void> clearPickerCopies() async {
    try {
      final tmp = await getTemporaryDirectory();
      await for (final e in tmp.list()) {
        if (!_pickerCopy.hasMatch(p.basename(e.path))) continue;
        try {
          await e.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
  }
}
