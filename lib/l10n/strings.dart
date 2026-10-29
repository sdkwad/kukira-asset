// All user-facing text. Bahasa Melayu is the default; English is the second language.
// To add a language, add a class that extends Str and register it in strFor().

import '../domain/rules.dart';
import 'strings_en.dart';
import 'strings_ms.dart';

Str strFor(String lang) => lang == 'en' ? const StrEn() : const StrMs();

abstract class Str {
  const Str();

  // ------------------------------------------------ formatting
  List<String> get monthsShort;
  List<String> get weekdays; // Monday first
  String get thousands => ',';

  String dShort(DateTime d) => d.year == DateTime.now().year ? '${d.day} ${monthsShort[d.month - 1]}' : dLong(d);
  String dLong(DateTime d) => '${d.day} ${monthsShort[d.month - 1]} ${d.year}';
  String weekdayDate(DateTime d) => '${weekdays[d.weekday - 1]}, ${dLong(d)}';
  String hm(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  String timeOfDay(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _group(int n) {
    final str = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) b.write(thousands);
      b.write(str[i]);
    }
    return (n < 0 ? '-' : '') + b.toString();
  }

  String km(int n) => '${_group(n)} km';
  String rm(double v) {
    final cents = (v * 100).round();
    return 'RM ${_group(cents ~/ 100)}.${(cents % 100).abs().toString().padLeft(2, '0')}';
  }

  String ago(DateTime d) {
    final n = daysBetween(d, DateTime.now());
    return n <= 0 ? agoToday : n == 1 ? agoYesterday : agoDays(n);
  }

  String get agoToday;
  String get agoYesterday;
  String agoDays(int n);

  // ------------------------------------------------ names
  String statusLabel(RStatus st);
  String ruleName(String rule);
  String kindName(String kind);
  String catName(String cat);
  String categoryName(String category);
  String categoryHint(String category);
  String ptypeName(String p);
  String ptypeHint(String p);
  String sourceName(String v);
  String titleName(String v);
  String occupancyName(String v);
  String conditionName(String v);
  String defectStatusName(String v);
  String leadLabel(int days);
  String monthsLabel(int months);
  String presetTitle(String key);
  String presetHint(String key);
  String presetNote(String key);
  String presetConfirm(String key);

  // ------------------------------------------------ navigation
  String get today;
  String get assetsTab;
  String get add;
  String get documentsTab;
  String get moreTab;

  // ------------------------------------------------ today
  String get emptyTitle;
  String get emptyBody;
  String get addFirstAsset;
  String get offlineNote;
  String get notifOffBanner;
  String get allowNotifications;
  String get notifDeniedHelp;
  String get noBackupBanner;
  String oldBackupBanner(String ago);
  String get backUpNow;
  String get overdue;
  String get nothingOverdue;
  String get dueSoonTitle;
  String get nothingSoon;
  String get recentlyDone;
  String get nothingDone;
  String doneAgo(String ago);
  String allReminders(int n);
  String updateOdoTitle(String name);
  String get odoNever;
  String odoLastUpdated(String ago);

  // ------------------------------------------------ due text
  String snoozedUntil(String date);
  String dueAtKm(String km);
  String kmPast(String over, String at);
  String kmToGo(String left, String at);
  String kmLeft(String left);
  String daysOverdue(int n, String date);
  String get dueToday;
  String get dueTomorrow;
  String dueIn(String date, int n);
  String whicheverFirst(String km, String date);
  String get ruleOnce;
  String ruleEveryMonths(int n, bool fromDue);
  String ruleEveryKm(String km);
  String ruleEither(String km, int months);
  String get oneOffDone;
  String nextOne(String what, bool fromDue);
  String get orWord;
  String get estShort;

