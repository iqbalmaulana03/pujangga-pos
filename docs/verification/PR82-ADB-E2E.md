# PR #82 — Pengujian ulang E2E Android melalui ADB

**Hasil: LULUS.** Kode aplikasi yang diuji: `6118359d1f4a7637ec8aa7286a9675ec7cb65428`.

Perangkat fisik Xiaomi `2201116TG`, Android 13; Flutter 3.47.9 / Dart 3.13.7.
Paket debug terisolasi: `com.pujanggapos.pujangga_pos.pr82e2e`.
Rekonsiliasi UI selesai `2026-11-20T16:01:38Z`; regresi native selesai
`2026-11-20T16:12:13Z`. Commit dokumentasi/runner setelah revisi ini tidak mengubah
kode aplikasi yang diuji. Seluruh 138 sumber aplikasi/pubspec dicocokkan dengan Git.

| Pemeriksaan | Hasil |
|---|---|
| UI USD, SGD, IDR | 33/33 skenario lulus; 18 screenshot |
| Kuantitas dan stok | 0.1 + 0.1 + 0.1 tepat 0.3; tiga penjualan pecahan menghabiskan stok; sepuluh pengurangan menghapus baris |
| Pembayaran tepat | USD 0.30 dimasukkan melalui ADB ke IME Android; kembalian nol; pembayaran kurang terblokir |
| Validasi | Batas tiga desimal, overflow yang dapat dipulihkan, dan pembulatan setengah menjauhi nol lulus |
| Transaksi campuran | Diskon item/order, pajak, komisi, pengeluaran, dan void cocok |
| Backup/restore | Enam database dan enam backup cocok; AES-GCM/PBKDF2 didekripsi independen di host |
| Restart proses | Dua PID berbeda, 7680 dan 9009; seluruh baris tetap sama |
| Regresi persistensi pada Android | 19/19 lulus; 38 snapshot SQLite dibandingkan di host |
| Stok legacy setelah restore | Edit katalog ke 0.200/0.300, penjualan, tambah/kurang/set stok menjaga saldo awal 0.1995 dan selisih aktual |
| Void legacy | Dua batas pembulatan, idempotensi, dan ekspor/restore ulang lulus |
| Penolakan stok kurang | Stok legacy 0.0005 tidak dapat menutup penjualan/pengurangan 0.001 |
| Pembersihan | Paket pr82e2e dihapus; inventaris aplikasi awal tetap sama |

UI, navigasi, checkout, struk, dan void memakai aplikasi asli. Fixture dan sebagian
angka diskon memakai controller/data source asli. Regresi tambahan menjalankan suite
persistensi yang sama dengan unit test pada SQLite Android; tidak seluruh kasus berupa
klik UI. Setiap database dibuktikan berada di cache namespace uji, terpisah dari data
pengguna. Host memeriksa seluruh tabel, integritas, foreign key, dan selisih Decimal.

Percobaan pertama suite tambahan berhenti saat instalasi dengan
`INSTALL_FAILED_USER_RESTRICTED`; belum ada test aplikasi yang dijalankan. Setelah
pengguna menyiapkan perangkat, pengulangan menjalankan seluruh 19 kasus hingga lulus.

## Bukti

- [33 skenario dan rekonsiliasi](pr82-adb-e2e/verified-result.json)
- [Dua restart proses](pr82-adb-e2e/cold-start-verified.json)
- [19 regresi dan 38 snapshot](pr82-adb-e2e/legacy-verified-result.json)
- [Log hasil perangkat](pr82-adb-e2e/events.txt)
- [Identitas sumber Git](pr82-adb-e2e/source-provenance.json)
- [SHA-256 bukti yang disertakan](pr82-adb-e2e/artifacts-sha256.json) (teks dinormalisasi CRLF ke LF)
- [Struk USD](pr82-adb-e2e/usd-exact-payment.png), [struk IDR](pr82-adb-e2e/idr-exact-payment.png), [void SGD](pr82-adb-e2e/sgd-void-detail.png)
- [Struk setelah restart](pr82-adb-e2e/cold-boot-2.png)

APK, database sintetis, backup, log lengkap termasuk percobaan instalasi pertama, dan
manifest SHA-256 seluruh 109 artefak tersedia lokal di `build/pr82-final-6118359/`.
Identitas Git dan hash manifest lengkap dicatat dalam provenance. Artefak lama tetap
tersedia dalam riwayat Git; bukti di direktori ini adalah hasil pengujian ulang terbaru.

## Reproduksi

Gunakan serial ADB dan path Flutter SDK sendiri, serta direktori hasil yang baru:

```powershell
rtk proxy python tool/run_scaled_arithmetic_e2e.py --device <serial> --flutter <flutter> --output build/pr82-ui-baru
rtk proxy python tool/run_scaled_cold_start.py --device <serial> --flutter <flutter> --evidence build/pr82-ui-baru
rtk proxy python tool/run_scaled_native_retest.py --device <serial> --flutter <flutter> --output build/pr82-native-baru
```

Jalankan cold-start setelah suite UI karena runner memakai APK dan snapshot dari tahap
tersebut. Runner native membangkitkan harness dari kasus persistensi yang sudah ada,
menyimpan salinannya bersama hasil, dan menghapus berkas harness sementara setelah lulus.
Jika gagal, harness dan paket uji dibiarkan untuk diagnosis; jangan menimpa data yang ada.

Verifikasi terbatas pada satu perangkat Android 13 dan alur PR #82. Upgrade produksi,
printer, kamera/barcode, serta integrasi aplikasi eksternal tidak dicakup.
