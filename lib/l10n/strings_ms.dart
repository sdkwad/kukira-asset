import '../domain/rules.dart';
import 'strings.dart';

class StrMs extends Str {
  const StrMs();

  @override
  List<String> get monthsShort => const ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ogo', 'Sep', 'Okt', 'Nov', 'Dis'];
  @override
  List<String> get weekdays => const ['Isnin', 'Selasa', 'Rabu', 'Khamis', 'Jumaat', 'Sabtu', 'Ahad'];
  @override
  String get agoToday => 'hari ini';
  @override
  String get agoYesterday => 'semalam';
  @override
  String agoDays(int n) => '$n hari lalu';

  // ------------------------------------------------ names
  @override
  String statusLabel(RStatus st) => switch (st) {
        RStatus.overdue => 'Lewat',
        RStatus.dueSoon => 'Hampir tiba',
        RStatus.upcoming => 'Akan datang',
        RStatus.done => 'Selesai',
      };
  @override
  String ruleName(String rule) => switch (rule) {
        'fixed' => 'Satu tarikh',
        'repeat' => 'Berulang',
        'mileage' => 'Ikut jarak',
        _ => 'Mana dulu',
      };
  @override
  String kindName(String kind) => switch (kind) {
        'maintenance' => 'Penyelenggaraan',
        'renovation' => 'Ubah suai',
        'incident' => 'Insiden',
        'defect' => 'Kecacatan',
        'payment' => 'Bayaran',
        _ => kind,
      };
  @override
  String catName(String cat) => switch (cat) {
        'plumbing' => 'Paip',
        'bathroom' => 'Tandas/bilik air',
        'roof' => 'Bumbung',
        'leakage' => 'Bocor/kalis air',
        'electrical' => 'Elektrik',
        'aircond' => 'Penghawa dingin',
        'painting' => 'Cat',
        'pest_control' => 'Kawalan perosak',
        'appliance' => 'Perkakas',
        'minor' => 'Kecil',
        'major' => 'Besar',
        'leak' => 'Bocor',
        'fire' => 'Kebakaran',
        'flood' => 'Banjir',
        'break_in' => 'Pecah masuk',
        'structural' => 'Struktur',
        'wall_crack' => 'Dinding/retak',
        'floor_tiles' => 'Lantai/jubin',
        'door_window' => 'Pintu/tingkap',
        'cukai_tanah' => 'Cukai tanah',
        'cukai_petak' => 'Cukai petak',
        'cukai_taksiran' => 'Cukai taksiran',
        'maintenance_charge' => 'Caj penyelenggaraan',
        'sinking_fund' => 'Kumpulan wang penjelas',
        'insurance_premium' => 'Premium insurans',
        'accident' => 'Kemalangan',
        'theft' => 'Kecurian',
        'oil' => 'Minyak enjin',
        'filter' => 'Penapis',
        'brake' => 'Brek',
        'tyre' => 'Tayar',
        'battery' => 'Bateri',
        'belt' => 'Tali sawat',
        'chain_sprocket' => 'Rantai/sproket',
        'road_tax' => 'Cukai jalan',
        _ => 'Lain-lain',
      };
  @override
  String categoryName(String c) => switch (c) { 'car' => 'Kereta', 'motorcycle' => 'Motosikal', _ => 'Rumah' };
  @override
  String categoryHint(String c) => switch (c) {
        'car' => 'Cukai jalan, insurans, servis',
        'motorcycle' => 'Cukai jalan, insurans, tukar minyak',
        _ => 'Cukai, DLP, kecacatan, penyelenggaraan',
      };
  @override
  String ptypeName(String p) => switch (p) { 'strata' => 'Strata', 'strata_landed' => 'Strata bertanah', _ => 'Bertanah' };
  @override
  String ptypeHint(String p) => switch (p) {
        'strata' => 'Kondo atau pangsapuri dengan JMB atau MC',
        'strata_landed' => 'Rumah bertanah berpagar dengan hakmilik strata',
        _ => 'Teres, berkembar, banglo dengan geran sendiri',
      };
  @override
  String sourceName(String v) => v == 'subsale' ? 'Subsale' : 'Baharu dari pemaju';
  @override
  String titleName(String v) => switch (v) { 'master' => 'Hakmilik induk', 'strata_issued' => 'Hakmilik strata dikeluarkan', _ => 'Hakmilik individu' };
  @override
  String occupancyName(String v) => switch (v) { 'rented' => 'Disewakan', 'vacant' => 'Kosong', _ => 'Diduduki sendiri' };
  @override
  String conditionName(String v) => v == 'second_hand' ? 'Terpakai' : 'Baharu';
  @override
  String defectStatusName(String v) => switch (v) { 'in_progress' => 'Pemaju sedang baiki', 'done' => 'Sudah dibaiki', _ => 'Belum selesai' };
  @override
  String leadLabel(int d) => switch (d) {
        0 => 'Pada hari itu',
        7 => '1 minggu sebelum',
        14 => '2 minggu sebelum',
        30 => '1 bulan sebelum',
        _ => '$d hari sebelum',
      };
  @override
  String monthsLabel(int m) => switch (m) { 1 => 'Sebulan', 12 => 'Setahun', _ => '$m bulan' };
  @override
  String presetTitle(String k) => switch (k) {
        'cukaiTanah' => 'Cukai tanah',
        'cukaiPetak' => 'Cukai petak',
        'cukaiTaksiran' => 'Cukai taksiran',
        'houseInsurance' => 'Pembaharuan insurans rumah',
        'maintenanceCharge' => 'Caj penyelenggaraan & kumpulan wang penjelas',
        'aircond' => 'Servis penghawa dingin',
        'pestControl' => 'Kawalan perosak',
        'waterTank' => 'Cuci tangki air',
        'roadTax' => 'Pembaharuan cukai jalan',
        'vehicleInsurance' => 'Insurans tamat',
        'carService' => 'Servis kereta',
        'motoOil' => 'Tukar minyak enjin',
        'tyres' => 'Tukar tayar',
        'battery' => 'Periksa bateri',
        'chain' => 'Periksa rantai & sproket',
        'nextService' => 'Servis seterusnya',
        'nextOilChange' => 'Tukar minyak seterusnya',
        _ => k,
      };
  @override
  String presetHint(String k) => switch (k) {
        'cukaiTanah' => 'Anggaran 31 Mei. Berbeza ikut negeri. Sahkan dengan pejabat tanah.',
        'cukaiPetak' => 'Anggaran 31 Mei. Selagi hakmilik strata belum dikeluarkan, pejabat pengurusan yang bayar.',
        'cukaiTaksiran' => 'Anggaran: separuh tahun pertama sebelum hujung Feb, kedua sebelum hujung Ogos.',
        'houseInsurance' => 'Anda insuranskan bangunan sendiri. Pilih tarikh tamat polisi.',
        'maintenanceCharge' => 'Bulanan, ikut unit syer. Pilih tarikh bayaran seterusnya.',
        'roadTax' => 'Pilih tarikh tamat cukai jalan anda.',
        'vehicleInsurance' => 'Pilih tarikh tamat polisi anda.',
        'nextService' => 'Berulang setiap 6 bulan. Tambah jarak kemudian.',
        'nextOilChange' => 'Berulang setiap 3 bulan. Tambah jarak kemudian.',
        _ => '',
      };
  @override
  String presetNote(String k) => switch (k) {
        'cukaiTanah' => '31 Mei ialah tarikh akhir biasa, tetapi berbeza ikut negeri dan tahun.',
        'cukaiPetak' => '31 Mei ialah tarikh akhir biasa. Jika hakmilik strata belum dikeluarkan, pejabat pengurusan membayar bagi semua pemilik.',
        'cukaiTaksiran' => 'Dua kali setahun, dibayar Januari dan Julai; tunggakan selepas hujung Februari dan hujung Ogos.',
        _ => '',
      };
  @override
  String presetConfirm(String k) => switch (k) {
        'cukaiTaksiran' => 'PBT (majlis) anda',
        'cukaiPetak' => 'pejabat tanah atau pejabat pengurusan anda',
        _ => 'pejabat tanah anda',
      };

