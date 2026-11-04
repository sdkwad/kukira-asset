// Documents (0.2.7d): by asset with the three that matter most first, filters for asset and
// type, and a search that also finds records that mention the words.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/db.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/common.dart';
import 'package:kukira_asset/ui/documents.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final s = strFor('en');
  final t = today();

  AssetDocument doc(int id, int assetId, String title, String type, {int? expiresIn, int addedDaysAgo = 10, int? record, String file = 'f.pdf'}) => AssetDocument(
        id: id,
        assetId: assetId,
        filePath: '$id-$file',
        title: title,
        docType: type,
        linkedRecordId: record,
        expiry: expiresIn == null ? null : t.add(Duration(days: expiresIn)),
        addedAt: t.subtract(Duration(days: addedDaysAgo)),
      );

  World withDocs(List<AssetDocument> docs, {List<UpkeepRecord> records = const []}) {
    final w = fakeWorld();
    return World(
      assets: w.assets,
      houses: w.houses,
      vehicles: w.vehicles,
      reminders: w.reminders,
      records: records,
      odometer: w.odometer,
      vendors: w.vendors,
      documents: docs,
      settings: w.settings,
      costItems: w.costItems,
    );
  }

  final carDocs = [
    doc(1, 2, 'Insurance policy 2025-2026', 'insurance', expiresIn: 8, record: 7),
    doc(2, 2, 'Road tax e-LKM', 'other', expiresIn: 8, addedDaysAgo: 30),
    doc(3, 2, 'Vehicle grant (VOC)', 'geran', addedDaysAgo: 400),
    doc(4, 2, 'Old insurance policy', 'insurance', expiresIn: -300, addedDaysAgo: 700),
    doc(5, 2, 'Battery receipt', 'receipt', addedDaysAgo: 2),
  ];
  final houseDocs = [doc(6, 1, 'Sale and purchase agreement', 'spa', addedDaysAgo: 600)];

  test('documents about to end come first, then the newest', () {
    final sorted = [...carDocs]..sort((a, b) => compareDocs(a, b, t));
    expect(sorted.map((d) => d.id), [1, 2, 5, 3, 4]);
  });

  testWidgets('each asset shows its three first, and the rest on request', (tester) async {
    setPhone(tester, height: 1800);
    await tester.pumpWidget(harness(const DocumentsScreen(), withDocs([...carDocs, ...houseDocs])));
    await tester.pumpAndSettle();
    expect(find.text(s.docsCountEncrypted(6)), findsOneWidget);
    expect(find.text('Insurance policy 2025-2026'), findsOneWidget);
    expect(find.text('Battery receipt'), findsOneWidget);
    expect(find.text('Vehicle grant (VOC)'), findsNothing);
    expect(find.text('Sale and purchase agreement'), findsOneWidget);
    expect(find.text('${s.docTypeName('insurance')} · ${s.filePdf} · ${s.linkedToRecord}'), findsOneWidget);
    await tester.tap(find.text(s.seeMore(2)));
    await tester.pumpAndSettle();
    expect(find.text('Vehicle grant (VOC)'), findsOneWidget);
    expect(find.text('Old insurance policy'), findsOneWidget);
    expect(find.text(s.seeMore(2)), findsNothing);
  });

  testWidgets('filters by asset and by type', (tester) async {
    setPhone(tester, height: 1800);
    await tester.pumpWidget(harness(const DocumentsScreen(), withDocs([...carDocs, ...houseDocs])));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.assetFilter(s.all)));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Setia Alam house')));
    await tester.pumpAndSettle();
    expect(find.text(s.assetFilter('Setia Alam house')), findsOneWidget);
    expect(find.text('Sale and purchase agreement'), findsOneWidget);
    expect(find.text('Battery receipt'), findsNothing);

    await tester.tap(find.text(s.assetFilter('Setia Alam house')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(s.all)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.typeFilter(s.all)));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(s.docTypeName('insurance'))));
    await tester.pumpAndSettle();
    expect(find.text('Insurance policy 2025-2026'), findsOneWidget);
    expect(find.text('Old insurance policy'), findsOneWidget, reason: 'all of them, as only one type is shown');
    expect(find.text('Battery receipt'), findsNothing);
    expect(find.text('Sale and purchase agreement'), findsNothing);
  });

  testWidgets('a search lists matching documents with their asset, and records that mention it', (tester) async {
    setPhone(tester, height: 1800);
    final renewal = UpkeepRecord(
      id: 7,
      assetId: 2,
      kind: 'payment',
      title: 'Insurance renewal',
      date: t.subtract(const Duration(days: 20)),
      cost: 1086.40,
      notes: 'New policy, NCD 25%. Agent: Encik Rahman',
      createdAt: t,
    );
    final roadTax = UpkeepRecord(id: 8, assetId: 2, kind: 'payment', title: 'Road tax', date: t, notes: 'policy no. ET-2603-7781', createdAt: t);
    await tester.pumpWidget(harness(const DocumentsScreen(), withDocs([...carDocs, ...houseDocs], records: [renewal, roadTax])));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'policy');
    await tester.pumpAndSettle();
    expect(find.text(s.documentsTab), findsWidgets);
    expect(find.text('Insurance policy 2025-2026'), findsOneWidget);
    expect(find.text('Old insurance policy'), findsOneWidget, reason: 'a search lists all, not three');
    expect(find.text('Myvi · ${s.docTypeName('insurance')} · ${s.filePdf}'), findsNWidgets(2));
    expect(find.text(s.alsoInRecords), findsOneWidget);
    expect(find.text('Road tax'), findsOneWidget);
    expect(find.textContaining('${s.notes.toLowerCase()}: policy no. ET-2603'), findsOneWidget);
    expect(find.text(s.rm(1086.40)), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pumpAndSettle();
    expect(find.text(s.noMatch), findsOneWidget);
  });

  test('the record search says where it found the words', () {
    final r = UpkeepRecord(id: 1, assetId: 2, kind: 'maintenance', title: 'Service', date: t, notes: 'Changed the battery and wipers', createdAt: t);
    final w = withDocs(const [], records: [r]);
    expect(searchRecords(s, w, 'service').single.$2, isNull, reason: 'found in its name');
    expect(searchRecords(s, w, 'battery').single.$2, '${s.notes.toLowerCase()}: Changed the battery and wipers');
    expect(searchRecords(s, w, 'battery', assetId: 1), isEmpty);
    expect(searchRecords(s, w, '  '), isEmpty);
  });

  testWidgets('Add document is a button of its own, and an empty list says how to start', (tester) async {
    setPhone(tester, height: 1600);
    await tester.pumpWidget(harness(const DocumentsScreen(), withDocs(const [])));
    await tester.pumpAndSettle();
    expect(find.text(s.noDocsTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FloatingActionButton, s.addDocument));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentFormScreen), findsOneWidget);
  });

  testWidgets('the page fits a 360 dp phone at 130% text', (tester) async {
    setPhone(tester);
    await tester.pumpWidget(harness(
      MediaQuery.withClampedTextScaling(minScaleFactor: 1.3, maxScaleFactor: 1.3, child: const DocumentsScreen()),
      withDocs([...carDocs, ...houseDocs]),
      lang: 'ms',
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
