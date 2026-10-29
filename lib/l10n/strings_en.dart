import '../domain/rules.dart';
import 'strings.dart';

class StrEn extends Str {
  const StrEn();

  @override
  List<String> get monthsShort => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  @override
  List<String> get weekdays => const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  @override
  String get agoToday => 'today';
  @override
  String get agoYesterday => 'yesterday';
  @override
  String agoDays(int n) => '$n days ago';

  // ------------------------------------------------ names
  @override
  String statusLabel(RStatus st) => switch (st) {
        RStatus.overdue => 'Overdue',
        RStatus.dueSoon => 'Due soon',
        RStatus.upcoming => 'Upcoming',
        RStatus.done => 'Done',
      };
  @override
  String ruleName(String rule) => switch (rule) {
        'fixed' => 'One date',
        'repeat' => 'Repeats',
        'mileage' => 'Mileage',
        _ => 'Whichever first',
      };
  @override
  String kindName(String kind) => switch (kind) {
        'maintenance' => 'Maintenance',
        'renovation' => 'Renovation',
        'incident' => 'Incident',
        'defect' => 'Defect',
        'payment' => 'Payment',
        _ => kind,
      };
  @override
  String catName(String cat) => switch (cat) {
        'plumbing' => 'Plumbing',
        'bathroom' => 'Toilet/bathroom',
        'roof' => 'Roof',
        'leakage' => 'Leakage/waterproofing',
        'electrical' => 'Electrical',
        'aircond' => 'Aircond',
        'painting' => 'Painting',
        'pest_control' => 'Pest control',
        'appliance' => 'Appliance',
        'minor' => 'Minor',
        'major' => 'Major',
        'leak' => 'Leak',
        'fire' => 'Fire',
        'flood' => 'Flood',
        'break_in' => 'Break-in',
        'structural' => 'Structural',
        'wall_crack' => 'Wall/crack',
        'floor_tiles' => 'Floor/tiles',
        'door_window' => 'Door/window',
        'cukai_tanah' => 'Cukai tanah',
        'cukai_petak' => 'Cukai petak',
        'cukai_taksiran' => 'Cukai taksiran',
        'maintenance_charge' => 'Maintenance charge',
        'sinking_fund' => 'Sinking fund',
        'insurance_premium' => 'Insurance premium',
        'accident' => 'Accident',
        'theft' => 'Theft',
        'oil' => 'Engine oil',
        'filter' => 'Filter',
        'brake' => 'Brake',
        'tyre' => 'Tyre',
        'battery' => 'Battery',
        'belt' => 'Belt',
        'chain_sprocket' => 'Chain/sprocket',
        'road_tax' => 'Road tax',
        _ => 'Other',
      };
  @override
  String categoryName(String c) => switch (c) { 'car' => 'Car', 'motorcycle' => 'Motorcycle', _ => 'House' };
  @override
  String categoryHint(String c) => switch (c) {
        'car' => 'Road tax, insurance, servicing',
        'motorcycle' => 'Road tax, insurance, oil changes',
        _ => 'Taxes, DLP, defects, upkeep',
      };
  @override
  String ptypeName(String p) => switch (p) { 'strata' => 'Strata', 'strata_landed' => 'Strata landed', _ => 'Landed' };
  @override
  String ptypeHint(String p) => switch (p) {
        'strata' => 'Condo or apartment with a JMB or MC',
        'strata_landed' => 'Gated landed homes with strata title',
        _ => 'Terrace, semi-D, bungalow with its own title',
      };
  @override
  String sourceName(String v) => v == 'subsale' ? 'Subsale' : 'New from developer';
  @override
  String titleName(String v) => switch (v) { 'master' => 'Master title', 'strata_issued' => 'Strata title issued', _ => 'Individual title' };
  @override
  String occupancyName(String v) => switch (v) { 'rented' => 'Rented out', 'vacant' => 'Vacant', _ => 'Owner-occupied' };
  @override
  String conditionName(String v) => v == 'second_hand' ? 'Second-hand' : 'New';
  @override
  String defectStatusName(String v) => switch (v) { 'in_progress' => 'Developer working on it', 'done' => 'Fixed', _ => 'Open' };
  @override
  String leadLabel(int d) => switch (d) {
        0 => 'On the day',
        7 => '1 week before',
        14 => '2 weeks before',
        30 => '1 month before',
        _ => '$d days before',
      };
  @override
  String monthsLabel(int m) => switch (m) { 1 => 'Month', 12 => 'Year', _ => '$m months' };
  @override
  String presetTitle(String k) => switch (k) {
        'cukaiTanah' => 'Cukai tanah',
        'cukaiPetak' => 'Cukai petak',
        'cukaiTaksiran' => 'Cukai taksiran',
        'houseInsurance' => 'House insurance renewal',
        'maintenanceCharge' => 'Maintenance charge and sinking fund',
        'aircond' => 'Aircond service',
        'pestControl' => 'Pest control',
        'waterTank' => 'Water tank cleaning',
        'roadTax' => 'Road tax renewal',
        'vehicleInsurance' => 'Insurance expires',
        'carService' => 'Car service',
        'motoOil' => 'Engine oil change',
        'tyres' => 'Tyre change',
        'battery' => 'Battery check',
        'chain' => 'Chain and sprocket check',
        'nextService' => 'Next service',
        'nextOilChange' => 'Next oil change',
        _ => k,
      };
  @override
  String presetHint(String k) => switch (k) {
        'cukaiTanah' => 'Est. 31 May. Varies by state. Confirm with your land office.',
        'cukaiPetak' => 'Est. 31 May. Until strata title is issued, your management office pays it.',
        'cukaiTaksiran' => 'Est.: first half due by end Feb, second by end Aug.',
        'houseInsurance' => 'You insure your own building. Pick the policy expiry date.',
        'maintenanceCharge' => 'Monthly, by share units. Pick the next due date.',
        'roadTax' => 'Pick the expiry date on your road tax.',
        'vehicleInsurance' => 'Pick the expiry date on your policy.',
        'nextService' => 'Repeats every 6 months. Add mileage later.',
        'nextOilChange' => 'Repeats every 3 months. Add mileage later.',
        _ => '',
      };
  @override
  String presetNote(String k) => switch (k) {
        'cukaiTanah' => '31 May is a common deadline, but it varies by state and year.',
        'cukaiPetak' => '31 May is a common deadline. If strata title is not issued yet, the management office pays for all owners.',
        'cukaiTaksiran' => 'Two halves a year, payable in January and July; in arrears after the end of February and the end of August.',
        _ => '',
      };
  @override
  String presetConfirm(String k) => switch (k) {
        'cukaiTaksiran' => 'your council',
        'cukaiPetak' => 'your land office or management office',
        _ => 'your land office',
      };