  // ------------------------------------------------ navigation
  @override
  String get today => 'Hari ini';
  @override
  String get assetsTab => 'Aset';
  @override
  String get add => 'Tambah';
  @override
  String get documentsTab => 'Dokumen';
  @override
  String get moreTab => 'Lagi';

  // ------------------------------------------------ today
  @override
  String get emptyTitle => 'Tambah aset pertama anda';
  @override
  String get emptyBody => 'Rumah, kereta atau motosikal. Kukira akan tunjuk apa yang lewat dan apa yang hampir tiba, di sini.';
  @override
  String get addFirstAsset => 'Tambah aset pertama';
  @override
  String get offlineNote => 'Berfungsi tanpa internet. Rekod anda kekal dalam telefon ini.';
  @override
  String get notifOffBanner => 'Pemberitahuan dimatikan. Peringatan hanya muncul apabila anda buka app.';
  @override
  String get allowNotifications => 'Hidupkan pemberitahuan';
  @override
  String get notifDeniedHelp => 'Benarkan dalam Tetapan telefon > Apl > Kukira Asset > Pemberitahuan.';
  @override
  String get noBackupBanner => 'Anda belum buat sandaran. Jika telefon hilang, rekod anda turut hilang.';
  @override
  String oldBackupBanner(String ago) => 'Sandaran terakhir $ago. Rekod selepas itu akan hilang jika telefon hilang.';
  @override
  String get backUpNow => 'Buat sandaran sekarang';
  @override
  String get overdue => 'Lewat';
  @override
  String get nothingOverdue => 'Tiada yang lewat.';
  @override
  String get dueSoonTitle => 'Hampir tiba · 30 hari';
  @override
  String get nothingSoon => 'Tiada apa dalam 30 hari akan datang.';
  @override
  String get recentlyDone => 'Baru selesai';
  @override
  String get nothingDone => 'Tiada yang ditanda selesai dalam 30 hari lalu.';
  @override
  String doneAgo(String ago) => 'selesai $ago';
  @override
  String allReminders(int n) => 'Semua peringatan ($n)';
  @override
  String updateOdoTitle(String name) => 'Kemas kini odometer $name';
  @override
  String get odoNever => 'Belum direkod. Peringatan ikut jarak bergantung padanya.';
  @override
  String odoLastUpdated(String ago) => 'Kemas kini terakhir $ago';

