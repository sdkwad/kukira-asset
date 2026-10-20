# Kukira Asset: Handoff brief for Claude Code

Prepared 20 Oct 2026 from a research and planning session (Phases 1 to 10). Read this whole file first. It replaces the need to read the original chat.

## 0. Your job, in order

1. **Do not write the full app yet.** First produce a **clickable visual prototype** of the five core screens and three flows (section 9), so the owner can see and react to the plan. Plain HTML or a Flutter UI shell with fake data is fine.
2. Then build **two thin technical prototypes** before polishing anything: (a) reminders (section 6) and (b) encrypted backup and restore (section 7). These are the make-or-break risks.
3. Then build the MVP in the order in section 11.
4. Ask the owner before changing scope. Do not add features not listed in section 8.

## 1. Product

**Kukira Asset** is a mobile app for Malaysian individuals who own houses, cars and motorcycles. One place to see what is overdue or due soon, keep documents, and keep maintenance history.

Non-negotiable principles:

- **Offline-first.** Every core function works with no internet.
- **Local-only data.** No account, no cloud database, no automatic upload, no developer-hosted storage. No analytics or ad SDKs.
- **Simple.** Only nickname and type are mandatory when adding an asset. Optional details sit behind "More details".
- **Reminders are central.** All due dates, repeats and mileage thresholds feed one dashboard.
- **Honest about limits.** Legal and tax dates are editable estimates, never facts.

Positioning decided in research: **house-first** (Malaysian property ownership, DLP, tax deadlines, strata), with cars and motorcycles as a lighter companion module. Reason: the vehicle space is crowded (CareReta, Motorist, Serv, MyCar, brand apps, global apps) while no verified app covered Malaysian property obligations. This gap is "not found in limited searching", not proven.

## 2. Tech stack (decided)

- **Flutter** (Dart), Android first, iOS later.
- **drift** with **SQLCipher** (`sqlcipher_flutter_libs`). Do NOT add `sqlite3_flutter_libs` or `drift_flutter`; they conflict with SQLCipher (same native symbols; one project segfaulted). Call the SQLCipher setup on every isolate that opens the DB. Create the encrypted DB as a new file; an existing plain DB cannot be encrypted in place.
- **flutter_secure_storage** for the database key (Android Keystore, iOS Keychain). **local_auth** for biometrics, but the lock must gate a key, not just hide the UI.
- **flutter_local_notifications** for reminders.
- No network permission needed in the manifest for core features.
- Fallback if Flutter proves a poor fit: Expo (React Native) with `expo-sqlite` (SQLCipher option) and `expo-notifications`.
- The owner's PC is probably Windows (unconfirmed). iOS builds require macOS and Xcode; plan Android first and confirm the iOS build route later.

## 3. Data model (seven tables)

Tags: **E** essential, **O** optional, **C** calculated and editable.

**Asset**: nickname (E), category house|car|motorcycle (E), acquired_date (O), notes (O), photo (O), created/updated (C).

**HouseProfile** (1:1 with Asset): property_type landed|strata|strata_landed (E); address (O); source new_from_developer|subsale (O); spa_date (O); vp_date (O); dlp_end (C = vp_date + 24 months, labelled "estimated"); title_status individual|master|strata_issued (O, manual); council (O); state (O); contact for developer/JMB/MC (O); occupancy owner|rented|vacant (O); tenancy start/end/rent due day (O).

**VehicleProfile** (1:1): vehicle_type car|motorcycle (E); plate (E); make, model, year, cc (O); new|second_hand (O); warranty expiry date and/or km (O); chassis/engine numbers (O, hidden under More details); insurance provider, policy number, expiry (O); road_tax_expiry (O); current_odometer (C from latest OdometerReading).

**Reminder**: title (E); asset (E); rule_type fixed_date|repeat|mileage|date_or_mileage (E); due_date (E if date based); due_odometer (E if mileage based); repeat interval days/months/years and/or km (O); repeat_from completion|previous_due (O, default completion); lead time days or km (O, defaults); status upcoming|due_soon|overdue|done (C); source template|preset|manual (C); last_completed (C).