  // ------------------------------------------------ navigation
  @override
  String get today => 'Today';
  @override
  String get assetsTab => 'Assets';
  @override
  String get add => 'Add';
  @override
  String get documentsTab => 'Documents';
  @override
  String get moreTab => 'More';

  // ------------------------------------------------ today
  @override
  String get emptyTitle => 'Add your first asset';
  @override
  String get emptyBody => "A house, car or motorcycle. Kukira will show what's overdue and what's coming up, right here.";
  @override
  String get addFirstAsset => 'Add your first asset';
  @override
  String get offlineNote => 'Works offline. Your records stay on this phone.';
  @override
  String get notifOffBanner => 'Notifications are off. Reminders appear only when you open the app.';
  @override
  String get allowNotifications => 'Turn on notifications';
  @override
  String get notifDeniedHelp => 'Allow them in phone Settings > Apps > Kukira Asset > Notifications.';
  @override
  String get noBackupBanner => "You haven't made a backup yet. If this phone is lost, your records go with it.";
  @override
  String oldBackupBanner(String ago) => 'Last backup $ago. Records added since then are lost if this phone is lost.';
  @override
  String get backUpNow => 'Back up now';
  @override
  String get overdue => 'Overdue';
  @override
  String get nothingOverdue => 'Nothing overdue.';
  @override
  String get dueSoonTitle => 'Due soon · next 30 days';
  @override
  String get nothingSoon => 'Nothing due in the next 30 days.';
  @override
  String get recentlyDone => 'Recently completed';
  @override
  String get nothingDone => 'Nothing marked done in the last 30 days.';
  @override
  String doneAgo(String ago) => 'done $ago';
  @override
  String allReminders(int n) => 'All reminders ($n)';
  @override
  String updateOdoTitle(String name) => 'Update $name odometer';
  @override
  String get odoNever => 'Not recorded yet. Mileage reminders depend on it.';
  @override
  String odoLastUpdated(String ago) => 'Last updated $ago';

  // ------------------------------------------------ due text
  @override
  String snoozedUntil(String date) => 'Snoozed until $date';
  @override
  String dueAtKm(String km) => 'At $km';
  @override
  String kmPast(String over, String at) => '$over past $at';
  @override
  String kmToGo(String left, String at) => '$left to go · at $at';
  @override
  String kmLeft(String left) => '$left to go';
  @override
  String daysOverdue(int n, String date) => '$n day${n == 1 ? '' : 's'} overdue · was due $date';
  @override
  String get dueToday => 'Due today';
  @override
  String get dueTomorrow => 'Due tomorrow';
  @override
  String dueIn(String date, int n) => 'Due $date · in $n days';
  @override
  String whicheverFirst(String km, String date) => '$km or $date, whichever first';
  @override
  String get ruleOnce => 'One-off date';
  @override
  String ruleEveryMonths(int n, bool fromDue) =>
      'Every ${n == 1 ? 'month' : n == 12 ? 'year' : '$n months'}, counted from ${fromDue ? 'the previous due date' : 'when you mark it done'}';
  @override
  String ruleEveryKm(String km) => 'Every $km';
  @override
  String ruleEither(String km, int months) => 'Every $km or $months months, whichever comes first';
  @override
  String get oneOffDone => 'This was a one-off reminder, so nothing new was scheduled.';
  @override
  String nextOne(String what, bool fromDue) => 'Next one: $what (counted from ${fromDue ? 'the previous due date' : 'today'}).';
  @override
  String get orWord => ' or ';
  @override
  String get estShort => 'est.';