  // ------------------------------------------------ due text
  @override
  String snoozedUntil(String date) => 'Ditunda hingga $date';
  @override
  String dueAtKm(String km) => 'Pada $km';
  @override
  String kmPast(String over, String at) => 'Lebih $over dari $at';
  @override
  String kmToGo(String left, String at) => '$left lagi · pada $at';
  @override
  String kmLeft(String left) => '$left lagi';
  @override
  String daysOverdue(int n, String date) => 'Lewat $n hari · tarikh $date';
  @override
  String get dueToday => 'Hari ini';
  @override
  String get dueTomorrow => 'Esok';
  @override
  String dueIn(String date, int n) => '$date · $n hari lagi';
  @override
  String whicheverFirst(String km, String date) => '$km atau $date, mana dulu';
  @override
  String get ruleOnce => 'Satu tarikh sahaja';
  @override
  String ruleEveryMonths(int n, bool fromDue) =>
      '${n == 1 ? 'Setiap bulan' : n == 12 ? 'Setiap tahun' : 'Setiap $n bulan'}, dikira dari ${fromDue ? 'tarikh akhir sebelumnya' : 'hari anda tandakan selesai'}';
  @override
  String ruleEveryKm(String km) => 'Setiap $km';
  @override
  String ruleEither(String km, int months) => 'Setiap $km atau $months bulan, mana dulu';
  @override
  String get oneOffDone => 'Ini peringatan sekali sahaja, jadi tiada yang baharu dijadualkan.';
  @override
  String nextOne(String what, bool fromDue) => 'Seterusnya: $what (dikira dari ${fromDue ? 'tarikh akhir sebelumnya' : 'hari ini'}).';
  @override
  String get orWord => ' atau ';
  @override
  String get estShort => 'anggaran';

  // ------------------------------------------------ reminder sheet and form
  @override
  String get statusWord => 'Status';
  @override
  String get ruleWord => 'Peraturan';
  @override
  String get notifyWord => 'Pemberitahuan';
  @override
  String notifyOn(String date) => '$date, 9:00 pagi';
  @override
  String get lastDoneWord => 'Terakhir selesai';
  @override
  String estimatedNote(String note, String confirmWith) => 'Tarikh anggaran. $note Sahkan dengan $confirmWith.';
  @override
  String get theAuthority => 'pihak berkuasa berkaitan';
  @override
  String get markDone => 'Tanda selesai';
  @override
  String get snooze => 'Tunda';
  @override
  String snoozeDays(int d) => d == 7 ? '1 minggu' : '$d hari';
  @override
  String snoozedMsg(String date) => 'Ditunda hingga $date. Anda akan diingatkan pagi itu.';
  @override
  String get editReminder => 'Ubah peringatan';
  @override
  String get markedDone => 'Ditanda selesai';
  @override
  String get notNow => 'Bukan sekarang';
  @override
  String get addCostDetails => 'Tambah kos & butiran';
  @override
  String get newReminder => 'Peringatan baharu';
  @override
  String get asset => 'Aset';
  @override
  String get startFromTemplate => 'Mula dari templat';
  @override
  String get title => 'Tajuk';
  @override
  String get titleHint => 'Apa yang perlu dibuat?';
  @override
  String get when => 'Bila';
  @override
  String get orByDate => 'Atau sebelum tarikh';
  @override
  String get dueDate => 'Tarikh akhir';
  @override
  String get every => 'Setiap';
  @override
  String get countFromDue => 'Yang seterusnya dikira dari tarikh akhir sebelumnya.';
  @override
  String get countFromDone => 'Yang seterusnya dikira dari hari anda tandakan selesai.';
  @override
  String get dueAtKmLabel => 'Pada (km)';
  @override
  String get everyKmLabel => 'Kemudian setiap (km)';
  @override
  String get odoUnknown => 'Odometer belum direkod. Kemas kini di halaman kenderaan.';
  @override
  String odoNow(String km) => 'Odometer sekarang: $km';
  @override
  String get remindKmBefore => 'Ingatkan sebelum';
  @override
  String get remindMe => 'Ingatkan saya';
  @override
  String get saveReminder => 'Simpan peringatan';
  @override
  String get saveChanges => 'Simpan perubahan';
  @override
  String get errTitle => 'Tambah tajuk ringkas.';
  @override
  String get errDate => 'Pilih tarikh.';
  @override
  String get errKm => 'Masukkan bacaan km, atau jarak berulang.';
  @override
  String get savedMileage => 'Disimpan. Jarak diperiksa setiap kali anda kemas kini odometer.';
  @override
  String savedNotifyOn(String date) => 'Peringatan disimpan. Anda akan diberitahu pada $date.';
  @override
  String updatedNotifyOn(String date) => 'Disimpan. Pemberitahuan lama dibatalkan; yang baharu pada $date.';
  @override
  String get deleteReminderQ => 'Padam peringatan ini?';
  @override
  String get deleteReminderBody => 'Rekod yang berkaitan tidak dipadam.';
  @override
  String get delete => 'Padam';
  @override
  String get addAssetFirst => 'Tambah aset dahulu. Yang lain semua bergantung padanya.';

