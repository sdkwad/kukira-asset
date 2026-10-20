import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/db.dart';
import '../domain/rules.dart';
import '../services/files.dart';
import 'common.dart';

const docTypes = ['spa', 'geran', 'vp_letter', 'dlp', 'tax_bill', 'insurance', 'receipt', 'other'];

class Picked {
  const Picked(this.bytes, this.ext, [this.name]);
  final Uint8List bytes;
  final String ext;
  final String? name;
}

/// camera | gallery | files
Future<Picked?> pickFile(BuildContext context, String source) async {
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
  } catch (_) {
    if (context.mounted) snack(context, context.s.couldNotRead);
    return null;
  }
}

/// Shows an encrypted image from app storage.
class SecureImage extends StatelessWidget {
  const SecureImage(this.name, {super.key, this.size, this.fit = BoxFit.cover, this.cacheWidth = 400});
  final String name;
  final double? size;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: SecureFiles.read(context.db, name),
      builder: (c, snap) {
        if (snap.hasData) {
          return Image.memory(snap.data!, width: size, height: size, fit: fit, cacheWidth: cacheWidth, gaplessPlayback: true);
        }
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
        builder: (_) => Scaffold(
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

/// Saves new photos and deletes removed ones for a record.
Future<void> syncPhotos(AppDb db, {required int assetId, required int recordId, required List<AssetDocument> before, required List<AssetDocument> kept, required List<Picked> added}) async {
  for (final d in before.where((b) => !kept.any((k) => k.id == b.id))) {
    await db.deleteDocument(d.id);
    await SecureFiles.delete(d.filePath);
  }
  for (final p in added) {
    final name = await SecureFiles.save(db, p.bytes, p.ext);
    await db.addDocument(DocumentsCompanion(
      assetId: Value(assetId),
      filePath: Value(name),
      title: const Value('photo'),
      docType: const Value('photo'),
      linkedRecordId: Value(recordId),
    ));
  }
}

// ================================================================ list

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _q = '';
  String _type = 'all';

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final theme = Theme.of(context);
      final q = _q.trim().toLowerCase();
      final docs = w.files
          .where((d) => _type == 'all' || d.docType == _type)
          .where((d) => q.isEmpty || '${d.title} ${s.docTypeName(d.docType)} ${w.asset(d.assetId)?.nickname ?? ''}'.toLowerCase().contains(q))
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      final groups = <Widget>[];
      for (final a in w.assets) {
        final g = docs.where((d) => d.assetId == a.id).toList();
        if (g.isEmpty) continue;
        groups.add(SectionTitle(a.nickname, count: g.length));
        groups.add(CardList([for (final d in g) DocTile(d, w)]));
      }
      return Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
              child: Row(children: [
                Expanded(child: Text(s.documentsTab, style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700))),
                if (w.assets.isNotEmpty)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.attach_file),
                    label: Text(s.attach),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentFormScreen())),
                  ),
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
              SearchBar(
                hintText: s.searchDocs,
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                onChanged: (v) => setState(() => _q = v),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final t in ['all', ...docTypes])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(label: Text(t == 'all' ? s.all : s.docTypeName(t)), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
                    ),
                ]),
              ),
              if (groups.isEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Text(s.noMatch)) else ...groups,
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
  const DocTile(this.d, this.w, {super.key, this.showAsset = false});
  final AssetDocument d;
  final World w;
  final bool showAsset;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    Widget? trailing;
    if (d.expiry != null) {
      final n = daysBetween(today(), d.expiry!);
      final st = n < 0 ? RStatus.overdue : (n <= 30 ? RStatus.dueSoon : RStatus.upcoming);
      final (bg, fg) = statusColors(context, st);
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(n < 0 ? s.expired : s.expiresShort(s.dShort(d.expiry!)), style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
      );
    }
    return ListTile(
      leading: SecureFiles.isImage(d.filePath)
          ? ClipRRect(borderRadius: BorderRadius.circular(8), child: SecureImage(d.filePath, size: 44, cacheWidth: 150))
          : const SizedBox(width: 44, height: 44, child: Icon(Icons.picture_as_pdf_outlined, size: 32)),
      title: Text(d.title),
      subtitle: Text([s.docTypeName(d.docType), if (showAsset) w.asset(d.assetId)?.nickname ?? ''].join(' · ')),
      trailing: trailing,
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
                    final ok = await SecureFiles.openExternal(c.db, d.filePath, d.title);
                    if (!ok && c.mounted) snack(c, s.noViewer);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: Text(s.shareCopy),
                  onPressed: () => SecureFiles.shareCopy(c.db, d.filePath, d.title),
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
                    if (d.linkedReminderId != null) await db.deleteReminder(d.linkedReminderId!);
                    await db.deleteDocument(d.id);
                    await SecureFiles.delete(d.filePath);
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
      _assetId = widget.assetId ?? (w.assets.isEmpty ? null : w.assets.first.id);
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
    try {
      if (widget.editId == null) {
        final name = await SecureFiles.save(db, _file!.bytes, _file!.ext);
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
          filePath: Value(name),
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
          await db.updateReminder(remId, RemindersCompanion(title: Value(s.docExpires(title)), dueDate: Value(_expiry), done: const Value(false)));
        } else if (_expiry != null && _remind) {
          remId = await db.addReminder(RemindersCompanion(
            assetId: Value(d.assetId),
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
        ));
      }
    } catch (_) {
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
      if (_assetId == null) return Scaffold(appBar: AppBar(), body: Center(child: Text(s.addAssetFirst)));
      final editing = widget.editId != null;
      if (!editing && _file == null) {
        return Scaffold(
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
      return Scaffold(
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
