# Kukira Asset: specification

The full product brief is in `docs/handoff-brief.md`. This file holds the rules every change must follow, and the backlog notes agreed with the owner.

## Non-negotiable rules

1. **No INTERNET, storage or install permission.** The APK must not request `android.permission.INTERNET`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `READ_MEDIA_*` or `REQUEST_INSTALL_PACKAGES`. `android_overrides/app/src/main/AndroidManifest.xml` strips them, and the "Namakan APK dan semak kebenaran" step in `.github/workflows/build-apk.yml` fails the build if any appear. Never weaken that check.
2. **Everything stays encrypted.** The database is SQLCipher; documents and photos are AES-256-GCM files whose key lives inside the database; backups are passphrase-encrypted. The app lock wraps the database key (PIN) or keeps it in a fingerprint-protected Keystore entry. A lock that only hides the screen is not acceptable.
3. **Every new or changed screen has a widget test and respects SafeArea.** Page bodies use `SafeScaffold` (in `lib/ui/common.dart`) or an explicit `SafeArea`, so the primary button and the last field always sit above the Android navigation bar. `test/safe_area_test.dart` renders the form and list screens with a simulated bottom inset.
4. **One feature or fix per commit, and GitHub Actions green after each.** Work on a branch until CI is green, then squash it onto `main` as one commit.
5. **Tax and legal dates are editable "estimated, confirm" presets.** Cukai tanah, cukai petak, cukai taksiran and DLP dates are never presented as fact; each shows who to confirm with, and the user can change every date.
6. **APKs are signed with the Kukira release key only.** The key is never committed: CI takes it from the `KUKIRA_KEYSTORE_B64` and `KUKIRA_KEYSTORE_PASSWORD` secrets and checks every APK's certificate digest. The owner keeps the offline copy. Changing the key forces users to uninstall, which deletes their data, so it must never change.
7. **Data is set aside, never silently destroyed.** An unreadable database is moved aside (see `Vault.resetAndOpen`), restores only remove files after the new records are committed, and backups record their schema so a newer one is refused.
8. **Destructive quick actions can be undone.** Any swipe action (there are none yet) that completes or snoozes a reminder must show an Undo snackbar. Do not add swipe actions without this.

Also kept from the brief: offline-first, local-only data, no account, no analytics or ad SDKs, Bahasa Melayu first with English (every string in both `lib/l10n/strings_ms.dart` and `strings_en.dart`).

## Overdue notifications

Decided by the owner (2026-11-02), replacing the brief's single follow-up: an overdue reminder is notified the day after its due date and then weekly, four times in all (`overdueNudgeDays` in `lib/domain/rules.dart`). After that it stays under Overdue on Today until it is done or snoozed.

## Reminders that follow a date field

Road tax expiry, insurance expiry (vehicles) and the DLP end (house, from the VP date or the owner's correction) each keep one linked reminder, marked by `Reminders.autoSource` (`roadTax`, `insurance`, `dlp`).

- Setting a date creates the reminder; changing it updates the same reminder; clearing it removes the reminder. There is never more than one linked reminder per field.
- If the linked reminder was marked done or is snoozed, the app explains what will change and asks before reopening it or clearing the snooze.
- The due date of a linked reminder is edited on the asset page, not in the reminder form.
- Renewing road tax or insurance (`lib/services/renewal.dart`) is the exception to asking: the renewal sets the new end, and the linked reminder is moved there and reopened without a second question, because that is what renewing means. The renewal form says so. Each renewal is a payment record with its period (`Records.coverStart`, `coverEnd`, schema 5), so past periods are never overwritten.
- The planning rules are in `lib/domain/auto_sync.dart` (pure, unit tested); applying them is `lib/services/auto_reminders.dart`.

## Backups and stored files

- A backup file is the only way records leave the phone. Saving one to Google Drive, OneDrive or Dropbox goes through Android's own save dialog (the cloud app uploads it); never add a cloud API or the internet permission for it.
- Where a backup went is what the save dialog answers (`kukira/save` in MainActivity.kt, `Backup.placeOf`), never the choice made in Kukira. Say "in the cloud" only for a known cloud provider and "only on this phone" only for a known phone folder.
- Every stored file name, from the database or from a backup, must pass `SecureFiles.isSafeName`; a backup that names any other file is refused. It must keep accepting every name an older version made (`<32 hex>.<letters and digits>`, any length that fits). A backup header may ask for at most `Backup.maxIterations` rounds.
- Nothing readable is left outside the encrypted store: the pickers' copies in the cache are removed once read and at start (`SecureFiles.clearPickerCopies`), and copies handed to a viewer or the share sheet are cleared (`SecureFiles.clearTemp`, `handOverFolders`). A new plugin that copies files must be added there.

## Wide screens

`windowSize` (`lib/ui/common.dart`) follows Material: compact under 600 dp, medium to 840, expanded above. From medium the main places are on a `NavigationRail` with Tambah, and pages inside it (`RailScope`) hide their own floating Tambah; from expanded Today and Assets show list and detail side by side. `SafeScaffold` keeps a page to `readableWidth`. A phone layout must never change because of this.

## Pick lists and official sources

Fields with a natural list (make, model, year, insurer, state, council, area, cost item) use `ComboField` (`lib/ui/combo.dart`): it suggests, and whatever is typed is saved as typed.

- The council list is generated from KPKT's list of local authorities by `tool/councils` (see its README), with DBKL added. Never edit `lib/domain/councils.dart` by hand. A council keeps a website only if it was opened and named the council when the list was made.
- The insurer list in `lib/domain/lists.dart` is the companies with a General Insurance Business or General Takaful Business licence in the BNM Financial Sector Participants directory. Say the date it was read when it changes.
- Websites open in the phone's browser through the `kukira/links` channel in MainActivity. The app never loads a page itself and never asks for the internet permission for it.

## Backlog and constraints

Not built yet. These notes constrain how they are built.

- **OCR:** bundled on-device model only, with no model download at runtime. Check the APK size impact first. The user must confirm every auto-filled field.
- **Home-screen widget:** opt-in, and show counts only, so no sensitive details appear on the home screen.
- **Sharing:** start with a one-way encrypted snapshot import; defer two-way merge. Any sharing or PDF export needs a clear on-screen note that data leaves the phone.
- **First 0.3 candidates:** WhatsApp follow-up for DLP defects, and the room-by-room VP/DLP inspection.
- Also out of scope until agreed: Resale Passport PDF, `.kukira-pack` family sharing, parts lifespan.