  // ------------------------------------------------ record form
  @override
  String get newRecord => 'Rekod baharu';
  @override
  String get newDefect => 'Kecacatan baharu';
  @override
  String get kind => 'Jenis';
  @override
  String get category => 'Kategori';
  @override
  String get whatDone => 'Apa yang dibuat';
  @override
  String get whatFound => 'Apa yang dijumpai';
  @override
  String get recordHint => 'cth. Tukar paip sinki dapur';
  @override
  String get defectHint => 'cth. Retak di atas tingkap bilik';
  @override
  String get date => 'Tarikh';
  @override
  String get area => 'Bahagian rumah';
  @override
  String get areaHint => 'cth. Dapur';
  @override
  String get totalCost => 'Jumlah kos';
  @override
  String get alreadyReported => 'Sudah dilaporkan kepada pemaju';
  @override
  String get madeClaim => 'Saya buat tuntutan insurans';
  @override
  String get moreDetails => 'Butiran lanjut';
  @override
  String get workshop => 'Bengkel';
  @override
  String get vendor => 'Kontraktor / kedai';
  @override
  String get odometerKm => 'Odometer (km)';
  @override
  String get warrantyEndLabel => 'Waranti tamat';
  @override
  String get warrantyHelp => 'Kami akan ingatkan anda sebulan sebelum waranti tamat.';
  @override
  String get notes => 'Nota';
  @override
  String get photosLater => 'Gambar dan resit akan datang dalam versi seterusnya.';
  @override
  String linkedTo(String title) => 'Dipautkan kepada “$title”, yang sudah ditanda selesai.';
  @override
  String looksLike(String title) => 'Ini nampak seperti “$title”';
  @override
  String get markDoneAndNext => 'Tanda selesai dan jadualkan yang seterusnya';
  @override
  String get saveRecord => 'Simpan rekod';
  @override
  String get saveDefect => 'Simpan kecacatan';
  @override
  String get errDescription => 'Tambah penerangan ringkas.';
  @override
  String get recordSaved => 'Rekod disimpan.';
  @override
  String get defectAdded => 'Kecacatan ditambah.';
  @override
  String alsoMarkedDone(String title, String? next) => '“$title” ditanda selesai${next == null ? '' : '; seterusnya $next'}.';
  @override
  String warrantyEnds(String title) => 'Waranti tamat: $title';
  @override
  String get warrantyReminderAdded => 'Peringatan waranti ditambah.';

