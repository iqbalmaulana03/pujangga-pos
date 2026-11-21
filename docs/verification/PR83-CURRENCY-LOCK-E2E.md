# Verifikasi E2E PR #83 — Penguncian mata uang

## Verifikasi setelah commit dan push

Setelah commit tambahan E2E
[`296967a`](https://github.com/iqbalmaulana03/pujangga-pos/commit/296967ad5dc451d0fb425113272bdb8a0734d698)
di-push ke PR #83, **10/10 skenario E2E kembali lulus** di Redmi Android 13
pada 21 November 2026, pukul 22:21–22:27 WIB. Kedua suite membangun APK baru
dan merekam revisi committed tersebut sebagai `source_revision`.

- Penguncian mata uang: 7/7 lulus, 1 menit 32 detik; termasuk native Android
  Sharesheet yang dibuka dan dibatalkan, tanpa mengirim struk.
- Regresi USD/SGD/IDR: 3/3 lulus, 2 menit 57 detik; sembilan checkout,
  pembulatan pajak, stok, laporan, serta pembukaan ulang SQLite terverifikasi.
- Kedua runner selesai dengan exit code 0 dan memverifikasi pelestarian paket
  yang sebelumnya terpasang. Direktori database sementara telah dibersihkan;
  pemeriksaan ADB terpisah juga tidak menemukan sisa direktori kasus uji.
- [CI Analyze and test untuk 296967a](https://github.com/iqbalmaulana03/pujangga-pos/actions/runs/44918587048/job/136889443406)
  lulus; Agent review terakhir untuk commit tersebut juga SUCCESS.

Bukti revisi committed: [hasil penguncian](pr83-currency-lock-e2e/post-296967a/result.json)
dan [hasil regresi presisi](pr83-currency-lock-e2e/post-296967a/precision-summary.json).
Log dan screenshot mentah tetap lokal di `build/currency-lock-e2e-post-296967a/`
serta `build/currency-e2e/`. Pembaruan laporan/JSON ini tidak mengubah kode
aplikasi, konfigurasi build, tes, runner, atau dependensi dari `296967a`.
PR belum di-merge dan tidak ada deployment produksi dalam pengujian ini.

## Publikasi harness dan bukti

Harness, runner, konfigurasi paket debug khusus, dan bukti terpilih disertakan
untuk PR publik #83 di GitHub. Tidak ada domain privat, kredensial, log mentah,
atau file hasil build yang disertakan. Area notifikasi perangkat pada satu
screenshot detail historis run kedua disamarkan sebelum publikasi; konten
transaksi sintetis tetap terlihat. Identitas serial ADB tidak dipublikasikan.

## Pengujian ulang sebelum merge (run kedua)

Pada 21 November 2026, pukul 21:55–22:09 WIB, seluruh **10 skenario E2E
kembali lulus** pada perangkat Redmi Android 13 yang sama. Fetch sebelum
pengujian dan pembacaan ulang GitHub sesudahnya memastikan head PR tetap
`ee62e8b979790542a5c3189b9b5c9349fcc26dc6`. Kode aplikasi identik dengan
revisi committed tersebut; tidak ada perubahan kode produk untuk meluluskan tes.

- Suite penguncian: **7/7 lulus**, durasi tes perangkat 1 menit 32 detik,
  dengan build APK baru dan database baru per kasus. Penguncian masing-masing
  sumber data, penyimpanan pajak, transaksi Rp100.000, detail historis, laporan,
  native Sharesheet yang dibatalkan, serta pembukaan ulang SQLite lulus lagi.
- Regresi USD/SGD/IDR: **3/3 lulus**, durasi tes perangkat 2 menit 58 detik,
  mencakup sembilan checkout, pembulatan pajak, harga, stok, laporan,
  persistensi pengaturan, dan integritas SQLite.
- Persiapan regresi sempat terganggu: percobaan awal Gradle melaporkan
  `Build cancelled` dan koneksi lokal terputus sebelum tes aplikasi dimulai.
  Proses sisa yang terverifikasi milik runner dihentikan dan build diulang di
  luar sandbox. Instalasi kemudian sempat melaporkan
  `INSTALL_FAILED_USER_RESTRICTED`; pemasangan ulang paket uji khusus PR63
  berhasil dan ketiga tes selesai dengan exit code 0. Tidak ada kegagalan
  assertion aplikasi pada kedua suite yang selesai.
- Inventaris sebelum/sesudah menunjukkan semua paket yang sebelumnya
  terpasang tetap ada. Pemeriksaan ADB terpisah tidak menemukan direktori
  `currency-lock-*` atau `currency-e2e-*` tersisa dalam cache paket uji masing-masing.
- PR masih **OPEN**, pemeriksaan CI Analyze and test serta Agent review
  **SUCCESS**. Pengujian ini tidak melakukan merge.

Bukti run kedua: [hasil penguncian](pr83-currency-lock-e2e/run2/result.json),
[ringkasan regresi](pr83-currency-lock-e2e/run2/precision-summary.json),
[identitas chooser](pr83-currency-lock-e2e/run2/chooser-activity.txt),
[penolakan perubahan mata uang](pr83-currency-lock-e2e/run2/05-historical-currency-rejected.png),
dan [laporan IDR setelah pembukaan ulang](pr83-currency-lock-e2e/run2/09-reopened-report-idr.png).
Log lengkap run kedua berada di `build/currency-lock-e2e-run2/` dan
`build/currency-e2e/`. Percobaan persiapan yang dibatalkan diarsipkan pada
`build/currency-e2e-run2-cancelled/`; hasil percobaan tersebut tidak dihitung
sebagai kelulusan. Bukti run pertama tetap dipertahankan.

## Run pertama: target dan hasil

Pada 21 November 2026, pukul 21:44–21:46 WIB, **7 skenario Android lulus**
untuk PR [#83](https://github.com/iqbalmaulana03/pujangga-pos/pull/83),
head `ee62e8b979790542a5c3189b9b5c9349fcc26dc6`.
Durasi eksekusi tes perangkat: 1 menit 32 detik, di luar build/instalasi.
Regresi presisi mata uang juga **3 skenario lulus** pada 21:47–21:50 WIB,
sehingga total **10 skenario E2E lulus** pada revisi yang sama.
Perangkat fisik Redmi `2201116TG`, Android 13 / API 33, dengan Flutter 3.47.9
dan Dart 3.13.7. Identitas ADB tidak dicantumkan dalam laporan.

Kode aplikasi di `lib/`, `pubspec.yaml`, dan `pubspec.lock` identik dengan head
PR tersebut (`git diff --exit-code ee62e8b -- lib pubspec.yaml pubspec.lock`
lulus). Tambahan pengujian pada branch `test/83-currency-lock-e2e` hanya berupa
harness pengujian, runner, suffix paket debug, dan bukti ini. PR tidak di-merge
oleh pengujian ini.

## Cakupan dan bukti

| Skenario | Bukti yang diperiksa | Hasil |
| --- | --- | --- |
| Dataset keuangan kosong; profil bermodal nol | Pilih USD, SGD, IDR melalui dialog Pengaturan; simpan USD, buka ulang SQLite/provider, lalu simpan pajak | Lulus |
| Hanya item nonaktif | Ganti IDR ke USD/SGD ditolak; pajak tetap tersimpan | Lulus |
| Hanya transaksi voided | Ganti IDR ke USD/SGD ditolak walaupun tanpa katalog | Lulus |
| Hanya pengeluaran | Ganti IDR ke USD/SGD ditolak | Lulus |
| Hanya histori modal, modal saat ini nol | Ganti IDR ke USD/SGD ditolak | Lulus |
| Hanya modal awal bukan nol | Ganti IDR ke USD/SGD ditolak | Lulus |
| Checkout Rp100.000 melalui UI, lalu coba USD | Transaksi tersimpan; penolakan tidak mengubah pengaturan/data; detail historis, laporan, dan teks struk tetap IDR setelah pajak diubah serta SQLite/provider dibuka ulang | Lulus |

Kelima sumber pengunci diuji terpisah menggunakan fixture SQLite sintetis.
Pada setiap penolakan, seluruh tabel dibandingkan sebelum/sesudah dan harus
identik. Pesan penguncian harus muncul tanpa pesan sukses; penyimpanan pajak
11% dengan kode mata uang sama harus sukses. Penguncian diperiksa lagi
setelah SQLite dan provider ditutup/dibuka ulang. Ini bukan klaim pengujian
restart proses Android atau reboot perangkat.

Alur transaksi memakai aplikasi, router, controller, repository, dan plugin
SQLite asli. Pembayaran memakai label QRIS tanpa integrasi pembayaran eksternal.
Teks berbagi diobservasi melalui wrapper yang tetap memanggil `SharePlus`
asli. Host ADB mengonfirmasi foreground
`android/com.android.internal.app.MiuiChooserActivity`, lalu menekan Back.
Payload berbagi harus identik dengan struk sebelum percobaan perubahan,
tanpa simbol dolar. Seluruh tabel harus identik setelah berbagi dibatalkan.
Tidak ada struk yang dikirim dan tidak ada tangkapan layar target/kontak
menu berbagi yang disimpan.

Setelah pembukaan ulang SQLite, transaksi historis tetap Rp100.000,
pajak default tetap 11%, laporan tetap Rp100.000 dengan margin Rp60.000,
`PRAGMA integrity_check` menghasilkan `ok`, dan `foreign_key_check` kosong.

## Isolasi dan artefak

- Paket uji: `com.pujanggapos.pujangga_pos.pr83e2e`, diverifikasi dengan `aapt`
  sebelum instalasi. Runner memakai `--no-uninstall` dan tidak menjalankan
  `pm clear`, reset, atau uninstall terhadap aplikasi lain.
- Setiap kasus memakai path unik `cache/currency-lock-*/isolated.db` di sandbox
  paket uji. Identitas paket dan containment path diperiksa sebelum penulisan
  pertama. Semua tujuh direktori uji dibersihkan oleh teardown.
- Inventaris paket sebelum/sesudah membuktikan aplikasi yang sudah terpasang
  tetap ada. Ini bukti pelestarian paket, bukan pemeriksaan isi data aplikasi lain.
- APK suite penguncian: versi `1.2.5-debug`, versionCode `6`, SHA-256
  `58fb99846e02b4b41b6866653f471571be35a118afb546b0bbf80f98bb35505c`.
- [Hasil terstruktur](pr83-currency-lock-e2e/result.json),
  [identitas chooser](pr83-currency-lock-e2e/chooser-activity.txt), dan
  [identitas perangkat](pr83-currency-lock-e2e/device.json).
- Tangkapan layar: [dataset kosong memilih USD](pr83-currency-lock-e2e/01-empty-usd-success.png),
  [penolakan perubahan setelah transaksi](pr83-currency-lock-e2e/05-historical-currency-rejected.png),
  [detail historis IDR](pr83-currency-lock-e2e/06-history-detail-idr.png),
  [laporan setelah pembukaan ulang](pr83-currency-lock-e2e/09-reopened-report-idr.png).
- Log build dan run lengkap serta 13 screenshot tersedia lokal di
  `build/currency-lock-e2e-run1/`. Screenshot hanya diambil ketika paket uji
  berada di foreground. Data usaha dan invoice dalam bukti bersifat sintetis.
- `flutter analyze --no-pub --fatal-infos`: lulus tanpa temuan.

## Regresi presisi mata uang dan audit akhir

`integration_test/currency_precision_test.dart` yang fixture-nya berubah
dalam PR dijalankan melalui `tools/run_currency_e2e.py` pada perangkat yang sama.
Ketiga mata uang USD, SGD, IDR lulus dalam 2 menit 57 detik, menggunakan paket
terpisah `com.pujanggapos.pujangga_pos.pr63e2e` dan direktori SQLite sementara
unik. Untuk tiap mata uang, tes mengubah nama item melalui UI tanpa mengubah
harga jual/modal/grosir, menyimpan pajak 10%, menjalankan tiga checkout,
memeriksa laporan dan stok, lalu membuka ulang data. Total sembilan checkout
lulus, termasuk batas pembulatan USD/SGD `1.45 + 0.15 = 1.60`.

Setiap pembukaan ulang mengonfirmasi tiga transaksi, harga/stok/pengaturan,
`integrity_check=ok`, dan `foreign_key_check` kosong. Runner keluar dengan kode
0 dan memverifikasi inventaris aplikasi sebelumnya tetap ada.
[Ringkasan regresi](pr83-currency-lock-e2e/precision-summary.json) memuat
penanda kelulusan dan SHA-256 APK suite ini. Log/screenshot lengkap berada
lokal di `build/currency-e2e-run1-archive/` setelah diarsipkan sebelum run kedua.

Pemeriksaan ADB terpisah setelah kedua suite selesai tidak menemukan direktori
`cache/currency-lock-*` pada paket PR83 maupun `cache/currency-e2e-*` pada paket
PR63. Paket debug uji tetap terpasang; aplikasi lain tidak di-uninstall.
Tidak ditemukan kegagalan pada sepuluh skenario yang dijalankan.

Pembacaan ulang GitHub setelah pengujian memastikan PR #83 masih **OPEN** pada
head `ee62e8b979790542a5c3189b9b5c9349fcc26dc6`. Pemeriksaan
[Analyze and test](https://github.com/iqbalmaulana03/pujangga-pos/actions/runs/44798820030/job/136505294291)
serta Agent review berstatus SUCCESS untuk head tersebut. Pengujian ini tidak
melakukan merge atau deployment. Bukti dan harness disiapkan pada worktree
`pr83-e2e` untuk disertakan dalam PR.

## Menjalankan ulang

Dari worktree dengan SDK yang sesuai, jalankan:

```powershell
rtk proxy C:\tmp\puro\envs\security-patch\flutter\bin\flutter.bat pub get --enforce-lockfile
rtk proxy python tools/run_currency_lock_e2e.py --device <serial-adb> --flutter C:\tmp\puro\envs\security-patch\flutter\bin\flutter.bat --output build/currency-lock-e2e-run3
```

Runner mengaktifkan suffix paket khusus otomatis. Gunakan direktori output
baru untuk mempertahankan bukti eksekusi sebelumnya. Biarkan perangkat
terbuka dan jangan berinteraksi selama pengujian. Pengujian ini tidak
memperbaiki data yang sudah tercampur denominasi sebelum perbaikan #73.
