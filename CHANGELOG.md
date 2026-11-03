# Changelog

## 0.2.6

Error audit: static checks, test coverage per file, and a line-by-line review of the least tested code.

- **Security:** when the app locks itself again after two minutes away, what is under the lock screen is now also hidden from screen readers (TalkBack) and keyboard focus. Before, the lock covered the records but a screen reader or automation tool could still read them, or a hardware keyboard type into a form, without the PIN. Unlocking still returns to exactly where you were.
- **Fixed:** if setting up notifications or opening the encrypted database failed at start-up, the app showed a blank screen. Notifications failing no longer stops the app (Today still shows everything), and a database that cannot be opened right now shows "Kukira couldn't open your records just now" with what to try first, instead of nothing.
- **Fixed:** cukai taksiran (and other reminders that repeat from a month-end due date) drifted: after the end of February, the August half fell on 28 August instead of 31 August, for good. Month-end dates now stay at month end (31 Aug, 28/29 Feb, 31 Aug).
- **Fixed:** Today asked for a vehicle's odometer reading twice when its monthly odometer reminder was already listed.
- **Fixed:** Add asset could call into a closed screen if it was left while saving.
- **Tests:** the Add asset flow (the first screen every new user sees, 16% covered before) is tested end to end, plus the lock cover, the start-up failure screen and month-end dates. CI now prints line coverage per file.

## 0.2.5

UI polish from the first review of real screenshots (31 screens, made in CI). Looks and layout only; no change to how reminders, records or backups work.

- **Changed:** status is said once. Today's Overdue and Due soon lists no longer add a "Lewat" pill to every row (the section and the due text already say it), and asset cards drop the pill on their "Next" line. Mixed lists (All reminders, an asset's Reminders tab) keep it.
- **Changed:** the reminder sheet says "6 days overdue" once (it said "Overdue · 6 days overdue"), and shows the next notification it will get, instead of the first one, which could be weeks in the past. When none are left: "None left to send. It stays on Today."
- **Fixed:** the "no backup yet" banner on Today was green, the colour for "all good"; it is now a warning. The Last backup tile says "Never" instead of "–", and the three summary tiles are the same height.
- **Changed:** assets without a photo no longer start with a large decorative gradient and faded icon. Cards show a small category icon by the name (all three demo assets now fit on one screen), the Overview starts with the facts, and Edit details labels the photo buttons "Asset photo (optional)". Assets with a photo still show it.
- **Changed:** on a vehicle record the odometer field is shown straight away instead of under More details, since it keeps mileage reminders right.
- **Changed:** More shows whether the app lock is on ("Off", "On, with PIN", "On, with PIN and fingerprint") instead of repeating "PIN or fingerprint"; the title is now just "App lock".
- **Fixed:** the battery advice in Reminder health check was squeezed into six lines beside its button; the button now sits under the text.
- **Fixed:** the black number plate is visible in dark mode (thin grey edge).
- **Changed:** Backup and restore has one note about phone backups instead of two stacked boxes.
- **Tests:** 13 checks pin these changes (`test/ui_polish_test.dart`); screenshots now also cover asset tabs, the reminder and record sheets, All reminders, App lock, Privacy and Attach document. A layout overflow introduced during this work was caught by the tests before release.

## 0.2.4

Notifications you can rely on, from the second audit.

- **Fixed:** opening Kukira (or changing anything) no longer wipes your reminder notifications from the notification tray. Each notification now keeps the same id, only scheduled ones that are no longer needed are cancelled, and a notification in the tray is removed only once its reminder is done, snoozed, deleted or no longer due soon.
- **Fixed:** a snoozed reminder that is still overdue when the snooze ends is now followed up weekly (3 more times), instead of going silent.
- **New:** if more reminders are due than fit in the schedule (48), an "Open Kukira" notice is scheduled the day after the last one, so the schedule is refreshed before it runs out.
- **Fixed:** editing a house or vehicle now saves the dates and their linked reminders together, and suggested reminders in Add asset are added all at once or not at all. A failed save says so.
- **Fixed:** a backup shared through the share sheet no longer stays in the app cache; it is cleared like viewed documents.
- **Privacy:** the error log now removes file names, paths and quoted text from error messages.
- **Code:** saving a record moved from the form into `lib/services/record_save.dart` and is tested on its own.
- **Tests:** screenshots of 22 screens are made in CI with the real fonts (`test/screenshots_test.dart`), for reviewing the UI. Plus tests for notification ids and the tray, snooze follow-ups, the refresh notice, asset transactions, the record service and error-message scrubbing.

## 0.2.3