  // ------------------------------------------------ assets
  @override
  String get addAsset => 'Tambah aset';
  @override
  String get searchHint => 'Cari aset, rekod, peringatan';
  @override
  String get noMatch => 'Tiada padanan.';
  @override
  String get remindersTab => 'Peringatan';
  @override
  String get recordsTitle => 'Rekod';
  @override
  String get noRemindersYet => 'Belum ada peringatan.';
  @override
  String get nextLabel => 'Seterusnya';
  @override
  String dlpDaysLeftShort(int n) => 'DLP: $n hari lagi untuk lapor kecacatan';
  @override
  String get assetDeleted => 'Aset ini sudah dipadam.';
  @override
  String get overviewTab => 'Ringkasan';
  @override
  String get upkeepTab => 'Rekod';
  @override
  String get defectsTab => 'Kecacatan';
  @override
  String deleteAssetQ(String name) => 'Padam $name?';
  @override
  String get deleteAssetBody => 'Semua peringatan dan rekod untuk aset ini akan dipadam. Ini tidak boleh dibatalkan.';
  @override
  String get editDetails => 'Ubah butiran';
  @override
  String get deleteAsset => 'Padam aset';
  @override
  String get propertyType => 'Jenis hartanah';
  @override
  String get boughtAs => 'Dibeli';
  @override
  String get vpDate => 'Tarikh milikan kosong (VP)';
  @override
  String get vpHelp => 'Dari surat VP. Digunakan untuk anggaran tempoh liabiliti kecacatan (DLP).';
  @override
  String get spaDate => 'Tarikh perjanjian jual beli (SPA)';
  @override
  String get titleStatus => 'Status hakmilik';
  @override
  String get council => 'PBT (majlis)';
  @override
  String get councilHint => 'cth. MBSA';
  @override
  String get state => 'Negeri';
  @override
  String get occupancy => 'Penghunian';
  @override
  String get address => 'Alamat';
  @override
  String get contact => 'Hubungi (pemaju / JMB / MC)';
  @override
  String get contactHint => 'Nama dan nombor telefon';
  @override
  String get nickname => 'Nama panggilan';
  @override
  String get dlpTitle => 'Tempoh liabiliti kecacatan';
  @override
  String get dlpDaysLeft => 'hari lagi untuk lapor kecacatan';
  @override
  String endsAbout(String date) => 'Tamat sekitar $date';
  @override
  String get dlpNote => 'Anggaran: 24 bulan dari milikan kosong, seperti dalam SPA standard rumah baharu. Sahkan tarikh dalam SPA anda.';
  @override
  String get dlpSubsaleNote => 'Pembeli subsale mungkin mewarisi baki waranti. Semak dengan peguam anda.';
  @override
  String dlpEnded(String date) => 'DLP anggaran tamat pada $date. Senarai kecacatan disembunyikan, tetapi rekod anda disimpan.';
  @override
  String get addVpForDlp => 'Tambah tarikh milikan kosong (VP) untuk melihat kiraan DLP dan senarai kecacatan.';
  @override
  String get strataInsuranceNote => 'Untuk bangunan strata, JMB atau MC yang menginsuranskan bangunan. Semak sama ada anda perlukan insurans isi rumah sendiri.';
  @override
  String get odoNotSet => 'Belum direkod';
  @override
  String get odoAddFirst => 'Tambah bacaan pertama';
  @override
  String get update => 'Kemas kini';
  @override
  String get vehicle => 'Kenderaan';
  @override
  String get plate => 'Nombor plat';
  @override
  String get make => 'Jenama';
  @override
  String get model => 'Model';
  @override
  String get year => 'Tahun';
  @override
  String get roadTaxExpiry => 'Cukai jalan tamat';
  @override
  String get insuranceExpiry => 'Insurans tamat';
  @override
  String get insurer => 'Syarikat insurans';
  @override
  String get policyNo => 'No. polisi';
  @override
  String get warranty => 'Waranti';
  @override
  String get warrantyUntil => 'Waranti hingga';
  @override
  String get warrantyKm => 'Waranti hingga (km)';
  @override
  String get chassisNo => 'No. casis';
  @override
  String get engineNo => 'No. enjin';
  @override
  String get expiryNoReminderNote => 'Tarikh di sini untuk rujukan. Untuk diingatkan, tambah peringatan cukai jalan atau insurans.';
  @override
  String get notSet => 'Belum ditetapkan';
  @override
  String get yes => 'Ya';
  @override
  String get deleteRecord => 'Padam rekod';
  @override
  String get deleteRecordQ => 'Padam rekod ini?';
  @override
  String get cannotUndo => 'Ini tidak boleh dibatalkan.';
  @override
  String spentThisYear(int year) => 'Belanja $year setakat ini';
  @override
  String get noRecordsYet => 'Belum ada rekod.';
  @override
  String get addRecord => 'Tambah rekod';
  @override
  String get addReminder => 'Tambah peringatan';
  @override
  String foundOn(String date) => 'dijumpai $date';
  @override
  String get notReportedYet => 'belum dilaporkan';
  @override
  String reportedOn(String date) => 'dilaporkan $date';
  @override
  String get none => 'Tiada.';
  @override
  String dlpDaysLeftEnds(String date) => 'hari lagi · tamat sekitar $date';
  @override
  String get defectReportNote => 'Anggaran. Laporkan kecacatan kepada pemaju secara bertulis sebelum DLP tamat, dan simpan salinannya.';
  @override
  String get defectOpen => 'Belum selesai';
  @override
  String get defectInProgress => 'Pemaju sedang baiki';
  @override
  String get defectFixed => 'Sudah dibaiki';
  @override
  String get addDefect => 'Tambah kecacatan';
  @override
  String get found => 'Dijumpai';
  @override
  String get reported => 'Dilaporkan';
  @override
  String get notYet => 'Belum';
  @override
  String get markReportedToday => 'Tanda dilaporkan kepada pemaju hari ini';
  @override
  String get reportedToday => 'Ditanda dilaporkan hari ini. Simpan surat atau e-mel anda.';
  @override
  String odoDialogTitle(String name) => 'Odometer $name';
  @override
  String odoLast(String km, String ago) => 'Terakhir: $km, $ago';
  @override
  String get odoCheckNote => 'Peringatan ikut jarak diperiksa apabila anda simpan.';
  @override
  String odoTooLow(String km) => 'Masukkan bacaan sekurang-kurangnya $km.';
  @override
  String get save => 'Simpan';
  @override
  String get cancel => 'Batal';
  @override
  String nowStatus(String title, String status) => '“$title” kini: $status.';
  @override
  String odoSaved(String km) => 'Odometer disimpan: $km.';
  @override
  String mileageNoteTitle(String name) => 'Peringatan jarak: $name';
  @override
  String get clear => 'Kosongkan';
  @override
  String get pickDate => 'Pilih tarikh';

