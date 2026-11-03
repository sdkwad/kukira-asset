import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/services/files.dart';

import 'helpers.dart';

void main() {
  test('decrypted copies are removed once they are old enough, and all of them at start-up', () async {
    final root = await useTempStorage();
    final view = Directory('${root.path}/tmp/view')..createSync(recursive: true);
    final old = File('${view.path}/Geran.pdf')..writeAsBytesSync([1]);
    old.setLastModifiedSync(DateTime.now().subtract(SecureFiles.tempLifetime + const Duration(minutes: 1)));
    final fresh = File('${view.path}/Insurance.pdf')..writeAsBytesSync([2]);

    // Back in Kukira: the old copy goes, the one a viewer may still be reading stays.
    await SecureFiles.clearTemp(olderThan: SecureFiles.tempLifetime);
    expect(old.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);

    // Next start-up: nothing decrypted is left.
    await SecureFiles.clearTemp();
    expect(view.existsSync(), isFalse);

    // Nothing to clear is not an error.
    await SecureFiles.clearTemp(olderThan: SecureFiles.tempLifetime);
  });

  test('a backup handed to the share sheet goes into the same folder and is cleared too', () async {
    final root = await useTempStorage();
    final f = await SecureFiles.writeTemp('kukira-backup-2026-11-03.kukira', Uint8List.fromList([1, 2, 3]));
    expect(f.path, startsWith('${root.path}/tmp/view'));
    await SecureFiles.clearTemp();
    expect(f.existsSync(), isFalse);
  });
}
