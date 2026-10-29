import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/domain/pin_throttle.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/lock.dart';

import 'helpers.dart';

void main() {
  group('PinThrottle', () {
    final t0 = DateTime(2026, 10, 29, 9);

    test('four wrong PINs are free, then each one adds 30 seconds', () {
      var t = PinThrottle.none;
      for (var i = 0; i < 4; i++) {
        t = t.failed(t0);
      }
      expect(t.waiting(t0), isFalse);
      t = t.failed(t0);
      expect(t.waitUntil, t0.add(const Duration(seconds: 30)));
      t = t.failed(t0);
      expect(t.waitUntil, t0.add(const Duration(seconds: 60)));
      expect(t.waiting(t0.add(const Duration(seconds: 59))), isTrue);
      expect(t.waiting(t0.add(const Duration(seconds: 60))), isFalse);
    });

    test('survives being saved and read back', () {
      final t = const PinThrottle(6, null).failed(t0);
      final back = PinThrottle.decode(t.encode());
      expect(back.fails, 7);
      expect(back.waitUntil, t.waitUntil);
    });

    test('a damaged saved value never locks the user out', () {
      for (final v in [null, '', 'x', '-3|2026', 'abc|def']) {
        expect(PinThrottle.decode(v).waiting(t0), isFalse, reason: '$v');
      }
    });
  });

  testWidgets('the wait after too many wrong PINs survives closing the app', (tester) async {
    // No PIN is stored, so every PIN is wrong.
    FlutterSecureStorage.setMockInitialValues({});
    setPhone(tester);
    final s = strFor('en');
    Widget app(Key key) => MaterialApp(
          key: key,
          locale: const Locale('en'),
          supportedLocales: const [Locale('ms'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: LockScreen(s: s, onChecked: () {}),
        );
    final waitText = find.textContaining('Too many tries');

    await tester.pumpWidget(app(const ValueKey(1)));
    await tester.pump();
    for (var attempt = 1; attempt <= 5; attempt++) {
      expect(waitText, findsNothing, reason: 'attempt $attempt');
      for (final d in ['1', '2', '3', '4']) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(waitText, findsOneWidget);

    // "Closing and reopening the app": a brand-new lock screen reads the saved count.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(const ValueKey(2)));
    await tester.pump();
    expect(waitText, findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Dispose, so the countdown timer stops.
    await tester.pumpWidget(const SizedBox());
  });
}