  // ------------------------------------------------ reminder sheet and form
  @override
  String get statusWord => 'Status';
  @override
  String get ruleWord => 'Rule';
  @override
  String get notifyWord => 'Notification';
  @override
  String get lastDoneWord => 'Last done';
  @override
  String estimatedNote(String note, String confirmWith) => 'Estimated date. $note Confirm with $confirmWith.';
  @override
  String get theAuthority => 'the relevant authority';
  @override
  String get markDone => 'Mark done';
  @override
  String get snooze => 'Snooze';
  @override
  String snoozeDays(int d) => d == 7 ? '1 week' : d == 1 ? '1 day' : '$d days';
  @override
  String snoozedMsg(String date) => "Snoozed until $date. You'll get a reminder that morning.";
  @override
  String get editReminder => 'Edit reminder';
  @override
  String get markedDone => 'Marked done';
  @override
  String get notNow => 'Not now';
  @override
  String get addCostDetails => 'Add cost and details';
  @override
  String get newReminder => 'New reminder';
  @override
  String get asset => 'Asset';
  @override
  String get startFromTemplate => 'Start from a template';
  @override
  String get title => 'Title';
  @override
  String get titleHint => 'What needs doing?';
  @override
  String get when => 'When';
  @override
  String get orByDate => 'Or by date';
  @override
  String get dueDate => 'Due date';
  @override
  String get every => 'Every';
  @override
  String get countFromDue => 'The next one is counted from the previous due date.';
  @override
  String get countFromDone => 'The next one is counted from the day you mark it done.';
  @override
  String get dueAtKmLabel => 'Due at (km)';
  @override
  String get everyKmLabel => 'Then every (km)';
  @override
  String get odoUnknown => 'No odometer reading yet. Update it on the vehicle page.';
  @override
  String odoNow(String km) => 'Odometer now: $km';
  @override
  String get remindKmBefore => 'Remind me before';
  @override
  String get remindMe => 'Remind me';
  @override
  String get saveReminder => 'Save reminder';
  @override
  String get saveChanges => 'Save changes';
  @override
  String get errTitle => 'Add a short title.';
  @override
  String get errDate => 'Pick a date.';
  @override
  String get errKm => 'Enter a km reading, or a repeat distance.';
  @override
  String get savedMileage => 'Saved. Mileage is checked each time you update the odometer.';
  @override
  String savedNotifyOn(String date) => "Reminder saved. You'll be notified on $date.";
  @override
  String updatedNotifyOn(String date) => 'Saved. Old notification cancelled; new one set for $date.';
  @override
  String get deleteReminderQ => 'Delete this reminder?';
  @override
  String get deleteReminderBody => 'Records linked to it are kept.';
  @override
  String get delete => 'Delete';
  @override
  String get addAssetFirst => 'Add an asset first. Everything else hangs off it.';

  // ------------------------------------------------ record form
  @override
  String get newRecord => 'New record';
  @override
  String get newDefect => 'New defect';
  @override
  String get kind => 'Kind';
  @override
  String get category => 'Category';
  @override
  String get whatDone => 'What was done';
  @override
  String get whatFound => 'What was found';
  @override
  String get recordHint => 'e.g. Replaced kitchen tap';
  @override
  String get defectHint => 'e.g. Crack above bedroom window';
  @override
  String get date => 'Date';
  @override
  String get area => 'Area';
  @override
  String get areaHint => 'e.g. Kitchen';
  @override
  String get totalCost => 'Total cost';
  @override
  String get alreadyReported => 'Already reported to the developer';
  @override
  String get madeClaim => 'I made an insurance claim';
  @override
  String get moreDetails => 'More details';
  @override
  String get workshop => 'Workshop';
  @override
  String get vendor => 'Vendor';
  @override
  String get odometerKm => 'Odometer (km)';
  @override
  String get warrantyEndLabel => 'Warranty ends';
  @override
  String get warrantyHelp => "We'll remind you a month before it ends.";
  @override
  String get notes => 'Notes';
  @override
  String linkedTo(String title) => 'Linked to “$title”, already marked done.';
  @override
  String looksLike(String title) => 'This looks like “$title”';
  @override
  String get markDoneAndNext => 'Mark it done and schedule the next one';
  @override
  String get saveRecord => 'Save record';
  @override
  String get saveDefect => 'Save defect';
  @override
  String get errDescription => 'Add a short description.';
  @override
  String get recordSaved => 'Record saved.';
  @override
  String get defectAdded => 'Defect added.';
  @override
  String alsoMarkedDone(String title, String? next) => '“$title” marked done${next == null ? '' : '; next $next'}.';
  @override
  String warrantyEnds(String title) => 'Warranty ends: $title';
  @override
  String get warrantyReminderAdded => 'Warranty reminder added.';