Daily-use reliability, from a full audit of the app.

- **Fixed:** a quick double tap on Save could create a reminder, asset or vendor twice. Save buttons now disable themselves while saving.
- **Changed:** an overdue reminder is now notified the day after its due date and then weekly, four times in all, instead of once. A swiped-away notification no longer leaves an overdue road tax silent.
- **Fixed:** changing a record's warranty end date now moves its warranty reminder (before, it stayed at the old date). The reminder follows the date like road tax does, follows the record's title, and goes when the record is deleted. Existing warranty reminders are linked on upgrade (database schema 4).
- **Fixed:** saving or deleting a record or document now happens in one step: if the app is stopped part way or the save fails, nothing is half-saved (no record without its cost items or photos, no document without its reminder). A failed record save now says so.
- **Security:** with the app lock on, Recent apps no longer shows a picture of your records (Android 13+; on older Android this also blocks screenshots while the lock is on).
- **Security:** decrypted copies made to view or share a document are deleted 5 minutes later once you're back in Kukira, instead of staying until the next app start.
- **New:** an encrypted error log in Reminder health check lists errors Kukira caught quietly (where and what, never record contents), with Copy to send it to the developer.
- **Build:** package versions are locked (`pubspec.lock` committed, enforced in CI) and analyzer warnings now fail the build.
- **Tests:** save-once, weekly overdue nudges, warranty reminders, transactions with files, schema 1/2/3 to 4 upgrades, temp-file cleanup, Recent apps setting, error log and its screen.

## 0.2.2

Safety release: nothing new to see, but less can go wrong with your data.

- **Changed:** APKs are now signed with the Kukira release key instead of a test key kept in the repo. **Coming from 0.2.1 or earlier, Android will not install 0.2.2 over it:** make a backup, uninstall the old version, install 0.2.2 and restore the backup. This is needed once only.
- **Fixed:** when the records could not be opened and you chose Start fresh (or restored a backup from that screen), the old database and its files were deleted. They are now set aside, still locked, and the old key entries are kept, so nothing is destroyed if the key turns out to be readable. If the phone's secure storage can't be read, nothing is changed.
- **Fixed:** restoring a backup is now safe if the app is stopped part way or the backup can't be applied: your current records and files stay until the new ones are fully in place. A failed restore says so.
- **New:** backups record the database version. A backup made by a newer Kukira is refused with a message instead of being restored with fields missing.
- **Fixed:** restoring a 0.1 or 0.2 backup now links its road tax and insurance reminders to the date fields, so changing a date later doesn't create a duplicate.
- **New:** if a document or photo can't be read while making a backup, you're told how many are missing instead of the backup silently leaving them out.
- **Fixed:** closing and reopening the app no longer resets the wait after too many wrong PINs.
- **Tests:** database upgrades from schema 1 and 2, backup formats 1 and 2 round trip, wrong passphrase, newer backup, missing files, interrupted and failed restores, the unreadable-database set-aside, and the PIN wait across restarts.

## 0.2.1

- **Fixed:** the Android navigation bar no longer covers the Save button and the last fields on New reminder, New record, Edit details (house and vehicle) and every other form and list screen.
- **New:** road tax expiry, insurance expiry and the VP date (DLP end) keep one linked reminder each. Setting a date creates it, changing the date updates the same reminder, clearing the date removes it, and saving again never makes a duplicate. If the linked reminder was marked done or snoozed, the app explains and asks before changing it. Road tax and insurance reminders created in 0.2 are linked automatically on upgrade (database schema 3).
- **New:** house Edit details shows only the title status choices and suggested reminders that fit the property type (landed, strata, strata landed), and suggested reminders can be added straight from there.
- **Changed:** for subsale homes the VP date is no longer treated as irrelevant: it is labelled "Original VP date (if still within DLP)". The DLP countdown appears only when a VP date is set.
- **Fixed:** Privacy & about showed version 0.1.0; it now shows the installed app version.
- **Tests:** widget tests for 18 screens with a simulated navigation bar, linked-reminder planner and database tests, property-type and subsale form tests, and a version test.
- **Docs:** `SPEC.md` (non-negotiable rules and backlog constraints) and `CLAUDE.md`.

## 0.2.0

Documents and photos (encrypted), PIN and fingerprint lock, vendor book, record editing, cost breakdown, DLP end override, notification time, custom repeats, monthly odometer reminder, backups with files, new look, smaller APKs.

## 0.1.0

First test APK: encrypted database, assets, reminders and notifications, Today screen, records, DLP defects, odometer, encrypted backup and restore, reminder health check, Bahasa Melayu and English.
