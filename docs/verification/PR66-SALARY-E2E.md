# E2E PR #66 — rekonsiliasi gaji dan konsistensi modal

Hasil: **LULUS**, 11 November 2026. Tiga skenario Android selesai dengan
`All tests passed!` dan exit code runner `0`. PR tidak di-merge oleh tes ini.

## Revisi, perangkat, dan isolasi

- Implementasi yang diuji: `c284c89892a4d7f2317cea24cfa643e57efc72e5`.
  Tambahan harness hanya mencakup integration test, runner, dan suffix paket debug;
  kode bisnis `lib/` tidak diubah untuk E2E.
- Redmi 2201116TG, Android 13; Flutter 3.47.9 / Dart 3.13.7 / Java 17;
  APK debug arm64. Run sukses berlangsung sekitar 2 menit 36 detik setelah instalasi.
- Paket `com.pujanggapos.pujangga_pos.pr66e2e` diverifikasi dari manifest APK
  sebelum instalasi. Runner menolak paket tes yang sudah ada dan menonaktifkan
  uninstall otomatis Flutter.
- SHA-256 APK yang diuji:
  `bf2295c361e076a8bd805a8bd1e6deb83cf0d66c3a28986f82458093f45bbdaa`.
- Setiap skenario memakai file SQLite baru di cache paket khusus. Path efektif
  diverifikasi dengan `PRAGMA database_list` sebelum fixture sintetis ditulis.
- Sesudah run, ketiga database dihapus, paket tes di-uninstall, dan path APK
  aplikasi utama serta `.debug` sama dengan inventaris sebelum run. Pemeriksaan
  ADB terpisah mengonfirmasi paket `.pr66e2e` sudah tidak terpasang.
  Database aplikasi pengguna tidak dibuka oleh harness.

## Fixture dan hasil

Setiap skenario dimulai dari profil bermodal Rp10.000.000, stok awal bernilai
Rp1.000.000, karyawan bergaji Rp1.000.000 efektif 15 Agustus 2026, dan karyawan
kedua yang baru efektif 1 Desember 2026. Tabel pengeluaran dan riwayat kompensasi
masih kosong, sehingga rekonsiliasi juga menguji pembentukan riwayat dari master
legacy/restore. Waktu acuan rekonsiliasi ditahan pada awal masing-masing skenario.

| Skenario pertama | Hasil akhir |
| --- | --- |
| Katalog → simpan stok → modal, tanpa dashboard/laporan sebelumnya | Lulus |
| Laporan tahunan → modal/validasi stok | Lulus |
| Dashboard → modal/validasi stok | Lulus |

Ketiga skenario menjalankan seluruh alur berikut melalui widget/router aplikasi
asli dan SQLite Android asli; hasil keuangan tidak dimock:

| Pemeriksaan | Hasil |
| --- | --- |
| Rekonsiliasi pertama | Tepat 4 gaji Agustus–November, total Rp4.000.000; tanggal pertama 15 Agustus; karyawan masa depan Rp0 |
| Modal dan kas sebelum pembelian | Total kapital Rp6.000.000, stok Rp1.000.000, sisa kas Rp5.000.000 |
| Penolakan stok sebelum laporan lama | Form menolak stok Rp6.000.000 dan tidak menyimpan item |
| Laporan tahunan | Pengeluaran Rp4.000.000; baris karyawan dan biaya tampil |
| Laporan lama lewat dialog rentang tanggal | Pilih 1–31 Agustus melalui mode input dialog asli; pengeluaran Rp1.000.000; seluruh baris pengeluaran tetap identik |
| Dashboard lalu validasi stok ulang | Kas tetap Rp5.000.000; stok Rp6.000.000 kembali ditolak; tidak ada gaji ganda |
| Kontrol positif stok | Stok senilai Rp2.000.000 berhasil disimpan lewat form; kas menjadi Rp3.000.000 |
| Penjualan melalui UI | QRIS Rp1.500.000 berhasil; satu penjualan tersimpan; stok item baru turun 2 → 1 |
| Modal setelah penjualan | Kas Rp4.500.000, stok Rp2.000.000, total kapital Rp6.500.000 |
| Buka ulang SQLite dan provider/router | Enam tabel identik; omzet Rp1.500.000 tetap tampil; gaji masih tepat 4; `integrity_check=ok`, `foreign_key_check` kosong |

Enam tabel yang dibandingkan penuh adalah `expenses`, `items`,
`sales_transactions`, `sales_transaction_items`, `stock_movements`, dan
`employee_compensation_periods`.

## Batas cakupan dan percobaan awal

Fixture profil, item awal, dan karyawan dibuat langsung di database sintetis;
tes ini tidak mencakup pengisian onboarding/karyawan lewat UI. Harness memakai
router dan tema produksi dengan entry route berbeda untuk menguji urutan baca;
inisialisasi startup normal tidak menjadi bagian skenario. Penggantian dependency
hanya untuk database disposable dan clock repository laporan. Pembelian stok,
filter tanggal, navigasi layar, dan checkout dilakukan lewat interaksi UI.

“Buka ulang” berarti melepas widget/provider/router dan menutup koneksi SQLite,
lalu membukanya kembali dalam proses integration test yang sama. Ini bukan
pengujian force-stop, restart OS, atau build release. QRIS adalah metode pencatatan
penjualan lokal; tidak ada pembayaran eksternal.

Percobaan pertama berhenti pada kesalahan harness: tombol konfirmasi dialog
tanggal mode input adalah `OK`, bukan `Save`. Setelah finder diperbaiki, ketiga
skenario diulang dari database kosong dan semuanya lulus. Tidak ada perubahan
logika aplikasi untuk mendapatkan hasil sukses.

## Bukti dan jalankan ulang

- [Ringkasan runner, identitas APK, dan kejadian verifikasi](pr66-salary-e2e/result.json)
- [Gaji empat bulan di laporan tahunan](pr66-salary-e2e/capital-annual.png)
- [Laporan Agustus](pr66-salary-e2e/capital-historical.png)
- [Penolakan stok setelah laporan lama](pr66-salary-e2e/capital-rejected-after-old-report.png)
- [Penjualan QRIS](pr66-salary-e2e/capital-receipt.png)
- [Laporan setelah buka ulang](pr66-salary-e2e/dashboard-reopened-report.png)

Screenshot diperiksa dan hanya berisi aplikasi tes dengan data sintetis.
Serial perangkat, data pengguna, kredensial, dan dump sistem lengkap tidak
disertakan dalam bukti. Log lengkap tersedia lokal di `build/pr66-e2e/run.log`.

```powershell
rtk proxy python tools/run_salary_e2e.py --device <serial> --flutter <path-ke-flutter.bat>
```

Gunakan perangkat ADB terotorisasi dan terbuka, Flutter sesuai `pubspec.yaml`,
Java 17, serta Android SDK. Jalankan satu tes perangkat pada satu waktu.
