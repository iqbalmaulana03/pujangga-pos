# E2E backup PR #60 — 9 November 2026

Hasil: **lulus untuk skenario backup snapshot pada revisi `218477b597b2896fa07ca1cce3a67522af4497fe`**. PR masih terbuka dan tidak di-merge dalam pekerjaan ini. Revisi head diverifikasi kembali setelah pengujian dan tidak berubah.

## Target dan isolasi

- Perangkat fisik Redmi 2201116TG, Android 13; Flutter 3.47.9 / Dart 3.13.7.
- Checkout terpisah `.worktrees/pr60-e2e`, berdasarkan revisi PR di atas.
- Tidak ada perubahan kode aplikasi dalam `lib/`. Tambahan hanya harness Dart, runner Python, dokumen ini, serta konfigurasi suffix paket debug khusus `.pr60e2e`. Suffix debug standar tetap `.debug`; runner mengaktifkan paket khusus melalui environment `PUJANGGA_BACKUP_E2E=1` pada kedua subprocess build dan test.
- Manifest APK diverifikasi sebelum peluncuran: `com.pujanggapos.pujangga_pos.pr60e2e`. Flutter dijalankan dengan `--no-uninstall`; runner tidak menjalankan clear-data atau uninstall.
- Dua file SQLite memakai path eksplisit di direktori sementara baru dalam cache paket uji. Path diperiksa sebelum database dibuka. Fixture profil usaha, barang, dan stok awal 10 seluruhnya sintetis.
- Teardown menghapus direktori database milik tes. Inventaris ADB terpisah setelah tes mengonfirmasi direktori `backup-e2e-*` sudah tidak ada; cache `share_plus` dan paket uji tetap ada.
- Paket debug yang sudah terpasang tetap ada. Paket produksi tidak ada pada awal runner, lalu muncul selama tes ketika aplikasi uji juga berpindah ke latar belakang. Setelah pengguna mengonfirmasi HP dapat dipakai, activity uji yang masih hidup dikembalikan ke depan tanpa memulai ulang tes. Paket produksi ada pada inventaris akhir; data paket produksi tidak dibuka atau direkonsiliasi oleh pengujian ini.

## Bukti perilaku

| Skenario | Hasil terverifikasi |
| --- | --- |
| Backup dijeda sesudah pembacaan `items`; checkout QRIS Rp10.000 dimulai melalui UI hingga mencapai antrean transaksi SQLite Android | Setelah pembacaan dilanjutkan, checkout berhasil dengan satu penjualan dan stok 9. Backup konkuren direstore ke database sementara lain dan berisi stok 10 tanpa penjualan. Tidak ada campuran keadaan. |
| Tombol `Cadangkan Data` setelah penjualan | File JSON nyata dibuat, semua tabel backup tersedia, satu penjualan tercatat. Restore ke database lain menghasilkan stok 9 dan histori konsisten. |
| Bagikan backup | Host mengamati `android/com.android.internal.app.MiuiChooserActivity`, mengambil screenshot, lalu mengirim Android Back. Tidak ada penerima atau tujuan berbagi dipilih. |
| Kegagalan baca setelah pembacaan nyata `sales_transaction_items` | UI menampilkan `Gagal mencadangkan data`; provider direktori ekspor tidak dipanggil lagi. Tidak ada ekspor sukses tambahan dan ledger aktif tidak berubah. |
| `Pulihkan Data` dan dialog konfirmasi, backup sebelum penjualan | UI kembali ke aplikasi, stok SQLite 10, nol header/detail penjualan; screenshot halaman Stok menampilkan 10 Pcs dan nilai aset Rp40.000. |
| `Pulihkan Data` dan dialog konfirmasi, backup setelah penjualan | Stok SQLite 9, satu header/detail penjualan, saldo sama dengan movement terakhir dan jumlah seluruh perubahan stok. |
| Lepas seluruh widget/provider, tutup dan buka ulang SQLite, jalankan kembali aplikasi | Satu penjualan tetap ada. Halaman Stok menampilkan 9 Pcs dan nilai aset Rp36.000. `PRAGMA integrity_check` bernilai `ok`; `foreign_key_check` kosong. |

