import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/add_asset.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('adding a house with two suggested tax reminders saves the house and both reminders', (tester) async {
    setPhone(tester, height: 1800);
    final s = strFor('en');
    final db = AppDb(NativeDatabase.memory());
    await tester.pumpWidget(harness(
      Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AddAssetScreen())),
          child: const Text('open'),
        ),
      ),
      fakeWorld(),
      db: db,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Step 1: what. Step 2: name and property type.
    await tester.tap(find.text(s.categoryName('house')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Rumah Shah Alam');
    await tester.tap(find.text(s.done));
    await tester.pumpAndSettle();

    // Step 3: suggested reminders with a default date each.
    await tester.tap(find.text(s.presetTitle('cukaiTanah')));
    await tester.tap(find.text(s.presetTitle('cukaiTaksiran')));
    await tester.pump();
    final save = find.text(s.saveN(2));
    await tester.scrollUntilVisible(save, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final (assets, reminders) = (await tester.runAsync(() async => (await db.select(db.assets).get(), await db.select(db.reminders).get())))!;
    expect(assets.single.nickname, 'Rumah Shah Alam');
    expect(reminders.map((r) => r.category).toSet(), {'cukai_tanah', 'cukai_taksiran'});
    expect(reminders.every((r) => r.estimated && r.repeatFrom == 'due' && r.dueDate != null), isTrue);
    await tester.runAsync(db.close);
  });

  testWidgets('a vehicle needs its plate before it is added', (tester) async {
    setPhone(tester, height: 1600);
    final s = strFor('en');
    final db = AppDb(NativeDatabase.memory());
    await tester.pumpWidget(harness(const AddAssetScreen(), fakeWorld(), db: db));
    await tester.tap(find.text(s.categoryName('car')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Myvi');
    await tester.tap(find.text(s.done));
    await tester.pumpAndSettle();
    expect(find.text(s.errPlate), findsOneWidget);
    expect(await tester.runAsync(() => db.select(db.assets).get()), isEmpty);
    await tester.runAsync(db.close);
  });
}
