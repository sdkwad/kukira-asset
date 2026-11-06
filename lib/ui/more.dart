import 'dart:io' show File;

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/db.dart';
import '../data/vault.dart';
import '../l10n/strings.dart';
import '../services/backup.dart';
import '../services/error_log.dart';
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
      return SafeScaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
            PageTitle(s.moreTab),
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
                subtitle: Text(s.activeCount(w.listed.where((r) => !r.done).length)),
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
                subtitle: Text(switch (context.app.lockMode) {
                  'pin' => s.lockStatusPin,
                  'pin_bio' => s.lockStatusPinBio,
                  _ => s.lockStatusOff,
                }),
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
      final rs = w.listed.where((r) => !r.done && (_f == 'all' || w.asset(r.assetId)?.category == _f)).toList()..sort(remOrder(w));
      return SafeScaffold(
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

/// Lets the owner pick the time of day reminders are notified.
Future<void> pickNotifyTime(BuildContext context, World w) async {
  final db = context.db;
  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: w.notifyHour, minute: w.notifyMinute));
  if (t == null) return;
  await db.setSetting('notifyHour', '${t.hour}');
  await db.setSetting('notifyMinute', '${t.minute}');
}

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) => WorldView(builder: _build);

  Widget _build(BuildContext context, World w) {
    final s = context.s;
    final app = context.app;
    return SafeScaffold(
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
                onTap: () => pickNotifyTime(context, w),
              ),
              const NoteDetailsTile(),
              // The advice is long, so the button goes under it instead of squeezing it.
              ListTile(
                leading: const Icon(Icons.battery_alert_outlined),
                title: Text(s.batteryTitle),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.batteryBody),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization),
                    child: Text(s.open),
                  ),
                ]),
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
            Notifier.forgetSchedule();
            await app.rebuildNow();
            if (context.mounted) snack(context, s.rebuilt);
          },
        ),
        const SizedBox(height: 16),
        NoteBox(s.todayIsGuaranteed),
        const SizedBox(height: 16),
        const ErrorLogCard(),
      ]),
    );
  }
}

/// Errors the app caught and kept quiet (see ErrorLog), newest first, with Copy and Clear.
class ErrorLogCard extends StatefulWidget {
  const ErrorLogCard({super.key});

  @override
  State<ErrorLogCard> createState() => _ErrorLogCardState();
}

class _ErrorLogCardState extends State<ErrorLogCard> {
  late Future<List<LoggedError>> _entries = ErrorLog.entries();

  Future<void> _copy(List<LoggedError> list) async {
    final s = context.s;
    final info = await PackageInfo.fromPlatform();
    await Clipboard.setData(ClipboardData(text: ErrorLog.asText(list, version: '${info.version} (${info.buildNumber})')));
    if (mounted) snack(context, s.errorLogCopied);
  }

  Future<void> _clear() async {
    await ErrorLog.clear();
    if (mounted) setState(() => _entries = ErrorLog.entries());
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return FutureBuilder<List<LoggedError>>(
      future: _entries,
      builder: (c, snap) {
        final list = snap.data ?? const <LoggedError>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle(s.errorLogTitle, count: list.length),
          CardList(
            [
              for (final e in list.reversed.take(5))
                ListTile(
                  dense: true,
                  title: Text(e.where),
                  subtitle: Text('${s.dLong(e.at)}, ${s.timeOfDay(e.at)} · ${e.what}', maxLines: 3, overflow: TextOverflow.ellipsis),
                ),
            ],
            empty: s.errorLogNone,
          ),
          if (list.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.copy_outlined), label: Text(s.copyErrorLog), onPressed: () => _copy(list))),
              const SizedBox(width: 8),
              Expanded(child: TextButton(onPressed: _clear, child: Text(s.clearErrorLog))),
            ]),
          ],
          const SizedBox(height: 8),
          NoteBox(s.errorLogNote, icon: Icons.privacy_tip_outlined),
        ]);
      },
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
/// Returns the contents only when the user confirms the replacement. The picked file is
/// still needed then (a format 3 backup is read again while restoring); the caller removes
/// it with [SecureFiles.clearPickerCopies] once the restore is done.
Future<BackupContents?> pickAndOpenBackup(BuildContext context, Str s) async {
  final c = await _pickAndOpen(context, s);
  if (c == null) await SecureFiles.clearPickerCopies();
  return c;
}