Pemilihan file Android diganti dengan pemilih deterministik yang mengembalikan path file sintetis milik tes. Parsing file, validasi schema, dialog konfirmasi, controller, penyimpanan dan restore memakai implementasi aplikasi asli. Backup konkuren dimulai melalui controller nyata; checkout dimulai melalui UI. Penghalang baca dan kegagalan baca hanya berada pada wrapper executor harness. Fixture setup/katalog diisi langsung melalui SQLite. Hasil ini tidak mencakup navigasi pemilih dokumen Android, penerima berbagi, setup/katalog melalui UI, atau restart proses Android; reopen mencakup widget/provider aplikasi dan koneksi database baru.

## Pelaksanaan dan artefak

Run pertama yang lulus selesai sekitar 14:10 WIB, exit code 0, `1 passed`. Waktu tes 2 menit 13 detik termasuk jeda saat aplikasi berada di latar belakang. Analisis statis seluruh proyek/harness bersih sebelum run dan file harness diperiksa ulang setelah koreksi kondisi tunggu. CI `Analyze and test` dan review pada revisi `218477b` juga sukses.

Setelah konfigurasi paket dirapikan agar diaktifkan oleh runner, seluruh E2E dijalankan ulang pada 14:17 WIB: `1 passed` dalam 30 detik, exit code 0. Seluruh checkpoint snapshot konkuren, backup UI, chooser native, kegagalan baca, dua restore UI dan reopen kembali lulus. Inventaris paket produksi/debug sama sebelum dan sesudah run; pemeriksaan ADB terpisah mengonfirmasi direktori database sementara sudah terhapus. Bukti pengulangan tersimpan di `build/backup-e2e-configured/`; SHA-256 APK pengulangan: `4e4ba4f93df44fc19d48248e1f6c72413754b25ac4f4a78d5041f4bc977c6795`.

Tanpa environment khusus, task Gradle `:app:processDebugMainManifest` juga berhasil dan manifest debug diperiksa tetap memakai `com.pujanggapos.pujangga_pos.debug`. Format Dart, kompilasi sintaks runner Python, dan pemeriksaan whitespace Git lulus.

Percobaan awal berhenti karena harness membaca nilai backup lama sebelum operasi UI kedua selesai. Skenario konkuren sudah lulus pada percobaan itu. Kondisi tunggu diperbaiki agar menunggu path file baru dan status selesai; kode produk tidak diubah. Log awal dipertahankan di `build/backup-e2e-initial-harness-failure/`.

Runner final:

```powershell
rtk proxy python tools/run_backup_e2e.py --device DEVICE_SERIAL --flutter C:\tmp\puro\envs\security-patch\flutter\bin\flutter.bat
```

Jalankan `flutter pub get --enforce-lockfile` terlebih dahulu dengan SDK yang sesuai. Runner mengaktifkan suffix debug `.pr60e2e` otomatis dan menolak APK dengan application ID berbeda sebelum menjalankan tes. Opsi `--output build/backup-e2e-NAMA_RUN` menyimpan bukti pengulangan dalam direktori berbeda. Jangan melakukan navigasi atau instalasi lain di HP selama tes berjalan.

Artefak lokal di `build/backup-e2e/`: `run.log`, `build.log`, `apk-package.txt`, `package-inventory.txt`, `share-activity.txt`, `receipt.png`, `native-share.png`, `restored-before-sale.png`, dan `restored-after-reopen.png`.

SHA-256 APK final setelah build oleh test runner: `79fe1bd1b7347aabf970651af5a2386f582e0f6376b1c80d420c2f7481c97f63` (`tested-apk.sha256`). `apk.sha256` mencatat preflight build dan bukan acuan APK final.

Tidak ada kredensial, data pelanggan, atau data usaha nyata pada fixture. Harness dan laporan disiapkan untuk disertakan pada branch PR #60; APK, database, screenshot, dan log mentah tetap lokal di direktori build yang diabaikan Git.
