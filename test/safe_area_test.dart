// Every form and list screen, rendered on a phone with a 48 px navigation bar:
// after scrolling to the end, the last item (usually the Save button) must sit above the bar.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/add_asset.dart';
import 'package:kukira_asset/ui/assets.dart';
import 'package:kukira_asset/ui/documents.dart';
import 'package:kukira_asset/ui/forms.dart';
import 'package:kukira_asset/ui/lock.dart';
import 'package:kukira_asset/ui/more.dart';
import 'package:kukira_asset/ui/today.dart';
import 'package:kukira_asset/ui/vendors.dart';

import 'helpers.dart';

const inset = 48.0;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');

  final cases = <String, (Widget, Finder)>{
    'New reminder': (const ReminderFormScreen(assetId: 2), find.text(s.saveReminder)),
    'New record': (const RecordFormScreen(assetId: 1), find.text(s.saveRecord)),
    'Edit details (house)': (const HouseEditScreen(assetId: 1), find.text(s.saveChanges)),
    'Edit details (vehicle)': (const VehicleEditScreen(assetId: 2), find.text(s.saveChanges)),
    'Asset detail': (const AssetDetailScreen(assetId: 1), find.text(s.editDetails)),
    'Add asset': (const AddAssetScreen(), find.text(s.onlyNameNeeded)),
    'Attach document': (const DocumentFormScreen(assetId: 1), find.text(s.docCopiedNote)),
    'Vendor form': (const VendorFormScreen(), find.text(s.save)),
    'Vendor book': (const VendorsScreen(), find.byType(FloatingActionButton)),
    'All reminders': (const AllRemindersScreen(), find.text(s.addReminder)),
    'Reminder health check': (const HealthScreen(), find.text(s.todayIsGuaranteed)),
    'Backup and restore': (const BackupScreen(), find.text(s.backupNudgeNote)),
    'App lock': (const SecurityScreen(), find.text(s.pinForgetNote)),
    'Assets': (const AssetsScreen(), find.text(s.addAsset)),
    'Documents': (const DocumentsScreen(), find.text(s.docsPrivacyNote)),
    'More': (const MoreScreen(), find.text(s.privacyAbout)),
    'Today': (const TodayScreen(), find.textContaining(s.allReminders(1))),
  };

  for (final MapEntry(key: name, value: (screen, last)) in cases.entries) {
    testWidgets('$name keeps its last item above the navigation bar', (tester) async {
      setPhone(tester, bottomInset: inset);
      await tester.pumpWidget(harness(screen, fakeWorld()));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.dragFrom(const Offset(phoneWidth / 2, 420), const Offset(0, -1500));
        await tester.pumpAndSettle();
      }
      expect(last, findsWidgets, reason: '$name: last item not found');
      final bottom = tester.getRect(last.last).bottom;
      expect(bottom, lessThanOrEqualTo(phoneHeight - inset + 0.5), reason: '$name: last item ends at $bottom, under the navigation bar');
    });
  }
}