  // ------------------------------------------------ assets
  @override
  String get addAsset => 'Add asset';
  @override
  String get searchHint => 'Search assets, records, reminders';
  @override
  String get noMatch => 'No matches.';
  @override
  String get remindersTab => 'Reminders';
  @override
  String get recordsTitle => 'Records';
  @override
  String get noRemindersYet => 'No reminders yet.';
  @override
  String get nextLabel => 'Next';
  @override
  String dlpDaysLeftShort(int n) => 'DLP: $n days left to report defects';
  @override
  String get assetDeleted => 'This asset was deleted.';
  @override
  String get overviewTab => 'Overview';
  @override
  String get upkeepTab => 'Upkeep';
  @override
  String get defectsTab => 'Defects';
  @override
  String deleteAssetQ(String name) => 'Delete $name?';
  @override
  String get deleteAssetBody => 'All reminders and records for this asset are deleted too. This cannot be undone.';
  @override
  String get editDetails => 'Edit details';
  @override
  String get deleteAsset => 'Delete asset';
  @override
  String get propertyType => 'Property type';
  @override
  String get boughtAs => 'Bought';
  @override
  String get vpDate => 'Vacant possession (VP) date';
  @override
  String get vpHelp => 'From your VP letter. Used to estimate the defect liability period (DLP).';
  @override
  String get spaDate => 'Sale and purchase agreement (SPA) date';
  @override
  String get titleStatus => 'Title status';
  @override
  String get council => 'Council';
  @override
  String get councilHint => 'e.g. MBSA';
  @override
  String get state => 'State';
  @override
  String get occupancy => 'Occupancy';
  @override
  String get address => 'Address';
  @override
  String get contact => 'Contact (developer / JMB / MC)';
  @override
  String get contactHint => 'Name and phone number';
  @override
  String get nickname => 'Nickname';
  @override
  String get dlpTitle => 'Defect liability period';
  @override
  String get dlpDaysLeft => 'days left to report defects';
  @override
  String endsAbout(String date) => 'Ends about $date';
  @override
  String get dlpNote => 'Estimated: 24 months from vacant possession, as in the standard SPA for new homes. Confirm the date in your SPA.';
  @override
  String get dlpSubsaleNote => 'Subsale buyers may inherit the remaining warranty. Check with your lawyer.';
  @override
  String dlpEnded(String date) => 'The estimated DLP ended on $date. The defect list is hidden, but your records are kept.';
  @override
  String get addVpForDlp => 'Add the vacant possession (VP) date to see the DLP countdown and defect list.';
  @override
  String get strataInsuranceNote => 'For strata buildings, your JMB or MC insures the building. Check whether you need your own contents cover.';
  @override
  String get odoNotSet => 'Not recorded';
  @override
  String get odoAddFirst => 'Add the first reading';
  @override
  String get update => 'Update';
  @override
  String get vehicle => 'Vehicle';
  @override
  String get plate => 'Plate number';
  @override
  String get make => 'Make';
  @override
  String get model => 'Model';
  @override
  String get year => 'Year';
  @override
  String get roadTaxExpiry => 'Road tax expiry';
  @override
  String get insuranceExpiry => 'Insurance expiry';
  @override
  String get insurer => 'Insurer';
  @override
  String get policyNo => 'Policy no.';
  @override
  String get warranty => 'Warranty';
  @override
  String get warrantyUntil => 'Warranty until';
  @override
  String get warrantyKm => 'Warranty until (km)';
  @override
  String get chassisNo => 'Chassis no.';
  @override
  String get engineNo => 'Engine no.';
  @override
  String get notSet => 'Not set';
  @override
  String get yes => 'Yes';
  @override
  String get deleteRecordQ => 'Delete this record?';
  @override
  String get cannotUndo => 'This cannot be undone.';
  @override
  String spentThisYear(int year) => 'Spent in $year so far';
  @override
  String get noRecordsYet => 'No records yet.';
  @override
  String get addRecord => 'Add record';
  @override
  String get addReminder => 'Add reminder';
  @override
  String foundOn(String date) => 'found $date';
  @override
  String get notReportedYet => 'not reported yet';
  @override
  String reportedOn(String date) => 'reported $date';
  @override
  String get none => 'None.';
  @override
  String dlpDaysLeftEnds(String date) => 'days left · ends about $date';
  @override
  String get defectReportNote => 'Estimated. Report defects to your developer in writing before the DLP ends, and keep a copy.';
  @override
  String get defectOpen => 'Open';
  @override
  String get defectInProgress => 'Developer working on it';
  @override
  String get defectFixed => 'Fixed';
  @override
  String get addDefect => 'Add defect';
  @override
  String get reported => 'Reported';
  @override
  String get notYet => 'Not yet';
  @override
  String get markReportedToday => 'Mark reported to developer today';
  @override
  String get reportedToday => 'Marked as reported today. Keep your letter or email.';
  @override
  String odoDialogTitle(String name) => '$name odometer';
  @override
  String odoLast(String km, String ago) => 'Last: $km, $ago';
  @override
  String get odoCheckNote => 'Mileage reminders are checked when you save.';
  @override
  String odoTooLow(String km) => 'Enter a reading of at least $km.';
  @override
  String get save => 'Save';
  @override
  String get cancel => 'Cancel';
  @override
  String nowStatus(String title, String status) => '“$title” is now $status.';
  @override
  String odoSaved(String km) => 'Odometer saved: $km.';
  @override
  String mileageNoteTitle(String name) => 'Mileage reminder: $name';
  @override
  String get clear => 'Clear';
  @override
  String get pickDate => 'Pick a date';

