import 'dart:typed_data';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/vault.dart';
import '../l10n/strings.dart';
import '../services/backup.dart';
import '../services/files.dart';
import '../services/notifications.dart';
import 'common.dart';
import 'forms.dart';
import 'lock.dart';
import 'today.dart';
import 'vendors.dart';

// ================================================================ More

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      void go(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      return Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
              child: Text(s.moreTab, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            CardList([
              ListTile(
                leading: const Icon(Icons.save_alt_outlined),
                title: Text(s.backupRestore),
                subtitle: Text(w.lastBackup == null ? s.noBackupYet : s.lastBackupAgo(s.ago(w.lastBackup!))),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => go(const BackupScreen()),
              ),
              ValueListenableBuilder<bool?>(
                valueListenable: context.app.notif,
                builder: (c, on, _) => ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: Text(s.healthCheck),
                  subtitle: Text(on == true ? s.notifAllowed : s.notifNotAllowed),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => go(const HealthScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            CardList([
              ListTile(
                leading: const Icon(Icons.list_alt_outlined),
                title: Text(s.allRemindersTitle),
                subtitle: Text(s.activeCount(w.reminders.where((r) => !r.done).length)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => go(const AllRemindersScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.contacts_outlined),
                title: Text(s.vendorBook),
                subtitle: Text(s.contactsCount(w.vendors.length)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => go(const VendorsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(s.language),
                subtitle: Text(context.app.lang == 'ms' ? 'Bahasa Melayu' : 'English'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickLanguage(context),
              ),
            ]),
            const SizedBox(height: 12),
            CardList([
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(s.appLock),
                subtitle: Text(s.appLockSub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => go(const SecurityScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(s.privacyAbout),
                subtitle: Text(s.privacyShort),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => go(const AboutScreen()),
              ),
            ]),
          ]),
        ),
      );
    });
  }
}

Future<void> _pickLanguage(BuildContext context) async {
  final app = context.app;
  final v = await showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: Text(app.s.language),
      children: [
        for (final (code, name) in const [('ms', 'Bahasa Melayu'), ('en', 'English')])
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, code),
            child: Row(children: [
              Icon(app.lang == code ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20),
              const SizedBox(width: 12),
              Text(name),
            ]),
          ),
      ],
    ),
  );
  if (v != null) app.setLang(v);
}

// ================================================================ all reminders

class AllRemindersScreen extends StatefulWidget {
  const AllRemindersScreen({super.key});

  @override
  State<AllRemindersScreen> createState() => _AllRemindersState();
}

class _AllRemindersState extends State<AllRemindersScreen> {
  String _f = 'all';

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final rs = w.reminders.where((r) => !r.done && (_f == 'all' || w.asset(r.assetId)?.category == _f)).toList()..sort(remOrder(w));
      return Scaffold(
        appBar: AppBar(title: Text(s.allRemindersTitle)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          ChoiceRow<String>(
            options: const ['all', 'house', 'car', 'motorcycle'],
            value: _f,
            label: (v) => v == 'all' ? s.all : s.categoryName(v),
            onChanged: (v) => setState(() => _f = v),
          ),
          const SizedBox(height: 12),
          CardList([for (final r in rs) ReminderTile(r, w, onTap: () => showReminderSheet(context, r.id))], empty: s.noRemindersYet),
          const SizedBox(height: 12),
          if (w.assets.isNotEmpty)
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(s.addReminder),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReminderFormScreen())),
            ),
        ]),
      );
    });
  }
}