  // ------------------------------------------------ reminder sheet and form
  String get statusWord;
  String get ruleWord;
  String get notifyWord;
  String get lastDoneWord;
  String estimatedNote(String note, String confirmWith);
  String get theAuthority;
  String get markDone;
  String get snooze;
  String snoozeDays(int d);
  String snoozedMsg(String date);
  String get editReminder;
  String get markedDone;
  String get notNow;
  String get addCostDetails;
  String get newReminder;
  String get asset;
  String get startFromTemplate;
  String get title;
  String get titleHint;
  String get when;
  String get orByDate;
  String get dueDate;
  String get every;
  String get countFromDue;
  String get countFromDone;
  String get dueAtKmLabel;
  String get everyKmLabel;
  String get odoUnknown;
  String odoNow(String km);
  String get remindKmBefore;
  String get remindMe;
  String get saveReminder;
  String get saveChanges;
  String get errTitle;
  String get errDate;
  String get errKm;
  String get savedMileage;
  String savedNotifyOn(String date);
  String updatedNotifyOn(String date);
  String get deleteReminderQ;
  String get deleteReminderBody;
  String get delete;
  String get addAssetFirst;

  // ------------------------------------------------ record form
  String get newRecord;
  String get newDefect;
  String get kind;
  String get category;
  String get whatDone;
  String get whatFound;
  String get recordHint;
  String get defectHint;
  String get date;
  String get area;
  String get areaHint;
  String get totalCost;
  String get alreadyReported;
  String get madeClaim;
  String get moreDetails;
  String get workshop;
  String get vendor;
  String get odometerKm;
  String get warrantyEndLabel;
  String get warrantyHelp;
  String get notes;
  String linkedTo(String title);
  String looksLike(String title);
  String get markDoneAndNext;
  String get saveRecord;
  String get saveDefect;
  String get errDescription;
  String get recordSaved;
  String get defectAdded;
  String alsoMarkedDone(String title, String? next);
  String warrantyEnds(String title);
  String get warrantyReminderAdded;

  // ------------------------------------------------ assets
  String get addAsset;
  String get searchHint;
  String get noMatch;
  String get remindersTab;
  String get recordsTitle;
  String get noRemindersYet;
  String get nextLabel;
  String dlpDaysLeftShort(int n);
  String get assetDeleted;
  String get overviewTab;
  String get upkeepTab;
  String get defectsTab;
  String deleteAssetQ(String name);
  String get deleteAssetBody;
  String get editDetails;
  String get deleteAsset;
  String get propertyType;
  String get boughtAs;
  String get vpDate;
  String get vpHelp;
  String get spaDate;
  String get titleStatus;
  String get council;
  String get councilHint;
  String get state;
  String get occupancy;
  String get address;
  String get contact;
  String get contactHint;
  String get nickname;
  String get dlpTitle;
  String get dlpDaysLeft;
  String endsAbout(String date);
  String get dlpNote;
  String get dlpSubsaleNote;
  String dlpEnded(String date);
  String get addVpForDlp;
  String get strataInsuranceNote;
  String get odoNotSet;
  String get odoAddFirst;
  String get update;
  String get vehicle;
  String get plate;
  String get make;
  String get model;
  String get year;
  String get roadTaxExpiry;
  String get insuranceExpiry;
  String get insurer;
  String get policyNo;
  String get warranty;
  String get warrantyUntil;
  String get warrantyKm;
  String get chassisNo;
  String get engineNo;
  String get notSet;
  String get yes;
  String get deleteRecordQ;
  String get cannotUndo;
  String spentThisYear(int year);
  String get noRecordsYet;
  String get addRecord;
  String get addReminder;
  String foundOn(String date);
  String get notReportedYet;
  String reportedOn(String date);
  String get none;
  String dlpDaysLeftEnds(String date);
  String get defectReportNote;
  String get defectOpen;
  String get defectInProgress;
  String get defectFixed;
  String get addDefect;
  String get reported;
  String get notYet;
  String get markReportedToday;
  String get reportedToday;
  String odoDialogTitle(String name);
  String odoLast(String km, String ago);
  String get odoCheckNote;
  String odoTooLow(String km);
  String get save;
  String get cancel;
  String nowStatus(String title, String status);
  String odoSaved(String km);
  String mileageNoteTitle(String name);
  String get clear;
  String get pickDate;