  // ------------------------------------------------ add asset
  @override
  String get errNickname => 'Beri nama yang anda kenal.';
  @override
  String get errPlate => 'Tambah nombor plat supaya kenderaan mudah dibezakan.';
  @override
  String get errPickDates => 'Pilih tarikh untuk setiap peringatan yang ditanda, atau nyahtanda.';
  @override
  String addedIn(String name, String time) => '$name ditambah dalam $time.';
  @override
  String stepOf(int a, int b) => 'LANGKAH $a DARI $b';
  @override
  String get whatAdding => 'Apa yang anda mahu tambah?';
  @override
  String get onlyNameNeeded => 'Hanya nama diperlukan sekarang. Butiran lain boleh ditambah kemudian.';
  @override
  String nameYour(String c) => switch (c) { 'car' => 'Namakan kereta anda', 'motorcycle' => 'Namakan motosikal anda', _ => 'Namakan rumah anda' };
  @override
  String nicknameHint(String c) => switch (c) { 'car' => 'cth. Myvi', 'motorcycle' => 'cth. Y15', _ => 'cth. Rumah Bangi' };
  @override
  String get ptypeWhy => 'Ini menentukan peringatan cukai dan insurans yang kami cadangkan.';
  @override
  String get back => 'Kembali';
  @override
  String get done => 'Siap';
  @override
  String get optional => 'Pilihan';
  @override
  String get suggestedReminders => 'Peringatan dicadangkan';
  @override
  String get tickAndDate => 'Tanda yang anda mahu. Setiap satu hanya perlukan tarikh.';
  @override
  String get skip => 'Langkau';
  @override
  String saveN(int n) => n == 0 ? 'Simpan' : 'Simpan $n peringatan';
  @override
  String isSetUp(String name) => '$name sudah sedia';
  @override
  String addedInKeepSafe(String time) => 'Ditambah dalam $time. Dua perkara untuk jaga rekod anda:';
  @override
  String get notifications => 'Pemberitahuan';
  @override
  String get allowed => 'Dibenarkan';
  @override
  String get notifPitch => 'Dapat peringatan sebelum tarikh akhir';
  @override
  String get allow => 'Benarkan';
  @override
  String get backupFile => 'Fail sandaran';
  @override
  String get backupPitch => 'Data anda hanya ada di telefon ini';
  @override
  String get backUp => 'Sandarkan';
  @override
  String get goToToday => 'Pergi ke Hari ini';
  @override
  String get addAssetHint => 'Rumah, kereta atau motosikal';
  @override
  String get record => 'Rekod';
  @override
  String get addRecordHint => 'Penyelenggaraan, baik pulih, ubah suai, kecacatan, bayaran';
  @override
  String get reminder => 'Peringatan';
  @override
  String get addReminderHint => 'Satu tarikh, berulang atau ikut jarak';
  @override
  String get document => 'Dokumen';
  @override
  String get comingSoon => 'Akan datang dalam versi seterusnya';

