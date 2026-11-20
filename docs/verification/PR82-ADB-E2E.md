# PR #82 — Pengujian E2E Android melalui ADB

**Hasil: LULUS.** Revisi yang diuji: `24c9d9e06f24affca42945b5c4e2634b9ab70944`.

- PR: https://github.com/iqbalmaulana03/pujangga-pos/pull/82
- Perangkat nyata: Xiaomi model `2201116TG`, Android 13.
- Flutter 3.47.9 / Dart 3.13.7; APK debug dengan paket khusus `com.pujanggapos.pujangga_pos.pr82e2e`.
- Verifikasi UI dan rekonsiliasi host selesai: `2026-11-20T10:16:19.762153+00:00`.
- Verifikasi restart proses selesai: `2026-11-20T10:22:05.148428+00:00`.
- Seluruh 138 berkas sumber aplikasi dan pubspec dicocokkan dengan revisi PR. Kode bisnis tidak diubah; entrypoint pengujian dan suffix paket terpisah digunakan dalam worktree `test/82-scaled-arithmetic-e2e`.

## Skenario pada perangkat

Setiap kelompok berikut lulus untuk **USD, SGD, dan IDR**, total **33 skenario**. Fixture IDR memakai nominal 100 kali nominal USD/SGD, sehingga contoh pembayaran 0.30 menjadi Rp30.

| Kelompok | Bukti perilaku |
|---|---|
| Kuantitas dan penghapusan baris | UI menolak `0.1234`, menerima `0.001`; sepuluh pengurangan `0.1` dari `1` menghapus baris keranjang. |
| Akumulasi dan stok | UI `0.1 + 0.1 + 0.1` menghasilkan `0.3`; penjualan menghabiskan stok `0.3` tepat menjadi nol. |
| Pembayaran tepat | Harga `0.10 × 3`, bayar `0.30`, total `0.30`, kembalian nol. Pembayaran `0.29` mematikan CTA. Untuk USD, nominal `0.30` dimasukkan melalui perintah ADB ke IME Android. |
| Penjualan bertahap | Tiga transaksi `0.1` meninggalkan stok berturut-turut `0.2`, `0.1`, lalu `0`. |
| Overflow dan pemulihan | Draft `1e100` tetap aman saat tombol tambah/kurang dan penambahan item yang sama dijalankan; penyimpanan terblokir, data tidak berubah, dan input UI `1` memulihkannya. |
| Transaksi campuran | Produk dan jasa masing-masing `0.30`; diskon item `0.01`, diskon transaksi `0.09`, pajak 10% menghasilkan `0.05`, total `0.55`, dan komisi jasa `0.03`. Header dan pengeluaran cocok. |
| Void melalui UI | Konfirmasi void mengembalikan stok produk dan menghapus pengeluaran komisi; detail menampilkan status dibatalkan. |
| Stok dan batas pembulatan pada Android | Tambah stok sepuluh kali `0.1`, lalu kurangi sepuluh kali `0.1`, menghasilkan nol. Nilai positif/negatif tepat setengah unit dan sedikit di atas/bawahnya mengikuti pembulatan menjauhi nol. |
| Backup plaintext | Ekspor, inspeksi, restore ke database terpisah, dan seluruh baris cocok. |
| Backup terenkripsi | Ekspor/restore pada Android lulus; host mendekripsi AES-GCM/PBKDF2 secara independen dan mencocokkan seluruh tabel. |
| Pembukaan ulang SQLite dan aplikasi | Provider/aplikasi dibangun ulang setelah koneksi SQLite ditutup. Snapshot legacy `0.015` (IDR `1.5`) dibaca tanpa dihitung ulang; seluruh baris, integritas, dan foreign key tetap valid. |

UI, navigasi, checkout, struk, dan konfirmasi void memakai aplikasi asli. Pengaturan fixture, sebagian nominal diskon, penyesuaian stok tambahan, dan verifikasi angka memakai controller/data source asli pada Android. Pengujian ini tidak menggunakan database pengguna.

## Verifikasi independen dan restart proses

Host membaca kembali enam database SQLite (sumber dan hasil restore untuk tiga mata uang), enam backup, serta 18 screenshot perangkat. Tiap mata uang memiliki tujuh transaksi, 30 pergerakan stok, stok akhir barang berat/bagian nol, stok barang satuan 17, dan tidak ada pengeluaran komisi aktif setelah void. Pemeriksaan seluruh tabel, `integrity_check`, dan `foreign_key_check` lulus.

Tahap tambahan menggunakan entrypoint cold-start yang menjalankan `PujanggaPosApp` asli terhadap snapshot USD hasil pengujian perangkat. Snapshot dipindahkan kembali ke namespace uji dengan checksum SHA-256 yang sama. ADB menjalankan `am force-stop` dan `am start` dua kali. PID Android berbeda: `32209` dan `3659`. Pada kedua peluncuran, struk `0.30` ditampilkan, riwayat legacy tetap `0.015`, dan seluruh baris dibandingkan kembali secara independen dengan hasil transaksi awal.

## Bukti dan reproduksi

- [Ringkasan 33 skenario dan rekonsiliasi](pr82-adb-e2e/verified-result.json)
- [Bukti dua proses Android](pr82-adb-e2e/cold-start-verified.json)
- [Log hasil perangkat](pr82-adb-e2e/events.txt)
- [Identitas Git dan manifest sumber PR](pr82-adb-e2e/source-provenance.json)
- [Hash artefak lengkap](pr82-adb-e2e/artifacts-sha256.json)
- [Struk pembayaran USD tepat](pr82-adb-e2e/usd-exact-payment.png)
- [Struk pembayaran IDR](pr82-adb-e2e/idr-exact-payment.png)
- [Void SGD](pr82-adb-e2e/sgd-void-detail.png)
- [Struk setelah proses Android dimulai ulang](pr82-adb-e2e/cold-boot-2.png)

Ringkasan sumber mencantumkan Git tree/blob dan SHA-256 manifest lengkap; tautan commit bukti aslinya mempertahankan seluruh fingerprint per berkas. Artefak lengkap, database sintetis, dan backup tersedia lokal di `build/pr82-e2e-run3/`. Harness dapat dijalankan dari worktree ini dengan:

```powershell
rtk proxy python tool/run_scaled_arithmetic_e2e.py --device <serial-adb> --flutter C:/tmp/puro/envs/security-patch/flutter/bin/flutter.bat --output build/pr82-e2e-baru
rtk proxy python tool/run_scaled_cold_start.py --device <serial-adb> --flutter C:/tmp/puro/envs/security-patch/flutter/bin/flutter.bat --evidence build/pr82-e2e-baru
```

## Pembersihan dan batas verifikasi

Paket `pr82e2e` telah dihapus setelah kedua tahap. Inventaris paket Pujangga yang sudah ada tetap sama; aplikasi `pr80e2e` tidak diganti atau dihapus. Database sementara dihapus setelah skenario selesai. Semua profil, barang, dan karyawan pengujian bersifat sintetis.

Pengujian dilakukan pada satu perangkat fisik Android 13. Pengujian ini tidak mencakup upgrade instalasi produksi, matriks perangkat Android lain, printer, kamera/barcode, atau integrasi aplikasi eksternal. PR tetap terbuka untuk merge oleh pemilik repository.
