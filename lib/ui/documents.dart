import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/db.dart';
import '../domain/rules.dart';
import '../l10n/strings.dart';
import '../services/error_log.dart';
import '../services/files.dart';
import 'add_actions.dart';
import 'assets.dart';
import 'common.dart';

const docTypes = ['spa', 'geran', 'vp_letter', 'dlp', 'tax_bill', 'insurance', 'receipt', 'other'];

class Picked {
  const Picked(this.bytes, this.ext, [this.name]);
  final Uint8List bytes;
  final String ext;
  final String? name;
}

/// Tests only: answers [pickFile] instead of the camera, the gallery or the file picker.
@visibleForTesting
Future<Picked?> Function(String source)? debugPickFile;

/// camera | gallery | files
Future<Picked?> pickFile(BuildContext context, String source) async {
  final debug = debugPickFile;
  if (debug != null) return debug(source);
  try {
    if (source == 'files') {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      final f = r?.files.singleOrNull;
      if (f == null || f.bytes == null) return null;
      return Picked(f.bytes!, f.extension ?? SecureFiles.extOf(f.name), f.name);
    }
    final x = await ImagePicker().pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (x == null) return null;
    final ext = SecureFiles.extOf(x.name);
    return Picked(await x.readAsBytes(), ext.isEmpty ? 'jpg' : ext, x.name);
  } catch (e) {
    ErrorLog.record('document.pick', e);
    if (context.mounted) snack(context, context.s.couldNotRead);
    return null;
  } finally {
    // The pickers leave a plain copy of what was picked in the cache. Only the encrypted
    // file Kukira makes from the bytes is kept.
    await SecureFiles.clearPickerCopies();
  }
}

/// Shows an encrypted image from app storage. The file is decrypted once per name, not on
/// every rebuild (a scrolling page header rebuilds every frame), and an image already
/// decrypted shows at once instead of after a blank frame.
class SecureImage extends StatefulWidget {
  const SecureImage(this.name, {super.key, this.size, this.fit = BoxFit.cover, this.cacheWidth = 400, this.opacity = 1});
  final String name;
  final double? size;
  final BoxFit fit;
  final int? cacheWidth;

  /// Drawn with this opacity, without the offscreen layer an Opacity widget needs.
  final double opacity;

  /// Screenshots only: draws a test picture for [name] instead of reading an encrypted file,
  /// so asset photos can be pictured without a key. Never set in the app.
  @visibleForTesting
  static ImageProvider Function(String name)? debugImage;

  @override
  State<SecureImage> createState() => _SecureImageState();
}

class _SecureImageState extends State<SecureImage> {
  String? _loaded;
  Future<Uint8List>? _bytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(SecureImage old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) _load();
  }

  void _load() {
    if (_loaded == widget.name) return;
    _loaded = widget.name;
    _bytes = SecureImage.debugImage != null || SecureFiles.cached(widget.name) != null ? null : SecureFiles.read(context.db, widget.name);
  }

  Widget _image(Uint8List bytes) => Image.memory(
        bytes,
        width: widget.size,
        height: widget.size,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: true,
        opacity: widget.opacity >= 1 ? null : AlwaysStoppedAnimation(widget.opacity),
      );

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final debug = SecureImage.debugImage;
    if (debug != null) {
      return Image(image: debug(widget.name), width: size, height: size, fit: widget.fit, opacity: widget.opacity >= 1 ? null : AlwaysStoppedAnimation(widget.opacity));
    }
    final hit = SecureFiles.cached(widget.name);
    if (hit != null) return _image(hit);
    return FutureBuilder<Uint8List>(
      future: _bytes ??= SecureFiles.read(context.db, widget.name),
      builder: (c, snap) {
        if (snap.hasData) return _image(snap.data!);
        return Container(
          width: size,
          height: size,
          color: Theme.of(c).colorScheme.surfaceContainerHighest,
          child: snap.hasError ? const Icon(Icons.broken_image_outlined) : null,
        );
      },
    );
  }
}