Future<BackupContents?> _pickAndOpen(BuildContext context, Str s) async {
  final File? file;
  try {
    file = await Backup.pick();
  } catch (e) {
    ErrorLog.record('backup.pick', e);
    if (context.mounted) snack(context, s.couldNotRead);
    return null;
  }
  if (file == null || !context.mounted) return null;
  String? error;
  BackupContents? contents;
  while (contents == null) {
    final pass = await _askPassphrase(context, s, error: error);
    if (pass == null || !context.mounted) return null;
    try {
      contents = await withProgress(context, s.unlocking, () => Backup.openFile(file!, pass));
    } on WrongPassphrase {
      error = s.wrongPassphrase;
    } on DamagedBackup {
      if (context.mounted) snack(context, s.backupDamaged);
      return null;
    } on NotABackup {
      if (context.mounted) snack(context, s.notABackup);
      return null;
    } on NewerBackup {
      if (context.mounted) snack(context, s.backupTooNew);
      return null;
    } catch (e) {
      ErrorLog.record('backup.open', e);
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

/// Picks a backup file, checks it with the owner and replaces the records with it. True when
/// the records were restored. Used by Backup and restore and by the first-run welcome.
Future<bool> restoreBackup(BuildContext context) async {
  final s = context.s;
  final db = context.db;
  final c = await pickAndOpenBackup(context, s);
  if (c == null || !context.mounted) return false;
  try {
    await withProgress(context, s.restoring, () => Backup.restore(db, c));
  } catch (e) {
    ErrorLog.record('backup.restore', e);
    // Backup.restore leaves the current records and files as they were.
    if (context.mounted) snack(context, e is DamagedBackup ? s.backupDamaged : s.restoreFailed);
    return false;
  } finally {
    await SecureFiles.clearPickerCopies();
  }
  if (context.mounted) snack(context, s.restoredFrom(s.dLong(c.created)));
  return true;
}

/// Where a new backup file goes: a cloud drive (through Android's save dialog), another app
/// (the share sheet) or a folder on the phone. Null when the owner backs out.
Future<String?> chooseBackupPlace(BuildContext context) {
  final s = context.s;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(s.whereToSave, style: Theme.of(c).textTheme.titleMedium)),
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: Text(s.saveToCloud),
            subtitle: Text(s.saveToCloudHint),
            onTap: () => Navigator.pop(c, 'cloud'),
          ),
          ListTile(leading: const Icon(Icons.share_outlined), title: Text(s.shareToApp), subtitle: Text(s.shareToAppHint), onTap: () => Navigator.pop(c, 'share')),
          ListTile(leading: const Icon(Icons.folder_outlined), title: Text(s.saveToFolder), subtitle: Text(s.saveToFolderHint), onTap: () => Navigator.pop(c, 'folder')),
          const SizedBox(height: 8),
        ]),
      ),
    ),
  );
}