  // ------------------------------------------------ add asset
  @override
  String get errNickname => 'Give it a name you will recognise.';
  @override
  String get errPlate => 'Add the plate number so you can tell vehicles apart.';
  @override
  String get errPickDates => 'Pick a date for each ticked reminder, or untick it.';
  @override
  String addedIn(String name, String time) => '$name added in $time.';
  @override
  String stepOf(int a, int b) => 'STEP $a OF $b';
  @override
  String get whatAdding => 'What are you adding?';
  @override
  String get onlyNameNeeded => 'Only a name is needed now. You can add more details later.';
  @override
  String nameYour(String c) => switch (c) { 'car' => 'Name your car', 'motorcycle' => 'Name your motorcycle', _ => 'Name your house' };
  @override
  String nicknameHint(String c) => switch (c) { 'car' => 'e.g. Myvi', 'motorcycle' => 'e.g. Y15', _ => 'e.g. Bangi house' };
  @override
  String get ptypeWhy => 'This decides which tax and insurance reminders we suggest.';
  @override
  String get back => 'Back';
  @override
  String get done => 'Done';
  @override
  String get optional => 'Optional';
  @override
  String get suggestedReminders => 'Suggested reminders';
  @override
  String get tickAndDate => 'Tick the ones you want. Each needs only a date.';
  @override
  String get skip => 'Skip';
  @override
  String saveN(int n) => n == 0 ? 'Save' : 'Save $n reminder${n == 1 ? '' : 's'}';
  @override
  String isSetUp(String name) => '$name is set up';
  @override
  String addedInKeepSafe(String time) => 'Added in $time. Two things keep your records safe:';
  @override
  String get notifications => 'Notifications';
  @override
  String get allowed => 'Allowed';
  @override
  String get notifPitch => 'Get a nudge before things are due';
  @override
  String get allow => 'Allow';
  @override
  String get backupFile => 'Backup file';
  @override
  String get backupPitch => 'Your data is only on this phone';
  @override
  String get backUp => 'Back up';
  @override
  String get goToToday => 'Go to Today';
  @override
  String get addAssetHint => 'House, car or motorcycle';
  @override
  String get record => 'Record';
  @override
  String get addRecordHint => 'Maintenance, repair, renovation, defect, payment';
  @override
  String get reminder => 'Reminder';
  @override
  String get addReminderHint => 'A date, a repeat or a mileage';
  @override
  String get document => 'Document';

  // ------------------------------------------------ more
  @override
  String get backupRestore => 'Backup and restore';
  @override
  String get noBackupYet => 'No backup yet';
  @override
  String lastBackupAgo(String ago) => 'Last backup $ago';
  @override
  String get healthCheck => 'Reminder health check';
  @override
  String get notifAllowed => 'Notifications allowed';
  @override
  String get notifNotAllowed => 'Notifications not allowed';
  @override
  String get allRemindersTitle => 'All reminders';
  @override
  String activeCount(int n) => '$n active';
  @override
  String get language => 'Language';
  @override
  String get appLock => 'App lock (PIN or fingerprint)';
  @override
  String get privacyAbout => 'Privacy and about';
  @override
  String get privacyShort => 'No account. No internet. No tracking.';
  @override
  String get all => 'All';
  @override
  String get notifPermission => 'Notification permission';
  @override
  String get notifNotAllowedLong => 'Not allowed. Reminders only show inside the app.';
  @override
  String get batteryTitle => 'Battery optimisation';
  @override
  String get batteryBody => 'Some phones stop reminders when the app is closed. In Settings > Apps > Kukira Asset > Battery, choose "Unrestricted".';
  @override
  String get lastRebuild => 'Schedule last rebuilt';
  @override
  String rebuildSummary(String time, int count) => 'Today, $time · $count notifications queued (up to 50)';
  @override
  String get nextNotification => 'Next notification';
  @override
  String get noneScheduled => 'None scheduled';
  @override
  String get sendTest => 'Send a test reminder';
  @override
  String get testNeedsPermission => "Notifications are off, so the test can't show. Allow them first.";
  @override
  String get rebuildNow => 'Rebuild the schedule now';
  @override
  String get rebuilt => 'Schedule rebuilt.';
  @override
  String get todayIsGuaranteed => "Phones can delay or drop notifications. The Today screen always shows what's overdue and due soon, so open it now and then.";

