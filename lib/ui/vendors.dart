import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/db.dart';
import 'common.dart';

const vendorTrades = ['plumbing', 'electrical', 'aircond', 'renovation', 'pest_control', 'roof', 'cleaning', 'workshop', 'tyre', 'insurance', 'other'];

class VendorsScreen extends StatelessWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final vs = [...w.vendors]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return SafeScaffold(
        appBar: AppBar(title: Text(s.vendorBook)),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: Text(s.addVendor),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorFormScreen())),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
          if (vs.isEmpty) NoteBox(s.noVendors),
          CardList([
            for (final v in vs)
              ListTile(
                leading: CircleAvatar(child: Text(v.name.isEmpty ? '?' : v.name[0].toUpperCase())),
                title: Text(v.name),
                subtitle: Text([
                  if (v.trade != null) s.tradeName(v.trade!),
                  if (v.phone != null) v.phone!,
                  s.jobsCount(w.records.where((r) => r.vendorId == v.id).length),
                ].join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VendorFormScreen(editId: v.id))),
              ),
          ]),
        ]),
      );
    });
  }
}

class VendorFormScreen extends StatefulWidget {
  const VendorFormScreen({super.key, this.editId});
  final int? editId;

  @override
  State<VendorFormScreen> createState() => _VendorFormState();
}

class _VendorFormState extends State<VendorFormScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  String? _trade;
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final v = w.vendor(widget.editId);
      if (!_loaded) {
        _loaded = true;
        if (v != null) {
          _name.text = v.name;
          _phone.text = v.phone ?? '';
          _note.text = v.note ?? '';
          _trade = v.trade;
        }
      }
      final jobs = v == null ? <UpkeepRecord>[] : w.records.where((r) => r.vendorId == v.id).toList();
      return SafeScaffold(
        appBar: AppBar(
          title: Text(v == null ? s.addVendor : s.editVendor),
          actions: [
            if (v != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: s.delete,
                onPressed: () async {
                  final ok = await confirm(context, title: s.deleteVendorQ(v.name), body: s.deleteVendorBody, ok: s.delete, danger: true);
                  if (!ok || !context.mounted) return;
                  await context.db.deleteVendor(v.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: s.vendorName, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: s.phone,
              border: const OutlineInputBorder(),
              suffixIcon: _phone.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: s.copy,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _phone.text));
                        snack(context, s.copied);
                      },
                    ),
            ),
          ),
          const SizedBox(height: 14),
          FieldLabel(s.trade),
          ChoiceRow<String>(options: vendorTrades, value: _trade, label: s.tradeName, onChanged: (x) => setState(() => _trade = x)),
          const SizedBox(height: 14),
          TextField(controller: _note, maxLines: 3, decoration: InputDecoration(labelText: s.notes, border: const OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              if (_name.text.trim().isEmpty) return;
              final c = VendorsCompanion(name: Value(_name.text.trim()), phone: Value(nn(_phone.text)), trade: Value(_trade), note: Value(nn(_note.text)));
              final db = context.db;
              if (v == null) {
                await db.addVendor(c);
              } else {
                await db.updateVendor(v.id, c);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(s.save),
          ),
          if (jobs.isNotEmpty) ...[
            SectionTitle(s.jobsTitle, count: jobs.length),
            CardList([
              for (final r in jobs)
                ListTile(
                  title: Text(r.title),
                  subtitle: Text([s.dLong(r.date), w.asset(r.assetId)?.nickname ?? '', if (r.cost != null) s.rm(r.cost!)].join(' · ')),
                ),
            ]),
          ],
        ]),
      );
    });
  }
}