Future<void> showPhoto(BuildContext context, String name) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SafeScaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Center(child: InteractiveViewer(maxScale: 5, child: SecureImage(name, fit: BoxFit.contain, cacheWidth: null))),
        ),
      ),
    );

/// A row of photo thumbnails, tappable to view.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip(this.photos, {super.key});
  final List<AssetDocument> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) => InkWell(
          onTap: () => showPhoto(c, photos[i].filePath),
          child: ClipRRect(borderRadius: BorderRadius.circular(10), child: SecureImage(photos[i].filePath, size: 84)),
        ),
      ),
    );
  }
}

/// Editable photo list used inside forms: existing photos plus new ones not saved yet.
class PhotoEditor extends StatelessWidget {
  const PhotoEditor({super.key, required this.existing, required this.added, required this.onChanged});
  final List<AssetDocument> existing;
  final List<Picked> added;
  final VoidCallback onChanged;

  Widget _thumb(BuildContext context, Widget img, VoidCallback onRemove) => Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 84, height: 84, child: img)),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            tooltip: context.s.remove,
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    Future<void> add(String src) async {
      final p = await pickFile(context, src);
      if (p == null) return;
      added.add(p);
      onChanged();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(s.photos),
      if (existing.isNotEmpty || added.isNotEmpty) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in existing)
            _thumb(context, SecureImage(d.filePath, size: 84), () {
              existing.remove(d);
              onChanged();
            }),
          for (final p in added)
            _thumb(context, Image.memory(p.bytes, fit: BoxFit.cover, cacheWidth: 300), () {
              added.remove(p);
              onChanged();
            }),
        ]),
        const SizedBox(height: 8),
      ],
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(icon: const Icon(Icons.photo_camera_outlined), label: Text(s.camera), onPressed: () => add('camera')),
        OutlinedButton.icon(icon: const Icon(Icons.photo_library_outlined), label: Text(s.gallery), onPressed: () => add('gallery')),
      ]),
    ]);
  }
}

// ================================================================ list

/// Every document, by asset: the three that matter most of each (those about to end first),
/// and "See N more". A search looks in names, types and assets, and in records too, where a
/// policy number is often kept in the notes.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

/// How many documents of an asset show before "See N more".
const docsPerAsset = 3;

/// Documents about to end first (soonest), then the rest newest first.
int compareDocs(AssetDocument a, AssetDocument b, DateTime today) {
  bool live(AssetDocument d) => d.expiry != null && !dayOnly(d.expiry!).isBefore(today);
  if (live(a) != live(b)) return live(a) ? -1 : 1;
  final byExpiry = live(a) ? a.expiry!.compareTo(b.expiry!) : 0;
  return byExpiry != 0 ? byExpiry : b.addedAt.compareTo(a.addedAt);
}

/// A record the search found, with where it was found when that is not its name.
typedef RecordHit = (UpkeepRecord record, String? where);

