# Changelog

## 0.2.8 (build 13)

Renewing road tax and insurance (planned as 0.2.7e), wide screens, backups to a cloud drive, and the fixes from a full audit. The database moves to schema 5; it upgrades on its own and older backups still restore. The app still has no internet permission.

- **New:** Renew road tax or insurance from the asset page (once the end is within 60 days), from its reminder, or from Tambah. One form: 6 or 12 months or another length, starting the day after the old end, the new end, the cost and a proof (e-LKM, policy, receipt), all but the dates optional. The length follows the last period on record. When road tax and insurance end close together, both can be renewed at once, each with its own dates, and Tambah shows them as one suggestion.
- **New:** each renewal is a payment record that keeps its period (schema 5: `coverStart`, `coverEnd`), so every past period stays in Records; the asset page shows the current period's length. One save, in one transaction, sets the new end, moves the linked reminder there (reopening it if it was marked done or snoozed: renewing is the reason to move it, and the form says so) and files the proof, encrypted, with the record. A failed save changes nothing and leaves no file.
- **New:** wide screens. From 600 dp (a tablet, an unfolded phone, a large phone on its side) the four places are on a rail at the side, with Tambah at the top; from 840 dp Today shows the picked reminder beside the list instead of in a sheet, and Assets shows the picked asset beside the list. An asset's overview goes into two columns when there is room. Forms and lists keep a readable width. Phones are unchanged.
- **New:** "Google Drive, OneDrive or Dropbox" is the first place offered for a new backup. It opens Android's own save dialog, where the installed cloud apps are places: that app does the upload, so Kukira itself still never goes online, and the file stays encrypted with its passphrase. If the last backup was saved only in a folder on the phone, Backup and restore says it would be lost with the phone.
- **Security:** a backup made by someone else could name files such as "../..", and restoring it would write outside Kukira's files folder. Every stored file name, in a backup and in the database, must now be one the app could have made; any other backup is refused.
- **Security:** a backup's header is read before its passphrase is checked, so a made-up file could ask for billions of key-stretching rounds and hang the app. It may now ask for at most 2 million. A backup that opens but is not laid out as one is refused cleanly.
- **Fixed:** deleting a record deleted its photos but left its other documents (such as a renewal proof) "linked to a record" that no longer existed. They now stay as documents of the asset.
- **Fixed:** a record cost that was not a number ("1o0") was saved as no cost, a mistyped item as RM 0, and a negative cost was accepted. The form now says the cost is not valid.
- **Fixed:** a tenancy could end before it started.
- **Fixed:** a service record that marked its reminder done counted the next one from the day it was typed in, not the day of the service (a service on 1 Oct entered on 20 Oct made the next one 20 Apr instead of 1 Apr).
- **Fixed:** a document moved to another asset left its expiry reminder, and its link to a record, on the old asset. Both now follow: the reminder moves, the link to the old asset's record is let go.
- **Fixed:** a renewal used the records as they were when its form opened; if the reminder changed meanwhile, a second one could be made. It now reads them when saving.
- **Fixed:** the menu button stayed in its white circle after the photo header shrank to a plain bar.
- **Tests:** the period rules (month ends, leap years, follow-on and lapsed), the renewal save (period kept, date and reminder moved, proof filed, both covers, a failed save changing nothing, a reminder changed while the form was open), the schema 4 to 5 upgrade, the rail, list and detail panes, two columns and readable widths on tablet and medium windows, the cloud backup choice and the phone-only warning, and each audit fix.

## 0.2.7 (phase d, build 12)

Tambah suggests what is due, a new Documents tab, the photo fade from the owner's test, and a smoother app. No database change; encryption, backups and documents work as before, and the app still has no internet permission.

