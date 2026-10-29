// Upgrades databases made by 0.1.0 (schema 1) and 0.2.0 (schema 2) and checks that they
// end up with the same columns as a new install, with every row kept.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';

/// The tables as 0.1.0 created them.
const schema1 = [
  'CREATE TABLE assets (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, nickname TEXT NOT NULL, category TEXT NOT NULL, '
      'acquired_date INTEGER NULL, notes TEXT NULL, photo_path TEXT NULL, '
      "created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "
      "updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))",
  'CREATE TABLE house_profiles (asset_id INTEGER NOT NULL REFERENCES assets (id) ON DELETE CASCADE, property_type TEXT NOT NULL, '
      'address TEXT NULL, source TEXT NULL, spa_date INTEGER NULL, vp_date INTEGER NULL, dlp_end_override INTEGER NULL, '
      'title_status TEXT NULL, council TEXT NULL, state TEXT NULL, contact TEXT NULL, occupancy TEXT NULL, '
      'tenancy_start INTEGER NULL, tenancy_end INTEGER NULL, rent_due_day INTEGER NULL, PRIMARY KEY (asset_id))',
  'CREATE TABLE vehicle_profiles (asset_id INTEGER NOT NULL REFERENCES assets (id) ON DELETE CASCADE, vehicle_type TEXT NOT NULL, '
      'plate TEXT NOT NULL, make TEXT NULL, model TEXT NULL, year INTEGER NULL, cc INTEGER NULL, condition TEXT NULL, '
      'warranty_expiry INTEGER NULL, warranty_km INTEGER NULL, chassis_no TEXT NULL, engine_no TEXT NULL, '
      'insurance_provider TEXT NULL, policy_no TEXT NULL, insurance_expiry INTEGER NULL, road_tax_expiry INTEGER NULL, '
      'PRIMARY KEY (asset_id))',
  'CREATE TABLE odometer_readings (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      'asset_id INTEGER NOT NULL REFERENCES assets (id) ON DELETE CASCADE, date INTEGER NOT NULL, km INTEGER NOT NULL)',
  'CREATE TABLE reminders (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, asset_id INTEGER NOT NULL REFERENCES assets (id) ON DELETE CASCADE, '
      'title TEXT NOT NULL, category TEXT NULL, rule_type TEXT NOT NULL, due_date INTEGER NULL, due_odometer INTEGER NULL, '
      "repeat_months INTEGER NULL, repeat_km INTEGER NULL, repeat_from TEXT NOT NULL DEFAULT 'completion', "
      "lead_days INTEGER NOT NULL DEFAULT 7, lead_km INTEGER NOT NULL DEFAULT 1000, source TEXT NOT NULL DEFAULT 'manual', "
      'estimated INTEGER NOT NULL DEFAULT 0 CHECK (estimated IN (0, 1)), note TEXT NULL, confirm_with TEXT NULL, '
      'done INTEGER NOT NULL DEFAULT 0 CHECK (done IN (0, 1)), last_completed INTEGER NULL, snoozed_until INTEGER NULL, '
      "created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))",
  'CREATE TABLE vendors (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT NULL, trade TEXT NULL, note TEXT NULL)',
  'CREATE TABLE records (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, asset_id INTEGER NOT NULL REFERENCES assets (id) ON DELETE CASCADE, '
      'kind TEXT NOT NULL, category TEXT NULL, title TEXT NOT NULL, date INTEGER NOT NULL, cost REAL NULL, '
      'vendor_id INTEGER NULL REFERENCES vendors (id) ON DELETE SET NULL, vendor_name TEXT NULL, area TEXT NULL, status TEXT NULL, '
      'warranty_end INTEGER NULL, notes TEXT NULL, linked_reminder_id INTEGER NULL, odometer INTEGER NULL, '
      'insurance_claim INTEGER NULL CHECK (insurance_claim IN (0, 1)), claim_ref TEXT NULL, claim_status TEXT NULL, '
      'reported_to_developer INTEGER NULL, '
      "created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))",
  'CREATE TABLE documents (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, asset_id INTEGER NOT NULL REFERENCES assets (id) ON DELETE CASCADE, '
      'file_path TEXT NOT NULL, title TEXT NOT NULL, doc_type TEXT NOT NULL, linked_record_id INTEGER NULL, '
      'linked_reminder_id INTEGER NULL, expiry INTEGER NULL, '
      "added_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))",
  'CREATE TABLE settings ("key" TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY ("key"))',
];

