import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/ui/lock.dart';

void main() {
  Widget app({required bool locked}) => MaterialApp(
        home: LockCover(
          locked: locked,
          lock: const Scaffold(body: Center(child: Text('Enter PIN'))),
          child: const Scaffold(body: Column(children: [Text('Road tax WXY 4821'), TextField(key: ValueKey('note'))])),
        ),
      );

  testWidgets('while locked, the records behind the lock are hidden from screen readers and focus', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(locked: true));
    expect(find.bySemanticsLabel('Enter PIN'), findsOneWidget);
    expect(find.bySemanticsLabel('Road tax WXY 4821'), findsNothing);
    final field = tester.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('note')), matching: find.byType(EditableText)));
    field.focusNode.requestFocus();
    await tester.pump();
    expect(field.focusNode.hasFocus, isFalse, reason: 'nothing behind the lock can take keyboard focus');

    await tester.pumpWidget(app(locked: false));
    expect(find.bySemanticsLabel('Road tax WXY 4821'), findsOneWidget);
    expect(find.text('Enter PIN'), findsNothing);
    semantics.dispose();
  });

  testWidgets('unlocking keeps what was on screen (the app underneath is not rebuilt from scratch)', (tester) async {
    await tester.pumpWidget(app(locked: false));
    await tester.enterText(find.byKey(const ValueKey('note')), 'half-typed note');
    await tester.pumpWidget(app(locked: true));
    await tester.pumpWidget(app(locked: false));
    expect(find.text('half-typed note'), findsOneWidget);
  });
}
