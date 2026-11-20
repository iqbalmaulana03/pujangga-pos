# Pengujian Android pembayaran finite

Gunakan Flutter sesuai `docs/CI-CD.md`, Python 3.12+, Android SDK, dan perangkat Android yang tampil sebagai `device` pada `adb devices -l`. Jalankan dari checkout PR setelah `flutter pub get --enforce-lockfile`.

```powershell
rtk proxy python tool/run_finite_payment_e2e.py --device <serial> --flutter <path-flutter.bat> --adb <path-adb.exe>
```

Runner memilih package `com.pujanggapos.pujangga_pos.pr80e2e` dengan `PUJANGGA_FINITE_E2E=1`, menjalankan integration test, menangani input nominal normal melalui ADB, mengambil screenshot, menarik artefak sintetis, dan merekonsiliasi SQLite di komputer. Path SDK dan serial perangkat tidak disimpan dalam kode.

**Selalu gunakan `--no-uninstall` sejak eksekusi Flutter pertama.** Runner sudah memasangnya. Flutter integration test secara default melakukan uninstall saat cleanup; sebelum APK pertama tersedia, identitas package dapat berasal dari namespace source dan belum mencakup suffix uji. Pengujian manual tanpa runner juga wajib memasang opsi ini. Jangan uninstall atau clear data package aplikasi harian untuk menjalankan suite ini.

Harness memverifikasi package cache dan path SQLite aktual sumber/tujuan sebelum seed atau restore. Semua provider memakai database sementara unik. Database kerja dibersihkan setelah test; package uji dan artefak sintetis dipertahankan. Output default berada di `build/e2e-80/` dan tidak masuk Git: log, dua screenshot, backup, salinan SQLite, hasil rekonsiliasi, dan checksum APK. Runner harus digunakan tanpa opsi Python `-O`, agar assertion bukti tetap aktif.

## Cakupan dan hasil perangkat

Pada 20 November 2026, kode aplikasi PR #80 revisi `62b47bd` lulus pada Redmi 2201116TG, Android 13/API 33:

- Tujuh penolakan UI: Infinity, -Infinity, NaN, overflow `1e309`, negatif, kosong, dan kurang bayar. Tombol simpan nonaktif dan submit controller ditolak.
- Dua puluh satu penolakan datasource SQLite Android, termasuk null pada total nol dan overflow subtotal, agregat, pajak, atau komisi. Seluruh baris pada 11 tabel backup tetap identik setelah penolakan.
- Koreksi setelah overflow, checkout barang+jasa, diskon, pajak, receipt, stok, dan komisi menggunakan aplikasi asli. Nominal normal diketik melalui ADB: total 19800, bayar 25000, kembalian 5200, stok barang 9, komisi 1800.
- Backup plaintext dan terenkripsi dibuat melalui service Android, diperiksa, dan di-restore ke database terpisah. Seluruh tabel cocok. Database ditutup/dibuka ulang; `integrity_check` serta rekonsiliasi independen salinan SQLite di komputer lulus.

Input berbahaya memakai test IME terdaftar untuk mensimulasikan paste. Input nominal normal memakai keyboard Android melalui ADB. Memasukkan editing state sintetis bersamaan dengan IME Android nyata dapat membuat keduanya tidak sinkron, sebagaimana didokumentasikan Flutter. Native share sheet dan file picker tidak termasuk cakupan suite ini.

## Catatan insiden eksekusi awal

Pada percobaan awal sebelum `--no-uninstall` dipasang, package rilis yang sebelumnya terpasang tidak ditemukan lagi. Pengguna mengonfirmasi tidak menghapus aplikasi dan datanya hanya data uji/kosong. Audit lifecycle Flutter menunjukkan cleanup dengan identitas package sebelum build sebagai kemungkinan penyebab; event uninstall package utama sudah tidak ada dalam buffer sehingga sebab spesifik tidak dapat dibuktikan langsung. Eksekusi akhir menonaktifkan uninstall otomatis. Package rilis belum dipasang ulang dan tidak ada restore data rilis yang dilakukan.
