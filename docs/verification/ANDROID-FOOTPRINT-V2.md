# Optimasi lanjutan storage dan pengukuran RAM

Tanggal: 3 November 2026 WIB. Mode implementasi lokal, sesuai permintaan pengguna.
Implementasi dan perbaikan review dikirim melalui PR #44. Tidak ada perubahan
versi, upload Play, atau rollout.

## Target dan baseline Play Store

- File tracked checkout awal tidak diubah di `release/1.2.3+4_apps`, commit `0e7cb8f`.
- Worktree tugas: `.worktrees/android-footprint-v2`, branch
  `perf/android-footprint-v2`, basis `a0a154e1541fa4435549806fbbb3bc19abaa3249`.
  Remote di-fetch sebelum pekerjaan; basis ini sama dengan rilis `1.2.4+5`.
- GitHub Actions run `41218104300` untuk `release/1.2.4+5_apps` sukses.
  Artefak rilis diunduh dan checksum AAB cocok dengan `release.json` CI:
  `4879f31cd2195dffeeb40a7e36baa7bd0d1a6d518f45ece937ddf0cd78d3af6c`.
- Perangkat Redmi 2201116TG, Android API 33, ARM64, density 440.
  Paket produksi `com.pujanggapos.pujangga_pos` terpasang dari
  `com.android.vending`, versionName `1.2.4`, versionCode `5`.
- Pemeriksaan layar Penyimpanan Android: **total 30,83 MB; ukuran aplikasi
  30,21 MB; data pengguna 618 KB; cache 471 KB**. Angka cache tidak dijumlahkan
  lagi dengan data pengguna. Ini memperjelas arti angka awal 30,83 MB.
- Empat split APK yang terpasang berjumlah 29.736.561 byte. Ukuran terpasang
  Android, ukuran berkas APK, AAB, dan unduhan merupakan metrik terpisah.

## Perubahan dan ukuran

Data tanggal `intl` produksi kini mendaftarkan `id` dan `en_US`; `id_ID` memakai
fallback Indonesia. Generator mengambil data dari dependency yang terkunci.
Tes membandingkan seluruh simbol dan skeleton tanggal kedua locale terhadap
CLDR milik `intl`, serta tanggal struk, waktu, dan nomor invoice. Tidak ada
perubahan format tampilan, fitur, dependensi, navigasi, atau skema database.

Build rilis dan workflow pengukuran memakai `--split-debug-info`. Informasi
diagnostik Dart disimpan di luar aplikasi, tanpa obfuscation. Workflow rilis
mengarsipkan simbol semua ABI dan checksum selama 90 hari. Simbol perlu
diarsipkan lebih lama selama versi masih digunakan; petunjuk di
[ANDROID-SIZE.md](../ANDROID-SIZE.md).

Baseline lokal dan hasil optimasi memakai Flutter 3.47.9 / Dart 3.13.7,
Java 17.0.19, lockfile identik, konfigurasi release dan signing debug pengukuran
yang sama. Baseline tanpa pemisahan simbol; kandidat memakai flag baru.
Bundletool 1.18.3 dan profil tetap ARM64/API 33/density 440/locale `id` identik.
AAB pengukuran tetap menggunakan application ID produksi dan tidak dipasang
di atas aplikasi Play. Paket QA menggunakan ID lain.

Saat review PR #44, pasangan build ukuran baseline dan kandidat diulang untuk
merekam SHA-256 lockfile mentah dan konfigurasi paket sebelum serta sesudah
masing-masing build. Keempat capture identik; baseline tidak lagi mengandalkan
hash yang kosong dari laporan historis. JSON menyertakan waktu capture, hash
source, dan checksum artefak hasil build. Source runtime kandidat tetap sama;
pengukuran RAM tidak diulang dan tetap memakai 60 sampel QA awal.

