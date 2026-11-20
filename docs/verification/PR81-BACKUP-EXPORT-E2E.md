# E2E PR #81 — kontrak ekspor backup

Hasil: **LULUS**, 20 November 2026, Redmi Note 11 Pro / 2201116TG,
Android 13, melalui perangkat ADB terotorisasi. Dua suite perangkat selesai
dengan `All tests passed!` dan exit code `0`. Rekonsiliasi independen di komputer
juga lulus. PR tidak di-merge oleh pengujian ini.

## Revisi dan isolasi

- Kode aplikasi: `57f6146b1d33b32335b3ecbfcdd3a4cec3dad853`, head PR saat run.
  Perubahan tambahan hanya harness, suffix paket debug, runner, dan laporan;
  kode `lib/` tidak diubah untuk pengujian ini.
- Flutter 3.47.9 / Dart 3.13.7, Java 17, APK debug Android.
- Paket UI recovery: `com.pujanggapos.pujangga_pos.issue56e2e`.
  Paket kontrak ekspor: `com.pujanggapos.pujangga_pos.pr81e2e`.
- Kedua paket belum terpasang sebelum run. Manifest APK diperiksa sebelum
  instalasi; setiap pemanggilan `flutter test` memakai `--no-uninstall`.
- Database sumber dan tujuan memakai file berbeda dalam cache paket khusus.
  Suite kontrak memeriksa `PRAGMA database_list` sebelum mengisi fixture.
- Inventaris awal hanya berisi paket uji PR #80. Kedua paket milik run ini
  dihapus setelah bukti dikumpulkan; inventaris ADB akhir kembali sama dengan
  inventaris awal. Paket PR #80 dipertahankan.

## Skenario dan hasil

| Skenario | Bukti yang diverifikasi |
| --- | --- |
| Snapshot berlebih dari UI | Footer 65.537 unit menyebabkan restore batal; pesan menyatakan data aktif belum diganti; seluruh tabel identik dan tidak ada recovery point baru |
| Restore dan recovery UI | Backup lama mengembalikan stok 10 tanpa penjualan; setelah provider/aplikasi dibuat ulang, snapshot terenkripsi memulihkan satu penjualan/detail dan stok 9; foreign key bersih |
| Reset UI | Membatalkan reset/ekspor mempertahankan penjualan; reset eksplisit menghapus data sintetis dan snapshot, lalu kembali ke setup |
| Ekspor plaintext dan terenkripsi | Kedua file lolos inspeksi, restore ke database terpisah, perbandingan seluruh tabel dan byte logo, serta penutupan/pembukaan ulang SQLite |
| Batas parsing | Kedua format menolak ukuran file, total baris, token, kedalaman, dan string berlebih; tabel, `sqlite_sequence`, backup sebelumnya, dan daftar file tetap sama |
| Overhead enkripsi | Plaintext sekitar 16,2 MB masih lolos anggaran payload, tetapi envelope akhir di atas 20 MiB ditolak sebelum publikasi |
| Kegagalan file I/O | Injeksi kegagalan tulis, inspeksi byte tersimpan, dan rename pada kedua format tidak meninggalkan file final parsial; staging terenkripsi hanya menerima ciphertext |
| Dataset SQLite nyata | 50.003 baris gabungan, representasi payload 9.729.739 byte termasuk logo, ditolak pada kedua format tanpa perubahan data/file |
| Rekonsiliasi independen | Python `cryptography` mengautentikasi/dekripsi ekspor; tabel dan logo cocok dengan plaintext. SQLite komputer membandingkan seluruh tabel hasil restore; `integrity_check=ok`, `foreign_key_check` kosong |

Suite UI selesai dalam sekitar 73 detik; suite kontrak dalam sekitar 79 detik,
di luar build/instalasi. Suite kontrak mencatat 20 checkpoint terverifikasi.

## Bukti dan batas interpretasi

- [Hasil UI recovery dan checksum APK](pr81-backup-export-e2e/recovery-result.json)
- [Hasil kontrak, checksum APK/harness, dan rekonsiliasi](pr81-backup-export-e2e/contract-result.json)
- [Inventaris cleanup independen](pr81-backup-export-e2e/cleanup.json)
- [Cadangan pemulihan setelah aplikasi dibuat ulang](pr81-backup-export-e2e/recovery-settings.png)
- [Dialog reset sesudah pemulihan snapshot](pr81-backup-export-e2e/recovery-reset.png)

Screenshot telah diperiksa dan hanya menampilkan aplikasi uji. Serial perangkat,
isi aplikasi lain, dan log mentah tidak dipublikasikan. Bukti lengkap lokal ada di
`build/pr81-e2e/`, termasuk backup sintetis, salinan SQLite, arsip perangkat, dan log.

Pemilih file suite UI menggunakan fixture deterministik. Native DocumentsUI dan
share sheet tidak diuji dalam run ini. Kegagalan file I/O disimulasikan pada
operasi file nyata; ini bukan pengujian disk penuh atau mati listrik. Dataset
50.003 baris dapat mencapai batas kompleksitas sebelum batas baris; gate baris
diuji terpisah dengan fixture 50.001 objek yang lebih kecil. Tidak ada klaim
performa/memori rilis atau jaminan seluruh perangkat Android.

## Jalankan ulang

Pasang Python 3.12+ dengan `cryptography`, Java 17, Android SDK, dan Flutter
sesuai proyek. Jangan jalankan bersamaan dengan tes perangkat lain. Runner
menolak paket `.pr81e2e` yang sudah terpasang agar tidak menimpa run lain.

```powershell
rtk proxy python tool/run_backup_export_e2e.py --device <serial> --flutter <path-flutter.bat>
```

Untuk suite UI recovery, set `PUJANGGA_RECOVERY_E2E=1` pada environment proses
dan jalankan Flutter yang sama dengan `test --no-pub --no-uninstall -d <serial>
integration_test/recovery_backup_test.dart`. Pastikan `.issue56e2e` belum
terpasang dan verifikasi ID APK debug sebelum instalasi. Runner kontrak
mempertahankan paket dan artefak sintetis untuk inspeksi; cleanup hanya boleh
menarget paket yang terbukti dibuat oleh run sendiri.
