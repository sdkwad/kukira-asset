// Backups to a cloud drive (0.2.8): offered first when saving, through Android's own save
// dialog so the app still has no internet permission, and a warning when the last backup is
// only on the phone.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/more.dart';

import 'helpers.dart';

World withSettings(World w, Map<String, String> settings) => World(
      assets: w.assets,
      houses: w.houses,
      vehicles: w.vehicles,
      reminders: w.reminders,
      records: w.records,
      odometer: w.odometer,
      vendors: w.vendors,
      documents: w.documents,
      settings: settings,
      costItems: w.costItems,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');

  testWidgets('a cloud drive is the first place offered for a new backup', (tester) async {
    setPhone(tester, height: 1200);
    String? picked = 'unset';
    await tester.pumpWidget(harness(
      Builder(builder: (c) => TextButton(onPressed: () async => picked = await chooseBackupPlace(c), child: const Text('save'))),
      fakeWorld(),
    ));
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    final cloud = tester.getRect(find.text(s.saveToCloud));
    expect(cloud.top, lessThan(tester.getRect(find.text(s.shareToApp)).top));
    expect(find.text(s.saveToCloudHint), findsOneWidget, reason: 'it says the app itself never goes online');
    await tester.tap(find.text(s.saveToCloud));
    await tester.pumpAndSettle();
    expect(picked, 'cloud');
  });

  testWidgets('a backup kept only on the phone is pointed out; one in the cloud is not', (tester) async {
    setPhone(tester, height: 1600);
    final when = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
    await tester.pumpWidget(harness(const BackupScreen(), withSettings(fakeWorld(), {'lastBackup': when, 'lastBackupTo': 'folder'})));
    await tester.pumpAndSettle();
    expect(find.text(s.backupOnlyOnPhone), findsOneWidget);
    expect(find.text(s.restoreFromCloudHint), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(const BackupScreen(), withSettings(fakeWorld(), {'lastBackup': when, 'lastBackupTo': 'cloud'})));
    await tester.pumpAndSettle();
    expect(find.text(s.backupOnlyOnPhone), findsNothing);
    expect(find.textContaining(s.backupInCloud), findsOneWidget);
  });
}
