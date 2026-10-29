# Kukira Asset

App Android untuk pemilik rumah, kereta dan motosikal di Malaysia. Satu tempat untuk lihat apa yang lewat atau hampir tiba, simpan rekod penyelenggaraan, dan jejak kecacatan dalam tempoh DLP. Semua data kekal dalam telefon: tiada akaun, tiada internet, tiada awan.

Versi ini: **0.2.2 (APK ujian)**. Senarai perubahan penuh: `CHANGELOG.md`. Peraturan wajib: `SPEC.md`.

## Baharu dalam 0.2.2

Keluaran keselamatan data, tiada ciri baharu:

- APK ditandatangani dengan kunci keluaran Kukira. **Dari 0.2.1: sandarkan, nyahpasang, pasang 0.2.2, pulihkan** (sekali sahaja, lihat Kunci tandatangan di bawah).
- Rekod yang tidak dapat dibuka diketepikan, bukan dipadam.
- Pemulihan sandaran selamat walaupun app terhenti di tengah jalan.
- Sandaran merekod versi pangkalan data; sandaran dari versi lebih baharu ditolak.
- Tempoh menunggu selepas PIN salah kekal walaupun app ditutup.

## Baharu dalam 0.2.1

- Bar navigasi Android tidak lagi menutup butang Simpan dan medan terakhir.
- Tarikh cukai jalan, insurans dan VP kini menyegerakkan satu peringatan masing-masing (cipta, kemas kini, buang; tiada pendua). Peringatan yang sudah selesai atau ditunda hanya diubah selepas anda sahkan.
- Borang rumah menapis status hakmilik dan cadangan peringatan ikut jenis hartanah. Untuk subsale, tarikh VP dilabel "Tarikh VP asal (jika masih dalam DLP)".
- Skrin Privasi & maklumat memaparkan versi sebenar.

## Baharu dalam 0.2

- Dokumen: ambil gambar atau pilih PDF (SPA, geran, surat VP, bil cukai, insurans, resit). Disimpan tersulit, dibuka dengan pemapar telefon. Tarikh tamat boleh menjadi peringatan.
- Gambar pada rekod, kecacatan dan insiden. Gambar aset pada kad.
- Kunci app dengan PIN (membungkus kunci pangkalan data) dan cap jari (Keystore). Dikunci semula selepas 2 minit di latar belakang.
- Buku vendor: simpan tukang dan bengkel, pilih semasa merekod kerja.
- Ubah rekod, pecahan kos (upah, barang), ubah tarikh tamat DLP, masa pemberitahuan sendiri, ulangan setiap N hari/minggu/bulan/tahun, peringatan bulanan odometer, butang terus ke tetapan bateri.
- Sandaran format 2: termasuk dokumen dan gambar. Sandaran 0.1 masih boleh dipulihkan.
- Rupa: ringkasan di atas Hari ini, kad aset berwarna, bulatan DLP, animasi tanda selesai, skrin pembukaan.
- APK dipecah ikut jenis pemproses (sekitar 25 MB setiap satu).

## Apa yang ada dalam 0.1

- Aset: rumah (bertanah, strata, strata bertanah), kereta, motosikal. Hanya nama dan jenis yang wajib.
- Tambah aset pertama dalam 3 ketikan, kemudian cadangan peringatan (cukai tanah/petak, cukai taksiran, insurans, cukai jalan, servis) yang hanya perlukan tarikh.
- Peringatan: satu tarikh, berulang, ikut jarak, atau mana dulu. Tanda selesai, tunda, ubah.
- Skrin Hari ini: Lewat, Hampir tiba (30 hari), Baru selesai. Banner bila pemberitahuan dimatikan atau sandaran sudah lama.
- Pemberitahuan tempatan sekitar 9:00 pagi (tetingkap bergulir 50 pemberitahuan, dibina semula setiap kali data berubah).
- Rekod: penyelenggaraan, ubah suai, insiden, kecacatan, bayaran. Kos, bengkel/kontraktor, waranti (cipta peringatan).
- Kiraan DLP dan senarai kecacatan apabila tarikh VP diisi.
- Odometer: peringatan ikut jarak diperiksa setiap kali bacaan dikemas kini.
- Pangkalan data disulitkan (SQLCipher). Kunci dalam Android Keystore.
- Sandaran disulitkan dengan frasa laluan (AES-256-GCM, PBKDF2) dan pemulihan dengan pratonton.
- Skrin "rekod tidak dapat dibuka" jika kunci tiada (contohnya selepas tukar telefon).
- Semakan peringatan: status kebenaran, jadual terakhir, hantar ujian.
- Bahasa Melayu (asal) dan English.

Seterusnya (0.3): senarai semak VP/DLP ikut bilik, rumah sewa, peringatan strata dan musim tengkujuh, jangka hayat alat ganti, jangkaan servis, rekod kemalangan dan NCD, senarai semak balik kampung, sejarah servis untuk jual.