// ================================================================ health check

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) => WorldView(builder: _build);

  Widget _build(BuildContext context, World w) {
    final s = context.s;
    final app = context.app;
    return Scaffold(
      appBar: AppBar(title: Text(s.healthCheck)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ValueListenableBuilder<bool?>(
          valueListenable: app.notif,
          builder: (c, on, _) => ValueListenableBuilder<RebuildInfo?>(
            valueListenable: app.rebuildInfo,
            builder: (c, info, _) => CardList([
              ListTile(
                leading: Icon(on == true ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
                title: Text(s.notifPermission),
                subtitle: Text(on == true ? s.allowed : s.notifNotAllowedLong),
                trailing: on == true ? const Icon(Icons.check_circle_outline) : FilledButton.tonal(onPressed: () => askNotifications(context), child: Text(s.allow)),
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(s.notifyTime),
                subtitle: Text(s.hm(w.notifyHour, w.notifyMinute)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final db = context.db;
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: w.notifyHour, minute: w.notifyMinute));
                  if (t == null) return;
                  await db.setSetting('notifyHour', '${t.hour}');
                  await db.setSetting('notifyMinute', '${t.minute}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.battery_alert_outlined),
                title: Text(s.batteryTitle),
                subtitle: Text(s.batteryBody),
                trailing: FilledButton.tonal(
                  onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization),
                  child: Text(s.open),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.event_repeat_outlined),
                title: Text(s.lastRebuild),
                subtitle: Text(info == null ? s.notYet : s.rebuildSummary(s.timeOfDay(info.at), info.count)),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(s.nextNotification),
                subtitle: Text(info?.nextAt == null ? s.noneScheduled : '${info!.nextTitle} · ${s.dLong(info.nextAt!)}, ${s.timeOfDay(info.nextAt!)}'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.send_outlined),
          label: Text(s.sendTest),
          onPressed: () async {
            if (app.notif.value != true) {
              snack(context, s.testNeedsPermission);
              return;
            }
            await Notifier.test(s);
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh),
          label: Text(s.rebuildNow),
          onPressed: () async {
            await app.rebuildNow();
            if (context.mounted) snack(context, s.rebuilt);
          },
        ),
        const SizedBox(height: 16),
        NoteBox(s.todayIsGuaranteed),
      ]),
    );
  }
}

// ================================================================ backup

Future<String?> _askNewPassphrase(BuildContext context) {
  final s = context.s;
  final p1 = TextEditingController();
  final p2 = TextEditingController();
  var ack = false;
  var show = false;
  return showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final mismatch = p2.text.isNotEmpty && p1.text != p2.text;
      final ok = p1.text.length >= 8 && p1.text == p2.text && ack;
      return AlertDialog(
        title: Text(s.choosePassphrase),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.passphraseIntro),
            const SizedBox(height: 12),
            TextField(
              controller: p1,
              obscureText: !show,
              onChanged: (_) => set(() {}),
              decoration: InputDecoration(
                labelText: s.passphrase,
                helperText: s.passphraseHelp,
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: Icon(show ? Icons.visibility_off : Icons.visibility), onPressed: () => set(() => show = !show)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: p2,
              obscureText: !show,
              onChanged: (_) => set(() {}),
              decoration: InputDecoration(labelText: s.typeAgain, errorText: mismatch ? s.passMismatch : null, border: const OutlineInputBorder()),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: ack,
              title: Text(s.forgetWarningAck, style: const TextStyle(fontSize: 14)),
              onChanged: (v) => set(() => ack = v ?? false),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
          FilledButton(onPressed: ok ? () => Navigator.pop(c, p1.text) : null, child: Text(s.createFile)),
        ],
      );
    }),
  );
}

Future<String?> _askPassphrase(BuildContext context, Str s, {String? error}) {
  final p = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(s.enterPassphrase),
      content: TextField(
        controller: p,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(labelText: s.passphrase, errorText: error, errorMaxLines: 3, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, p.text), child: Text(s.unlockFile)),
      ],
    ),
  );
}

/// Pick a file, ask for the passphrase (retrying on a wrong one) and show a preview.
/// Returns the contents only when the user confirms the replacement.
Future<BackupContents?> pickAndOpenBackup(BuildContext context, Str s) async {
  final Uint8List? bytes;
  try {
    bytes = await Backup.pick();
  } catch (_) {
    if (context.mounted) snack(context, s.couldNotRead);
    return null;
  }
  if (bytes == null || !context.mounted) return null;
  String? error;
  BackupContents? contents;
  while (contents == null) {
    final pass = await _askPassphrase(context, s, error: error);
    if (pass == null || !context.mounted) return null;
    try {
      contents = await withProgress(context, s.unlocking, () => Backup.open(bytes!, pass));
    } on WrongPassphrase {
      error = s.wrongPassphrase;
    } on NotABackup {
      if (context.mounted) snack(context, s.notABackup);
      return null;
    } catch (_) {
      if (context.mounted) snack(context, s.couldNotRead);
      return null;
    }
    if (!context.mounted) return null;
  }
  final c = contents;
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(s.checkBeforeRestore),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.backupMadeOn(s.dLong(c.created))),
        const SizedBox(height: 8),
        Text(s.backupCounts(c.count('assets'), c.count('reminders'), c.count('records'), c.count('documents') - c.photoCount)),
        if (c.photoCount > 0) Text(s.photosCount(c.photoCount)),
        const SizedBox(height: 12),
        NoteBox(s.restoreReplaces(s.dLong(c.created)), warn: true),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(s.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error, foregroundColor: Theme.of(d).colorScheme.onError),
          onPressed: () => Navigator.pop(d, true),
          child: Text(s.replaceMyData),
        ),
      ],
    ),
  );
  return ok == true ? c : null;
}

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final s = context.s;
    final db = context.db;
    final pass = await _askNewPassphrase(context);
    if (pass == null || !context.mounted) return;
    final bytes = await withProgress(context, s.encrypting, () => Backup.create(db, pass));
    if (!context.mounted) return;
    final name = Backup.fileName(DateTime.now());
    final where = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(s.whereToSave, style: Theme.of(c).textTheme.titleMedium)),
          ListTile(leading: const Icon(Icons.share_outlined), title: Text(s.shareToApp), subtitle: Text(s.shareToAppHint), onTap: () => Navigator.pop(c, 'share')),
          ListTile(leading: const Icon(Icons.folder_outlined), title: Text(s.saveToFolder), subtitle: Text(s.saveToFolderHint), onTap: () => Navigator.pop(c, 'folder')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (where == null || !context.mounted) return;
    bool saved;
    try {
      saved = where == 'share' ? await Backup.share(bytes, name) : await Backup.saveToFolder(bytes, name);
    } catch (_) {
      saved = false;
    }
    if (!context.mounted) return;
    if (saved) {
      await db.setSetting('lastBackup', DateTime.now().toIso8601String());
      if (context.mounted) snack(context, s.backupSaved(name));
    } else {
      snack(context, s.backupNotSaved);
    }
  }

  Future<void> _restore(BuildContext context) async {
    final s = context.s;
    final db = context.db;
    final c = await pickAndOpenBackup(context, s);
    if (c == null || !context.mounted) return;
    await withProgress(context, s.restoring, () => Backup.restore(db, c));
    if (context.mounted) snack(context, s.restoredFrom(s.dLong(c.created)));
  }

  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final last = w.lastBackup;
      return Scaffold(
        appBar: AppBar(title: Text(s.backupRestore)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.lastBackupLabel.toUpperCase(), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(last == null ? s.never : s.dLong(last), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (last != null) Text(s.ago(last)),
                const SizedBox(height: 10),
                Text(s.backupExplainer),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(icon: const Icon(Icons.save_alt_outlined), label: Text(s.createBackup), onPressed: () => _create(context)),
          const SizedBox(height: 8),
          OutlinedButton.icon(icon: const Icon(Icons.restore), label: Text(s.restoreFromFile), onPressed: () => _restore(context)),
          const SizedBox(height: 16),
          NoteBox(s.passphraseWarning, warn: true, icon: Icons.key_outlined),
          const SizedBox(height: 8),
          NoteBox(s.phoneBackupNote, icon: Icons.phone_android_outlined),
          const SizedBox(height: 8),
          NoteBox(s.backupNudgeNote, icon: Icons.notifications_none),
        ]),
      );
    });
  }
}