  // ------------------------------------------------ backup
  @override
  String get choosePassphrase => 'Choose a passphrase';
  @override
  String get passphraseIntro => 'The passphrase locks the backup file. It is separate from the app lock.';
  @override
  String get passphrase => 'Passphrase';
  @override
  String get passphraseHelp => 'At least 8 characters. A short sentence is easy to remember.';
  @override
  String get typeAgain => 'Type it again';
  @override
  String get passMismatch => 'The two passphrases are different.';
  @override
  String get forgetWarningAck => 'I understand: if I forget this passphrase, nobody can open this backup.';
  @override
  String get createFile => 'Create file';
  @override
  String get enterPassphrase => 'Enter passphrase';
  @override
  String get unlockFile => 'Unlock file';
  @override
  String get couldNotRead => "That file couldn't be read. Try choosing it again.";
  @override
  String get unlocking => 'Unlocking the file…';
  @override
  String get wrongPassphrase => "That passphrase doesn't open this file. Nothing on this phone was changed.";
  @override
  String get notABackup => 'This is not a Kukira backup file.';
  @override
  String get checkBeforeRestore => 'Check before restoring';
  @override
  String backupMadeOn(String date) => 'Backup made on $date.';
  @override
  String backupCounts(int a, int r, int rec, int d) => '$a assets · $r reminders · $rec records · $d documents';
  @override
  String restoreReplaces(String date) => 'Restoring replaces everything on this phone with the file. Anything added after $date will be lost.';
  @override
  String get replaceMyData => 'Replace my data';
  @override
  String get encrypting => 'Encrypting your records…';
  @override
  String get whereToSave => 'Where should the backup go?';
  @override
  String get shareToApp => 'Send to an app';
  @override
  String get shareToAppHint => 'Google Drive, email, WhatsApp to yourself';
  @override
  String get saveToFolder => 'Save in a phone folder';
  @override
  String get saveToFolderHint => 'Pick a folder, such as Downloads';
  @override
  String backupSaved(String name) => 'Backup saved: $name. Kukira never uploads it anywhere.';
  @override
  String get backupNotSaved => 'The backup was not saved.';
  @override
  String get restoring => 'Restoring…';
  @override
  String restoredFrom(String date) => 'Restored from the $date backup. Reminders rescheduled.';
  @override
  String get lastBackupLabel => 'Last backup';
  @override
  String get never => 'Never';
  @override
  String get backupExplainer => 'Your records live only on this phone. A backup file is the only way to move them to a new phone or get them back after a reset.';
  @override
  String get createBackup => 'Create backup file';
  @override
  String get restoreFromFile => 'Restore from backup file';
  @override
  String get passphraseWarning => 'The backup is locked with a passphrase you choose. If you forget it, nobody can open the file, including us.';
  @override
  String get phoneBackupNote => "Your phone's automatic backup does not include Kukira data. If you lose the phone or uninstall without a backup file, your records are gone.";
  @override
  String get backupNudgeNote => 'Kukira reminds you to back up every 30 days.';

  // ------------------------------------------------ about, documents, unreadable
  @override
  String get pNoAccount => 'No account';
  @override
  String get pNoAccountBody => 'You never sign up or log in.';
  @override
  String get pNoInternet => 'No internet needed';
  @override
  String get pNoInternetBody => 'Kukira does not ask for network access. Nothing is uploaded.';
  @override
  String get pEncrypted => 'Encrypted on your phone';
  @override
  String get pEncryptedBody => 'The database is encrypted. Backups go only where you send them.';
  @override
  String get pNoAds => 'No ads or analytics';
  @override
  String get pNoAdsBody => 'Nobody sees how you use the app.';
  @override
  String get legalDisclaimer => 'Tax, title and DLP dates in Kukira are estimates to help you plan. They are not legal advice. Confirm with your agreement, land office or council.';
  @override
  String get unreadableTitle => "We can't open your records on this phone";
  @override
  String get unreadableBody => 'The key that unlocks your records stays with the phone it was made on. This usually happens after moving to a new phone or restoring from a phone backup.\n\nIf you have a Kukira backup file, restore it now. You will need its passphrase.';
  @override
  String get startFresh => 'Start fresh instead';
  @override
  String get startFreshWarning => "The unreadable records won't come back in the app. Kukira sets them aside instead of deleting them, and they stay locked on this phone until you uninstall the app. Only do this if you have no backup file.";
  @override
  String get keepIt => 'Keep it';
  @override
  String get eraseAndStart => 'Start fresh';

  // ------------------------------------------------ notifications
  @override
  String get channelName => 'Reminders';
  @override
  String get channelDescription => 'Due-date reminders for your house and vehicles';
  @override
  String noteLead(String asset, String date) => '$asset · due $date';
  @override
  String noteDue(String asset) => '$asset · due today';
  @override
  String noteOverdue(String asset) => '$asset · now overdue. Open Kukira to mark it done or snooze.';
  @override
  String noteSnooze(String asset) => '$asset · snooze is over';
  @override
  String get backupNudgeTitle => 'Time for a backup';
  @override
  String get backupNudgeBody => 'Your Kukira records are only on this phone. Make a fresh backup file.';
  @override
  String get testNoteTitle => 'Test reminder';
  @override
  String get testNoteBody => 'Reminders from Kukira will look like this.';