**Record**: asset; kind maintenance|renovation|incident|defect|payment; category; date; cost (O, single total or optional line items); vendor (O); area tag (O); status open|in_progress|done (used by defect and incident); warranty_end (O, creates a reminder); notes; photos; linked reminder (O); incident extras: description, insurance claim yes/no, reference, claim status, linked repair (O); defect extras: reported_to_developer date (O). Vehicle records add odometer and workshop.
- House categories: plumbing, toilet/bathroom, roof, leakage/waterproofing, electrical, aircond, painting, pest control, appliance, other. Renovation: minor|major (a label only, no legal meaning). Incident: leak, fire, flood, break-in, structural, other. Payment: cukai tanah/petak, cukai taksiran, maintenance charge, sinking fund, insurance premium.
- Vehicle categories (one shared list with a vehicle-type flag): oil, filter, brake, tyre, battery, belt, aircond, other; motorcycle adds chain/sprocket. Users can add their own.

**Document**: asset; file (PDF or photo, in app-private storage; DB stores path); title; type (SPA, geran, VP letter, DLP, tax bill, insurance, receipt, other); linked record/reminder (O); expiry (O, can create a reminder); added date (C).

**Vendor**: name, phone, trade, note. Records link to vendors.

**OdometerReading**: vehicle, date, km.

Deliberately NOT stored: asset value, loans, rental income, utility accounts, fuel logs, room inventory.

## 4. Malaysian rules to encode (as editable presets only)

Every preset shows "estimated, confirm with your agreement / land office / council". Confidence is stated. Primary statutes were NOT read directly; sources were secondary commentary. Have the owner (works in property management) check against the statutes before launch.

- **DLP**: Schedule G (landed) and H (strata) statutory SPAs under the Housing Development (Control and Licensing) Act 1966 give 24 months from the date the purchaser takes vacant possession. (Was 18 months before Dec 2007.) Does not apply to subsale in the same way; subsale buyers may inherit remaining warranty. Legal confirmation needed.
- **Strata sequence**: developer management period starts at VP; JMB first AGM within 12 months of VP; strata title issuance timing varies, so title status is a manual field. Sinking fund is not less than 10% of charges (fixed at 10% during developer period), charges are by share units. Arrears demand gives at least 14 days.
- **Insurance**: for strata buildings the MC/JMB insures the building under the Strata Management Act 2013 (section numbers conflict across sources, so do not cite them in the app). For landed strata schemes the parcel owner insures their own. Ask property type before showing an insurance prompt.
- **Cukai tanah / cukai petak** (State Land Office): preset 31 May. Varies by state and year (Penang waived late penalties after 31 May in 2026). If strata title is not issued, the management office pays quit rent for all owners.
- **Cukai taksiran** (local council): two half-year periods; payable January and July, in arrears after end of February and end of August under the Local Government Act 1976. Rates and portals vary by council; some councils defer in some years.
- **Vehicles**: valid insurance is a legal requirement. Road tax is annual. I could not confirm current JPJ early-renewal windows or whether the MyJPJ road tax reminder feature has launched. Do NOT build renewal logic. Store manual expiry dates and let the user choose the lead time. Road tax and insurance reminders are already free elsewhere, so they are table stakes, not a differentiator.

## 5. Competitive context (so you do not rebuild what exists)