/// What to say once a backup file is saved. [wanted] is the place picked in Kukira
/// ([chooseBackupPlace]), [place] where Android says the file went ([Backup.placeOf]).
String backupSavedMessage(Str s, String name, {required int missing, required String wanted, required String place}) {
  if (missing > 0) return s.backupSavedMissing(name, missing);
  if (wanted == 'cloud' && place == 'folder') return s.backupOnPhoneNotCloud(name);
  return s.backupSaved(name);
}

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final s = context.s;
    final db = context.db;
    final pass = await _askNewPassphrase(context);
    if (pass == null || !context.mounted) return;
    final BackupFile backup;
    try {
      backup = await withProgress(context, s.encrypting, () => Backup.create(db, pass));
    } catch (e) {
      // Such as a phone too full for the file.
      ErrorLog.record('backup.create', e);
      if (context.mounted) snack(context, s.backupNotSaved);
      return;
    }
    final name = backup.name;
    final where = context.mounted ? await chooseBackupPlace(context) : null;
    if (where == null || !context.mounted) {
      await backup.discard();
      return;
    }
    String? place;
    try {
      // Folders on the phone, Drive, OneDrive and Dropbox are all places in Android's own save
      // dialog: a cloud app does the upload, so Kukira needs no internet permission for it.
      // Where the file went is what the dialog answers, not what was picked above: the
      // dialog often opens at Downloads, and saving there keeps the file on the phone.
      place = where == 'share' ? (await Backup.share(backup) ? 'share' : null) : await Backup.saveWithDialog(backup);
    } catch (e) {
      ErrorLog.record('backup.save', e);
      place = null;
    } finally {
      // Saved, shared (the share sheet keeps its own copy) or not: this copy is done with.
      await backup.discard();
    }
    if (!context.mounted) return;
    if (place == null) {
      snack(context, s.backupNotSaved);
      return;
    }
    await db.setSetting('lastBackup', DateTime.now().toIso8601String());
    await db.setSetting('lastBackupTo', place);
    if (context.mounted) snack(context, backupSavedMessage(s, name, missing: backup.missing, wanted: where, place: place));
  }


  @override
  Widget build(BuildContext context) {
    return WorldView(builder: (context, w) {
      final s = context.s;
      final last = w.lastBackup;
      return SafeScaffold(
        appBar: AppBar(title: Text(s.backupRestore)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.lastBackupLabel, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(last == null ? s.never : s.dLong(last), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (last != null) Text(w.settings['lastBackupTo'] == 'cloud' ? '${s.ago(last)} · ${s.backupInCloud}' : s.ago(last)),
                const SizedBox(height: 10),
                Text(s.backupExplainer),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // A backup kept only on the phone is lost with the phone.
          if (last != null && w.settings['lastBackupTo'] == 'folder') ...[
            NoteBox(s.backupOnlyOnPhone, warn: true, icon: Icons.phone_android_outlined),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(icon: const Icon(Icons.save_alt_outlined), label: Text(s.createBackup), onPressed: () => _create(context)),
          const SizedBox(height: 8),
          OutlinedButton.icon(icon: const Icon(Icons.restore), label: Text(s.restoreFromFile), onPressed: () => restoreBackup(context)),
          Padding(padding: const EdgeInsets.fromLTRB(4, 6, 4, 0), child: Text(s.restoreFromCloudHint, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 16),
          NoteBox(s.passphraseWarning, warn: true, icon: Icons.key_outlined),
          const SizedBox(height: 8),
          // One note for how backups work on the phone, instead of two stacked boxes.
          NoteBox('${s.phoneBackupNote}\n\n${s.backupNudgeNote}', icon: Icons.phone_android_outlined),
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
    return SafeScaffold(
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
        // The version comes from the installed package (pubspec.yaml), never a hardcoded string.
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (c, snap) => Text(
            snap.hasData ? s.aboutVersion(snap.data!.version, snap.data!.buildNumber) : 'Kukira Asset',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ]),
    );
  }
}

// ================================================================ unreadable database

/// Shown instead of the app when the database cannot be opened on this phone.
class UnreadableScreen extends StatefulWidget {
  const UnreadableScreen({super.key, required this.s, required this.onReady, this.forgotPin = false, this.openFailed = false});
  final Str s;
  final bool forgotPin;

  /// Opening failed with an error rather than a missing key: try again first.
  final bool openFailed;
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
    var error = '';
    final db = await withProgress<AppDb?>(context, s.restoring, () async {
      final AppDb db;
      try {
        db = await Vault.resetAndOpen();
      } catch (e) {
        ErrorLog.record('vault.reset', e);
        error = s.secureStorageError;
        return null;
      }
      try {
        await Backup.restore(db, c);
        return db;
      } catch (e) {
        ErrorLog.record('backup.restore', e);
        await db.close();
        error = e is DamagedBackup ? s.backupDamaged : s.restoreFailed;
        return null;
      } finally {
        await SecureFiles.clearPickerCopies();
      }
    });
    if (!mounted) return;
    if (db == null) {
      snack(context, error);
      return;
    }
    widget.onReady(db);
  }

  Future<void> _fresh() async {
    final AppDb db;
    try {
      // The unreadable records are set aside by Vault, not deleted.
      db = await Vault.resetAndOpen();
    } catch (e) {
      ErrorLog.record('vault.reset', e);
      if (mounted) snack(context, widget.s.secureStorageError);
      return;
    }
    SecureFiles.reset();
    widget.onReady(db);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final theme = Theme.of(context);
    return SafeScaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 40),
          Icon(Icons.key_off_outlined, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(widget.forgotPin ? s.forgotPinTitle : (widget.openFailed ? s.openFailedTitle : s.unreadableTitle), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(widget.forgotPin ? s.forgotPinBody : (widget.openFailed ? s.openFailedBody : s.unreadableBody)),
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