- **Changed:** an asset's photo now fills its card and the top of its page: at full strength on the right, and at a quarter of it under the text, instead of only the right half. Text on a photo uses the main text colour, which stays at least 6:1 even over a black or white photo, and a status such as "6 days late" sits on its own chip.
- **Faster:** the encrypted database runs on its own isolate, so saving and reloading no longer hold up drawing and touches. It still uses SQLCipher and still refuses to open unencrypted; if its isolate cannot start, it opens as before and the reason goes to the error log.
- **Faster:** after a change, only the notifications that changed are scheduled again, instead of all of them (up to 50), each of which made Android rewrite its whole list on the thread that delivers touches. "Rebuild the schedule now" still schedules everything.
- **Faster:** a picture is decrypted once instead of on every rebuild (the shrinking page header rebuilt every frame), one already in memory shows at once, and the header fades its photo without an offscreen layer.
- **New:** Tambah starts with "Suggested": up to three reminders that are overdue or due soon, with the asset and how late or near. "Record engine oil change" opens a record that marks the reminder done when saved; road tax, insurance, the DLP and the odometer open the reminder itself. On an asset's page only that asset's, then "Other records for Myvi".
- **Changed:** Documents shows how many there are, groups them by asset with the three that matter most first (those about to end) and "See N more", and filters by asset and type with two buttons instead of a long row of chips. The search lists every matching document with its asset, and "Also in records": records that mention the words in their name, notes, shop, area or items, such as a policy number in the notes. "Add document" is a floating button.
- **Tests:** worst-case contrast of text over a photo in both modes, the photo filling the card, the database opening, writing, reopening and refusing to run unencrypted on its own isolate, when a notification is scheduled again, suggestions (which, in what order, what they open), Documents (order, groups, filters, search in records) and every new screen at 130% text on a 360 dp phone.

## 0.2.7 (phase c, build 11)

Forms that ask only what applies, lists to pick from, and a first run. No database change; encryption, backups, documents and notifications work as before, and the app still has no internet permission.

- **New:** make, model, year, insurer, state, council (PBT), area and cost item fields suggest from a list as you type, and the arrow opens the whole list. Whatever you type is saved as typed, so a model or council that is not listed is never an error. Names you typed before are offered too, and models follow the make.
- **New:** the council list is generated from KPKT's official list of local authorities (156 councils with DBKL), and the insurer list is every company with a general insurance or general takaful licence in Bank Negara Malaysia's directory (23), both read on 4 Nov 2026. A council's website is kept only if it opened and named the council when the list was made (150 of 156); `tool/councils` re-checks them.
- **New:** a council with a website has a link in the house form and in the house details. It opens in the phone's own browser; Kukira does not load the page. A short form shared by two councils (MPS is Sandakan and Selayang) links only when the state makes it clear.
- **Changed:** a subsale house asks "Still within the developer's DLP?" first. Only then are the original VP date and DLP end asked; otherwise they are cleared on save, with the DLP reminder. The SPA date, address, contact and notes wait behind "+" buttons until needed.
- **New:** a house that is rented out asks for the tenancy start and end and the day rent is due, and shows them in the details. For reference only: there is no tenancy reminder yet. They are kept if the house stops being rented out, so a wrong tap loses nothing.
- **New:** a fresh install opens on a welcome (what Kukira does, BM or EN, and "Restore a backup" for moving from an old phone), then a setup page for notifications, their time and the PIN lock. Both finish the first run; a phone that already has assets never sees them.
- **New:** a photo can be added while adding an asset, and changed or taken out before saving. It is encrypted like every other picture once the asset exists; if it cannot be saved, the asset is kept and you are told. In Edit details the photo is one small row with a Change button instead of a banner and three buttons.
- **Tests:** matching and the official lists, picking and typing in the forms, the council link (and no guess on a shared short form), each house situation and what it saves, the first run and what marks it done, the photo saved encrypted and linked to the asset, and every new screen at 130% text on a 360 dp phone and above the navigation bar.

## 0.2.7 (phase b, build 10)

How the app looks, from the second design review and the owner's test on a phone. No database change; encryption, backups, documents and notifications work as before.

