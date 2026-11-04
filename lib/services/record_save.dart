import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../data/db.dart';
import '../domain/rules.dart';
import '../l10n/strings.dart';
import 'auto_reminders.dart';
import 'files.dart';

/// What the record form collected, as plain values.
class RecordInput {
  const RecordInput({
    required this.assetId,
    this.editId,
    required this.kind,
    this.category,
    required this.title,
    required this.date,
    this.cost,
    this.costItems = const [],
    this.vendorName,
    this.vendorId,
    this.addVendor = false,
    this.area,
    this.notes,
    this.odometer,
    this.warrantyEnd,
    this.status,
    this.reportedOn,
    this.insuranceClaim,
    this.linkedReminderId,
    this.photosRemoved = const [],
    this.photosAdded = const [],
    this.completes,
  });

  final int assetId;

  /// The record being edited, or null for a new one.
  final int? editId;
  final String kind;
  final String? category;
  final String title;
  final DateTime date;
  final double? cost;
  final List<(String, double)> costItems;
  final String? vendorName;

  /// The vendor picked from the vendor book, if any.
  final int? vendorId;

  /// Add [vendorName] to the vendor book when it is not there yet.
  final bool addVendor;
  final String? area;
  final String? notes;
  final int? odometer;
  final DateTime? warrantyEnd;
  final String? status;
  final DateTime? reportedOn;
  final bool? insuranceClaim;
  final int? linkedReminderId;
  final List<AssetDocument> photosRemoved;

  /// New photos as (bytes, file extension).
  final List<(Uint8List, String)> photosAdded;

  /// The reminder this record completes, if the user ticked "mark done".
  final Reminder? completes;
}

/// Saves a record and everything that goes with it: a new vendor, the cost breakdown,
/// photos, an odometer reading, marking the matching reminder done and the warranty
/// reminder ([warranty], see planWarranty). New photo files are written first and the
/// rest happens in one transaction, so a failed or interrupted save leaves nothing
/// half-done. Returns the record id and adds a message per change to [msgs].
Future<int> saveRecord(AppDb db, Str s, World w, RecordInput r,
    {required AutoChange warranty, required bool overwriteWarranty, required DateTime today, required List<String> msgs}) async {
  final files = FileChanges(db);
  final photoNames = [for (final (bytes, ext) in r.photosAdded) await files.add(bytes, ext)];
  return files.commit(() async {
    final asset = w.asset(r.assetId);
    final name = r.vendorName;
    int? vendorId;
    if (name != null) {
      final known = w.vendors.where((v) => v.name.toLowerCase() == name.toLowerCase()).firstOrNull;
      if (known != null) {
        vendorId = known.id;
      } else if (r.addVendor) {
        vendorId = await db.addVendor(VendorsCompanion(name: Value(name), trade: Value(asset?.category == 'house' ? null : 'workshop')));
      }
    }

    final warrantyId = await applyWarranty(db, s, warranty, assetId: r.assetId, recordTitle: r.title, overwriteManual: overwriteWarranty, msgs: msgs);
    final c = RecordsCompanion(
      assetId: Value(r.assetId),
      kind: Value(r.kind),
      category: Value(r.category),
      title: Value(r.title),
      date: Value(r.date),
      cost: Value(r.cost),
      vendorId: Value(vendorId),
      vendorName: Value(name),
      area: Value(r.area),
      notes: Value(r.notes),
      odometer: Value(r.odometer),
      warrantyEnd: Value(r.warrantyEnd),
      status: Value(r.status),
      reportedToDeveloper: Value(r.reportedOn),
      insuranceClaim: Value(r.insuranceClaim),
      linkedReminderId: Value(r.linkedReminderId),
      warrantyReminderId: Value(warrantyId),
    );
    final recordId = r.editId ?? await db.addRecord(c);
    if (r.editId != null) await db.updateRecord(recordId, c);
    await db.setCostItems(recordId, r.costItems);

    for (final d in r.photosRemoved) {
      await db.deleteDocument(d.id);
      files.remove(d.filePath);
    }
    for (final n in photoNames) {
      await db.addDocument(DocumentsCompanion(
        assetId: Value(r.assetId),
        filePath: Value(n),
        title: const Value('photo'),
        docType: const Value('photo'),
        linkedRecordId: Value(recordId),
      ));
    }

    final cur = w.odoOf(r.assetId);
    var odo = cur;
    if (asset?.category != 'house' && r.odometer != null && (cur == null || r.odometer! > cur)) {
      await db.addOdometer(r.assetId, r.odometer!, r.date);
      odo = r.odometer;
    }
    final done = r.completes;
    if (done != null) {
      // Done on the record's date (a service from 1 Oct entered on 20 Oct), so the next one
      // counts from when it was really done; never from a date still to come.
      final on = dayOnly(r.date).isAfter(dayOnly(today)) ? today : r.date;
      final n = await db.completeReminder(done, today: on, odometer: odo);
      msgs.add(s.alsoMarkedDone(done.title, n.done ? null : (n.due != null ? s.dLong(n.due!) : s.km(n.dueKm ?? 0))));
    }
    return recordId;
  });
}
