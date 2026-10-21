# Changelog

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