  // ------------------------------------------------ add asset
  String get errNickname;
  String get errPlate;
  String get errPickDates;
  String addedIn(String name, String time);
  String stepOf(int a, int b);
  String get whatAdding;
  String get onlyNameNeeded;
  String nameYour(String category);
  String nicknameHint(String category);
  String get ptypeWhy;
  String get back;
  String get done;
  String get optional;
  String get suggestedReminders;
  String get tickAndDate;
  String get skip;
  String saveN(int n);
  String isSetUp(String name);
  String addedInKeepSafe(String time);
  String get notifications;
  String get allowed;
  String get notifPitch;
  String get allow;
  String get backupFile;
  String get backupPitch;
  String get backUp;
  String get goToToday;
  String get addAssetHint;
  String get record;
  String get addRecordHint;
  String get reminder;
  String get addReminderHint;
  String get document;

  // ------------------------------------------------ more
  String get backupRestore;
  String get noBackupYet;
  String lastBackupAgo(String ago);
  String get healthCheck;
  String get notifAllowed;
  String get notifNotAllowed;
  String get allRemindersTitle;
  String activeCount(int n);
  String get language;
  String get appLock;
  String get privacyAbout;
  String get privacyShort;
  String get all;
  String get notifPermission;
  String get notifNotAllowedLong;
  String get batteryTitle;
  String get batteryBody;
  String get lastRebuild;
  String rebuildSummary(String time, int count);
  String get nextNotification;
  String get noneScheduled;
  String get sendTest;
  String get testNeedsPermission;
  String get rebuildNow;
  String get rebuilt;
  String get todayIsGuaranteed;

  // ------------------------------------------------ backup
  String get choosePassphrase;
  String get passphraseIntro;
  String get passphrase;
  String get passphraseHelp;
  String get typeAgain;
  String get passMismatch;
  String get forgetWarningAck;
  String get createFile;
  String get enterPassphrase;
  String get unlockFile;
  String get couldNotRead;
  String get unlocking;
  String get wrongPassphrase;
  String get notABackup;
  String get checkBeforeRestore;
  String backupMadeOn(String date);
  String backupCounts(int assets, int reminders, int records, int documents);
  String restoreReplaces(String date);
  String get replaceMyData;
  String get encrypting;
  String get whereToSave;
  String get shareToApp;
  String get shareToAppHint;
  String get saveToFolder;
  String get saveToFolderHint;
  String backupSaved(String name);
  String get backupNotSaved;
  String get restoring;
  String restoredFrom(String date);
  String get lastBackupLabel;
  String get never;
  String get backupExplainer;
  String get createBackup;
  String get restoreFromFile;
  String get passphraseWarning;
  String get phoneBackupNote;
  String get backupNudgeNote;

  // ------------------------------------------------ about, documents, unreadable
  String get pNoAccount;
  String get pNoAccountBody;
  String get pNoInternet;
  String get pNoInternetBody;
  String get pEncrypted;
  String get pEncryptedBody;
  String get pNoAds;
  String get pNoAdsBody;
  String get legalDisclaimer;
  String get unreadableTitle;
  String get unreadableBody;
  String get startFresh;
  String get startFreshWarning;
  String get keepIt;
  String get eraseAndStart;

  // ------------------------------------------------ notifications
  String get channelName;
  String get channelDescription;
  String noteLead(String asset, String date);
  String noteDue(String asset);
  String noteOverdue(String asset);
  String noteSnooze(String asset);
  String get backupNudgeTitle;
  String get backupNudgeBody;
  String get testNoteTitle;
  String get testNoteBody;