Hash lockfile mentah Windows adalah
`70449bcc95fcbd886082486654850cf3b8279233e15f9d6bc7d5be09867afc21`.
Hash setelah normalisasi CRLF menjadi LF adalah
`3e53413c6258cb7364cab2bad3ced5564171fcbea023f16ac368ceea4e6717f9`,
sama dengan blob Git baseline/kandidat dan lockfile CI Play. Perbedaan hash
mentah berasal dari line ending; isi dependency identik. Kedua fingerprint
disimpan agar provenance byte build dan perbandingan lintas OS dapat diperiksa.

| Metrik, byte desimal | Baseline lokal | Optimasi | Penghematan |
| --- | ---: | ---: | ---: |
| AAB unggahan | 67.736.895 | 63.378.297 | 4.358.598 |
| APK terpilih untuk perangkat | 29.564.277 | 28.319.093 | 1.245.184 (4,21%) |
| Estimasi unduhan bundletool | 13.250.843 | 12.569.058 | 681.785 (5,15%) |
| Kode Dart ARM64, tanpa kompresi | 8.192.904 | 6.947.720 | 1.245.184 |

Build antara awal (tidak diulang saat review) yang hanya memangkas data tanggal menghasilkan APK terpilih
29.433.205 byte: hemat 131.072 byte. Pemisahan simbol memberi penghematan
tambahan 1.114.112 byte. Pemeriksaan hash membuktikan **18/18 library native
engine/plugin dan aset model barcode identik**, selain library kode Dart yang
memang berubah. Dukungan ABI, minimum SDK, dan model scanner offline tetap.

Angka lokal tidak identik dengan split Play yang terpasang. Selisih pemrosesan
distribusi tidak diisolasi dalam audit ini. Ukuran aplikasi Android/Play setelah
optimasi belum diukur karena belum ada rilis baru; jangan mengonversi langsung
penghematan APK menjadi janji total penyimpanan Android tertentu.

## RAM pada sandbox QA

Paket baru `com.pujanggapos.pujangga_pos.footprintqa` diverifikasi belum ada
sebelum pemasangan; Android memberikan UID 10365 dan direktori data sendiri.
Entrypoint memeriksa path database berada di sandbox paket itu sebelum reset
atau seed. Database usaha pengguna tidak dibaca, di-reset, atau diisi fixture.

Instrumentasi identik sebelum/sesudah: release ARM64, HTTP loopback melalui
ADB forward, fixture kosong dan 1.000 item/10.000 transaksi. Keduanya memakai
logo sintetis PNG 4096×4096 untuk menguji beban gambar. Setiap fixture dijalankan
tiga kali dengan restart proses: startup, katalog dengan scroll, dua putaran
lima tab, riwayat dengan scroll, kembali Beranda, sepuluh kali buka/tutup kamera.
Fixture transaksi bertanggal Oktober 2026. Ini pengujian data sintetis, bukan
pengukuran konsumsi RAM database pengguna sehari-hari.

Median tiga pengulangan, satuan MiB. PSS/RSS mengikuti label TOTAL Android;
swap dilaporkan terpisah dalam JSON. Peak RSS memakai high-water mark proses.

| Fixture | Tahap | PSS sebelum → sesudah | RSS sebelum → sesudah |
| --- | --- | ---: | ---: |
| Kosong | Startup | 186,50 → 118,04 | 297,87 → 231,00 |
| Kosong | Katalog | 133,57 → 123,69 | 254,62 → 251,03 |
| Kosong | Riwayat | 160,83 → 151,07 | 281,88 → 278,51 |
| Kosong | Navigasi | 132,36 → 118,44 | 252,00 → 245,88 |
| Kosong | Setelah pemindai | 154,88 → 143,66 | 277,66 → 274,55 |
| Besar | Startup | 217,45 → 202,35 | 329,50 → 318,24 |
| Besar | Katalog | 157,38 → 151,53 | 278,66 → 275,90 |
| Besar | Riwayat | 170,94 → 154,62 | 292,73 → 279,00 |
| Besar | Navigasi | 153,60 → 142,38 | 273,59 → 266,67 |
| Besar | Setelah pemindai | 176,84 → 162,41 | 299,39 → 289,02 |

