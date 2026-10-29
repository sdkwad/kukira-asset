// Shared test harness: a fake World and an AppScope, so screens can be pumped
// without a real database, notifications or secure storage.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/common.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePaths extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePaths(this.root);
  final Directory root;

  @override
  Future<String?> getApplicationSupportPath() async => (await Directory('${root.path}/support').create(recursive: true)).path;

  @override
  Future<String?> getTemporaryPath() async => (await Directory('${root.path}/tmp').create(recursive: true)).path;
}

/// Points app storage (database folder, encrypted files, temp) at a fresh temporary folder.
/// Returns that folder; it is deleted after the test.
Future<Directory> useTempStorage() async {
  final root = await Directory.systemTemp.createTemp('kukira_test_');
  PathProviderPlatform.instance = _FakePaths(root);
  addTearDown(() => root.delete(recursive: true));
  return root;
}

final _t = DateTime(2026, 10, 20);

Asset fakeAsset(int id, String category, String name) =>
    Asset(id: id, nickname: name, category: category, createdAt: _t, updatedAt: _t);

Reminder fakeReminder({
  int id = 1,
  int assetId = 2,
  String title = 'Road tax renewal',
  DateTime? due,
  bool done = false,
  DateTime? snoozedUntil,
  String? autoSource,
}) =>
    Reminder(
      id: id,
      assetId: assetId,
      title: title,
      ruleType: 'fixed',
      dueDate: due ?? DateTime(2026, 11, 3),
      repeatFrom: 'completion',
      leadDays: 14,
      leadKm: 1000,
      source: 'manual',
      estimated: false,
      done: done,
      snoozedUntil: snoozedUntil,
      autoSource: autoSource,
      createdAt: _t,
    );

/// House (id 1) and car (id 2).
World fakeWorld({String ptype = 'landed', String? source, DateTime? vp, DateTime? roadTax, List<Reminder>? reminders}) => World(
      assets: [fakeAsset(1, 'house', 'Setia Alam house'), fakeAsset(2, 'car', 'Myvi')],
      houses: {1: HouseProfile(assetId: 1, propertyType: ptype, source: source, vpDate: vp)},
      vehicles: {2: VehicleProfile(assetId: 2, vehicleType: 'car', plate: 'WXY 4821', roadTaxExpiry: roadTax)},
      reminders: reminders ?? [fakeReminder()],
      records: const [],
      odometer: const {},
      vendors: const [],
      documents: const [],
      settings: const {},
      costItems: const {},
    );

Widget harness(Widget home, World w, {String lang = 'en'}) => AppScope(
      // Never opened: the screens under test only read from [world].
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
        locale: Locale(lang),
        supportedLocales: const [Locale('ms'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      ),
    );

const phoneWidth = 360.0;
const phoneHeight = 760.0;

/// A 360 x 760 phone with a status bar and a 3-button navigation bar ([bottomInset] logical px).
void setPhone(WidgetTester tester, {double bottomInset = 48, double height = phoneHeight}) {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(phoneWidth * dpr, height * dpr);
  tester.view.padding = FakeViewPadding(top: 24 * dpr, bottom: bottomInset * dpr);
  tester.view.viewPadding = FakeViewPadding(top: 24 * dpr, bottom: bottomInset * dpr);
  addTearDown(tester.view.reset);
}
