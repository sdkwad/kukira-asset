# Changelog

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