Closest Malaysian vehicle competitor is **CareReta** (account-based; receipts to the user's own Google Drive; AI receipt scan credits; 3D parts view; tyre positions; yearly summaries; loyalty and vouchers). Others: Motorist (reminders for road tax, insurance), Serv, MyCar, brand apps (HondaTouch and others). Global local-first apps already offer offline plus no account: MaintLog, Filing Cabinet (UK), HomeOps, CarBook. Do not copy the account, 3D model, ads, AI or loyalty features.

## 6. Reminder engine rules

Platform facts (verified in official docs unless noted):
- **iOS keeps at most 64 pending local notifications** per app; the soonest 64 survive, repeating ones count as one.
- **Android 14+**: `SCHEDULE_EXACT_ALARM` is denied by default for new apps targeting 13+ and stays denied after backup/restore; `USE_EXACT_ALARM` is only publishable for qualifying alarm/calendar apps. **Use inexact scheduling** (a morning delivery window is enough).
- Android needs the boot-completed permission and receivers so the plugin can restore schedules after restart; Android 13+ needs the POST_NOTIFICATIONS runtime permission.
- Delivery on some Android devices is unreliable when the app is terminated (one GitHub report; OEM battery settings are a known cause).

Rules:
1. The database is the source of truth; the OS schedule is disposable.
2. Keep a **rolling window of the next ~50 notifications**. Rebuild the whole schedule on: app open, reminder add/edit/complete, device restart, timezone change.
3. **Today screen is the guaranteed view** (reads the DB). Notifications are best-effort and the app must say so.
4. Mark done: create a Record (optional details), set last_completed, generate next occurrence from the repeat rule (default counted from completion).
5. Edit due date: cancel old notifications for that reminder, schedule new, keep history.
6. Overdue: one follow-up notification, then stay under Overdue on Today until done or snoozed.
7. Mileage reminders compare latest odometer with due odometer when odometer is updated; Today shows "odometer last updated N days ago". Offer an optional monthly "update your odometer" date reminder.
8. Permission denied: banner on Today ("Reminders appear only when you open the app").
9. **Reminder health check** in More: permission state, last schedule rebuild, send test reminder, link to battery settings.

## 7. Security and backup

Separate four layers:
1. **Local storage**: SQLCipher database plus encrypted attachments.
2. **Automatic device backup**: treat as untrusted. Android Auto Backup is on by default and includes most app files; exclude all app data via `dataExtractionRules` (Android 12+: both `cloud-backup` and `device-transfer`) and `fullBackupContent` (Android 11 and lower), or set `allowBackup="false"`. iOS `isExcludedFromBackup` is only guidance, may reset after some file operations, and is not guaranteed, so on iOS rely on encryption first.
3. **Manual backup (the only supported move/restore path)**: one encrypted file containing DB and attachments, key derived from a **user passphrase** (separate from the PIN). Saved via the system share sheet so the user picks the destination. Restore asks for the passphrase and shows a preview (counts of assets, records, documents) before replacing data. Warn plainly: a forgotten passphrase cannot be recovered; losing the phone or uninstalling without a backup loses the data.
4. **Off-device features**: none in MVP.

**Risk to test early (design reasoning, not a sourced fact):** if the DB key lives only in Keystore/Keychain and an encrypted DB file is restored by the OS onto a new phone, the key may not come with it. The app must detect an unreadable database and show a clear "Restore from backup file" screen, not crash.

Backup nudge: a local reminder every 30 days and "last backup" shown on Today.
App lock: PIN or biometric, gating the key.

## 8. MVP scope (Stage 1)

In scope: assets and profiles; reminders (fixed, repeat, mileage, whichever first) with lead times, done and snooze; templates and editable presets; Today dashboard; records; DLP defect list with countdown (visible while a VP date exists and DLP is running); documents; search; vendor book; encrypted DB and files; PIN/biometric lock; encrypted manual backup and restore; reminder health check; backup nudge; onboarding (first asset in under a minute, suggested reminders as chips); privacy policy and store disclosures.

English only (put all text in resource files so Bahasa Malaysia can be added).

**Not in MVP:** accounts, cloud sync, family sharing, government or portal integration, receipt OCR/AI, 3D models, ads, loyalty, fuel and trip logs, cost charts, house history PDF, tyre positions, room inventory, utility or rental accounting, renewing road tax or insurance in-app, legal advice, iOS release, widgets.

Stage 2 (only if users keep records for about 3 months and ask): house history PDF, cost summaries, configurable intervals, Bahasa Malaysia, tyre positions. Stage 3: on-device receipt scan, document text recognition, optional file-based sharing.

## 9. Navigation and flows

Tabs: **Today**, **Assets**, central **+ Add** (asset, record, reminder, document), **Documents**, **More** (backup and restore, security, notifications, reminder health check, about). Reminders live on Today; "All reminders" view reached from it and filtered inside each asset. Search at top of Assets and Documents.

Screens: Today (Overdue, Due soon next 30 days, Recently completed; banners only when needed); Assets list (card with next due item); Asset detail (house: Overview, Upkeep, Reminders, Documents, Defects while DLP runs; vehicle: same without Defects plus mileage); Add/edit record bottom sheet; Documents list; Backup and security.

Flows:
- **First asset (3 taps, under a minute):** choose House/Car/Motorcycle; nickname plus one question (house: landed/strata/strata-landed; vehicle: plate); Done. Then offer 2 to 3 suggested reminders as tick chips, each needing only a date; all skippable.
- **Set a reminder:** title or template; rule; due date; lead time default. Tax presets show "confirm with your land office or council".
- **Record maintenance:** + Record; kind and category; date; single total cost (itemise optional); optional vendor, area, photos, warranty end, notes. If it completes a reminder, offer to mark done and schedule next.
- **Attach and open a document:** Attach from camera/photos/files; title and type; optional expiry creating a reminder. Open from Documents or search in the system viewer.
- **Backup and restore:** as in section 7.
- **First-time:** empty Today shows one prompt "Add your first asset". Offer PIN, backup and notifications after the first reminder is saved, not before.

## 10. Acceptance criteria (test on at least two real Android phones)

1. A new user adds one asset and one reminder in under two minutes unaided.
2. A reminder due tomorrow still fires after phone restart and after force-close.
3. With notification permission denied, Today still lists it and a banner explains why.
4. Changing a due date removes the old notification and creates the new one.
5. Marking a repeating reminder done creates the next occurrence from the completion date.
6. An export file restores on a different phone with the right passphrase and fails safely with a wrong one.
7. Opening the app with no network shows all data and attachments.
8. The app makes no network request in normal use (verify with a traffic monitor).
9. The database file cannot be read without the key.
10. A mileage reminder becomes overdue when odometer is updated past its threshold.

## 11. Build order

0. Clickable prototype (no real code) plus user tests.
1. Setup, encrypted database, assets and profiles.
2. Reminders engine, notifications, Today screen, health check.
3. Records, defects, vendors, documents, search.
4. Presets, templates, onboarding.
5. Lock, backup and restore, nudges.
6. Privacy policy, store listing, Android closed test.
7. iOS port and testing.

## 12. Distribution facts

- **Android APK**: fine for private testing.
- **Google Play**: US$25 one-time registration fee (official). A new **personal** developer account must run a closed test with at least **12 testers opted in for 14 continuous days** before applying for production (official). Organisation accounts reportedly exempt (secondary source). Plan about three weeks for first launch. Needs a privacy policy and accurate Data safety section.
- **Apple App Store**: US$99 per year (official). Needs privacy policy URL, privacy details and privacy manifest; recent guides say uploads need Xcode 26 or later (verify).
- Malaysian mobile share varies by month in StatCounter data (Android about 54 to 60%, iOS about 40 to 46% in mid-2026), so Android first covers roughly half or more of phones, not all.

## 13. Decision log

| # | Decision | Reason |
|---|---|---|
| 1 | House-first, vehicles lighter | Vehicle space crowded; property rules are local |
| 2 | Local-only is a trust feature, not the headline | Several global apps already offer it |
| 3 | All legal dates editable presets marked "estimated" | State and council variation |
| 4 | Ask property type at setup | Changes tax and insurance prompts |
| 5 | No vehicle renewal logic | Rules unverified; free alternatives exist |
| 6 | Seven tables; dashboard is a Reminder query | Avoids separate frequency modules |
| 7 | Only nickname and type mandatory | "No huge forms" |
| 8 | Cars and motorcycles share one structure | Less to build |
| 9 | Next due counts from completion by default | Matches real servicing |
| 10 | Defect list is MVP | Most Malaysia-specific differentiator |
| 11 | Flutter, drift, SQLCipher | Best-documented stack; Expo is fallback |
| 12 | Inexact Android alarms; rolling ~50 window | Avoids Android 14 and iOS 64-limit failures |
| 13 | Today is guaranteed; notifications best-effort | OS cannot guarantee delivery |
| 14 | Manual encrypted backup is the only move/restore path | OS backups unreliable for keys |
| 15 | No analytics or ads SDKs | Keeps privacy claim true |
| 16 | Android first, iOS after reliability proven | Scope and Mac requirement |
| 17 | Prototype and user tests before full build | Validate before investing |

## 14. Open questions for the owner

1. Strata-landed as a third property type (recommended) or a checkbox?
2. English only, or English and Bahasa Malaysia at launch?
3. Free, one-time purchase, or free with optional one-time unlock? (See commercial notes in the chat summary: no-cloud limits recurring revenue.)
4. Which two or three Android phones are available for testing, including one with aggressive battery management?
5. Does the owner have a Mac, or will iOS builds need another route?
