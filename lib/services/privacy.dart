import 'package:flutter/services.dart';

/// Hides the app's picture in Android's Recent apps screen while the app lock is on,
/// so the records cannot be seen there without the PIN. See MainActivity.kt.
class Privacy {
  static const channel = MethodChannel('kukira/privacy');

  /// [lockMode] is Vault.lockMode(): none | pin | pin_bio.
  static Future<void> applyLockMode(String lockMode) async {
    try {
      await channel.invokeMethod<void>('hideInRecents', lockMode != 'none');
    } catch (_) {
      // Not available (tests, other platforms). The lock itself still protects the key.
    }
  }
}
