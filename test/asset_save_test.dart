import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/domain/auto_sync.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/auto_reminders.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  final today = DateTime(2026, 11, 3);
  final nov = DateTime(2026, 11, 20);

  late AppDb db;
  late int car;
  setUp(() async {
    db = AppDb(NativeDatabase.memory());
    car = await db.createAsset(category: 'car', nickname: 'Myvi', plate: 'WXY 4821');
  });
  tearDown(() => db.close());

  Future<VehicleProfile> vehicle() => (db.select(db.vehicleProfiles)..where((t) => t.assetId.equals(car))).getSingle();

  test('the road tax date and its linked reminder are saved together', () async {
    final change = planChange(const [], car, autoRoadTax, oldDate: null, newDate: nov, today: today);
    await saveFieldsWithAuto(db, s, car, [change],
        overwriteManual: true, saveFields: () => db.updateVehicle(car, VehicleProfilesCompanion(roadTaxExpiry: Value(nov))));

    expect((await vehicle()).roadTaxExpiry, nov);
    expect((await db.select(db.reminders).getSingle()).autoSource, autoRoadTax);
  });

  test('if the reminder part fails, the new date is not saved either', () async {
    // An update for a linked reminder that is not there makes applyAuto fail.
    const broken = AutoChange(autoRoadTax, AutoPlan(AutoKind.update, due: null), null);
    await expectLater(
      saveFieldsWithAuto(db, s, car, [broken],
          overwriteManual: true, saveFields: () => db.updateVehicle(car, VehicleProfilesCompanion(roadTaxExpiry: Value(nov)))),
      throwsA(anything),
    );

    expect((await vehicle()).roadTaxExpiry, isNull);
    expect(await db.select(db.reminders).get(), isEmpty);
  });
}
