# Pelan Kukira Asset 0.3: "Rumah, dari VP hingga disewa"

Diluluskan oleh pemilik pada 6 Nov 2026, dengan jawapan di hujung. Belum ada kod ditulis. Kerja kod bermula selepas build 16 diuji di telefon dan build 17 (pembaikan) siap.

Peraturan SPEC kekal: tiada internet, semua bersulit, tarikh undang-undang ialah pratetap "anggaran, sahkan", BM dahulu, setiap skrin baharu ada ujian widget, satu ciri satu commit.

## Ringkasan

| # | Ciri | Saiz | Bergantung kepada |
|---|---|---|---|
| F1 | Tarikh akhir tuntutan Tribunal | Kecil | DLP sedia ada |
| F2 | Penyahenapan tangki septik (IWK) | Kecil | Pratetap sedia ada |
| F3 | Sewa: penyewa, sejarah dan bayaran bulanan | Besar | Skema 6 |
| F4 | Senarai semak VP/DLP ikut bilik + WhatsApp | Besar | Skema 6, rekod kecacatan sedia ada |
| F5 | Insurans rumah dan semakan banjir sebelum tengkujuh | Kecil | Pratetap sedia ada |
| F6 | Strata: yuran, sinking fund, AGM | Kecil | Pratetap sedia ada |
| F7 | Senarai semak balik kampung | Sederhana | Skema 6 |
| R | Keluaran 0.3.0: versi, CHANGELOG, README, SPEC, tangkapan skrin | - | Semua di atas |

Cadangan susunan: F1, F2 (cepat, terus berguna), F3, F4, F5, F6, F7, R.

## Skema 6 (satu naik taraf untuk semua)

Jadual baharu. Tiada jadual atau lajur lama dipadam; sandaran lama (skema 1 hingga 5) mesti terus dipulihkan, dan sandaran format 3 membawa jadual baharu.

- `Tenancies`: id, assetId, nama penyewa, telefon (pilihan), mula, tamat, sewa sebulan, hari bayar (1 hingga 28), deposit, tarikh tandatangan, tarikh disetem, dokumen perjanjian (pautan ke Documents), tarikh berakhir sebenar, nota.
- `RentPayments`: id, tenancyId, bulan (tahun dan bulan), tarikh dibayar, jumlah, nota. Satu bayaran untuk satu bulan (tiada bayar sebahagian).
- `Inspections`: id, assetId, jenis (vp atau sebelum DLP tamat), tarikh, bilangan bilik tidur dan bilik air.
- `InspectionChecks`: id, inspectionId, ruang, perkara, keputusan (ok, cacat, tiada), recordId (kecacatan yang dibuat).
- `Checklists` dan `ChecklistItems`: senarai semak boleh guna semula (F7).
- `HouseProfiles` ditambah: `cccDate`, `septicTank` (ya atau tidak), `insidePbt` (ya atau tidak).

Naik taraf: tarikh sewa lama dalam `HouseProfiles` (mula, tamat, hari bayar) dipindah menjadi satu baris `Tenancies`. Lajur lama kekal, tidak digunakan lagi.

## F1. Tarikh akhir tuntutan Tribunal

- Peringatan automatik baharu (`autoSource: tribunal`) = DLP tamat + 12 bulan. Ia mengikut tarikh DLP seperti peringatan DLP sedia ada: tukar VP atau DLP, peringatan ini bergerak bersama, dengan pertanyaan yang sama sebelum membuka semula yang sudah selesai.
- Kad DLP di halaman rumah menunjukkan tarikh akhir itu.
- Medan pilihan baharu: tarikh CCC. Nota: tuntutan bukan kecacatan (contohnya lewat serah) lebih selamat dikira dari CCC.
- Ditanda anggaran: "sahkan dengan peguam atau Tribunal Tuntutan Pembeli Rumah".
- Sumber: Akta 118 s.16N(2); *Lakefront Residence v TTPR* [2023] MLJU 2352 (kecacatan dikira dari DLP tamat). Had RM50,000 dari sumber sekunder sahaja, jadi tidak ditunjuk.

## F2. Penyahenapan tangki septik (IWK)

- Rumah tanah: soalan "guna tangki septik sendiri?" dan "dalam kawasan PBT?".
- Pratetap berulang: 24 bulan (dalam PBT) atau 36 bulan (luar PBT), anggaran, sahkan dengan IWK. Kos rujukan RM192 sekitaran.
- Tidak ditawarkan untuk strata atau rumah yang bersambung ke pembetungan pusat. Sabah dan Sarawak ada peraturan sendiri: pratetap ini menyebut "kawasan IWK sahaja".
- Sumber: iwk.com.my (Water Services Industry (Sewage Disposal Services) Regulations 2021, berkuat kuasa 30 Mac 2021).

## F3. Sewa (paling besar)

Rupa seperti lakaran yang diluluskan: kad penyewa, ringkasan tahun, grid 12 bulan berwarna, sejarah penyewa.

