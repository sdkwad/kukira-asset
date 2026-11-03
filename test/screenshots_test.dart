// Screenshots of the main screens on a 360 x 760 phone, for reviewing the real pixels.
// Skipped in the normal test run. CI runs
//   flutter test --update-goldens --dart-define=SHOTS=true test/screenshots_test.dart
// which writes test/goldens/*.png, and uploads them with build/screenshots/problems.txt
// (any layout errors found while drawing).
//
// Text uses the real Roboto and Material Icons fonts from the Flutter SDK
// ($FLUTTER_ROOT/bin/cache/artifacts/material_fonts), so the pictures look like the phone.

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/services/error_log.dart';
import 'package:kukira_asset/ui/add_asset.dart';
import 'package:kukira_asset/ui/app.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/common.dart';
import 'package:kukira_asset/ui/documents.dart';
import 'package:kukira_asset/ui/forms.dart';
import 'package:kukira_asset/ui/lock.dart';
import 'package:kukira_asset/ui/more.dart';
import 'package:kukira_asset/ui/vendors.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'helpers.dart';

const _enabled = bool.fromEnvironment('SHOTS');
final _out = Directory('build/screenshots');
final _problems = <String>[];
final _boundary = GlobalKey();

Future<void> _loadFonts() async {
  final dir = Directory('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) {
    _problems.add('fonts: ${dir.path} not found, text is drawn as boxes');
    return;
  }
  final files = dir.listSync().whereType<File>().toList();
  Future<ByteData> bytes(File f) async => ByteData.view(f.readAsBytesSync().buffer);
  final roboto = FontLoader('Roboto');
  for (final f in files.where((f) => f.path.contains('Roboto') && f.path.endsWith('.ttf'))) {
    roboto.addFont(bytes(f));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons');
  for (final f in files.where((f) => f.path.contains('MaterialIcons'))) {
    icons.addFont(bytes(f));
  }
  await icons.load();
}

/// A house, a car and a motorcycle with reminders in every state, records and a vendor.
World demoWorld() {
  final now = DateTime.now();
  final t = DateTime(now.year, now.month, now.day);
  DateTime d(int days) => t.add(Duration(days: days));
  final created = d(-200);
  Reminder rem(int id, int asset, String title, DateTime? due,
          {String rule = 'fixed', String? category, int lead = 14, int? dueKm, int? everyMonths, int? everyKm, bool estimated = false, bool done = false, DateTime? completed, String? auto}) =>
      Reminder(
        id: id,
        assetId: asset,
        title: title,
        category: category,
        ruleType: rule,
        dueDate: due,
        dueOdometer: dueKm,
        repeatMonths: everyMonths,
        repeatKm: everyKm,
        repeatFrom: 'completion',
        leadDays: lead,
        leadKm: 1000,
        source: 'manual',
        estimated: estimated,
        done: done,
        lastCompleted: completed,
        createdAt: created,
        autoSource: auto,
      );
  return World(
    assets: [
      Asset(id: 1, nickname: 'Rumah Setia Alam', category: 'house', createdAt: created, updatedAt: created),
      Asset(id: 2, nickname: 'Myvi', category: 'car', createdAt: created, updatedAt: created),
      Asset(id: 3, nickname: 'Y15ZR', category: 'motorcycle', createdAt: created, updatedAt: created),
    ],
    houses: {1: HouseProfile(assetId: 1, propertyType: 'landed', source: 'new_from_developer', vpDate: d(-300), titleStatus: 'individual', council: 'MBSA', state: 'Selangor')},
    vehicles: {
      2: VehicleProfile(assetId: 2, vehicleType: 'car', plate: 'WXY 4821', make: 'Perodua', model: 'Myvi', year: 2021, roadTaxExpiry: d(9), insuranceExpiry: d(9)),
      3: VehicleProfile(assetId: 3, vehicleType: 'motorcycle', plate: 'BMK 772', make: 'Yamaha', model: 'Y15ZR', year: 2019, roadTaxExpiry: d(140)),
    },
    reminders: [
      rem(1, 2, 'Pembaharuan cukai jalan', d(9), category: 'road_tax', auto: 'roadTax'),
      rem(2, 2, 'Pembaharuan insurans', d(9), category: 'insurance_premium', lead: 30, auto: 'insurance'),
      rem(3, 2, 'Tukar minyak enjin', d(-6), rule: 'either', category: 'engine_oil', dueKm: 48000, everyMonths: 6, everyKm: 10000),
      rem(4, 1, 'Cukai tanah', d(45), rule: 'repeat', category: 'quit_rent', everyMonths: 12, lead: 30, estimated: true),
      rem(5, 1, 'Cukai taksiran (penggal 1)', d(120), rule: 'repeat', category: 'assessment', everyMonths: 6, estimated: true),
      rem(6, 1, 'Servis penghawa dingin', d(-2), rule: 'repeat', category: 'aircond', everyMonths: 6),
      rem(7, 1, 'Tamat tempoh DLP', d(430), category: 'dlp', lead: 60, estimated: true, auto: 'dlp'),
      rem(8, 3, 'Pembaharuan cukai jalan', d(140), category: 'road_tax', auto: 'roadTax'),
      rem(9, 2, 'Putar tayar', d(20), rule: 'repeat', everyMonths: 6),
      rem(10, 1, 'Cuci tangki air', null, done: true, completed: d(-3)),
    ],
    records: [
      UpkeepRecord(id: 1, assetId: 2, kind: 'maintenance', category: 'engine_oil', title: 'Servis 40,000 km', date: d(-170), cost: 245.5, vendorName: 'Bengkel Ah Seng', vendorId: 1, odometer: 40120, createdAt: d(-170)),
      UpkeepRecord(id: 2, assetId: 1, kind: 'defect', title: 'Retak dinding bilik utama', date: d(-20), area: 'Bilik utama', status: 'in_progress', reportedToDeveloper: d(-18), createdAt: d(-20)),
      UpkeepRecord(id: 3, assetId: 1, kind: 'maintenance', category: 'aircond', title: 'Servis aircond 3 unit', date: d(-180), cost: 270, createdAt: d(-180)),
    ],
    odometer: {2: OdometerReading(id: 1, assetId: 2, date: d(-12), km: 47310)},
    vendors: [const Vendor(id: 1, name: 'Bengkel Ah Seng', phone: '012-345 6789', trade: 'workshop')],
    documents: [AssetDocument(id: 1, assetId: 2, filePath: 'x.pdf', title: 'Polisi insurans 2026', docType: 'insurance', expiry: d(9), addedAt: d(-30))],
    settings: const {},
    costItems: {
      1: const [CostItem(id: 1, recordId: 1, label: 'Minyak enjin', amount: 180), CostItem(id: 2, recordId: 1, label: 'Upah', amount: 65.5)],
    },
  );
}

Widget _app(Widget home, World w, {required String lang, required Brightness brightness}) => AppScope(
      db: AppDb(NativeDatabase.memory()),
      s: strFor(lang),
      lang: lang,
      world: ValueNotifier<World?>(w),
      notif: ValueNotifier<bool?>(true),
      rebuildInfo: ValueNotifier(null),
      setLang: (_) {},
      rebuildNow: () async {},
      lockChanged: () {},
      lockNow: () {},
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(brightness),
        locale: Locale(lang),
        supportedLocales: const [Locale('ms'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      ),
    );

void main() {
  setUpAll(() async {
    if (!_enabled) return;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(appName: 'Kukira Asset', packageName: 'app.kukira.kukira_asset', version: '0.2.4', buildNumber: '6', buildSignature: '');
    if (_out.existsSync()) _out.deleteSync(recursive: true);
    _out.createSync(recursive: true);
  });
  tearDownAll(() {
    if (!_enabled) return;
    final report = _problems.isEmpty ? 'No layout problems.' : _problems.join('\n');
    File('${_out.path}/problems.txt').writeAsStringSync('$report\n');
  });

  void shot(String name, Widget Function() screen, {World? world, String lang = 'ms', Brightness brightness = Brightness.light, double height = phoneHeight}) {
    testWidgets(name, skip: !_enabled, (tester) async {
      setPhone(tester, height: height);
      debugDisableShadows = false;
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => _problems.add('$name: ${d.exceptionAsString().split('\n').first}');
      try {
        await tester.pumpWidget(RepaintBoundary(key: _boundary, child: _app(screen(), world ?? demoWorld(), lang: lang, brightness: brightness)));
        await tester.pumpAndSettle();
        await expectLater(find.byKey(_boundary), matchesGoldenFile('goldens/$name.png'));
      } finally {
        FlutterError.onError = previous;
        debugDisableShadows = true;
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  shot('01-hari-ini', () => const Shell());
  shot('02-hari-ini-kosong', () => const Shell(), world: _emptyWorld());
  shot('03-aset', () => const AssetsScreen());
  shot('04-kereta', () => const AssetDetailScreen(assetId: 2));
  shot('05-rumah', () => const AssetDetailScreen(assetId: 1));
  shot('06-peringatan-baharu', () => const ReminderFormScreen(), height: 1500);
  shot('07-rekod-baharu', () => const RecordFormScreen(assetId: 2), height: 1700);
  shot('08-dokumen', () => const DocumentsScreen());
  shot('09-lagi', () => const MoreScreen(), height: 1100);
  shot('10-semakan-peringatan', () {
    ErrorLog.detach();
    ErrorLog.record('notifications.schedule', StateError('example error'));
    return const HealthScreen();
  }, height: 1500);
  shot('11-sandaran', () => const BackupScreen(), height: 1100);
  shot('12-tambah-aset', () => const AddAssetScreen());
  shot('13-kunci', () => LockScreen(s: strFor('ms'), onChecked: () {}));
  shot('14-vendor', () => const VendorsScreen());
  shot('15-ubah-rumah', () => const HouseEditScreen(assetId: 1), height: 2200);
  shot('16-ubah-kenderaan', () => const VehicleEditScreen(assetId: 2), height: 2200);
  shot('20-gelap-hari-ini', () => const Shell(), brightness: Brightness.dark);
  shot('21-gelap-kereta', () => const AssetDetailScreen(assetId: 2), brightness: Brightness.dark);
  shot('22-gelap-peringatan-baharu', () => const ReminderFormScreen(), brightness: Brightness.dark);
  shot('30-en-today', () => const Shell(), lang: 'en');
  shot('31-en-car', () => const AssetDetailScreen(assetId: 2), lang: 'en');
  shot('32-en-more', () => const MoreScreen(), lang: 'en', height: 1100);
}

World _emptyWorld() => World(
      assets: const [],
      houses: const {},
      vehicles: const {},
      reminders: const [],
      records: const [],
      odometer: const {},
      vendors: const [],
      documents: const [],
      settings: const {},
      costItems: const {},
    );