  // ------------------------------------------------ more
  @override
  String get backupRestore => 'Sandaran & pemulihan';
  @override
  String get noBackupYet => 'Belum ada sandaran';
  @override
  String lastBackupAgo(String ago) => 'Sandaran terakhir $ago';
  @override
  String get healthCheck => 'Semakan peringatan';
  @override
  String get notifAllowed => 'Pemberitahuan dibenarkan';
  @override
  String get notifNotAllowed => 'Pemberitahuan tidak dibenarkan';
  @override
  String get allRemindersTitle => 'Semua peringatan';
  @override
  String activeCount(int n) => '$n aktif';
  @override
  String get language => 'Bahasa';
  @override
  String get appLock => 'Kunci app (PIN atau cap jari)';
  @override
  String get privacyAbout => 'Privasi & maklumat';
  @override
  String get privacyShort => 'Tiada akaun. Tiada internet. Tiada penjejakan.';
  @override
  String get all => 'Semua';
  @override
  String get notifPermission => 'Kebenaran pemberitahuan';
  @override
  String get notifNotAllowedLong => 'Tidak dibenarkan. Peringatan hanya kelihatan dalam app.';
  @override
  String get batteryTitle => 'Penjimatan bateri';
  @override
  String get batteryBody => 'Sesetengah telefon menghentikan peringatan apabila app ditutup. Dalam Tetapan > Apl > Kukira Asset > Bateri, pilih "Tanpa had".';
  @override
  String get lastRebuild => 'Jadual terakhir dibina semula';
  @override
  String rebuildSummary(String time, int count) => 'Hari ini, $time · $count pemberitahuan dijadualkan (maksimum 50)';
  @override
  String get nextNotification => 'Pemberitahuan seterusnya';
  @override
  String get noneScheduled => 'Tiada yang dijadualkan';
  @override
  String get sendTest => 'Hantar peringatan ujian';
  @override
  String get testNeedsPermission => 'Pemberitahuan dimatikan, jadi ujian tidak boleh dipaparkan. Benarkan dahulu.';
  @override
  String get rebuildNow => 'Bina semula jadual sekarang';
  @override
  String get rebuilt => 'Jadual dibina semula.';
  @override
  String get todayIsGuaranteed => 'Telefon boleh melewatkan atau menggugurkan pemberitahuan. Skrin Hari ini sentiasa menunjukkan apa yang lewat dan hampir tiba, jadi bukalah sekali-sekala.';

  // ------------------------------------------------ backup
  @override
  String get choosePassphrase => 'Pilih frasa laluan';
  @override
  String get passphraseIntro => 'Frasa laluan mengunci fail sandaran. Ia berasingan daripada kunci app.';
  @override
  String get passphrase => 'Frasa laluan';
  @override
  String get passphraseHelp => 'Sekurang-kurangnya 8 aksara. Ayat pendek lebih mudah diingat.';
  @override
  String get typeAgain => 'Taip sekali lagi';
  @override
  String get passMismatch => 'Kedua-dua frasa laluan tidak sama.';
  @override
  String get forgetWarningAck => 'Saya faham: jika saya lupa frasa laluan ini, tiada sesiapa boleh membuka sandaran ini.';
  @override
  String get createFile => 'Buat fail';
  @override
  String get enterPassphrase => 'Masukkan frasa laluan';
  @override
  String get unlockFile => 'Buka fail';
  @override
  String get couldNotRead => 'Fail itu tidak dapat dibaca. Cuba pilih semula.';
  @override
  String get unlocking => 'Membuka fail…';
  @override
  String get wrongPassphrase => 'Frasa laluan ini tidak membuka fail. Tiada apa di telefon ini yang berubah.';
  @override
  String get notABackup => 'Ini bukan fail sandaran Kukira.';
  @override
  String get checkBeforeRestore => 'Semak sebelum memulihkan';
  @override
  String backupMadeOn(String date) => 'Sandaran dibuat pada $date.';
  @override
  String backupCounts(int a, int r, int rec, int d) => '$a aset · $r peringatan · $rec rekod · $d dokumen';
  @override
  String restoreReplaces(String date) => 'Pemulihan menggantikan semua data di telefon ini dengan isi fail. Apa-apa yang ditambah selepas $date akan hilang.';
  @override
  String get replaceMyData => 'Gantikan data saya';
  @override
  String get encrypting => 'Menyulitkan rekod anda…';
  @override
  String get whereToSave => 'Simpan sandaran di mana?';
  @override
  String get shareToApp => 'Hantar ke app';
  @override
  String get shareToAppHint => 'Google Drive, e-mel, WhatsApp kepada diri sendiri';
  @override
  String get saveToFolder => 'Simpan dalam folder telefon';
  @override
  String get saveToFolderHint => 'Pilih folder, contohnya Muat turun';
  @override
  String backupSaved(String name) => 'Sandaran disimpan: $name. Kukira tidak memuat naiknya ke mana-mana.';
  @override
  String get backupNotSaved => 'Sandaran tidak disimpan.';
  @override
  String get restoring => 'Memulihkan…';
  @override
  String restoredFrom(String date) => 'Dipulihkan dari sandaran $date. Peringatan dijadualkan semula.';
  @override
  String get lastBackupLabel => 'Sandaran terakhir';
  @override
  String get never => 'Tiada lagi';
  @override
  String get backupExplainer => 'Rekod anda hanya disimpan di telefon ini. Fail sandaran ialah satu-satunya cara untuk memindahkannya ke telefon baharu atau mendapatkannya semula selepas set semula.';
  @override
  String get createBackup => 'Buat fail sandaran';
  @override
  String get restoreFromFile => 'Pulihkan dari fail sandaran';
  @override
  String get passphraseWarning => 'Fail sandaran dikunci dengan frasa laluan pilihan anda. Jika anda lupa, tiada sesiapa boleh membukanya, termasuk kami.';
  @override
  String get phoneBackupNote => 'Sandaran automatik telefon tidak termasuk data Kukira. Jika telefon hilang atau app dinyahpasang tanpa fail sandaran, rekod anda hilang.';
  @override
  String get backupNudgeNote => 'Kukira mengingatkan anda untuk buat sandaran setiap 30 hari.';

