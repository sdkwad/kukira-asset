import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/db.dart';
import '../data/vault.dart';
import '../l10n/strings.dart';
import '../services/error_log.dart';
import '../services/files.dart';
import '../services/notifications.dart';
import '../services/privacy.dart';
import 'assets.dart';
import 'common.dart';
import 'documents.dart';
import 'lock.dart';
import 'more.dart';
import 'today.dart';
import 'welcome.dart';

ThemeData buildTheme(Brightness b) {
  final k = b == Brightness.light ? KukiraColors.light : KukiraColors.dark;
  // The seed fills the roles the design system does not set (dialogs, menus, chips).
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1E6A4E), brightness: b).copyWith(
    primary: k.primary,
    onPrimary: k.onPrimary,
    primaryContainer: k.tonal,
    onPrimaryContainer: k.onTonal,
    secondaryContainer: k.tonal,
    onSecondaryContainer: k.onTonal,
    surface: k.background,
    onSurface: k.text,
    onSurfaceVariant: k.textMuted,
    outlineVariant: k.line,
    error: k.overdue,
    errorContainer: k.overdueBg,
    onErrorContainer: k.overdue,
  );
  final theme = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    extensions: [k],
    scaffoldBackgroundColor: k.background,
    cardTheme: CardTheme(
      elevation: 0,
      color: k.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KSpace.groupRadius), side: BorderSide(color: k.line)),
    ),
    dividerTheme: DividerThemeData(color: k.divider, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: k.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: k.tonal,
      iconTheme: WidgetStateProperty.resolveWith((st) => IconThemeData(color: st.contains(WidgetState.selected) ? k.onTonal : k.label)),
      labelTextStyle: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected)
          ? TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: k.primary)
          : TextStyle(fontSize: 12, color: k.label)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: k.primary,
      foregroundColor: k.onPrimary,
      elevation: 2,
      highlightElevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: k.background, surfaceTintColor: Colors.transparent),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
  // The button's label style replaces the default one rather than adding to it, so it starts
  // from the theme's own label style to keep the font.
  return theme.copyWith(
    floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
      extendedTextStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
    ),
  );
}

class KukiraApp extends StatefulWidget {
  const KukiraApp({super.key, required this.boot});
  final BootResult boot;

  @override
  State<KukiraApp> createState() => _KukiraAppState();
}

class _KukiraAppState extends State<KukiraApp> with WidgetsBindingObserver {
  AppDb? _db;
  String _lang = 'ms';
  final _world = ValueNotifier<World?>(null);
  final _notif = ValueNotifier<bool?>(null);
  final _rebuild = ValueNotifier<RebuildInfo?>(null);
  StreamSubscription<World>? _sub;
  Timer? _debounce;
  Timer? _tempSweep;
  String _lockMode = 'none';
  bool _locked = false;
  bool _forgotPin = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _db = widget.boot.db;
    if (_db != null) _attach();
    _readLock();
  }

  Future<void> _readLock() async {
    final m = await Vault.lockMode();
    await Privacy.applyLockMode(m);
    if (mounted) setState(() => _lockMode = m);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _debounce?.cancel();
    _tempSweep?.cancel();
    super.dispose();
  }

  void _attach() {
    ErrorLog.attach(_db!);
    _sub?.cancel();
    _world.value = null;
    _sub = _db!.watchWorld().listen((w) {
      _world.value = w;
      final l = w.settings['lang'];
      if (l != null && l != _lang) setState(() => _lang = l);
      _scheduleRebuild();
    });
    _refreshNotif();
  }

  // The OS schedule is rebuilt from the database after any change (debounced) and on app open.
  void _scheduleRebuild() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _rebuildNow);
  }

  Future<void> _rebuildNow() async {
    final w = _world.value;
    if (w == null) return;
    _rebuild.value = await Notifier.rebuild(w, strFor(_lang));
  }

  Future<void> _refreshNotif() async => _notif.value = await Notifier.enabled();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    }
    if (state == AppLifecycleState.resumed && _db != null) {
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      // Lock again after two minutes away (long enough to take a photo or pick a file).
      if (_lockMode != 'none' && away > const Duration(minutes: 2)) setState(() => _locked = true);
      _refreshNotif();
      _scheduleRebuild();
      _sweepTemp();
    }
  }

  // Back from the phone's viewer or a share target: delete decrypted copies older than
  // SecureFiles.tempLifetime now, and the fresh ones once they reach that age.
  void _sweepTemp() {
    SecureFiles.clearTemp(olderThan: SecureFiles.tempLifetime);
    _tempSweep?.cancel();
    _tempSweep = Timer(SecureFiles.tempLifetime + const Duration(seconds: 5), () => SecureFiles.clearTemp(olderThan: SecureFiles.tempLifetime));
  }

  void _setLang(String l) {
    setState(() => _lang = l);
    _db?.setSetting('lang', l);
  }

  @override
  Widget build(BuildContext context) {
    final s = strFor(_lang);
    final Widget home;
    if (_db != null) {
      home = const Home();
    } else if (widget.boot.state == BootState.locked && !_forgotPin) {
      home = LockScreen(
        s: s,
        onOpened: (db) {
          setState(() => _db = db);
          _attach();
        },
        onForgot: () => setState(() => _forgotPin = true),
      );
    } else {
      home = UnreadableScreen(
        s: s,
        forgotPin: _forgotPin,
        openFailed: widget.boot.state == BootState.failed,
        onReady: (db) {
          setState(() {
            _db = db;
            _lockMode = 'none';
          });
          Privacy.applyLockMode('none');
          _attach();
        },
      );
    }
    final app = MaterialApp(
      title: 'Kukira Asset',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: Locale(_lang),
      supportedLocales: const [Locale('ms'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
      builder: (context, child) => LockCover(
        locked: _locked && _db != null,
        lock: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => LockScreen(s: s, onChecked: () => setState(() => _locked = false)),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (_db == null) return app;
    return AppScope(
      db: _db!,
      s: s,
      lang: _lang,
      world: _world,
      notif: _notif,
      rebuildInfo: _rebuild,
      setLang: _setLang,
      rebuildNow: _rebuildNow,
      lockChanged: _readLock,
      lockNow: () => setState(() => _locked = true),
      lockMode: _lockMode,
      child: app,
    );
  }
}

/// The four main places, or the welcome on the very first run.
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) => WorldView(builder: (context, w) => needsWelcome(w) ? const WelcomeScreen() : const Shell());
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

/// The four main places, defined once: a bottom bar on a phone now, a navigation rail on a
/// wide screen later. "Tambah" is not one of them; it is a button on the screens that use it.
List<({IconData icon, IconData selected, String label})> mainDestinations(Str s) => [
      (icon: Icons.today_outlined, selected: Icons.today, label: s.today),
      (icon: Icons.grid_view_outlined, selected: Icons.grid_view, label: s.assetsTab),
      (icon: Icons.description_outlined, selected: Icons.description, label: s.documentsTab),
      (icon: Icons.menu, selected: Icons.menu, label: s.moreTab),
    ];

class _ShellState extends State<Shell> {
  int _page = 0; // 0 Today, 1 Assets, 2 Documents, 3 More

  static const _pages = [TodayScreen(), AssetsScreen(), DocumentsScreen(), MoreScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _page, children: _pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.tokens.line))),
        child: NavigationBar(
          selectedIndex: _page,
          onDestinationSelected: (i) => setState(() => _page = i),
          destinations: [
            for (final d in mainDestinations(context.s)) NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
          ],
        ),
      ),
    );
  }
}