- **Changed:** Today says what is due in one sentence ("2 overdue and 2 due soon across your 3 assets") instead of three tiles, which cut off at large text sizes. "Needs action" and "Next 30 days" appear only when they have something. When nothing is due it says "All in order" and shows the next three, instead of three empty sections. A search button searches assets, reminders, records and documents.
- **Changed:** every reminder row says how late or how near on the right ("6 days late", "9 days", "580 km to go", on whichever of date or km is nearer) and when below ("by 28 Oct or 50,120 km", "ends 12 Nov"), so neither is said twice. Backup and notification warnings are rows on Today.
- **New:** an asset's photo shows on its card on the right, faded into the card on the left, where the name, plate and next reminder stay readable (at least 94% cover under the text, in light and dark). Assets without a photo keep the plain icon.
- **New:** an asset page with a photo opens on it, faded the same way, and shrinks to a small photo by the name as you scroll.
- **Changed:** the asset overview: what the asset is, a sentence on what needs attention, Status (odometer, monthly odometer reminder, road tax and insurance; for a house the defect liability period, taxes and charges), Upkeep with a km bar, the latest records with this year's spending, and Details folded into one line. The DLP line always says it is an estimate to confirm in your SPA.
- **Changed:** Records is a history: newest first on a line down the side, each year with its count and total, and each record with its items. The search looks inside items ("battery"). An unreported defect during the DLP can be marked reported from its card.
- **Changed:** the remaining all-capital labels are in sentence case, and the English Records tab is called Records.
- **Tests:** Today busy and calm, the short status rules, search, photo cards, the photo header shrinking, the overview (DLP line, details, monthly odometer switch), the record history (years, items, search, marking reported), all at 130% text on a 360 dp phone. Screenshots now picture asset photos (two sample photos in `test/fixtures`, credited).

## 0.2.7 (phase a, build 9)

The foundation of the approved 0.2.7 design: navigation, Tambah and the design system. No database change; encryption, backups, documents and notifications work as before.

- **Changed:** four real tabs: Today, Assets, Documents, More. The "+" in the middle of the bar, which opened a sheet instead of a page, is now a floating Tambah button on Today, Assets and each asset's page.
- **Changed:** Tambah follows where you are. On an asset's page it offers that asset's actions (service or repair, payment, incident, odometer, reminder, document; for a house also defect and renovation). With one asset it goes straight to it; with several it asks which one first, and "New asset" is in the same list. With no asset yet the button is not shown; "Add your first asset" is the one action.
- **Fixed:** a record, reminder or document started without an asset (from All reminders or Documents) was quietly put on the first asset. With several assets the form now asks which one.
- **Changed:** a record's title is optional. Left empty, the record takes the name of the reminder it marks done ("Tukar minyak enjin"), or else its category ("Cukai jalan"). The form shows that name under the field before saving.
- **Changed:** every asset has the same four tabs: Overview, Records, Reminders, Documents. The Defects tab, which came and went with the DLP, is gone. Defects are records: Records lists them with the rest and filters by kind, and the Defects filter shows them by repair status with the DLP note, as the old tab did. The overview's defect button opens it.
- **Fixed:** after the DLP ended, defects were not shown anywhere. They now stay under Records.
- **Changed:** colours, type and spacing come from one set of design tokens for light and dark (`lib/ui/tokens.dart`). List rows share one layout (title with its status on the right, context below), a status always has a word and an icon as well as a colour, and asset icons are neutral. Section titles are no longer in capitals, and the estimate tag sits by the date it is about.
- **Tests:** Tambah with no asset, one asset and several, from Today and from an asset's page; forms asking for the asset; saving a record without a title; the fixed tabs and defects after the DLP; the contrast of every text colour in both modes; rows and tabs at 130% text on a 360 dp phone. Screenshots now also cover Tambah (light and dark), the asset choice and 130% text, and are drawn with regular Roboto (Roboto Condensed had been mixed into the font, making text look narrower than on the phone).

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
