/// Wrong-PIN attempts and how long to wait before the next try.
///
/// The first four wrong PINs cost nothing. From the fifth, each wrong PIN makes the next
/// try wait 30 seconds longer (30 s, 60 s, 90 s, ...). The state is saved in secure storage
/// (see Vault), so closing and reopening the app does not reset it.
class PinThrottle {
  const PinThrottle(this.fails, this.lastFail);

  static const none = PinThrottle(0, null);
  static const freeTries = 4;
  static const step = Duration(seconds: 30);

  final int fails;
  final DateTime? lastFail;

  PinThrottle failed(DateTime now) => PinThrottle(fails + 1, now);

  /// When the next try is allowed, or null when it is allowed now.
  DateTime? get waitUntil => fails > freeTries && lastFail != null ? lastFail!.add(step * (fails - freeTries)) : null;

  bool waiting(DateTime now) {
    final w = waitUntil;
    return w != null && now.isBefore(w);
  }

  String encode() => '$fails|${lastFail?.toIso8601String() ?? ''}';

  /// Anything unreadable counts as no wrong tries, so a damaged entry never locks the user out.
  static PinThrottle decode(String? v) {
    if (v == null) return none;
    final parts = v.split('|');
    final fails = int.tryParse(parts.first);
    if (fails == null || fails <= 0) return none;
    return PinThrottle(fails, parts.length > 1 ? DateTime.tryParse(parts[1]) : null);
  }
}