- Status bulan: dibayar (hijau), dibayar lewat (kuning), belum (merah), belum tiba (kelabu).
- Tekan satu bulan: tanda dibayar dengan tarikh dan jumlah (lalai = sewa penuh, hari ini). Tekan lama: ubah atau padam bayaran.
- Peringatan:
  - Setem perjanjian: 30 hari selepas tandatangan (anggaran, sahkan dengan LHDN; e-Duti Setem di MyTax). Hilang bila tarikh disetem diisi.
  - Sewa bulanan: jika bulan belum ditanda dibayar, notifikasi 7 hari selepas hari bayar (boleh diubah). Tidak ada notifikasi untuk bulan yang sudah dibayar.
  - Tamat sewa: 60 hari sebelum (peringatan tamat sewa sedia ada dipindah ke sini).
  - Deposit: bila sewa berakhir, peringatan "pulangkan atau tolak deposit".
- Hari ini: "Sewa Dis belum diterima · Rumah Setia Alam" di bawah Perlu tindakan.
- Sejarah: setiap penyewaan disimpan selamanya dengan semua bayarannya. Penyewaan baharu tidak menggantikan yang lama.
- Notifikasi mengikut "sembunyikan butiran": tiada nama penyewa atau jumlah sewa pada skrin kunci.
- Privasi: nama dan telefon penyewa ialah data orang lain; ia kekal dalam telefon dan bersulit seperti data lain.

## F4. Senarai semak VP/DLP ikut bilik + WhatsApp

- Mula semakan: pilih bilangan bilik tidur dan bilik air; Kukira menyusun ruang (ruang tamu, dapur, bilik tidur 1 hingga n, bilik air 1 hingga n, balkoni, luar rumah) dan perkara bagi setiap ruang (siling, dinding, lantai dan jubin, pintu, tingkap, paip dan sinki, suis dan soket, cat). Boleh tambah atau buang perkara.
- Setiap perkara: OK, Cacat atau Tiada. Cacat membuka rekod kecacatan sedia ada (gambar, catatan) dengan ruang sudah diisi.
- Kemajuan ditunjuk ("Dapur 6/8 disemak · 2 cacat").
- Dua jenis: semasa terima kunci (VP), dan sebelum DLP tamat (Kukira cadangkan 2 bulan sebelum).
- Hantar kepada pemaju: satu mesej tersusun (bernombor, ikut ruang, tarikh dilaporkan) dihantar melalui helaian kongsi Android ke WhatsApp, bersama gambar. Nombor pemaju diambil dari kenalan rumah. Sebelum hantar, nota jelas: "teks dan gambar ini akan keluar dari telefon". Selepas dihantar, kecacatan ditanda "dilaporkan pada" tarikh itu.
- Tiada internet: WhatsApp dibuka oleh Android, sama seperti laman web PBT.

## F5. Insurans rumah dan semakan banjir

- Pratetap insurans dipecah: houseowner (bangunan) dan householder (isi rumah), dengan nota pendek tentang beza dan tentang MRTA/MLTA (melindungi pinjaman, bukan rumah).
- Strata: nota bahawa polisi kebakaran MC tidak melindungi isi rumah atau bencana.
- Pratetap tahunan "Semakan sebelum tengkujuh", tarikh lalai ikut negeri rumah (boleh diubah): negeri yang dilanda monsun timur laut (Kelantan, Terengganu, Pahang, Johor, Sabah, Sarawak) 1 Okt, sebelum monsun bermula awal November; negeri lain 15 Sep, sebelum hujan lebat peralihan monsun Oktober. Tarikh ini anggaran dan disahkan dengan MetMalaysia sebelum dibina. Isinya: bumbung dan longkang, pam, barang berharga ke atas, semak sama ada polisi melindungi banjir (tanah runtuh biasanya dikecualikan).
- Sumber sekunder (penanggung insurans, berita); semua ditanda "sahkan dengan syarikat insurans".

## F6. Strata

- Pratetap: yuran penyelenggaraan (sedia ada), sinking fund (sekurang-kurangnya 10% yuran, anggaran), AGM tahunan JMB/MC (pilihan).
- Kenalan pengurusan (sedia ada) ditunjuk pada kad strata.
- Kecil; kebanyakannya pratetap dan nota.

## F7. Senarai semak balik kampung

- Senarai boleh guna semula untuk kereta (tayar dan tayar ganti, minyak hitam, air radiator, lampu, wiper, dokumen dan cukai jalan) dan rumah (kunci, suis utama, paip air, gas, pintu pagar, minta jiran tengok).
- Tanda satu demi satu; dikosongkan untuk perjalanan seterusnya; tarikh terakhir digunakan disimpan.
- Peringatan pilihan sebelum perjalanan: pengguna pilih tarikh (tarikh raya berubah setiap tahun, jadi tidak ditetapkan oleh app).

## Ujian dan keluaran

- Naik taraf skema 5 ke 6 dengan data sebenar, dan pemulihan sandaran skema 1 hingga 5 dan format 1, 2 dan 3.
- Ujian widget untuk setiap skrin baharu, ujian peraturan untuk setiap pratetap dan peringatan.
- Tangkapan skrin baharu untuk sewa, semakan bilik, dan senarai semak.
- SPEC: bahagian baharu untuk sewa (sejarah selamanya), Tribunal, IWK, dan WhatsApp (data keluar dengan nota).

## Keputusan pemilik (6 Nov 2026)

1. Nombor telefon penyewa: disimpan (pilihan).
2. Notifikasi sewa belum dibayar: 7 hari selepas hari bayar.
3. Bayar sebahagian: tidak.
4. Semakan tengkujuh: ikut negeri.
5. Susunan F1 hingga F7: setuju.
