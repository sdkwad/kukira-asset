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
  // Not RobotoCondensed: in the same family it replaced the regular weight, so body text
  // was drawn narrower than on the phone.
  for (final f in files.where((f) => f.path.contains('Roboto') && !f.path.contains('Condensed') && f.path.endsWith('.ttf'))) {
    roboto.addFont(bytes(f));
  }
  await roboto.load();
  // The number plate asks for the phone's 'monospace' font, which tests don't have.
  final mono = FontLoader('monospace');
  for (final f in files.where((f) => f.path.endsWith('Roboto-Bold.ttf'))) {
    mono.addFont(bytes(f));
  }
  await mono.load();
  final icons = FontLoader('MaterialIcons');
  for (final f in files.where((f) => f.path.contains('MaterialIcons'))) {
    icons.addFont(bytes(f));
  }
  await icons.load();
}

/// A house, a car and a motorcycle with reminders in every state, records and a vendor.
/// Categories are the real record category keys (lib/domain/presets.dart), so screens that
/// match records to reminders behave as on the phone.
/// Photos decode outside the test's fake clock; without this they would be blank.
Future<void> _decodeImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pumpAndSettle();
}

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
      // Photos on the house and the motorcycle (test/fixtures); the car has none.
      Asset(id: 1, nickname: 'Rumah Setia Alam', category: 'house', photoPath: 'house.jpg', createdAt: created, updatedAt: created),
      Asset(id: 2, nickname: 'Myvi', category: 'car', createdAt: created, updatedAt: created),
      Asset(id: 3, nickname: 'Y15ZR', category: 'motorcycle', photoPath: 'moto.jpg', createdAt: created, updatedAt: created),
    ],
    houses: {1: HouseProfile(assetId: 1, propertyType: 'landed', source: 'new_from_developer', vpDate: d(-300), titleStatus: 'individual', council: 'MBSA', state: 'Selangor')},
    vehicles: {
      2: VehicleProfile(assetId: 2, vehicleType: 'car', plate: 'WXY 4821', make: 'Perodua', model: 'Myvi', year: 2021, roadTaxExpiry: d(9), insuranceExpiry: d(9)),
      3: VehicleProfile(assetId: 3, vehicleType: 'motorcycle', plate: 'BMK 772', make: 'Yamaha', model: 'Y15ZR', year: 2019, roadTaxExpiry: d(140)),
    },
    reminders: [
      rem(1, 2, 'Pembaharuan cukai jalan', d(9), category: 'road_tax', auto: 'roadTax'),
      rem(2, 2, 'Pembaharuan insurans', d(9), category: 'insurance_premium', lead: 30, auto: 'insurance'),
      rem(3, 2, 'Tukar minyak enjin', d(-6), rule: 'either', category: 'oil', dueKm: 48000, everyMonths: 6, everyKm: 10000),
      rem(4, 1, 'Cukai tanah', d(45), rule: 'repeat', category: 'cukai_tanah', everyMonths: 12, lead: 30, estimated: true),
      rem(5, 1, 'Cukai taksiran (penggal 1)', d(120), rule: 'repeat', category: 'cukai_taksiran', everyMonths: 6, estimated: true),
      rem(6, 1, 'Servis penghawa dingin', d(-2), rule: 'repeat', category: 'aircond', everyMonths: 6),
      rem(7, 1, 'Tamat tempoh DLP', d(430), category: 'dlp', lead: 60, estimated: true, auto: 'dlp'),
      rem(8, 3, 'Pembaharuan cukai jalan', d(140), category: 'road_tax', auto: 'roadTax'),
      rem(9, 2, 'Putar tayar', d(20), rule: 'repeat', category: 'tyre', everyMonths: 6),
      rem(10, 1, 'Cuci tangki air', null, done: true, completed: d(-3)),
    ],
    records: [
      UpkeepRecord(id: 1, assetId: 2, kind: 'maintenance', category: 'oil', title: 'Servis 40,000 km', date: d(-170), cost: 245.5, vendorName: 'Bengkel Ah Seng', vendorId: 1, odometer: 40120, createdAt: d(-170)),
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

Widget _app(Widget home, World w, {required String lang, required Brightness brightness, double textScale = 1}) => AppScope(
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
        // Android's font size setting, for the large-text pictures.
        builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
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
    final photos = {for (final n in ['house.jpg', 'moto.jpg']) n: MemoryImage(File('test/fixtures/$n').readAsBytesSync())};
    SecureImage.debugImage = (name) => photos[name] ?? photos['house.jpg']!;
    if (_out.existsSync()) _out.deleteSync(recursive: true);
    _out.createSync(recursive: true);
  });
  tearDownAll(() {
    if (!_enabled) return;
    final report = _problems.isEmpty ? 'No layout problems.' : _problems.join('\n');
    File('${_out.path}/problems.txt').writeAsStringSync('$report\n');
  });

  void shot(String name, Widget Function() screen,
      {World? world,
      String lang = 'ms',
      Brightness brightness = Brightness.light,
      double height = phoneHeight,
      double textScale = 1,
      Future<void> Function(WidgetTester t)? act}) {
    testWidgets(name, skip: !_enabled, (tester) async {
      setPhone(tester, height: height);
      debugDisableShadows = false;
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => _problems.add('$name: ${d.exceptionAsString().split('\n').first}');
      try {
        await tester.pumpWidget(RepaintBoundary(key: _boundary, child: _app(screen(), world ?? demoWorld(), lang: lang, brightness: brightness, textScale: textScale)));
        await tester.pumpAndSettle();
        await _decodeImages(tester);
        // For tabs and sheets: tap through to the state to picture.
        if (act != null) {
          await act(tester);
          await tester.pumpAndSettle();
          await _decodeImages(tester);
        }
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
  shot('29-hari-ini-tenang', () => const Shell(), world: _calmWorld());
  shot('03-aset', () => const AssetsScreen());
  shot('04-kereta', () => const AssetDetailScreen(assetId: 2));
  shot('05-rumah', () => const AssetDetailScreen(assetId: 1));
  shot('06-peringatan-baharu', () => const ReminderFormScreen(assetId: 1), height: 1500);
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
  final ms = strFor('ms');
  Future<void> Function(WidgetTester) tap(String text) => (t) async {
        await t.ensureVisible(find.text(text).first);
        await t.pumpAndSettle();
        await t.tap(find.text(text).first);
      };
  shot('17-kereta-rekod', () => const AssetDetailScreen(assetId: 2), act: tap(ms.upkeepTab));
  shot('18-kereta-peringatan', () => const AssetDetailScreen(assetId: 2), act: tap(ms.remindersTab), height: 1100);
  // Defects are records now: the Records tab, filtered to defects.
  shot('19-rumah-kecacatan', () => const AssetDetailScreen(assetId: 1), act: (t) async {
    await tap(ms.upkeepTab)(t);
    await t.pumpAndSettle();
    await tap(ms.kindName('defect'))(t);
  });
  shot('45-rumah-rekod', () => const AssetDetailScreen(assetId: 1), act: tap(ms.upkeepTab));
  shot('23-lembaran-peringatan', () => const Shell(), act: tap('Tukar minyak enjin'));
  shot('24-lembaran-rekod', () => const AssetDetailScreen(assetId: 2), act: (t) async {
    await tap(ms.upkeepTab)(t);
    await t.pumpAndSettle();
    await tap('Servis 40,000 km')(t);
  });
  shot('25-semua-peringatan', () => const AllRemindersScreen(), height: 1400);
  shot('26-kunci-app', () => const SecurityScreen());
  shot('27-privasi', () => const AboutScreen());
  shot('28-dokumen-baharu', () => const DocumentFormScreen(assetId: 2), height: 1100);
  shot('20-gelap-hari-ini', () => const Shell(), brightness: Brightness.dark);
  shot('21-gelap-kereta', () => const AssetDetailScreen(assetId: 2), brightness: Brightness.dark);
  shot('22-gelap-peringatan-baharu', () => const ReminderFormScreen(assetId: 1), brightness: Brightness.dark);
  // Tambah: from Today (asks which asset), from a car and a house page, and a form opened
  // without an asset.
  Future<void> openAdd(WidgetTester t) => t.tap(find.byType(FloatingActionButton).hitTestable());
  shot('40-tambah-pilih-aset', () => const Shell(), act: openAdd);
  shot('41-tambah-kereta', () => const AssetDetailScreen(assetId: 2), act: openAdd);
  shot('42-tambah-rumah', () => const AssetDetailScreen(assetId: 1), act: openAdd);
  shot('43-rekod-pilih-aset', () => const RecordFormScreen());
  shot('44-gelap-tambah-kereta', () => const AssetDetailScreen(assetId: 2), brightness: Brightness.dark, act: openAdd);
  // Android font size at 130% on the same 360 dp phone.
  shot('50-besar-hari-ini', () => const Shell(), textScale: 1.3);
  shot('51-besar-kereta', () => const AssetDetailScreen(assetId: 2), textScale: 1.3);
  shot('52-besar-tambah-kereta', () => const AssetDetailScreen(assetId: 2), textScale: 1.3, act: openAdd);
  shot('53-besar-rekod-baharu', () => const RecordFormScreen(assetId: 2), textScale: 1.3, height: 2000);
  shot('54-besar-semua-peringatan', () => const AllRemindersScreen(), textScale: 1.3, height: 1600);
  shot('55-besar-tambah-pilih-aset', () => const Shell(), textScale: 1.3, act: openAdd);
  shot('30-en-today', () => const Shell(), lang: 'en');
  shot('31-en-car', () => const AssetDetailScreen(assetId: 2), lang: 'en');
  shot('32-en-more', () => const MoreScreen(), lang: 'en', height: 1100);
}

/// The demo with nothing overdue or due in 30 days, and a backup two days ago.
World _calmWorld() {
  final w = demoWorld();
  final now = DateTime.now();
  return World(
    assets: w.assets,
    houses: w.houses,
    vehicles: w.vehicles,
    reminders: w.reminders.where((r) => r.done || (r.dueDate != null && r.dueDate!.difference(now).inDays > 30)).toList(),
    records: w.records,
    odometer: w.odometer,
    vendors: w.vendors,
    documents: w.documents,
    settings: {'lastBackup': now.subtract(const Duration(days: 2)).toIso8601String()},
    costItems: w.costItems,
  );
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