  // ------------------------------------------------ 0.2
  @override
  String get aboutDocument => 'About this document';
  @override
  String get addDocumentHint => 'SPA, geran, VP letter, bills, receipts, policies';
  @override
  String get addItem => 'Add item';
  @override
  String get addVendor => 'Add vendor';
  @override
  String get added => 'Added';
  @override
  String get alsoFingerprintBody => 'You can open Kukira with your fingerprint. The PIN still works if the fingerprint fails.';
  @override
  String get alsoFingerprintQ => 'Use fingerprint too?';
  @override
  String get appLockSub => 'PIN or fingerprint';
  @override
  String get attach => 'Attach';
  @override
  String get attachDocument => 'Attach document';
  @override
  String get camera => 'Camera';
  @override
  String get changesSaved => 'Changes saved.';
  @override
  String get choosePin => 'Choose a 4-digit PIN';
  @override
  String get chooseSource => 'Where from?';
  @override
  String contactsCount(int n) => '$n contact${n == 1 ? '' : 's'}';
  @override
  String get copied => 'Copied.';
  @override
  String get copy => 'Copy';
  @override
  String get costBreakdown => 'Cost breakdown';
  @override
  String get couldNotOpen => 'Could not open your records. Try again.';
  @override
  String get couldNotSave => 'Could not save. Try again.';
  @override
  String get customRepeat => 'Custom';
  @override
  String daysShort(int n) => n == 0 ? 'Today' : '${n}d';
  @override
  String get daysWord => 'days';
  @override
  String get deleteDocBody => 'The file is deleted from this phone, with its expiry reminder.';
  @override
  String get deleteDocQ => 'Delete this document?';
  @override
  String get deleteVendorBody => 'Old records keep the vendor name.';
  @override
  String deleteVendorQ(String name) => 'Delete $name?';
  @override
  String dlpEndOverrideHelp(String date) => 'Leave empty to use the estimate ($date). Fill it in if your SPA says otherwise.';
  @override
  String get dlpEndOverrideLabel => 'DLP end date (if different)';
  @override
  String get dlpOverrideNote => 'You set this end date from your SPA.';
  @override
  String get dlpSetByYou => 'Set by you';
  @override
  String get docCopiedNote => 'The file is copied into Kukira and encrypted. The original stays where it was.';
  @override
  String docExpires(String title) => '$title expires';
  @override
  String get docSaved => 'Document saved.';
  @override
  String docSavedWithReminder(String date) => 'Document saved. Expiry reminder on $date.';
  @override
  String get docTitleHint => 'e.g. House insurance policy 2027';
  @override
  String get docType => 'Document type';
  @override
  String docTypeName(String t) => switch (t) { 'spa' => 'SPA', 'geran' => 'Geran', 'vp_letter' => 'VP letter', 'dlp' => 'DLP', 'tax_bill' => 'Tax bill', 'insurance' => 'Insurance', 'receipt' => 'Receipt', 'photo' => 'Photo', _ => 'Other' };
  @override
  String get docsPrivacyNote => 'Files are stored encrypted inside Kukira and open in your phone\'s own viewer.';
  @override
  String get dueSoonShort => 'Due soon';
  @override
  String get edit => 'Edit';
  @override
  String get editDefect => 'Edit defect';
  @override
  String get editDocument => 'Edit document';
  @override
  String get editRecord => 'Edit record';
  @override
  String get editVendor => 'Edit vendor';
  @override
  String get enterPin => 'Enter your PIN';
  @override
  String get errDocTitle => 'Add a title so you can find it later.';
  @override
  String get errRepeat => 'Enter how often it repeats.';
  @override
  String get expired => 'Expired';
  @override
  String expiresShort(String date) => 'Exp. $date';
  @override
  String get expiry => 'Expiry';
  @override
  String get expiryOptional => 'Expiry date (optional)';
  @override
  String get filesPdf => 'Files (PDF or image)';
  @override
  String get fingerprintFailed => 'Fingerprint could not be set up. Try again.';
  @override
  String get fingerprintSub => 'Open with fingerprint or face';
  @override
  String get fingerprintUnavailable => 'No fingerprint is enrolled on this phone';
  @override
  String get forgotPin => 'Forgot PIN?';
  @override
  String get forgotPinBody => 'The PIN cannot be recovered because it locks your records. Restore from a Kukira backup file (you need its passphrase), or start fresh.';
  @override
  String get forgotPinTitle => 'Forgot PIN';
  @override
  String get gallery => 'Gallery';
  @override
  String greeting(int hour) => hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
  @override
  String get item => 'Item';
  @override
  String get itemHint => 'e.g. Labour';
  @override
  String jobsCount(int n) => '$n job${n == 1 ? '' : 's'}';
  @override
  String get jobsTitle => 'Recorded jobs';
  @override
  String get labour => 'Labour';
  @override
  String get lockExplainer => 'The lock protects the key that opens your records, not just the screen. Kukira locks again after 2 minutes in the background.';
  @override
  String get lockFailed => 'The lock could not be turned on. Try again.';
  @override
  String get lockNow => 'Lock now';
  @override
  String get lockOff => 'App lock turned off.';
  @override
  String get lockOn => 'App lock is on.';
  @override
  String get lockWithPin => 'Lock with PIN';
  @override
  String get lockWithPinSub => 'Asked each time you open Kukira';
  @override
  String get lockedTitle => 'Kukira is locked';
  @override
  String get monthlyOdoReminder => 'Monthly odometer reminder';
  @override
  String get monthlyOdoReminderSub => 'Keeps mileage reminders accurate';
  @override
  String get noDocsBody => 'Keep your SPA, geran, VP letter, tax bills, insurance policies and receipts here, encrypted and readable offline.';
  @override
  String get noDocsForAsset => 'No documents yet.';
  @override
  String get noDocsTitle => 'No documents yet';
  @override
  String get noVendors => 'No vendors yet. Add the plumbers, workshops and contractors you trust.';
  @override
  String get noViewer => 'No app on this phone can open this file.';
  @override
  String notifyOnAt(String date, String time) => '$date, $time';
  @override
  String get notifyTime => 'Notification time';
  @override
  String get open => 'Open';
  @override
  String openDefectList(int n) => 'Open defect list ($n open)';
  @override
  String overdueCount(int n) => '$n overdue';
  @override
  String get parts => 'Parts';
  @override
  String get phone => 'Phone';
  @override
  String get photos => 'Photos';
  @override
  String photosCount(int n) => '$n photo${n == 1 ? '' : 's'}';
  @override
  String get pinAgain => 'Enter the PIN again';
  @override
  String get pinForgetNote => 'If you forget the PIN, your records can only come back from a backup file. Make a backup first.';
  @override
  String get pinMismatch => 'The PINs didn\'t match. Try again.';
  @override
  String get remindBeforeExpiry => 'Remind me a month before it expires';
  @override
  String get remove => 'Remove';
  @override
  String get removePhoto => 'Remove photo';
  @override
  String ruleEveryDays(int n, bool fromDue) => 'Every ${n % 7 == 0 ? (n == 7 ? 'week' : '${n ~/ 7} weeks') : '$n days'}, counted from ${fromDue ? 'the previous due date' : 'when you mark it done'}';
  @override
  String get saveDocument => 'Save document';
  @override
  String get saveToVendorBook => 'Save to vendor book';
  @override
  String get searchDocs => 'Search documents';
  @override
  String get securing => 'Securing your records…';
  @override
  String get shareCopy => 'Share a copy';
  @override
  String get splitCost => 'Split cost into items';
  @override
  String tooManyTries(int sec) => 'Too many tries. Try again in $sec seconds.';
  @override
  String get trade => 'Trade';
  @override
  String tradeName(String t) => switch (t) { 'plumbing' => 'Plumbing', 'electrical' => 'Electrical', 'aircond' => 'Aircond', 'renovation' => 'Renovation', 'pest_control' => 'Pest control', 'roof' => 'Roof', 'cleaning' => 'Cleaning', 'workshop' => 'Workshop', 'tyre' => 'Tyres', 'insurance' => 'Insurance', _ => 'Other' };
  @override
  String unitName(String u) => switch (u) { 'day' => 'days', 'week' => 'weeks', 'year' => 'years', _ => 'months' };
  @override
  String get unlockTitle => 'Unlock Kukira';
  @override
  String get updateOdometer => 'Update odometer';
  @override
  String get useFingerprint => 'Use fingerprint';
  @override
  String get usePin => 'Use PIN';
  @override
  String get useSingleTotal => 'Use a single total';
  @override
  String get vendorBook => 'Vendor book';
  @override
  String get vendorName => 'Name';
  @override
  String get vendorPickHint => 'Pick from the vendor book or type a new name';
  @override
  String get wrongPin => 'Wrong PIN.';
  @override
  String get yesUseIt => 'Yes, use it';

