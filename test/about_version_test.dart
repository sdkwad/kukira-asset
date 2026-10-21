import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/more.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('Privacy and about shows the version from pubspec.yaml', (tester) async {
    // The APK's package version is pubspec.yaml's `version:`, so the screen must show exactly that.
    final m = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(m, isNotNull, reason: 'pubspec.yaml must have version: x.y.z+n');
    final version = m!.group(1)!;
    final build = m.group(2)!;
    PackageInfo.setMockInitialValues(appName: 'Kukira Asset', packageName: 'app.kukira.kukira_asset', version: version, buildNumber: build, buildSignature: '');

    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const AboutScreen(), fakeWorld()));
    await tester.pumpAndSettle();
    expect(find.text(strFor('en').aboutVersion(version, build)), findsOneWidget);
  });

  test('the About screen has no hardcoded version', () {
    final src = File('lib/ui/more.dart').readAsStringSync();
    expect(RegExp(r"Kukira Asset \d+\.\d+\.\d+").hasMatch(src), isFalse);
  });
}