/// The records whose name, notes, shop, area or items contain [q].
List<RecordHit> searchRecords(Str s, World w, String q, {int? assetId}) {
  final needle = q.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  String? excerpt(String text) {
    final at = text.toLowerCase().indexOf(needle);
    if (at < 0) return null;
    final start = (at - 18).clamp(0, text.length);
    final end = (at + needle.length + 24).clamp(0, text.length);
    return '${start > 0 ? '…' : ''}${text.substring(start, end).replaceAll('\n', ' ')}${end < text.length ? '…' : ''}';
  }

  final hits = <RecordHit>[];
  for (final r in w.records) {
    if (assetId != null && r.assetId != assetId) continue;
    if (r.title.toLowerCase().contains(needle)) {
      hits.add((r, null));
      continue;
    }
    final fields = <(String, String?)>[
      (s.notes, r.notes),
      (s.vendor, r.vendorName),
      (s.area, r.area),
      for (final i in w.costItems[r.id] ?? const <CostItem>[]) (s.item, i.label),
    ];
    for (final (label, text) in fields) {
      final e = text == null ? null : excerpt(text);
      if (e != null) {
        hits.add((r, s.foundIn(label, e)));
        break;
      }
    }
  }
  return hits;
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _search = TextEditingController();
  String _type = 'all';
  int? _asset;
  final Set<int> _open = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// A filter as a button that opens its choices, instead of a long row of chips.
  Widget _filter<T>(String label, T value, List<(T, String)> options, ValueChanged<T> onPick) {
    final k = context.tokens;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: k.text,
        side: BorderSide(color: k.line),
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KSpace.controlRadius)),
      ),
      onPressed: () async {
        final v = await showModalBottomSheet<(T,)>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (c) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
              child: ListView(shrinkWrap: true, children: [
                for (final (o, name) in options)
                  ListTile(
                    title: Text(name),
                    selected: o == value,
                    trailing: o == value ? Icon(Icons.check, color: k.primary) : null,
                    onTap: () => Navigator.pop(c, (o,)),
                  ),
              ]),
            ),
          ),
        );
        if (v != null) onPick(v.$1);
      },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 4),
        const Icon(Icons.expand_more, size: 20),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final k = context.tokens;
      final theme = Theme.of(context);
      final t = today();
      final q = _search.text.trim();
      if (_asset != null && w.asset(_asset!) == null) _asset = null;
      final docs = w.files
          .where((d) => (_type == 'all' || d.docType == _type) && (_asset == null || d.assetId == _asset))
          .where((d) => q.isEmpty || '${d.title} ${s.docTypeName(d.docType)} ${w.asset(d.assetId)?.nickname ?? ''}'.toLowerCase().contains(q.toLowerCase()))
          .toList()
        ..sort((a, b) => compareDocs(a, b, t));

      final body = <Widget>[];
      if (q.isNotEmpty) {
        // Search: one list across assets, then the records that mention it.
        final records = searchRecords(s, w, q, assetId: _asset);
        if (docs.isNotEmpty) {
          body.addAll([SectionTitle(s.documentsTab, count: docs.length), CardList([for (final d in docs) DocTile(d, w, showAsset: true, highlight: q)])]);
        }
        if (records.isNotEmpty) {
          body.addAll([
            SectionTitle(s.alsoInRecords, count: records.length),
            CardList([
              for (final (r, where) in records)
                AppRow(
                  title: r.title,
                  highlight: q,
                  status: r.cost == null ? null : Text(s.rm(r.cost!), style: KText.row.copyWith(color: k.text, fontFeatures: const [FontFeature.tabularFigures()])),
                  meta: [w.asset(r.assetId)?.nickname ?? '', where ?? s.dShort(r.date)].join(' · '),
                  onTap: () => showRecordSheet(context, r.id),
                ),
            ]),
          ]);
        }
        if (body.isEmpty) body.add(Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 0), child: Text(s.noMatch)));
      } else {
        for (final a in w.assets) {
          final g = docs.where((d) => d.assetId == a.id).toList();
          if (g.isEmpty) continue;
          final all = _open.contains(a.id) || _asset != null || g.length <= docsPerAsset;
          body.addAll([
            SectionTitle(a.nickname, count: g.length),
            CardList([for (final d in all ? g : g.take(docsPerAsset)) DocTile(d, w)]),
            if (!all)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => setState(() => _open.add(a.id)), child: Text(s.seeMore(g.length - docsPerAsset))),
              ),
          ]);
        }
        if (body.isEmpty) body.add(Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 0), child: Text(s.noMatch)));
      }

      return SafeScaffold(
        floatingActionButton: w.assets.isEmpty
            ? null
            : FloatingActionButton.extended(
                heroTag: null,
                icon: const Icon(Icons.add),
                label: Text(s.addDocument),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentFormScreen(assetId: _asset))),
              ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, KSpace.fabClearance), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(header: true, child: Text(s.documentsTab, style: KText.screenTitle.copyWith(color: k.text))),
                if (w.files.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(s.docsCountEncrypted(w.files.length), style: KText.meta.copyWith(color: k.textMuted)),
                ],
              ]),
            ),
            if (w.files.isEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.description_outlined, size: 40, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(s.noDocsTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(w.assets.isEmpty ? s.addAssetFirst : s.noDocsBody),
                  ]),
                ),
              )
            else ...[
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: s.searchDocsHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(
                          tooltip: s.clear,
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_search.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _filter<int?>(
                  s.assetFilter(_asset == null ? s.all : w.asset(_asset!)!.nickname),
                  _asset,
                  [(null, s.all), for (final a in w.assets) (a.id, a.nickname)],
                  (v) => setState(() => _asset = v),
                ),
                _filter<String>(
                  s.typeFilter(_type == 'all' ? s.all : s.docTypeName(_type)),
                  _type,
                  [('all', s.all), for (final d in docTypes) (d, s.docTypeName(d))],
                  (v) => setState(() => _type = v),
                ),
              ]),
              ...body,
            ],
            const SizedBox(height: 16),
            Text(s.docsPrivacyNote, style: theme.textTheme.bodySmall),
          ]),
        ),
      );
    });
  }
}

