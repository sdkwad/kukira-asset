import 'dart:typed_data';

import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;

import '../data/db.dart';
import '../domain/auto_sync.dart';
import '../domain/renewal.dart';
import '../domain/rules.dart';
import '../l10n/strings.dart';
import 'auto_reminders.dart';
import 'files.dart';

/// The current end date of [kind] on vehicle [v].
DateTime? coverEndOf(VehicleProfile v, RenewKind kind) => kind == RenewKind.roadTax ? v.roadTaxExpiry : v.insuranceExpiry;

/// The renewal record that paid for the cover ending on the vehicle's current date, if the
/// cover was renewed in Kukira. It says when the current period started.
UpkeepRecord? currentCoverRecord(World w, int assetId, RenewKind kind) {
  final v = w.vehicles[assetId];
  final end = v == null ? null : coverEndOf(v, kind);
  if (end == null) return null;
  final cat = renewCategory(kind);
  final matches = w.records
      .where((r) => r.assetId == assetId && r.category == cat && r.coverStart != null && r.coverEnd != null && dayOnly(r.coverEnd!) == dayOnly(end))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return matches.firstOrNull;
}

/// One cover renewed: the new period and what came with it.
class RenewInput {
  const RenewInput({required this.kind, required this.start, required this.end, this.cost, this.insurer, this.proof});
  final RenewKind kind;
  final DateTime start;
  final DateTime end;
  final double? cost;

  /// Insurance only: the insurer of the new policy.
  final String? insurer;

  /// A proof to keep with it (the e-LKM, the policy, a receipt): its bytes and extension.
  final (Uint8List, String)? proof;
}

/// Renews road tax and/or insurance of vehicle [assetId], all in one transaction:
/// - a payment record that keeps the new period (so every period stays in the history),
/// - the vehicle's end date (and insurer),
/// - the linked reminder, moved to the new end. Renewing is the reason to move it, so a
///   reminder that was marked done or snoozed is reopened without asking; the form says so.
/// - the proof, encrypted, as a document of the record that ends with the new period.
/// A proof is written before the transaction and removed again if the transaction fails,
/// so a failed save leaves no file behind and changes nothing.
Future<List<String>> applyRenewal(AppDb db, Str s, World w, int assetId, List<RenewInput> items, {required DateTime today}) async {
  final v = w.vehicles[assetId];
  if (v == null) throw StateError('Not a vehicle: $assetId');
  for (final i in items) {
    if (dayOnly(i.end).isBefore(dayOnly(i.start))) throw ArgumentError('The cover ends before it starts');
  }
  final written = <String>[];
  try {
    final files = <RenewInput, String>{};
    for (final i in items) {
      final p = i.proof;
      if (p == null) continue;
      final name = await SecureFiles.save(db, p.$1, p.$2);
      written.add(name);
      files[i] = name;
    }
    return await db.transaction(() async {
      final msgs = <String>[];
      final t = dayOnly(today);
      for (final i in items) {
        final road = i.kind == RenewKind.roadTax;
        final start = dayOnly(i.start);
        final end = dayOnly(i.end);
        final insurer = i.insurer?.trim();
        final recordId = await db.addRecord(RecordsCompanion(
          assetId: Value(assetId),
          kind: const Value('payment'),
          category: Value(renewCategory(i.kind)),
          title: Value(road ? s.roadTaxRenewal : s.insuranceRenewal),
          date: Value(t),
          cost: Value(i.cost),
          vendorName: Value(road || insurer == null || insurer.isEmpty ? null : insurer),
          coverStart: Value(start),
          coverEnd: Value(end),
        ));
        await db.updateVehicle(
          assetId,
          road
              ? VehicleProfilesCompanion(roadTaxExpiry: Value(end))
              : VehicleProfilesCompanion(
                  insuranceExpiry: Value(end),
                  insuranceProvider: insurer == null || insurer.isEmpty ? const Value.absent() : Value(insurer),
                ),
        );
        final source = road ? autoRoadTax : autoInsurance;
        final change = planChange(w.reminders, assetId, source, oldDate: coverEndOf(v, i.kind), newDate: end, today: t);
        await applyAuto(db, s, assetId, [change]);
        final linked = await (db.select(db.reminders)..where((r) => r.assetId.equals(assetId) & r.autoSource.equals(source))).get();
        for (final r in linked) {
          await db.updateReminder(r.id, RemindersCompanion(lastCompleted: Value(t)));
        }
        final file = files[i];
        if (file != null) {
          await db.addDocument(DocumentsCompanion(
            assetId: Value(assetId),
            filePath: Value(file),
            title: Value(road ? s.roadTaxProofTitle(start.year, end.year) : s.insurancePolicyTitle(start.year, end.year)),
            docType: Value(road ? 'receipt' : 'insurance'),
            linkedRecordId: Value(recordId),
            expiry: Value(end),
          ));
        }
        msgs.add(s.renewedUntil(road ? s.catName('road_tax') : s.insuranceWord, s.dLong(end)));
      }
      return msgs;
    });
  } catch (_) {
    for (final name in written) {
      try {
        await SecureFiles.delete(name);
      } catch (_) {
        // The file stays unused (still encrypted) until a restore clears unused files.
      }
    }
    rethrow;
  }
}
