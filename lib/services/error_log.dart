import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/db.dart';
import 'files.dart';

class LoggedError {
  const LoggedError(this.at, this.where, this.what);
  final DateTime at;

  /// Which part of the app, e.g. `notifications.schedule`.
  final String where;

  /// The error's own message, shortened.
  final String what;

  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'where': where, 'what': what};

  static LoggedError fromJson(Map<String, dynamic> j) => LoggedError(DateTime.parse(j['at'] as String), j['where'] as String, j['what'] as String);

  String get line => '${at.toIso8601String().substring(0, 19).replaceFirst('T', ' ')}  $where  $what';
}

/// Errors the app caught and kept quiet (a notification that could not be scheduled, a
/// file that could not be read, a save that failed), so a problem on the phone can be
/// looked at later. Only where it happened and the error message are kept, never the
/// contents of records. Encrypted with the file key, in app storage outside the documents
/// folder, newest [max] entries. Writing it never touches the database, so it cannot
/// trigger a reload (and another error) in a loop.
class ErrorLog {
  static const max = 200;
  static AppDb? _db;
  static List<LoggedError>? _saved;
  static final _pending = <LoggedError>[];
  static Future<void> _chain = Future.value();

  static Future<File> _file() async => File(p.join((await getApplicationSupportDirectory()).path, 'error-log.enc'));

  /// Called once the database is open; errors recorded before that are saved now.
  static void attach(AppDb db) {
    _db = db;
    _saved = null;
    if (_pending.isNotEmpty) _queue();
  }

  /// Forgets everything in memory, as after a restart. The write chain starts again too,
  /// so a test never waits on a Future from an earlier test's zone.
  @visibleForTesting
  static void detach() {
    _db = null;
    _saved = null;
    _pending.clear();
    _chain = Future.value();
  }

  /// Never throws. The same error from the same place within a minute is kept once.
  static void record(String where, Object error) {
    var what = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (what.length > 300) what = '${what.substring(0, 300)}…';
    final e = LoggedError(DateTime.now(), where, what);
    final last = _pending.isNotEmpty ? _pending.last : (_saved?.lastOrNull);
    if (last != null && last.where == where && last.what == what && e.at.difference(last.at) < const Duration(minutes: 1)) return;
    _pending.add(e);
    if (_db != null) _queue();
  }

  static void _queue() => _chain = _chain.then((_) => _flush()).catchError((Object _) {});

  static Future<void> _flush() async {
    final db = _db;
    if (db == null || _pending.isEmpty) return;
    final all = [...await _load(db), ..._pending];
    _pending.clear();
    final kept = all.length > max ? all.sublist(all.length - max) : all;
    _saved = kept;
    await _write(db, kept);
  }

  /// Oldest first.
  static Future<List<LoggedError>> entries() async {
    await _chain;
    final db = _db;
    return [if (db != null) ...await _load(db), ..._pending];
  }

  static Future<void> clear() async {
    await _chain;
    _pending.clear();
    _saved = const [];
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Plain text to paste into a message, newest first.
  static String asText(List<LoggedError> list, {required String version}) =>
      ['Kukira Asset $version', for (final e in list.reversed) e.line].join('\n');

  static Future<List<LoggedError>> _load(AppDb db) async {
    final cached = _saved;
    if (cached != null) return cached;
    var loaded = <LoggedError>[];
    try {
      final f = await _file();
      if (await f.exists()) {
        final box = SecretBox.fromConcatenation(await f.readAsBytes(), nonceLength: 12, macLength: 16);
        final clear = await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(await SecureFiles.fileKey(db)));
        loaded = [for (final j in jsonDecode(utf8.decode(clear)) as List) LoggedError.fromJson(Map<String, dynamic>.from(j as Map))];
      }
    } catch (_) {
      // An unreadable log (for example after restoring onto a new phone) starts again.
    }
    return _saved = loaded;
  }

  static Future<void> _write(AppDb db, List<LoggedError> list) async {
    final plain = utf8.encode(jsonEncode([for (final e in list) e.toJson()]));
    final box = await AesGcm.with256bits().encrypt(plain, secretKey: SecretKey(await SecureFiles.fileKey(db)));
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(Uint8List.fromList(box.concatenation()), flush: true);
    await tmp.rename(f.path);
  }
}