Median peak RSS pada tahap pemindai: fixture kosong 453,22 → 450,26 MiB;
fixture besar 497,05 → 493,56 MiB. Startup dan dekode masih menghasilkan alokasi
sementara besar. PSS startup fixture besar sesudah optimasi bervariasi
138,88–246,69 MiB; katalog juga memiliki satu sampel 214,38 MiB. Sampel ini
tidak membuktikan penurunan RAM dengan persentase seragam atau bebas leak
jangka panjang. Kontribusi masing-masing perubahan terhadap RAM belum diisolasi.
Heap retaining-path audit dan pagination SQL tidak dilakukan; tidak ada
perubahan RAM tambahan yang diterapkan berdasarkan dugaan.

## Verifikasi dan artefak

- `flutter analyze --fatal-infos --no-pub`: lulus.
- `flutter test --no-pub`: **99 tes lulus**. Suite database memakai SQLite FFI
  dengan direktori temporer; tes UI memakai provider/mock uji.
- Sepuluh tes Python lulus: empat tes simbolisasi dan enam tes laporan ukuran,
  termasuk penolakan simbol ABI parsial dan pembandingan fingerprint CRLF/LF.
  Kedua workflow dapat diparse. Validator juga lulus pada AAB kandidat aktual
  dengan simbol Dart lengkap untuk ARM, ARM64, dan x64.
- Build release AAB baseline, tanggal saja, dan optimasi final lulus. Laporan
  ukuran mencatat setiap library native, DEX, serta ukuran/hash file simbol.
- Decoder EAN-13 membaca fixture `5901234123457` pada paket terpisah
  `.footprintoffline` yang diverifikasi **tidak memiliki izin INTERNET**.
  Format `Selasa, 3 November 2026` juga diverifikasi pada release QA.
- `flutter symbolize` langsung pada SDK ini gagal karena decoder lama mencari
  ekspor isolate, sedangkan Dart menghasilkan `_kDartSnapshotText`. Helper
  repository memakai alamat virtual yang sudah tercantum dalam trace;
  pengujian exception QA memulihkan nama fungsi dan lokasi source dengan tepat.
  SDK tidak dimodifikasi. Trace mentah tidak disertakan dalam laporan.
- Client kamera paket QA: terbuka **1**, background **0**, resumed **1**,
  setelah ditutup **0**. Pemeriksaan terbatas 1.500 baris log terakhir paket QA
  tidak menemukan marker fatal, unhandled exception, SQLiteException, atau overflow.

Seluruh 60 sampel ringkas, rentang PSS, swap, peak RSS, checksum APK/AAB/simbol,
serta metadata tersedia di
[ANDROID-FOOTPRINT-V2-MEASUREMENTS.json](ANDROID-FOOTPRINT-V2-MEASUREMENTS.json).
Artefak lokal di `build/footprint-v2/` dan harness identik di `build/ram-audit/`
dalam worktree diabaikan Git. Tidak ada kredensial, nomor seri perangkat,
isi data usaha, atau stack trace mentah yang disalin ke laporan.

Kedua paket QA dan ADB forward port 18766 telah dihapus; forward lain
dipertahankan. Pemeriksaan independen setelah pembersihan memverifikasi
identitas Play `1.2.4+5` dan checksum keempat APK terpasang tetap sama.
Gradle dan manifest produksi dipulihkan ke isi checkout semula. Perubahan
implementasi tersedia pada branch tugas melalui PR #44;
file tracked checkout rilis awal tetap utuh. Folder `.worktrees/` yang
berisi worktree tugas terlihat sebagai entri untracked pada checkout awal.
Publikasi dan pengukuran ulang ukuran
terpasang dari Play menunggu otorisasi rilis terpisah.