class DocTile extends StatelessWidget {
  const DocTile(this.d, this.w, {super.key, this.showAsset = false, this.highlight});
  final AssetDocument d;
  final World w;
  final bool showAsset;

  /// Search text to mark in the name.
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    Widget? status;
    if (d.expiry != null) {
      final n = daysBetween(today(), d.expiry!);
      // An expired document is history (an older policy kept for the record), not an alarm.
      status = n < 0
          ? StatusLabel(s.expired, Tone.expired)
          : StatusLabel(s.expiresShort(s.dShort(d.expiry!)), n <= 30 ? Tone.dueSoon : Tone.upcoming);
    }
    final image = SecureFiles.isImage(d.filePath);
    return AppRow(
      leading: image
          ? ClipRRect(borderRadius: BorderRadius.circular(KSpace.controlRadius), child: SecureImage(d.filePath, size: 36, cacheWidth: 150))
          : const IconAvatar(Icons.description_outlined),
      title: d.title,
      highlight: highlight,
      status: status,
      meta: [
        if (showAsset) w.asset(d.assetId)?.nickname ?? '',
        s.docTypeName(d.docType),
        image ? s.fileImage : s.filePdf,
        if (!showAsset) d.linkedRecordId != null ? s.linkedToRecord : s.addedOn(s.dShort(d.addedAt)),
      ].join(' · '),
      onTap: () => showDocSheet(context, d.id),
    );
  }
}

Future<void> showDocSheet(BuildContext context, int docId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => WorldView(builder: (c, w) {
      final s = c.s;
      final d = w.documents.where((x) => x.id == docId).firstOrNull;
      if (d == null) return const SizedBox(height: 100);
      final img = SecureFiles.isImage(d.filePath);
      // A message shown from the sheet would be hidden behind it, so the sheet closes first.
      void tell(String msg) {
        if (sheet.mounted) Navigator.pop(sheet);
        if (context.mounted) snack(context, msg);
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(d.title, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (img)
              InkWell(
                onTap: () => showPhoto(c, d.filePath),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(height: 200, child: SecureImage(d.filePath, cacheWidth: 800))),
              ),
            if (img) const SizedBox(height: 12),
            Facts([
              (s.docType, s.docTypeName(d.docType)),
              (s.asset, w.asset(d.assetId)?.nickname ?? ''),
              (s.added, s.dLong(d.addedAt)),
              if (d.expiry != null) (s.expiry, s.dLong(d.expiry!)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: Text(s.open),
                  onPressed: () async {
                    final bool ok;
                    try {
                      ok = await SecureFiles.openExternal(c.db, d.filePath, d.title);
                    } catch (e) {
                      ErrorLog.record('document.open', e);
                      tell(s.fileNotOpened);
                      return;
                    }
                    if (!ok) tell(s.noViewer);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: Text(s.shareCopy),
                  onPressed: () async {
                    try {
                      await SecureFiles.shareCopy(c.db, d.filePath, d.title);
                    } catch (e) {
                      ErrorLog.record('document.share', e);
                      tell(s.fileNotOpened);
                    }
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(s.edit),
                  onPressed: () {
                    Navigator.pop(sheet);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentFormScreen(editId: d.id)));
                  },
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(s.delete),
                  onPressed: () async {
                    final ok = await confirm(c, title: s.deleteDocQ, body: s.deleteDocBody, ok: s.delete, danger: true);
                    if (!ok || !c.mounted) return;
                    final db = c.db;
                    final files = FileChanges(db)..remove(d.filePath);
                    await files.commit(() async {
                      if (d.linkedReminderId != null) await db.deleteReminder(d.linkedReminderId!);
                      await db.deleteDocument(d.id);
                    });
                    if (sheet.mounted) Navigator.pop(sheet);
                  },
                ),
              ),
            ]),
          ]),
        ),
      );
    }),
  );
}

