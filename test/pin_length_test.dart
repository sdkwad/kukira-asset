// A 6-digit PIN (0.2.8 build 16): the default for a new PIN, 4 digits still allowed, PINs
// set before keep working, and the PIN can be changed. The length is kept in the same entry
// as the wrapped key, so the two never disagree.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/data/vault.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/lock.dart';

import 'helpers.dart';

const wrappedKey = 'kukira_db_key_wrapped_v1';
final hex = 'ab' * 32;

void main() {
  final s = strFor('en');

  group('the stored PIN', () {
    test('keeps its length with the wrapped key, and older PINs count as 4 digits', () async {
      FlutterSecureStorage.setMockInitialValues({});
      expect(await Vault.pinLength(), 4, reason: 'no PIN at all');

      FlutterSecureStorage.setMockInitialValues({wrappedKey: await Vault.wrapKey(hex, '135790')});
      expect(await Vault.pinLength(), 6);
      expect(await Vault.checkPin('135790'), isTrue);
      expect(await Vault.checkPin('1357'), isFalse);

      // As 0.2.0 to 0.2.8 build 15 stored it: no length.
      FlutterSecureStorage.setMockInitialValues({wrappedKey: '{"salt":"AAAA","box":"AAAA"}'});
      expect(await Vault.pinLength(), 4);

      // Anything unreadable never asks for a length the PIN cannot have.
      for (final v in ['not json', '{"len":5}', '{"len":"6"}', '[]']) {
        FlutterSecureStorage.setMockInitialValues({wrappedKey: v});
        expect(await Vault.pinLength(), 4, reason: v);
      }
    });

    test('can be changed to another length, and the old PIN stops working', () async {
      FlutterSecureStorage.setMockInitialValues({wrappedKey: await Vault.wrapKey(hex, '2468'), 'kukira_pin_fails': '3|'});
      Vault.debugUseKey(hex);
      addTearDown(() => Vault.debugUseKey(null));
      expect(await Vault.pinLength(), 4);

      expect(await Vault.changePin('975310'), isTrue);
      expect(await Vault.pinLength(), 6);
      expect(await Vault.checkPin('975310'), isTrue);
      expect(await Vault.checkPin('2468'), isFalse);
      expect((await Vault.pinThrottle()).fails, 0, reason: 'a new PIN starts with no wrong tries');

      Vault.debugUseKey(null);
      expect(await Vault.changePin('111111'), isFalse, reason: 'only while the records are open');
      expect(await Vault.checkPin('975310'), isTrue);
    });
  });

  group('the lock screen', () {
    Future<void> pumpLock(WidgetTester tester, String stored) async {
      FlutterSecureStorage.setMockInitialValues({wrappedKey: stored, 'kukira_lock_mode': 'pin'});
      setPhone(tester, height: 900);
      await tester.pumpWidget(harness(LockScreen(s: s, onChecked: () {}), fakeWorld()));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for six digits when the PIN has six', (tester) async {
      await pumpLock(tester, '{"salt":"AAAA","box":"AAAA","len":6}');
      expect(tester.widget<PinPad>(find.byType(PinPad)).length, 6);
      for (final d in ['1', '2', '3', '4']) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
      // Four digits are not a whole PIN yet: nothing is checked and the digits stay.
      expect(tester.widget<PinPad>(find.byType(PinPad)).value, '1234');
      expect(find.text(s.wrongPin), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('still asks for four digits for a PIN set before', (tester) async {
      await pumpLock(tester, '{"salt":"AAAA","box":"AAAA"}');
      expect(tester.widget<PinPad>(find.byType(PinPad)).length, 4);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('App lock shows the lock and its PIN without waiting for the fingerprint check', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'kukira_lock_mode': 'pin', wrappedKey: '{"salt":"AAAA","box":"AAAA"}'});
    setPhone(tester, height: 1200);
    await tester.pumpWidget(harness(const SecurityScreen(), fakeWorld(), lockMode: 'pin'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, s.lockWithPin)).value, isTrue);
    expect(find.text(s.changePin), findsOneWidget);
    expect(find.text(s.pinIsShort(4)), findsOneWidget, reason: 'a PIN set before is four digits');
    await tester.pumpWidget(const SizedBox());
  });

  group('choosing a new PIN', () {
    testWidgets('is six digits unless four is picked', (tester) async {
      setPhone(tester, height: 1100);
      String? got = 'unset';
      await tester.pumpWidget(harness(
        Builder(builder: (c) => TextButton(onPressed: () async => got = await setNewPin(c), child: const Text('go'))),
        fakeWorld(),
      ));
      Future<void> type(String pin) async {
        for (final d in pin.split('')) {
          await tester.tap(find.text(d).last);
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text(s.choosePinN(6)), findsOneWidget);
      expect(find.text(s.pinLengthHint), findsOneWidget);
      await type('1234');
      expect(find.text(s.pinAgain), findsNothing, reason: 'four digits are not a whole 6-digit PIN');
      await type('56');
      expect(find.text(s.pinAgain), findsOneWidget);
      await type('123456');
      expect(got, '123456');

      // Four digits, picked on purpose.
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.pinDigits(4)));
      await tester.pumpAndSettle();
      expect(find.text(s.choosePinN(4)), findsOneWidget);
      await type('2580');
      expect(find.text(s.pinAgain), findsOneWidget);
      await type('2580');
      expect(got, '2580');
    });
  });
}