  // ------------------------------------------------ about, documents, unreadable
  @override
  String get pNoAccount => 'Tiada akaun';
  @override
  String get pNoAccountBody => 'Anda tidak perlu mendaftar atau log masuk.';
  @override
  String get pNoInternet => 'Tiada internet diperlukan';
  @override
  String get pNoInternetBody => 'Kukira tidak meminta akses rangkaian. Tiada apa yang dimuat naik.';
  @override
  String get pEncrypted => 'Disulitkan di telefon anda';
  @override
  String get pEncryptedBody => 'Pangkalan data disulitkan. Fail sandaran hanya pergi ke tempat yang anda pilih.';
  @override
  String get pNoAds => 'Tiada iklan atau analitik';
  @override
  String get pNoAdsBody => 'Tiada sesiapa melihat cara anda menggunakan app.';
  @override
  String get legalDisclaimer => 'Tarikh cukai, hakmilik dan DLP dalam Kukira ialah anggaran untuk membantu anda merancang. Ia bukan nasihat undang-undang. Sahkan dengan perjanjian, pejabat tanah atau PBT anda.';
  @override
  String get testBuild => 'versi ujian';
  @override
  String get docsComingTitle => 'Dokumen akan datang';
  @override
  String get docsComingBody => 'Versi seterusnya akan menyimpan SPA, geran, surat VP, bil cukai dan resit di sini, disulitkan dan boleh dibuka tanpa internet.';
  @override
  String get unreadableTitle => 'Rekod anda tidak dapat dibuka di telefon ini';
  @override
  String get unreadableBody => 'Kunci yang membuka rekod anda kekal di telefon tempat ia dibuat. Ini biasanya berlaku selepas berpindah ke telefon baharu atau memulihkan dari sandaran telefon.\n\nJika anda ada fail sandaran Kukira, pulihkan sekarang. Anda perlukan frasa laluannya.';
  @override
  String get startFresh => 'Mula semula tanpa data';
  @override
  String get startFreshWarning => 'Ini memadam data yang tidak dapat dibaca untuk selama-lamanya. Lakukan hanya jika anda tiada fail sandaran.';
  @override
  String get keepIt => 'Simpan dahulu';
  @override
  String get eraseAndStart => 'Padam dan mula';

  // ------------------------------------------------ notifications
  @override
  String get channelName => 'Peringatan';
  @override
  String get channelDescription => 'Peringatan tarikh akhir untuk rumah dan kenderaan anda';
  @override
  String noteLead(String asset, String date) => '$asset · tarikh akhir $date';
  @override
  String noteDue(String asset) => '$asset · tarikh akhir hari ini';
  @override
  String noteOverdue(String asset) => '$asset · sudah lewat. Buka Kukira untuk tanda selesai atau tunda.';
  @override
  String noteSnooze(String asset) => '$asset · tempoh tunda tamat';
  @override
  String get backupNudgeTitle => 'Masa untuk buat sandaran';
  @override
  String get backupNudgeBody => 'Rekod Kukira anda hanya ada di telefon ini. Buat fail sandaran baharu.';
  @override
  String get testNoteTitle => 'Peringatan ujian';
  @override
  String get testNoteBody => 'Peringatan dari Kukira akan kelihatan begini.';
}
