import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/db.dart';
import '../data/vault.dart';
import '../l10n/strings.dart';
import '../services/notifications.dart';
import 'add_asset.dart';
import 'assets.dart';
import 'common.dart';
import 'forms.dart';
import 'more.dart';
import 'today.dart';

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1E6A4E), brightness: b);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF6F8F6) : const Color(0xFF111714),
    cardTheme: CardTheme(
      elevation: 0,
      color: b == Brightness.light ? Colors.white : const Color(0xFF19221D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant)),
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _db = widget.boot.db;
    if (_db != null) _attach();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _attach() {
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
    if (state == AppLifecycleState.resumed && _db != null) {
      _refreshNotif();
      _scheduleRebuild();
    }
  }

  void _setLang(String l) {
    setState(() => _lang = l);
    _db?.setSetting('lang', l);
  }

  @override
  Widget build(BuildContext context) {
    final s = strFor(_lang);
    final app = MaterialApp(
      title: 'Kukira Asset',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: Locale(_lang),
      supportedLocales: const [Locale('ms'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: _db == null
          ? UnreadableScreen(
              s: s,
              onReady: (db) {
                setState(() => _db = db);
                _attach();
              },
            )
          : const Shell(),
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
      child: app,
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _page = 0; // 0 Today, 1 Assets, 2 Documents, 3 More

  static const _pages = [TodayScreen(), AssetsScreen(), DocumentsScreen(), MoreScreen()];

  int get _navIndex => _page < 2 ? _page : _page + 1;

  void _onNav(int i) {
    if (i == 2) {
      _showAddSheet(context);
      return;
    }
    setState(() => _page = i < 2 ? i : i - 1);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: IndexedStack(index: _page, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onNav,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.today_outlined), selectedIcon: const Icon(Icons.today), label: s.today),
          NavigationDestination(icon: const Icon(Icons.grid_view_outlined), selectedIcon: const Icon(Icons.grid_view), label: s.assetsTab),
          NavigationDestination(
            icon: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              child: const Icon(Icons.add),
            ),
            label: s.add,
          ),
          NavigationDestination(icon: const Icon(Icons.description_outlined), selectedIcon: const Icon(Icons.description), label: s.documentsTab),
          NavigationDestination(icon: const Icon(Icons.menu), label: s.moreTab),
        ],
      ),
    );
  }
}

void _showAddSheet(BuildContext context) {
  final s = context.s;
  final hasAssets = context.app.world.value?.assets.isNotEmpty ?? false;
  void go(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.home_outlined),
          title: Text(s.asset),
          subtitle: Text(s.addAssetHint),
          onTap: () {
            Navigator.pop(c);
            go(const AddAssetScreen());
          },
        ),
        ListTile(
          enabled: hasAssets,
          leading: const Icon(Icons.build_outlined),
          title: Text(s.record),
          subtitle: Text(s.addRecordHint),
          onTap: () {
            Navigator.pop(c);
            go(const RecordFormScreen());
          },
        ),
        ListTile(
          enabled: hasAssets,
          leading: const Icon(Icons.notifications_none),
          title: Text(s.reminder),
          subtitle: Text(s.addReminderHint),
          onTap: () {
            Navigator.pop(c);
            go(const ReminderFormScreen());
          },
        ),
        ListTile(
          enabled: false,
          leading: const Icon(Icons.description_outlined),
          title: Text(s.document),
          subtitle: Text(s.comingSoon),
        ),
        if (!hasAssets) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(s.addAssetFirst)),
        const SizedBox(height: 8),
      ]),
    ),
  );
}