// ================================================================ add / edit

class DocumentFormScreen extends StatefulWidget {
  const DocumentFormScreen({super.key, this.assetId, this.editId});
  final int? assetId;
  final int? editId;

  @override
  State<DocumentFormScreen> createState() => _DocumentFormState();
}

class _DocumentFormState extends State<DocumentFormScreen> {
  final _title = TextEditingController();
  Picked? _file;
  int? _assetId;
  String _type = 'other';
  DateTime? _expiry;
  bool _remind = true;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _load(World w) {
    if (_loaded) return;
    _loaded = true;
    final d = widget.editId == null ? null : w.documents.where((x) => x.id == widget.editId).firstOrNull;
    if (d != null) {
      _assetId = d.assetId;
      _title.text = d.title;
      _type = d.docType;
      _expiry = d.expiry;
      _remind = d.linkedReminderId != null;
    } else {
      _assetId = addStartAsset(w, widget.assetId);
    }
  }

  Future<void> _pick(String src) async {
    final p = await pickFile(context, src);
    if (p == null || !mounted) return;
    setState(() {
      _file = p;
      if (_title.text.isEmpty && p.name != null && src == 'files') {
        final n = p.name!;
        final dot = n.lastIndexOf('.');
        _title.text = dot > 0 ? n.substring(0, dot) : n;
      }
    });
  }

