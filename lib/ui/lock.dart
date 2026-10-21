import 'dart:async';

import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/vault.dart';
import '../l10n/strings.dart';
import 'common.dart';

/// Four dots and a number pad.
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.value, required this.onChanged, this.length = 4, this.extra});
  final String value;
  final ValueChanged<String> onChanged;
  final int length;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget key(String k) => Padding(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            width: 72,
            height: 64,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              onPressed: () {
                if (k == '⌫') {
                  if (value.isNotEmpty) onChanged(value.substring(0, value.length - 1));
                } else if (value.length < length) {
                  onChanged(value + k);
                }
              },
              child: k == '⌫' ? const Icon(Icons.backspace_outlined) : Text(k, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            ),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < length; i++)
          Container(
            margin: const EdgeInsets.all(8),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < value.length ? c.primary : Colors.transparent,
              border: Border.all(color: i < value.length ? c.primary : c.outline, width: 2),
            ),
          ),
      ]),
      const SizedBox(height: 16),
      for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final k in row) key(k)]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 84, height: 76, child: Center(child: extra ?? const SizedBox.shrink())),
        key('0'),
        key('⌫'),
      ]),
    ]);
  }
}

/// Unlock screen. At start-up it opens the database ([onOpened]); on resume it only checks ([onChecked]).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.s, this.onOpened, this.onChecked, this.onForgot, this.cancellable = false});
  final Str s;
  final void Function(AppDb db)? onOpened;
  final VoidCallback? onChecked;
  final VoidCallback? onForgot;
  final bool cancellable;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String? _error;
  bool _busy = false;
  bool _bio = false;
  int _fails = 0;
  DateTime? _waitUntil;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    Vault.lockMode().then((m) {
      if (!mounted) return;
      setState(() => _bio = m == 'pin_bio');
      if (_bio) _tryBio();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _tryBio() async {
    final s = widget.s;
    if (widget.onOpened != null) {
      final db = await Vault.unlockWithBio(s.unlockTitle, s.usePin);
      if (db != null) widget.onOpened!(db);
    } else {
      if (await Vault.checkBio(s.unlockTitle, s.usePin)) widget.onChecked?.call();
    }
  }

  Future<void> _submit(String pin) async {
    final s = widget.s;
    setState(() => _busy = true);
    try {
      if (widget.onOpened != null) {
        final db = await Vault.unlockWithPin(pin);
        if (db != null) {
          widget.onOpened!(db);
          return;
        }
        setState(() => _error = s.couldNotOpen);
      } else if (await Vault.checkPin(pin)) {
        widget.onChecked?.call();
        return;
      } else {
        throw WrongPin();
      }
    } on WrongPin {
      _fails++;
      _error = s.wrongPin;
      if (_fails >= 5) {
        _waitUntil = DateTime.now().add(Duration(seconds: 30 * (_fails - 4)));
        _tick?.cancel();
        _tick = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          if (DateTime.now().isAfter(_waitUntil!)) {
            _tick?.cancel();
            _waitUntil = null;
          }
          setState(() {});
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final theme = Theme.of(context);
    final waiting = _waitUntil != null && DateTime.now().isBefore(_waitUntil!);
    return PopScope(
      canPop: widget.cancellable,
      child: SafeScaffold(
        appBar: widget.cancellable ? AppBar() : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(s.lockedTitle, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(s.enterPin),
                const SizedBox(height: 20),
                if (_busy)
                  const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
                else if (waiting)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(s.tooManyTries(_waitUntil!.difference(DateTime.now()).inSeconds + 1), textAlign: TextAlign.center),
                  )
                else
                  PinPad(
                    value: _pin,
                    onChanged: (v) {
                      setState(() {
                        _pin = v;
                        _error = null;
                      });
                      if (v.length == 4) _submit(v);
                    },
                    extra: _bio ? IconButton(iconSize: 32, icon: const Icon(Icons.fingerprint), tooltip: s.useFingerprint, onPressed: _tryBio) : null,
                  ),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
                if (widget.onForgot != null) ...[
                  const SizedBox(height: 12),
                  TextButton(onPressed: widget.onForgot, child: Text(s.forgotPin)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a new PIN twice. Returns it, or null if cancelled.
Future<String?> setNewPin(BuildContext context) => Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _NewPinScreen()));

class _NewPinScreen extends StatefulWidget {
  const _NewPinScreen();

  @override
  State<_NewPinScreen> createState() => _NewPinState();
}

class _NewPinState extends State<_NewPinScreen> {
  String _pin = '';
  String? _first;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return SafeScaffold(
      appBar: AppBar(title: Text(s.appLock)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_first == null ? s.choosePin : s.pinAgain, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            PinPad(
              value: _pin,
              onChanged: (v) {
                setState(() {
                  _pin = v;
                  _error = null;
                });
                if (v.length < 4) return;
                if (_first == null) {
                  setState(() {
                    _first = v;
                    _pin = '';
                  });
                } else if (v == _first) {
                  Navigator.pop(context, v);
                } else {
                  setState(() {
                    _first = null;
                    _pin = '';
                    _error = s.pinMismatch;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Text(s.pinForgetNote, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

/// Asks for the current PIN. Returns true when it is right.
Future<bool> confirmPin(BuildContext context) async {
  final s = context.s;
  final ok = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => LockScreen(s: s, cancellable: true, onChecked: () => Navigator.pop(context, true))),
  );
  return ok ?? false;
}

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityState();
}

class _SecurityState extends State<SecurityScreen> {
  String _mode = 'none';
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await Vault.lockMode();
    final b = await Vault.bioAvailable();
    if (mounted) {
      setState(() {
        _mode = m;
        _bioAvailable = b;
      });
    }
  }

  Future<void> _toggleLock(bool on) async {
    final s = context.s;
    if (on) {
      final pin = await setNewPin(context);
      if (pin == null || !mounted) return;
      var bio = false;
      if (_bioAvailable) {
        bio = await confirm(context, title: s.alsoFingerprintQ, body: s.alsoFingerprintBody, ok: s.yesUseIt);
      }
      if (!mounted) return;
      final ok = await withProgress(context, s.securing, () => Vault.enableLock(pin, bio: bio, title: s.unlockTitle, cancel: s.cancel));
      if (mounted) snack(context, ok ? s.lockOn : s.lockFailed);
    } else {
      if (!await confirmPin(context)) return;
      await Vault.disableLock();
      if (mounted) snack(context, s.lockOff);
    }
    await _load();
    if (mounted) context.app.lockChanged();
  }

  Future<void> _toggleBio(bool on) async {
    final s = context.s;
    final ok = await Vault.setBio(on, title: s.unlockTitle, cancel: s.cancel);
    if (!ok && mounted) snack(context, s.fingerprintFailed);
    await _load();
    if (mounted) context.app.lockChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final on = _mode != 'none';
    return SafeScaffold(
      appBar: AppBar(title: Text(s.appLock)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        CardList([
          SwitchListTile(value: on, title: Text(s.lockWithPin), subtitle: Text(s.lockWithPinSub), onChanged: _toggleLock),
          SwitchListTile(
            value: _mode == 'pin_bio',
            title: Text(s.useFingerprint),
            subtitle: Text(_bioAvailable ? s.fingerprintSub : s.fingerprintUnavailable),
            onChanged: on && _bioAvailable ? _toggleBio : null,
          ),
        ]),
        const SizedBox(height: 12),
        NoteBox(s.lockExplainer, icon: Icons.shield_outlined),
        const SizedBox(height: 8),
        NoteBox(s.pinForgetNote, warn: true),
        if (on) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(icon: const Icon(Icons.lock_outline), label: Text(s.lockNow), onPressed: () => context.app.lockNow()),
        ],
      ]),
    );
  }
}