// ================================================================ about

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.privacyAbout)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        CardList([
          ListTile(leading: const Icon(Icons.person_off_outlined), title: Text(s.pNoAccount), subtitle: Text(s.pNoAccountBody)),
          ListTile(leading: const Icon(Icons.wifi_off), title: Text(s.pNoInternet), subtitle: Text(s.pNoInternetBody)),
          ListTile(leading: const Icon(Icons.lock_outline), title: Text(s.pEncrypted), subtitle: Text(s.pEncryptedBody)),
          ListTile(leading: const Icon(Icons.visibility_off_outlined), title: Text(s.pNoAds), subtitle: Text(s.pNoAdsBody)),
        ]),
        const SizedBox(height: 12),
        NoteBox(s.legalDisclaimer, warn: true),
        const SizedBox(height: 16),
        Text('Kukira Asset 0.1.0 · ${s.testBuild}', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

// ================================================================ unreadable database

/// Shown instead of the app when the database cannot be opened on this phone.
class UnreadableScreen extends StatefulWidget {
  const UnreadableScreen({super.key, required this.s, required this.onReady, this.forgotPin = false});
  final Str s;
  final bool forgotPin;
  final void Function(AppDb db) onReady;

  @override
  State<UnreadableScreen> createState() => _UnreadableState();
}

class _UnreadableState extends State<UnreadableScreen> {
  bool _askFresh = false;

  Future<void> _restore() async {
    final s = widget.s;
    final c = await pickAndOpenBackup(context, s);
    if (c == null || !mounted) return;
    final db = await withProgress(context, s.restoring, () async {
      final db = await Vault.resetAndOpen();
      await Backup.restore(db, c);
      return db;
    });
    widget.onReady(db);
  }

  Future<void> _fresh() async {
    final db = await Vault.resetAndOpen();
    SecureFiles.reset();
    await SecureFiles.deleteAll();
    widget.onReady(db);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 40),
          Icon(Icons.key_off_outlined, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(widget.forgotPin ? s.forgotPinTitle : s.unreadableTitle, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(widget.forgotPin ? s.forgotPinBody : s.unreadableBody),
          const SizedBox(height: 24),
          FilledButton.icon(icon: const Icon(Icons.restore), label: Text(s.restoreFromFile), onPressed: _restore),
          const SizedBox(height: 10),
          if (!_askFresh)
            OutlinedButton(onPressed: () => setState(() => _askFresh = true), child: Text(s.startFresh))
          else ...[
            NoteBox(s.startFreshWarning, warn: true),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _askFresh = false), child: Text(s.keepIt))),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError),
                  onPressed: _fresh,
                  child: Text(s.eraseAndStart),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
