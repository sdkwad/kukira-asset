import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/services/privacy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Recent apps hides the app only while the app lock is on', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(Privacy.channel, (c) async {
      calls.add(c);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(Privacy.channel, null));

    for (final mode in ['none', 'pin', 'pin_bio']) {
      await Privacy.applyLockMode(mode);
    }
    expect(calls.map((c) => c.method).toSet(), {'hideInRecents'});
    expect(calls.map((c) => c.arguments), [false, true, true]);
  });

  test('a phone without the channel never breaks the app', () async {
    await Privacy.applyLockMode('pin');
  });
}
