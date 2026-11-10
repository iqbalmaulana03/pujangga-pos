# E2E PR #64 — batas restore

Hasil: **LULUS**, 10 November 2026, Redmi Note 11 Pro (2201116TG), Android 13.
Run perangkat berakhir dengan `All tests passed!`, exit code runner `0`, dan
dua pemilihan file native berhasil. PR tidak di-merge oleh pengujian ini.

## Revisi dan isolasi

- Implementasi aplikasi yang diuji: `be9b2af72c246bebe52be321405f8377289ba8a1`.
- Revisi harness: `478a6c1a0965680cf986cea1d5eb42d76c93fd22`; perubahan sejak
  implementasi hanya tes, runner, dan suffix paket debug khusus.
- Flutter 3.47.9 / Dart 3.13.7 / Java 17; APK **debug** arm64.
- APK SHA-256: `79e5485447d4de142a7ba40b4370a9a82b4cbdab3d7721688276a1d08dc5b1d9`.
- ID APK diverifikasi sebelum instalasi: `com.pujanggapos.pujangga_pos.pr64e2e`.
  Paket ini tidak terpasang sebelum run. Uninstall otomatis Flutter dimatikan.
- SQLite menggunakan file baru di cache paket khusus. Tes memeriksa path efektif
  dengan `PRAGMA database_list` sebelum mengisi data sintetis.
- Setelah run, path APK aplikasi utama dan `.debug` sama dengan sebelum run.
  Paket tes dan folder bersama milik runner telah dihapus; pemeriksaan ADB
  terpisah juga mengonfirmasi keduanya tidak ada. Tidak ada data aplikasi utama
  yang dibaca atau diubah oleh tes.

## Skenario dan hasil

| Skenario | Hasil yang diverifikasi |
| --- | --- |
| Transaksi UI | Tambah PR64 Kopi, checkout QRIS Rp10.000; SQLite menyimpan satu penjualan dan stok turun 10 → 9 |
| Ukuran | File 20.971.521 byte dipilih melalui DocumentsUI Android dan ditolak sebelum dialog konfirmasi |
| Kedalaman | 100.000 array bersarang ditolak |
| Panjang teks | 65.537 unit UTF-16 ditolak |
| Jumlah baris | 50.001 objek baris ditolak |
| Kompleksitas | Array lebar 2.000.009 byte melewati anggaran pemindaian dan ditolak |
| Keutuhan penolakan | Semua kasus memakai kode `backup_limit_exceeded`; seluruh tabel backup dan `sqlite_sequence` identik sebelum/sesudah |
| Validasi setelah inspeksi | Kandidat valid dimodifikasi menjadi tanggal rusak sebelum konfirmasi; restore menolak dan seluruh data tetap identik |
| Kontrol positif besar | File tepat 20.971.520 byte dipilih melalui DocumentsUI; 5.001 item dan total 5.006 record mencapai dialog konfirmasi. Profil aktif belum berubah sebelum konfirmasi |
| Restore nyata | Konfirmasi mengganti profil aktif dengan profil backup, mempertahankan tanggal transaksi dan stok 9; `integrity_check=ok`, `foreign_key_check` kosong |
| Baca sesudah restore | UI riwayat, detail transaksi, dan laporan harian menampilkan satu penjualan, omzet Rp10.000 |
| Buka ulang | Widget/provider dibuat ulang dan koneksi SQLite dibuka ulang; seluruh baris identik, riwayat/detail/laporan tetap terbaca |

Backup besar berisi 5.001 baris item dengan kolom asli, metadata sintetis berupa
240 string masing-masing 65.536 karakter, dan whitespace hingga tepat 20 MiB.
Ini menguji decode, normalisasi, dan validasi ribuan baris, serta string besar
yang masih diizinkan. Ini bukan dataset dengan 50.000 baris valid; batas baris
diuji terpisah dengan input berlebih.

## Respons UI dan memori

Probe mulai setelah pemilih file mengembalikan path, dan berhenti ketika
controller inspeksi selesai. Waktu transfer/pemilihan native dan waktu restore
SQLite tidak termasuk interval inspeksi. Selama interval itu, timer 10 ms
mencatat kontinuitas event loop dan callback `FrameTiming` mencatat frame.

| Input | Inspeksi (ms) | Tick timer | Jeda timer maksimum (ms) | Frame tercatat |
| --- | ---: | ---: | ---: | ---: |
| Melebihi byte | 101 | 1 | 86 | 1 |
| Terlalu dalam | 232 | 2 | 219 | 1 |
| Teks berlebih | 192 | 1 | 190 | 0 |
| Baris berlebih | 162 | 3 | 137 | 1 |
| Kompleksitas berlebih | 590 | 40 | 108 | 6 |
| Backup kecil valid | 365 | 16 | 113 | 4 |
| Backup valid tepat 20 MiB | 1.972 | 180 | 51 | 11 |

Semua interval memenuhi pemeriksaan jeda timer di bawah 250 ms. Pada kontrol
20 MiB, build frame terlama 5.757 µs dan raster terlama 16.842 µs. UI tetap
memproses timer dan frame selama inspeksi. Jumlah frame ini bukan FPS; pompa
frame dari integration test dan batching callback memengaruhi pencatatan.
Input singkat dapat selesai tanpa callback frame tercatat.

Runner mengambil 237 sampel `dumpsys meminfo` khusus proses tes, dengan PSS
tertinggi 523.319 KiB (sekitar 511 MiB). Angka ini adalah puncak **seluruh run
debug**, termasuk framework tes, pembuatan/penyimpanan fixture 20 MiB, pemilih
file, inspeksi, dan restore. Ini bukan biaya memori parser saja atau profil
rilis. Tidak ada crash/OOM pada run ini. Hasil tidak menjamin performa seluruh
perangkat Android atau input yang tidak diuji.

## Jalankan ulang

```powershell
rtk proxy python tools/run_restore_validation_e2e.py --suite limits --device <serial> --flutter <path-ke-flutter.bat>
```

Runner memerlukan Flutter yang memenuhi `pubspec.yaml`, Java 17, Android SDK,
Python, serta ADB terotorisasi dan perangkat terbuka. Jangan menjalankan bersamaan
dengan tes perangkat lain. Jika `.pr64e2e` sudah terpasang, runner berhenti agar
tidak menimpa paket milik run lain. Mode default `--suite validation` tetap
menjalankan regresi PR #62 dengan paket `.pr62e2e`.

## Bukti tersimpan

- [Ringkasan runner dan identitas APK](pr64-restore-limits-e2e/result.json)
- [Metrik inspeksi](pr64-restore-limits-e2e/inspection-metrics.json)
- [Sampel memori proses tes](pr64-restore-limits-e2e/memory.json)
- [Kejadian verifikasi](pr64-restore-limits-e2e/events.txt)
- [Pesan penolakan byte](pr64-restore-limits-e2e/01-byte-limit-rejected.png)
- [Konfirmasi backup besar](pr64-restore-limits-e2e/02-valid-large-confirmation.png)
- [Laporan setelah buka ulang](pr64-restore-limits-e2e/04-reopened-report.png)

Screenshot diperiksa dan hanya berisi aplikasi tes dengan data sintetis.
Serial perangkat, nama file pengguna lain, isi database utama, dan dump
hierarki pemilih file tidak disertakan dalam bukti.