## Cara dapatkan APK

APK dibina oleh GitHub Actions setiap kali kod ditolak ke `main` (tiada perisian perlu dipasang di PC).

1. Buka repo di GitHub → tab **Actions** → larian terbaru **Bina APK**.
2. Di bawah **Artifacts**, muat turun `kukira-asset-apk` (fail zip).
3. Buka zip. Kebanyakan telefon perlukan fail **`arm64-v8a`**. Guna `armeabi-v7a` hanya untuk telefon lama 32-bit. Hantar fail `.apk` itu ke telefon (WhatsApp kepada diri sendiri, kabel USB, atau Google Drive).
4. Di telefon, buka fail itu. Benarkan **Pasang apl tidak diketahui** untuk app yang anda guna untuk membukanya.

### Kunci tandatangan

Mulai 0.2.2 setiap APK ditandatangani dengan kunci keluaran Kukira. Kunci itu tidak ada dalam repo: CI mengambilnya daripada dua GitHub secret, `KUKIRA_KEYSTORE_B64` (fail `.p12` dalam base64) dan `KUKIRA_KEYSTORE_PASSWORD`. CI juga menyemak bahawa setiap APK membawa sijil keluaran (SHA-256 `da88ed12…5e546754`), dan gagal jika tidak.

Pemilik menyimpan salinan luar talian (`kukira-release.p12` dan kata laluannya). **Jika kunci ini hilang, kemas kini tidak boleh dipasang di atas app sedia ada lagi**, dan pengguna terpaksa nyahpasang, yang memadam data mereka.

**Dari 0.2.1 atau lebih awal ke 0.2.2:** versi lama ditandatangani dengan kunci ujian, jadi Android tidak benarkan 0.2.2 dipasang di atasnya. Buat sandaran dahulu (Lagi → Sandaran), nyahpasang versi lama, pasang 0.2.2, kemudian pulihkan sandaran. Ini hanya perlu sekali.

## Senarai semak ujian (sekurang-kurangnya dua telefon Android)

1. Pengguna baharu tambah satu aset dan satu peringatan dalam masa kurang 2 minit tanpa bantuan.
2. Peringatan untuk esok masih muncul selepas telefon dimulakan semula dan selepas app ditutup paksa.
3. Dengan pemberitahuan ditolak, Hari ini masih menyenaraikannya dan banner menerangkan sebabnya.
4. Tukar tarikh akhir: pemberitahuan lama hilang, yang baharu dijadualkan (lihat Lagi → Semakan peringatan).
5. Tanda selesai peringatan berulang: yang seterusnya dikira dari tarikh selesai.
6. Fail sandaran dipulihkan di telefon lain dengan frasa laluan yang betul, dan gagal dengan selamat jika salah.
7. Mod kapal terbang: semua data kelihatan.
8. APK tidak meminta kebenaran INTERNET (CI menyemak ini dan gagal jika ada).
9. Fail pangkalan data tidak boleh dibaca tanpa kunci.
10. Peringatan ikut jarak menjadi Lewat apabila odometer dikemas kini melepasi had.

Sertakan sekurang-kurangnya satu telefon dengan pengurusan bateri yang agresif (contohnya Xiaomi, Oppo, Vivo, Huawei).

## Struktur kod

```
lib/
  main.dart               mula: pemberitahuan, buka pangkalan data, jalankan app
  data/db.dart            jadual drift dan pertanyaan (World = semua data dalam satu snapshot)
  data/vault.dart         SQLCipher + kunci dalam Keystore, kesan pangkalan data tak boleh dibaca
  domain/rules.dart       logik peringatan (status, seterusnya, pelan pemberitahuan), tanpa Flutter
  domain/presets.dart     cadangan dan templat, kategori rekod
  services/notifications.dart  jadual pemberitahuan tempatan
  services/backup.dart    fail sandaran disulitkan
  l10n/                   semua teks: strings_ms.dart, strings_en.dart
  ui/                     skrin
test/rules_test.dart      ujian logik peringatan
android_overrides/        manifest, peraturan sandaran, ikon
tool/patch_android.py     tampal folder android yang dijana oleh `flutter create` dalam CI
```

Folder `android/` tidak disimpan dalam repo. CI menjananya dari templat Flutter 3.27.4, kemudian menyalin `android_overrides/` dan menampal `build.gradle` (minSdk 23, desugaring, kunci keluaran daripada secret).

## Nota undang-undang

Tarikh cukai, hakmilik dan DLP ialah anggaran yang boleh diubah, bukan fakta. Sumber kajian ialah ulasan sekunder, bukan statut asal. Semak terhadap Akta Pemajuan Perumahan (Kawalan dan Pelesenan) 1966, Akta Pengurusan Strata 2013 dan Akta Kerajaan Tempatan 1976 sebelum terbit.
