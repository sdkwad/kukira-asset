import 'package:flutter/services.dart';

/// Opens a website in the phone's own browser. Kukira has no internet permission and never
/// loads the page itself: Android hands the address to the browser (see MainActivity.kt).
class Links {
  static const channel = MethodChannel('kukira/links');

  /// True when a browser took the address. Only http and https addresses are opened.
  static Future<bool> openWeb(String url) async {
    final u = Uri.tryParse(url);
    if (u == null || !(u.scheme == 'https' || u.scheme == 'http') || u.host.isEmpty) return false;
    try {
      return await channel.invokeMethod<bool>('openWeb', u.toString()) ?? false;
    } catch (_) {
      return false;
    }
  }
}