  // ------------------------------------------------ 0.2.1 linked reminders
  @override
  String autoCreated(String title, String date) => 'Reminder added: “$title” on $date.';
  @override
  String autoFieldName(String source) => switch (source) { 'roadTax' => 'the road tax expiry date', 'insurance' => 'the insurance expiry date', _ => 'the DLP end date' };
  @override
  String autoKept(String title) => '“$title” was left as it was.';
  @override
  String autoLinkedNote(String field) => 'This reminder follows $field. Change that date on the asset page.';
  @override
  String autoRemoved(String title) => 'Reminder removed: “$title”.';
  @override
  String get autoSyncNoteDlp => 'A “report defects” reminder follows the DLP end date automatically.';
  @override
  String get autoSyncNoteVehicle => 'Road tax and insurance reminders follow these dates automatically. Clear a date to remove its reminder.';
  @override
  String autoUpdated(String title, String date) => 'Reminder updated: “$title” is now due $date.';
  @override
  String conflictReopen(String title, String date) => '“$title” is marked done. Updating reopens it for $date.';
  @override
  String conflictSnooze(String title, String until, String date) => '“$title” is snoozed until $until. Updating clears the snooze and sets it for $date.';
  @override
  String get conflictTitle => 'Update linked reminders?';
  @override
  String get dlpAutoNote => 'Estimated end of the defect liability period.';
  @override
  String get dlpReminderTitle => 'Report defects before DLP ends';
  @override
  String get keepAsIs => 'Keep as they are';
  @override
  String get updateReminders => 'Update reminders';
  @override
  String get yourSpa => 'your SPA';

  // ------------------------------------------------ 0.2.1 house form
  @override
  String get allSuggestedAdded => 'All suggested reminders are already added.';
  @override
  String get suggestedForType => 'Suggested reminders for this property type';
  @override
  String get vpDateSubsale => 'Original VP date (if still within DLP)';
  @override
  String get vpHelpSubsale => 'From the first owner\'s VP letter. A subsale buyer may still be inside the developer\'s 24-month DLP. Leave it empty if unknown.';

  // ------------------------------------------------ 0.2.1 version
  @override
  String aboutVersion(String version, String build) => 'Kukira Asset $version (build $build) · test build';

  // ------------------------------------------------ unreadable database
  @override
  String get secureStorageError => "The phone's secure storage couldn't be read, so nothing was changed. Restart the phone and try again.";

  // ------------------------------------------------ backup schema
  @override
  String backupSavedMissing(String name, int n) => 'Backup saved: $name. But some documents or photos ($n) could not be read and are not in this backup. Check the Documents tab.';
  @override
  String get backupTooNew => 'This backup was made by a newer version of Kukira. Update this app first, then restore it again. Nothing was changed.';

  // ------------------------------------------------ restore
  @override
  String get restoreFailed => "The backup couldn't be restored, so nothing from it was applied. The records on this phone are as they were.";
}
