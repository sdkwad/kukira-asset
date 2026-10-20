import 'package:drift/drift.dart';

import '../domain/rules.dart';

part 'db.g.dart';

// ---------------------------------------------------------------- tables

class Assets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nickname => text()();

  /// house | car | motorcycle
  TextColumn get category => text()();
  DateTimeColumn get acquiredDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class HouseProfiles extends Table {
  IntColumn get assetId => integer().references(Assets, #id, onDelete: KeyAction.cascade)();

  /// landed | strata | strata_landed
  TextColumn get propertyType => text()();
  TextColumn get address => text().nullable()();

  /// new_from_developer | subsale
  TextColumn get source => text().nullable()();
  DateTimeColumn get spaDate => dateTime().nullable()();
  DateTimeColumn get vpDate => dateTime().nullable()();

  /// Only set when the owner corrects the estimated DLP end.
  DateTimeColumn get dlpEndOverride => dateTime().nullable()();

  /// individual | master | strata_issued
  TextColumn get titleStatus => text().nullable()();
  TextColumn get council => text().nullable()();
  TextColumn get state => text().nullable()();
  TextColumn get contact => text().nullable()();

  /// owner | rented | vacant
  TextColumn get occupancy => text().nullable()();
  DateTimeColumn get tenancyStart => dateTime().nullable()();
  DateTimeColumn get tenancyEnd => dateTime().nullable()();
  IntColumn get rentDueDay => integer().nullable()();

  @override
  Set<Column> get primaryKey => {assetId};
}

class VehicleProfiles extends Table {
  IntColumn get assetId => integer().references(Assets, #id, onDelete: KeyAction.cascade)();

  /// car | motorcycle
  TextColumn get vehicleType => text()();
  TextColumn get plate => text()();
  TextColumn get make => text().nullable()();
  TextColumn get model => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get cc => integer().nullable()();

  /// new | second_hand
  TextColumn get condition => text().nullable()();
  DateTimeColumn get warrantyExpiry => dateTime().nullable()();
  IntColumn get warrantyKm => integer().nullable()();
  TextColumn get chassisNo => text().nullable()();
  TextColumn get engineNo => text().nullable()();
  TextColumn get insuranceProvider => text().nullable()();
  TextColumn get policyNo => text().nullable()();
  DateTimeColumn get insuranceExpiry => dateTime().nullable()();
  DateTimeColumn get roadTaxExpiry => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {assetId};
}

class OdometerReadings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assetId => integer().references(Assets, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  IntColumn get km => integer()();
}

class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assetId => integer().references(Assets, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();

  /// Record category this reminder belongs to (used to match records to reminders).
  TextColumn get category => text().nullable()();

  /// fixed | repeat | mileage | either
  TextColumn get ruleType => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get dueOdometer => integer().nullable()();
  IntColumn get repeatMonths => integer().nullable()();
  IntColumn get repeatKm => integer().nullable()();

  /// completion | due
  TextColumn get repeatFrom => text().withDefault(const Constant('completion'))();
  IntColumn get leadDays => integer().withDefault(const Constant(7))();
  IntColumn get leadKm => integer().withDefault(const Constant(1000))();

  /// template | preset | manual
  TextColumn get source => text().withDefault(const Constant('manual'))();
  BoolColumn get estimated => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  TextColumn get confirmWith => text().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastCompleted => dateTime().nullable()();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('UpkeepRecord')
class Records extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assetId => integer().references(Assets, #id, onDelete: KeyAction.cascade)();

  /// maintenance | renovation | incident | defect | payment
  TextColumn get kind => text()();
  TextColumn get category => text().nullable()();
  TextColumn get title => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get cost => real().nullable()();
  IntColumn get vendorId => integer().nullable().references(Vendors, #id, onDelete: KeyAction.setNull)();
  TextColumn get vendorName => text().nullable()();
  TextColumn get area => text().nullable()();

  /// open | in_progress | done (defects and incidents)
  TextColumn get status => text().nullable()();
  DateTimeColumn get warrantyEnd => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get linkedReminderId => integer().nullable()();
  IntColumn get odometer => integer().nullable()();
  BoolColumn get insuranceClaim => boolean().nullable()();
  TextColumn get claimRef => text().nullable()();
  TextColumn get claimStatus => text().nullable()();
  DateTimeColumn get reportedToDeveloper => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('AssetDocument')
class Documents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assetId => integer().references(Assets, #id, onDelete: KeyAction.cascade)();
  TextColumn get filePath => text()();
  TextColumn get title => text()();
  TextColumn get docType => text()();
  IntColumn get linkedRecordId => integer().nullable()();
  IntColumn get linkedReminderId => integer().nullable()();
  DateTimeColumn get expiry => dateTime().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

class Vendors extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get trade => text().nullable()();
  TextColumn get note => text().nullable()();
}

@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ---------------------------------------------------------------- snapshot

/// Everything the app shows, loaded in one go. Personal data is small, so the
/// whole set is reloaded after each change and the UI reads from this snapshot.
class World {
  World({
    required this.assets,
    required this.houses,
    required this.vehicles,
    required this.reminders,
    required this.records,
    required this.odometer,
    required this.vendors,
    required this.documents,
    required this.settings,
  });

  final List<Asset> assets;
  final Map<int, HouseProfile> houses;
  final Map<int, VehicleProfile> vehicles;
  final List<Reminder> reminders;
  final List<UpkeepRecord> records;
  final Map<int, OdometerReading> odometer;
  final List<Vendor> vendors;
  final List<AssetDocument> documents;
  final Map<String, String> settings;

  Asset? asset(int id) {
    for (final a in assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  int? odoOf(int assetId) => odometer[assetId]?.km;

  DateTime? get lastBackup {
    final v = settings['lastBackup'];
    return v == null ? null : DateTime.tryParse(v);
  }
}

extension ReminderInfo on Reminder {
  RemInfo get info => RemInfo(
        rule: ruleType,
        due: dueDate,
        dueKm: dueOdometer,
        repeatMonths: repeatMonths,
        repeatKm: repeatKm,
        repeatFrom: repeatFrom,
        leadDays: leadDays,
        leadKm: leadKm,
        done: done,
        snoozedUntil: snoozedUntil,
      );
}

// ---------------------------------------------------------------- database

@DriftDatabase(tables: [
  Assets,
  HouseProfiles,
  VehicleProfiles,
  OdometerReadings,
  Reminders,
  Records,
  Documents,
  Vendors,
  Settings,
])
class AppDb extends _$AppDb {
  AppDb(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<World> loadWorld() async {
    final a = await (select(assets)..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)])).get();
    final h = await select(houseProfiles).get();
    final v = await select(vehicleProfiles).get();
    final r = await select(reminders).get();
    final rec = await (select(records)..orderBy([(t) => OrderingTerm.desc(t.date), (t) => OrderingTerm.desc(t.id)])).get();
    final o = await (select(odometerReadings)..orderBy([(t) => OrderingTerm.asc(t.date), (t) => OrderingTerm.asc(t.id)])).get();
    final ven = await select(vendors).get();
    final docs = await select(documents).get();
    final st = await select(settings).get();
    final latest = <int, OdometerReading>{};
    for (final x in o) {
      final cur = latest[x.assetId];
      if (cur == null || x.km >= cur.km) latest[x.assetId] = x;
    }
    return World(
      assets: a,
      houses: {for (final x in h) x.assetId: x},
      vehicles: {for (final x in v) x.assetId: x},
      reminders: r,
      records: rec,
      odometer: latest,
      vendors: ven,
      documents: docs,
      settings: {for (final x in st) x.key: x.value},
    );
  }

  Stream<World> watchWorld() async* {
    yield await loadWorld();
    await for (final _ in tableUpdates()) {
      yield await loadWorld();
    }
  }

  // -------- settings
  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion(key: Value(key), value: Value(value)));

  // -------- assets
  Future<int> createAsset({required String category, required String nickname, String? propertyType, String? plate}) {
    return transaction(() async {
      final id = await into(assets).insert(AssetsCompanion(nickname: Value(nickname), category: Value(category)));
      if (category == 'house') {
        await into(houseProfiles).insert(HouseProfilesCompanion(assetId: Value(id), propertyType: Value(propertyType ?? 'landed')));
      } else {
        await into(vehicleProfiles).insert(VehicleProfilesCompanion(assetId: Value(id), vehicleType: Value(category), plate: Value(plate ?? '')));
      }
      return id;
    });
  }

  Future<void> updateAsset(int id, AssetsCompanion c) =>
      (update(assets)..where((t) => t.id.equals(id))).write(c.copyWith(updatedAt: Value(DateTime.now())));

  Future<void> updateHouse(int assetId, HouseProfilesCompanion c) =>
      (update(houseProfiles)..where((t) => t.assetId.equals(assetId))).write(c);

  Future<void> updateVehicle(int assetId, VehicleProfilesCompanion c) =>
      (update(vehicleProfiles)..where((t) => t.assetId.equals(assetId))).write(c);

  Future<void> deleteAsset(int id) => (delete(assets)..where((t) => t.id.equals(id))).go();

  // -------- reminders
  Future<int> addReminder(RemindersCompanion c) => into(reminders).insert(c);

  Future<void> updateReminder(int id, RemindersCompanion c) =>
      (update(reminders)..where((t) => t.id.equals(id))).write(c);

  Future<void> deleteReminder(int id) => (delete(reminders)..where((t) => t.id.equals(id))).go();

  Future<NextDue> completeReminder(Reminder r, {required DateTime today, int? odometer}) async {
    final n = nextAfterDone(r.info, today: today, odometer: odometer);
    await updateReminder(
      r.id,
      RemindersCompanion(
        lastCompleted: Value(dayOnly(today)),
        snoozedUntil: const Value(null),
        done: Value(n.done),
        dueDate: Value(n.due),
        dueOdometer: Value(n.dueKm),
      ),
    );
    return n;
  }

  Future<void> snooze(int id, DateTime until) => updateReminder(id, RemindersCompanion(snoozedUntil: Value(until)));

  // -------- records, odometer
  Future<int> addRecord(RecordsCompanion c) => into(records).insert(c);

  Future<void> updateRecord(int id, RecordsCompanion c) => (update(records)..where((t) => t.id.equals(id))).write(c);

  Future<void> deleteRecord(int id) => (delete(records)..where((t) => t.id.equals(id))).go();

  Future<void> addOdometer(int assetId, int km, DateTime date) =>
      into(odometerReadings).insert(OdometerReadingsCompanion(assetId: Value(assetId), km: Value(km), date: Value(date)));

  // -------- backup
  Future<Map<String, List<Map<String, dynamic>>>> exportTables() async => {
        'assets': (await select(assets).get()).map((e) => e.toJson()).toList(),
        'houseProfiles': (await select(houseProfiles).get()).map((e) => e.toJson()).toList(),
        'vehicleProfiles': (await select(vehicleProfiles).get()).map((e) => e.toJson()).toList(),
        'odometerReadings': (await select(odometerReadings).get()).map((e) => e.toJson()).toList(),
        'reminders': (await select(reminders).get()).map((e) => e.toJson()).toList(),
        'records': (await select(records).get()).map((e) => e.toJson()).toList(),
        'documents': (await select(documents).get()).map((e) => e.toJson()).toList(),
        'vendors': (await select(vendors).get()).map((e) => e.toJson()).toList(),
      };

  /// Replaces all records with the contents of a backup. Settings (language) are kept.
  Future<void> replaceAll(Map<String, dynamic> t) {
    List<Map<String, dynamic>> rows(String k) =>
        ((t[k] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return transaction(() async {
      await delete(documents).go();
      await delete(records).go();
      await delete(odometerReadings).go();
      await delete(reminders).go();
      await delete(vehicleProfiles).go();
      await delete(houseProfiles).go();
      await delete(assets).go();
      await delete(vendors).go();
      await batch((b) {
        b.insertAll(vendors, rows('vendors').map(Vendor.fromJson));
        b.insertAll(assets, rows('assets').map(Asset.fromJson));
        b.insertAll(houseProfiles, rows('houseProfiles').map(HouseProfile.fromJson));
        b.insertAll(vehicleProfiles, rows('vehicleProfiles').map(VehicleProfile.fromJson));
        b.insertAll(odometerReadings, rows('odometerReadings').map(OdometerReading.fromJson));
        b.insertAll(reminders, rows('reminders').map(Reminder.fromJson));
        b.insertAll(records, rows('records').map(UpkeepRecord.fromJson));
        b.insertAll(documents, rows('documents').map(AssetDocument.fromJson));
      });
    });
  }
}