  Future<void> _save(World w) async {
    final s = context.s;
    if (_title.text.trim().isEmpty) return setState(() => _error = s.errDocTitle);
    setState(() => _saving = true);
    final db = context.db;
    final title = _title.text.trim();
    final files = FileChanges(db);
    try {
      // A new document's file is written first; its reminder and row are saved together.
      final name = widget.editId == null ? await files.add(_file!.bytes, _file!.ext) : null;
      await files.commit(() async {
        if (widget.editId == null) {
          int? remId;
          if (_expiry != null && _remind) {
            remId = await db.addReminder(RemindersCompanion(
              assetId: Value(_assetId!),
              title: Value(s.docExpires(title)),
              ruleType: const Value('fixed'),
              dueDate: Value(_expiry),
              leadDays: const Value(30),
              category: const Value('document'),
            ));
          }
          await db.addDocument(DocumentsCompanion(
            assetId: Value(_assetId!),
            filePath: Value(name!),
            title: Value(title),
            docType: Value(_type),
            expiry: Value(_expiry),
            linkedReminderId: Value(remId),
          ));
        } else {
          final d = w.documents.firstWhere((x) => x.id == widget.editId);
          int? remId = d.linkedReminderId;
          if (remId != null && (_expiry == null || !_remind)) {
            await db.deleteReminder(remId);
            remId = null;
          } else if (remId != null) {
            // The reminder follows the document, also to another asset. Only a new expiry
            // brings back a reminder that was marked done or snoozed.
            final moved = _expiry != d.expiry;
            await db.updateReminder(
              remId,
              RemindersCompanion(
                assetId: Value(_assetId!),
                title: Value(s.docExpires(title)),
                dueDate: Value(_expiry),
                done: moved ? const Value(false) : const Value.absent(),
                snoozedUntil: moved ? const Value(null) : const Value.absent(),
              ),
            );
          } else if (_expiry != null && _remind) {
            remId = await db.addReminder(RemindersCompanion(
              assetId: Value(_assetId!),
              title: Value(s.docExpires(title)),
              ruleType: const Value('fixed'),
              dueDate: Value(_expiry),
              leadDays: const Value(30),
              category: const Value('document'),
            ));
          }
          await db.updateDocument(d.id, DocumentsCompanion(
            assetId: Value(_assetId!),
            title: Value(title),
            docType: Value(_type),
            expiry: Value(_expiry),
            linkedReminderId: Value(remId),
            // A record belongs to its asset: moved to another one, the document leaves it.
            linkedRecordId: _assetId == d.assetId ? const Value.absent() : const Value(null),
          ));
        }
      });
    } catch (e) {
      ErrorLog.record('document.save', e);
      if (mounted) {
        setState(() => _saving = false);
        snack(context, s.couldNotSave);
      }
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    snack(context, _expiry != null && _remind ? s.docSavedWithReminder(s.dLong(_expiry!.subtract(const Duration(days: 30)))) : s.docSaved);
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      _load(w);
      final s = context.s;
      final theme = Theme.of(context);
      if (_assetId == null && w.assets.isNotEmpty) return AssetChoiceScreen(title: s.attachDocument, w: w, onPick: (id) => setState(() => _assetId = id));
      if (_assetId == null) return SafeScaffold(appBar: AppBar(), body: Center(child: Text(s.addAssetFirst)));
      final editing = widget.editId != null;
      if (!editing && _file == null) {
        return SafeScaffold(
          appBar: AppBar(title: Text(s.attachDocument)),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Text(s.chooseSource, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final (src, icon, label) in [
              ('camera', Icons.photo_camera_outlined, s.camera),
              ('gallery', Icons.photo_library_outlined, s.gallery),
              ('files', Icons.folder_outlined, s.filesPdf),
            ]) ...[
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(icon, size: 32, color: theme.colorScheme.primary),
                  title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pick(src),
                ),
              ),
              const SizedBox(height: 10),
            ],
            NoteBox(s.docCopiedNote, icon: Icons.lock_outline),
          ]),
        );
      }
      return SafeScaffold(
        appBar: AppBar(title: Text(editing ? s.editDocument : s.aboutDocument)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          if (_file != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SecureFiles.isImage('x.${_file!.ext}')
                  ? Image.memory(_file!.bytes, height: 180, fit: BoxFit.cover, cacheWidth: 800)
                  : Container(
                      height: 80,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 32),
                        const SizedBox(width: 8),
                        Flexible(child: Text(_file!.name ?? 'PDF')),
                      ]),
                    ),
            ),
            const SizedBox(height: 14),
          ],
          DropdownButtonFormField<int>(
            value: _assetId,
            decoration: InputDecoration(labelText: s.asset, border: const OutlineInputBorder()),
            items: [for (final x in w.assets) DropdownMenuItem(value: x.id, child: Text(x.nickname))],
            onChanged: (v) => setState(() => _assetId = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.title, hintText: s.docTitleHint, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          FieldLabel(s.docType),
          ChoiceRow<String>(options: docTypes, value: _type, label: s.docTypeName, onChanged: (v) => setState(() => _type = v)),
          const SizedBox(height: 14),
          DateField(label: s.expiryOptional, value: _expiry, onChanged: (d) => setState(() => _expiry = d)),
          if (_expiry != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _remind,
              title: Text(s.remindBeforeExpiry),
              onChanged: (v) => setState(() => _remind = v ?? false),
            ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : () => _save(w),
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(s.saveDocument),
          ),
        ]),
      );
    });
  }
}