  // ------------------------------------------------ 0.2
  String get aboutDocument;
  String get addDocumentHint;
  String get addItem;
  String get addVendor;
  String get added;
  String get alsoFingerprintBody;
  String get alsoFingerprintQ;
  String get appLockSub;
  String get attach;
  String get attachDocument;
  String get camera;
  String get changesSaved;
  String get choosePin;
  String get chooseSource;
  String contactsCount(int n);
  String get copied;
  String get copy;
  String get costBreakdown;
  String get couldNotOpen;
  String get couldNotSave;
  String get customRepeat;
  String daysShort(int n);
  String get daysWord;
  String get deleteDocBody;
  String get deleteDocQ;
  String get deleteVendorBody;
  String deleteVendorQ(String name);
  String dlpEndOverrideHelp(String date);
  String get dlpEndOverrideLabel;
  String get dlpOverrideNote;
  String get dlpSetByYou;
  String get docCopiedNote;
  String docExpires(String title);
  String get docSaved;
  String docSavedWithReminder(String date);
  String get docTitleHint;
  String get docType;
  String docTypeName(String t);
  String get docsPrivacyNote;
  String get dueSoonShort;
  String get edit;
  String get editDefect;
  String get editDocument;
  String get editRecord;
  String get editVendor;
  String get enterPin;
  String get errDocTitle;
  String get errRepeat;
  String get expired;
  String expiresShort(String date);
  String get expiry;
  String get expiryOptional;
  String get filesPdf;
  String get fingerprintFailed;
  String get fingerprintSub;
  String get fingerprintUnavailable;
  String get forgotPin;
  String get forgotPinBody;
  String get forgotPinTitle;
  String get gallery;
  String greeting(int hour);
  String get item;
  String get itemHint;
  String jobsCount(int n);
  String get jobsTitle;
  String get labour;
  String get lockExplainer;
  String get lockFailed;
  String get lockNow;
  String get lockOff;
  String get lockOn;
  String get lockWithPin;
  String get lockWithPinSub;
  String get lockedTitle;
  String get monthlyOdoReminder;
  String get monthlyOdoReminderSub;
  String get noDocsBody;
  String get noDocsForAsset;
  String get noDocsTitle;
  String get noVendors;
  String get noViewer;
  String notifyOnAt(String date, String time);
  String get notifyTime;
  String get open;
  String openDefectList(int n);
  String overdueCount(int n);
  String get parts;
  String get phone;
  String get photos;
  String photosCount(int n);
  String get pinAgain;
  String get pinForgetNote;
  String get pinMismatch;
  String get remindBeforeExpiry;
  String get remove;
  String get removePhoto;
  String ruleEveryDays(int n, bool fromDue);
  String get saveDocument;
  String get saveToVendorBook;
  String get searchDocs;
  String get securing;
  String get shareCopy;
  String get splitCost;
  String tooManyTries(int sec);
  String get trade;
  String tradeName(String t);
  String unitName(String u);
  String get unlockTitle;
  String get updateOdometer;
  String get useFingerprint;
  String get usePin;
  String get useSingleTotal;
  String get vendorBook;
  String get vendorName;
  String get vendorPickHint;
  String get wrongPin;
  String get yesUseIt;

  // ------------------------------------------------ 0.2.1 linked reminders
  String autoCreated(String title, String date);
  String autoFieldName(String source);
  String autoKept(String title);
  String autoLinkedNote(String field);
  String autoRemoved(String title);
  String get autoSyncNoteDlp;
  String get autoSyncNoteVehicle;
  String autoUpdated(String title, String date);
  String conflictReopen(String title, String date);
  String conflictSnooze(String title, String until, String date);
  String get conflictTitle;
  String get dlpAutoNote;
  String get dlpReminderTitle;
  String get keepAsIs;
  String get updateReminders;
  String get yourSpa;

  // ------------------------------------------------ 0.2.1 house form
  String get allSuggestedAdded;
  String get suggestedForType;
  String get vpDateSubsale;
  String get vpHelpSubsale;

  // ------------------------------------------------ 0.2.1 version
  String aboutVersion(String version, String build);

  // ------------------------------------------------ unreadable database
  String get secureStorageError;

  // ------------------------------------------------ backup schema
  String backupSavedMissing(String name, int n);
  String get backupTooNew;
}
