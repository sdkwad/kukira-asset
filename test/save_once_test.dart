import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/common.dart';
import 'package:kukira_asset/ui/vendors.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('SaveButton runs once while a save is in progress', (tester) async {
    var calls = 0;
    final done = Completer<void>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SaveButton(
          onPressed: () {
            calls++;
            return done.future;
          },
          child: const Text('Save'),
        ),
      ),
    ));

    // Two taps before the button has rebuilt, then a third while it shows the spinner.
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    done.complete();
    await tester.pump();
    expect(find.text('Save'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });

  testWidgets('a double tap on Save in the vendor form adds one vendor', (tester) async {
    setPhone(tester);
    final s = strFor('en');
    final db = AppDb(NativeDatabase.memory());
    await tester.pumpWidget(harness(
      Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const VendorFormScreen())),
          child: const Text('open'),
        ),
      ),
      fakeWorld(),
      db: db,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Bengkel Ah Seng');
    // The form is a lazy list: scroll until the Save button exists and is on screen.
    await tester.scrollUntilVisible(find.text(s.save), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(s.save));
    await tester.tap(find.text(s.save), warnIfMissed: false);
    await tester.pumpAndSettle();

    final vendors = await tester.runAsync(() => db.select(db.vendors).get());
    expect(vendors!.map((v) => v.name), ['Bengkel Ah Seng']);
    expect(find.text('open'), findsOneWidget, reason: 'the form closed once, back to the first page');
    await tester.runAsync(db.close);
  });
}
