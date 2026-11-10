# Tes end-to-end validasi restore

Hasil verifikasi 10 November 2026 pada Redmi Note 11 Pro / Android 13,
Flutter 3.47.9 / Dart 3.13.7: skenario perangkat lulus, dua pemilihan file native
berhasil, paket utama tidak berubah selama run akhir, dan cleanup paket/folder
tes terverifikasi. Suite host 175 tes dan analisis statis juga lulus.

Regresi issue #49 diuji pada perangkat Android melalui
`integration_test/restore_validation_test.dart`. APK debug khusus memakai ID
`com.pujanggapos.pujangga_pos.pr62e2e`, sehingga tidak menggantikan aplikasi
utama atau APK debug biasa.

## Jalankan

Gunakan Flutter/Dart yang memenuhi `pubspec.yaml`, Java 17, Android SDK, Python
3, serta satu perangkat ADB yang sudah diotorisasi dan tidak terkunci.

```powershell
rtk proxy flutter pub get
rtk proxy adb devices -l
rtk proxy python tools/run_restore_validation_e2e.py --device <serial>
```

Jika SDK Flutter yang sesuai belum ada di PATH, tambahkan
`--flutter <path-ke-flutter>`; lokasi ADB juga dapat ditentukan dengan `--adb`.
Runner menetapkan `PUJANGGA_RESTORE_E2E=1` hanya pada proses anak build/test dan
mengaktifkan `PR62_NATIVE_PICKER=true`. Test berhenti sebelum mutasi database
jika direktori cache bukan milik paket khusus tersebut.

Runner melakukan prebuild dan memeriksa ID APK memakai `aapt2`, lalu menjalankan
Flutter test dengan `--no-uninstall`. Jangan menjalankan tes perangkat dari
checkout bersih dengan uninstall otomatis: Flutter dapat menyimpan ID namespace
utama sebelum build pertama dan memakai ID lama itu saat teardown. Cleanup
runner hanya menghapus paket `.pr62e2e` secara eksplisit dan memverifikasi path
APK aplikasi utama tidak berubah. Gunakan `--aapt2 <path-ke-aapt2>` bila lokasi
Android SDK tidak dapat ditentukan dari environment atau `android/local.properties`.

Runner menyalin dua file sintetis ke folder unik miliknya di penyimpanan bersama Android
dan memilihnya lewat DocumentsUI asli menggunakan ADB/UIAutomator. File lain
tidak dibaca atau dipilih; XML pemilih file tidak dicatat ke log. Runner mengenali
label navigasi Indonesia dan Inggris. Pastikan aplikasi lain tidak mengambil
fokus selama pengujian.

## Bukti yang diperiksa

- Transaksi QRIS dibuat dari UI; SQLite Android menyimpan satu transaksi,
  satu detail, dan stok turun dari 10 ke 9.
- Backup asli diekspor menggunakan service aplikasi. Salinannya dimodifikasi
  menjadi tanggal rusak, tanggal kalender overflow, metode pembayaran tidak
  dikenal, kuantitas nol, dan total yang tidak konsisten.
- File bertanggal rusak dipilih melalui pemilih file Android asli. Semua varian
  invalid ditolak sebelum dialog konfirmasi. Seluruh tabel backup dan
  `sqlite_sequence` dibandingkan dengan snapshot sebelum penolakan.
- Kandidat yang valid saat inspeksi dimodifikasi sebelum konfirmasi UI. Restore
  memvalidasi ulang dan menolak kandidat, tanpa mengubah data aktif.
- Backup valid schema terkini juga dipilih melalui pemilih file Android asli.
  Restore mengembalikan profil yang sengaja dibedakan dari backup. Backup schema
  12, 13, 14, dan 15 kemudian dipulihkan melalui dialog UI yang sama.
- Setelah setiap restore, tes memeriksa tanggal asli, stok 9, detail transaksi,
  `integrity_check`, `foreign_key_check`, serta halaman riwayat, detail, dan
  laporan harian: satu transaksi dengan omzet Rp10.000.
- Tree aplikasi/provider dibuat ulang dan koneksi SQLite dibuka ulang. Semua
  baris tetap identik, riwayat dan laporan masih terbaca. Ini pengujian buka
  ulang tree aplikasi/database, bukan simulasi process death Android.

Kasus invalid tambahan dan schema lama memakai pemilihan file deterministik;
parsing, controller, validator, konfirmasi UI, restore, navigasi, provider, dan
SQLite selalu memakai implementasi aplikasi sebenarnya.

## Artefak dan cleanup

Runner menyimpan log, screenshot, fixture sintetis, hash APK, dan hasil terstruktur
di `build/pr62-e2e/` (tidak dimasukkan ke Git). `result.json` harus menunjukkan
`exit_code: 0` dan `native_file_selections: 2`; log harus berakhir dengan
`All tests passed!` serta marker cleanup.
Field `main_package_unchanged`, `test_package_removed`, dan
`shared_folder_removed` juga harus bernilai `true`. Hasil akhir baru ditulis
setelah cleanup dan pemeriksaan paket selesai.

Test membuat database di subdirektori cache unik dan membuktikan path efektif
lewat `PRAGMA database_list` sebelum menjalankan alur. Teardown menghapus database
dan fixture privat. Runner menghapus hanya file/folder bersama dan dump UI
yang dibuatnya sendiri, kemudian memverifikasi folder tersebut sudah tidak ada.
Runner mengelola penghapusan APK tes dengan ID paket eksplisit. Periksa kembali
daftar paket ADB dan metadata aplikasi utama setelah pengujian.