/// What 0.2.0 added.
const schema2Additions = [
  'CREATE TABLE cost_items (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      'record_id INTEGER NOT NULL REFERENCES records (id) ON DELETE CASCADE, label TEXT NOT NULL, amount REAL NOT NULL)',
  'ALTER TABLE reminders ADD COLUMN repeat_days INTEGER NULL',
];

/// One car with a road tax and an insurance reminder made by onboarding (no link yet),
/// a house, a record and a setting.
const sampleRows = [
  "INSERT INTO assets (id, nickname, category) VALUES (1, 'Rumah Setia Alam', 'house'), (2, 'Myvi', 'car')",
  "INSERT INTO house_profiles (asset_id, property_type, vp_date) VALUES (1, 'landed', 1700000000)",
  "INSERT INTO vehicle_profiles (asset_id, vehicle_type, plate, road_tax_expiry) VALUES (2, 'car', 'WXY 4821', 1793750400)",
  "INSERT INTO reminders (id, asset_id, title, category, rule_type, due_date) VALUES "
      "(1, 2, 'Road tax renewal', 'road_tax', 'fixed', 1793750400), "
      "(2, 2, 'Insurance renewal', 'insurance_premium', 'fixed', 1793750400), "
      "(3, 2, 'Engine oil', 'engine_oil', 'repeat', 1780000000)",
  "INSERT INTO records (id, asset_id, kind, title, date, cost) VALUES (1, 2, 'maintenance', 'Service', 1760000000, 180.5)",
  "INSERT INTO settings (\"key\", value) VALUES ('lang', 'ms')",
];

AppDb openAt(int version, {bool withRows = true}) => AppDb(NativeDatabase.memory(setup: (db) {
      // Runs before drift looks at user_version, so drift sees an old database to upgrade.
      final v = db.select('PRAGMA user_version').first.values.first as int;
      if (v != 0) return;
      for (final s in schema1) {
        db.execute(s);
      }
      if (version >= 2) {
        for (final s in schema2Additions) {
          db.execute(s);
        }
      }
      if (withRows) {
        for (final s in sampleRows) {
          db.execute(s);
        }
      }
      db.execute('PRAGMA user_version = $version');
    }));

Future<Map<String, Set<String>>> columns(AppDb db) async {
  final tables = await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'").get();
  return {
    for (final t in tables)
      t.read<String>('name'): {
        for (final c in await db.customSelect('PRAGMA table_info(${t.read<String>('name')})').get()) c.read<String>('name'),
      },
  };
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  for (final from in [1, 2]) {
    group('upgrade from schema $from', () {
      test('ends with the same tables and columns as a new install', () async {
        final fresh = AppDb(NativeDatabase.memory());
        final old = openAt(from);
        expect(await columns(old), await columns(fresh));
        expect(await old.customSelect('PRAGMA user_version').map((r) => r.data.values.first).getSingle(), AppDb.latestSchema);
        await fresh.close();
        await old.close();
      });

      test('keeps every row and links the onboarding reminders', () async {
        final db = openAt(from);
        final w = await db.loadWorld();
        expect(w.assets.map((a) => a.nickname), ['Rumah Setia Alam', 'Myvi']);
        expect(w.houses[1]!.vpDate, DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
        expect(w.records.single.cost, 180.5);
        expect(w.settings['lang'], 'ms');
        final byId = {for (final r in w.reminders) r.id: r};
        expect(byId[1]!.autoSource, 'roadTax');
        expect(byId[2]!.autoSource, 'insurance');
        expect(byId[3]!.autoSource, isNull);
        expect(byId[3]!.repeatDays, isNull);
        await db.close();
      });
    });
  }

  test('an empty schema 1 database upgrades cleanly', () async {
    final db = openAt(1, withRows: false);
    expect((await db.loadWorld()).assets, isEmpty);
    await db.close();
  });
}
