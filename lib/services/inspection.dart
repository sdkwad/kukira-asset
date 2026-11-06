// Saving a room-by-room check (0.3, F4), and sending the defect list to the developer.

import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:share_plus/share_plus.dart';

import '../data/db.dart';
import '../domain/inspection.dart';
import '../domain/rules.dart';
import '../l10n/strings.dart';
import 'files.dart';

Future<int> startInspection(AppDb db, int assetId, {required String kind, required int bedrooms, required int bathrooms}) =>
    db.into(db.inspections).insert(InspectionsCompanion(
          assetId: Value(assetId),
          kind: Value(kind),
          date: Value(dayOnly(DateTime.now())),
          bedrooms: Value(bedrooms),
          bathrooms: Value(bathrooms),
        ));

/// Sets the result of one thing in one room (ok, defect, na, or null to clear it).
/// A defect files a defect record the first time, named after the thing and the room. Taking
/// the defect back removes that record only while nothing has been added to it (no photo,
/// note or report and still open), so an undone tap leaves nothing behind and a record the
/// owner has worked on is kept.
Future<void> setCheck(AppDb db, Str s, Inspection ins, String room, String item, String? result) => db.transaction(() async {
      final existing = await (db.select(db.inspectionChecks)
            ..where((c) => c.inspectionId.equals(ins.id) & c.room.equals(room) & c.item.equals(item)))
          .getSingleOrNull();
      var recordId = existing?.recordId;
      if (result == 'defect' && recordId == null) {
        recordId = await db.addRecord(RecordsCompanion(
          assetId: Value(ins.assetId),
          kind: const Value('defect'),
          category: Value(defectCategory(item)),
          title: Value('${s.inspectionItemName(item)} · ${s.roomName(room)}'),
          area: Value(s.roomName(room)),
          date: Value(dayOnly(DateTime.now())),
          status: const Value('open'),
        ));
      } else if (result != 'defect' && recordId != null) {
        final id = recordId;
        final rec = await (db.select(db.records)..where((r) => r.id.equals(id))).getSingleOrNull();
        final photos = await (db.select(db.documents)..where((d) => d.linkedRecordId.equals(id))).get();
        final untouched = rec != null && rec.notes == null && rec.reportedToDeveloper == null && photos.isEmpty && (rec.status ?? 'open') == 'open';
        if (untouched) await db.deleteRecord(id);
        recordId = null;
      }
      if (existing == null) {
        await db.into(db.inspectionChecks).insert(InspectionChecksCompanion(
              inspectionId: Value(ins.id),
              room: Value(room),
              item: Value(item),
              result: Value(result),
              recordId: Value(recordId),
            ));
      } else {
        await (db.update(db.inspectionChecks)..where((c) => c.id.equals(existing.id))).write(InspectionChecksCompanion(result: Value(result), recordId: Value(recordId)));
      }
    });

/// Defects of the house not fixed yet: what is sent to the developer.
List<UpkeepRecord> defectsToSend(World w, int assetId) =>
    w.records.where((r) => r.assetId == assetId && r.kind == 'defect' && r.status != 'done').toList()..sort((a, b) => a.date.compareTo(b.date));

/// Sends the defect list, with its photos, through the phone's share sheet (WhatsApp, email,
/// and so on), then marks the ones not reported before as reported today. The text and the
/// photos leave the phone: the screen says so before this is called. False when the owner
/// backed out of the share sheet.
Future<bool> sendDefectReport(AppDb db, Str s, World w, int assetId) async {
  final a = w.asset(assetId);
  if (a == null) return false;
  final defects = defectsToSend(w, assetId);
  if (defects.isEmpty) return false;
  final heading = s.defectReportHeading(a.nickname);
  final text = defectReport(
    heading: heading,
    address: w.houses[assetId]?.address,
    dateLine: s.defectReportDate(s.dLong(dayOnly(DateTime.now()))),
    defects: [for (final d in defects) ReportedDefect(title: d.title, area: d.area, notes: d.notes)],
    otherArea: s.otherArea,
    footer: s.defectReportFooter,
  );
  final files = <XFile>[];
  for (final (i, d) in defects.indexed) {
    for (final p in w.photosOf(d.id)) {
      final f = await SecureFiles.viewCopy(db, p.filePath, '${i + 1} ${d.title}');
      files.add(XFile(f.path));
    }
  }
  final res = files.isEmpty ? await Share.share(text, subject: heading) : await Share.shareXFiles(files, text: text, subject: heading);
  if (res.status == ShareResultStatus.dismissed) return false;
  final t = dayOnly(DateTime.now());
  await db.transaction(() async {
    for (final d in defects.where((d) => d.reportedToDeveloper == null)) {
      await db.updateRecord(d.id, RecordsCompanion(reportedToDeveloper: Value(t), status: Value(d.status == null || d.status == 'open' ? 'in_progress' : d.status)));
    }
  });
  return true;
}
