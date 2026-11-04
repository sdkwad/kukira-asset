import 'package:flutter/material.dart';

import '../data/db.dart';
import 'add_asset.dart';
import 'common.dart';
import 'lock.dart';
import 'more.dart';
import 'today.dart';

/// The first run: a fresh install with nothing in it and the welcome not yet seen. A phone
/// that already has assets (an update, or a restored backup) never sees it.
bool needsWelcome(World w) => w.settings['onboarded'] == null && w.assets.isEmpty;

/// Remembers that the welcome was seen, so it is not shown again.
Future<void> markOnboarded(BuildContext context) => context.db.setSetting('onboarded', DateTime.now().toIso8601String());

/// Two dots under the first-run pages.
class _Dots extends StatelessWidget {
  const _Dots(this.index);
  final int index;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return ExcludeSemantics(
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < 2; i++)
          Container(
            width: i == index ? 20 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(color: i == index ? k.primary : k.line, borderRadius: BorderRadius.circular(3)),
          ),
      ]),
    );
  }
}

/// A setting on the setup page. Unlike AppRow it never cuts the explanation short: on day
/// one the reason to say yes matters more than a tidy row.
class _SetupRow extends StatelessWidget {
  const _SetupRow({required this.icon, required this.title, required this.body, required this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String body;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(children: [
            IconAvatar(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: KText.row.copyWith(color: k.text)),
                const SizedBox(height: 2),
                Text(body, style: KText.meta.copyWith(color: k.textMuted)),
              ]),
            ),
            const SizedBox(width: 8),
            trailing,
          ]),
        ),
      ),
    );
  }
}

/// What Kukira does, in three lines, with the language choice and a way to bring records
/// over from an old phone.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final k = context.tokens;
    final app = context.app;
    Widget point(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconAvatar(icon, tonal: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: KText.row.copyWith(color: k.text)),
                const SizedBox(height: 2),
                Text(body, style: KText.meta.copyWith(color: k.textMuted)),
              ]),
            ),
          ]),
        );
    return SafeScaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 16), children: [
            Align(
              alignment: Alignment.centerRight,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'ms', label: Text('BM'), tooltip: 'Bahasa Melayu'),
                  ButtonSegment(value: 'en', label: Text('EN'), tooltip: 'English'),
                ],
                selected: {app.lang},
                onSelectionChanged: (v) => app.setLang(v.first),
              ),
            ),
            const SizedBox(height: 40),
            Semantics(
              header: true,
              child: Text('Kukira', style: KText.screenTitle.copyWith(fontSize: 34, height: 40 / 34, color: k.primary, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            Text(s.welcomeTagline, style: KText.title.copyWith(color: k.text)),
            const SizedBox(height: 28),
            point(Icons.schedule, s.welcomeDueTitle, s.welcomeDueBody),
            point(Icons.receipt_long_outlined, s.welcomeRecordsTitle, s.welcomeRecordsBody),
            point(Icons.lock_outline, s.welcomePrivateTitle, s.welcomePrivateBody),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _Dots(0),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen())),
              child: Text(s.start),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () async {
                final restored = await restoreBackup(context);
                if (!restored || !context.mounted) return;
                await markOnboarded(context);
              },
              child: Text(s.restoreFromOldPhone, textAlign: TextAlign.center),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// The few settings worth choosing on day one: notifications, their time and the app lock.
/// Everything here can be changed later in More, so both buttons finish the first run.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  Future<void> _finish(BuildContext context, {required bool addAsset}) async {
    final nav = Navigator.of(context);
    await markOnboarded(context);
    // The first page under this one turns into Today once the welcome is marked seen.
    nav.popUntil((r) => r.isFirst);
    if (addAsset) nav.push(MaterialPageRoute(builder: (_) => const AddAssetScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final k = context.tokens;
      final app = context.app;
      final locked = app.lockMode != 'none';
      return SafeScaffold(
        appBar: AppBar(),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Semantics(header: true, child: Text(s.setupTitle, style: KText.screenTitle.copyWith(color: k.text))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
                child: Text(s.setupSub, style: KText.meta.copyWith(fontSize: 15, height: 22 / 15, color: k.label)),
              ),
              ValueListenableBuilder<bool?>(
                valueListenable: app.notif,
                builder: (c, on, _) => CardList([
                  _SetupRow(
                    icon: Icons.notifications_none,
                    title: s.notifications,
                    body: on == true ? s.allowed : s.notifPitchShort,
                    trailing: on == true
                        ? Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.check_circle_outline, color: k.primary))
                        : FilledButton.tonal(onPressed: () => askNotifications(context), child: Text(s.allow)),
                  ),
                  _SetupRow(
                    icon: Icons.schedule,
                    title: s.notifyTime,
                    body: s.everyDayAt(s.hm(w.notifyHour, w.notifyMinute)),
                    trailing: TextButton(onPressed: () => pickNotifyTime(context, w), child: Text(s.change)),
                    onTap: () => pickNotifyTime(context, w),
                  ),
                  _SetupRow(
                    icon: Icons.lock_outline,
                    title: s.lockWithPin,
                    body: s.pinRecommended,
                    trailing: Switch(
                      value: locked,
                      onChanged: (v) => v ? turnLockOn(context) : turnLockOff(context),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              NoteBox(s.setupBackupNote, icon: Icons.restore),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _Dots(1),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => _finish(context, addAsset: true), child: Text(s.addFirstAsset)),
              const SizedBox(height: 4),
              TextButton(onPressed: () => _finish(context, addAsset: false), child: Text(s.notNow)),
            ]),
          ),
        ]),
      );
    });
  }
}
