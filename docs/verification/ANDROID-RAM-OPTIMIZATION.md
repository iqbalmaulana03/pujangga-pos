# Verifikasi optimasi RAM Android

Tanggal: 31 Oktober 2026. Mode `implement`, sesuai permintaan pengguna; perubahan lokal, belum dipublikasikan.

Checkout `build/size-optimization`, branch `perf/reduce-android-download`, basis `df08f4bf7aa22ea0cc68ca44266f6f5a09f8c765`. Optimasi ukuran unduhan sebelumnya tetap dipertahankan. Checkout rilis `release/1.2.3+4_apps` tidak diubah.

## Implementasi

- Thumbnail katalog/transaksi didekode sesuai ukuran tampilan dan DPR, dikelompokkan per 64 piksel agar cache key dapat dibagi. `ResizeImagePolicy.fit` mempertahankan rasio sumber; `BoxFit.cover` mempertahankan tampilan kartu. Kegagalan gambar menampilkan placeholder.
- Logo profil 32 logical pixels memakai dekode sesuai DPR, menggantikan dekode gambar resolusi penuh.
- Cache Flutter dibatasi 24 MiB / 100 entri. Ini batas cache, bukan batas RAM seluruh proses atau gambar yang masih digunakan widget.
- Katalog/kategori memakai satu viewport dengan `SliverGrid.builder`; stok/riwayat memakai `SliverList.builder`. Header, urutan bagian, filter, padding, CTA, dan navigasi dipertahankan.
- Scanner dengan controller sendiri mengamati lifecycle: stop saat tidak aktif, start saat resumed. Start/stop/dispose diserialkan. Pemanggil menunggu transisi route dan pelepasan kamera selesai, termasuk jika ditutup saat start masih berlangsung.
- Lima tab utama, `StatefulShellRoute.indexedStack`, dan keranjang dipertahankan. Tidak ada perubahan skema atau pagination SQL.

## Metode dan isolasi

Redmi 2201116TG, Android 13, arm64, density 440 (DPR 2,75). Flutter 3.47.9 / Dart 3.13.7 release. Paket QA `com.pujanggapos.pujangga_pos.ramaudit`; paket Play Store `com.pujanggapos.pujangga_pos` tidak digunakan untuk fixture atau pengujian mutasi.

Entrypoint QA memverifikasi path database berada dalam sandbox `.ramaudit` sebelum reset/seed. Fixture: katalog/transaksi kosong (`empty`), serta 1.000 item + 10.000 transaksi satu detail (`large`). **Keduanya menggunakan logo sintetis 4096×4096**. Ini skenario beban gambar besar, bukan data pengguna atau pengukuran RAM dasar Flutter.

Instrumentasi identik sebelum/sesudah: HTTP loopback melalui ADB forward untuk navigasi, scroll, scanner, jumlah elemen, cache, dan RSS proses. Entrypoint produksi tidak berisi instrumentasi tersebut. Harness dan APK lokal berada di direktori ignored `build/ram-audit/`.

Tiga pengulangan per fixture/versi, masing-masing restart proses: startup Beranda (jeda tiga detik), Katalog (delapan scroll 700 logical pixels), dua putaran Transaksi → Stok → Laporan → Beranda → Katalog, Riwayat (lima scroll pada fixture besar), kembali Beranda, lalu sepuluh kali buka/tutup scanner dan jeda tiga detik.

Sampel memakai `adb shell dumpsys meminfo <paket-QA>`. Pada OEM ini, jumlah PSS kategori cocok dengan TOTAL PSS dikurangi TOTAL SWAP PSS. Resident PSS dan swap dilaporkan terpisah. RSS merupakan metrik lain, tidak dijumlahkan dengan PSS. Java/native/graphics pada JSON mengikuti label App Summary Android.

## Hasil

Median tiga pengulangan, satuan MiB. Semua 60 sampel ringkas dan SHA-256 APK tersedia di [ANDROID-RAM-MEASUREMENTS.json](ANDROID-RAM-MEASUREMENTS.json).

| Fixture | Tahap | Resident PSS sebelum → sesudah | Swap PSS sebelum → sesudah | RSS sebelum → sesudah |
| --- | --- | ---: | ---: | ---: |
| empty | startup | 218.7 → 186.1 | 3.2 → 2.4 | 324.5 → 298.8 |
| empty | catalog | 233.0 → 138.3 | 0.3 → 0.3 | 344.7 → 258.0 |
| empty | history | 260.9 → 166.8 | 0.3 → 0.3 | 373.5 → 285.8 |
| empty | navigation | 230.0 → 136.3 | 0.3 → 0.3 | 340.1 → 252.7 |
| empty | scanner | 253.8 → 159.0 | 0.3 → 0.3 | 366.8 → 281.7 |
| large | startup | 287.2 → 212.5 | 1.5 → 3.3 | 393.7 → 326.1 |
| large | catalog | 378.1 → 163.8 | 0.3 → 0.3 | 504.3 → 281.9 |
| large | history | 322.2 → 177.9 | 0.3 → 0.3 | 448.9 → 296.9 |
| large | navigation | 273.1 → 157.5 | 0.3 → 0.3 | 397.0 → 274.3 |
| large | scanner | 282.6 → 183.4 | 0.3 → 0.3 | 396.3 → 301.9 |

Pada katalog fixture besar, resident PSS turun 378,1 → 163,8 MiB (56,7%). Elemen katalog turun 98.543 → 2.715; cache gambar turun 64 → 1,03 MiB. Avatar sendiri turun dari bitmap 64 MiB menjadi 30.976 bytes. Kontribusi setiap perubahan belum diukur secara terpisah.

Startup masih memiliki alokasi sementara: median native heap fixture kosong naik 41,0 → 101,2 MiB pada titik awal, lalu kembali sekitar 39–42 MiB setelah navigasi. Peak RSS selama proses juga tidak turun secara konsisten. Pembatasan dekode/cache belum menghilangkan seluruh alokasi sementara codec atau data startup.

## Validasi

- `flutter analyze --no-pub`: lulus.
- `flutter test --no-pub`: 74 tes lulus. Tes SQLite FFI menggunakan direktori sementara; UI memakai override provider, bukan database HP.
- Empat tes baru: pembatasan dekode/kesamaan cache key, katalog/kategori 1.000 item yang lazy, urutan pause/resume kamera, serta disposal saat start belum selesai dan stop mengalami error.
- APK QA release sebelum/sesudah berhasil dibangun dan dipasang pada sandbox terpisah.
- `dumpsys media.camera`: satu client QA saat scanner terbuka, tanpa client saat background, satu setelah resumed, tanpa client setelah ditutup.
- Pemeriksaan 400 baris log proses QA terakhir: tidak ditemukan marker fatal, unhandled exception, overflow, atau kegagalan operasi session. Ini pemeriksaan terbatas, bukan bukti seluruh sesi bebas error.
- [Screenshot katalog sintetis](android-ram-qa-catalog.png) diperiksa: dua kolom kartu, logo, badge stok, CTA tambah, dan lima tab tampil. Tidak ada deviasi desain yang disengaja; perbandingan piksel dengan Stitch belum dilakukan pada audit RAM ini.

## Batas hasil dan status

Tidak ada janji RAM di bawah 20 MiB. Hasil fixture logo besar tidak boleh digunakan untuk menyatakan RAM aplikasi Play Store pengguna turun dari 84 MiB dengan persentase yang sama. Engine Flutter, grafis, plugin, dan data tetap membutuhkan RAM.

Pengukuran ini beban singkat, bukan pembuktian bebas memory leak jangka panjang. Heap snapshot/retaining paths DevTools belum diambil. Provider masih memuat seluruh hasil query; pagination SQL merupakan langkah lanjutan bila diperlukan berdasarkan profil data lebih besar.

Paket QA telah dihapus dan ADB forward dibersihkan. Application ID Gradle produksi telah dipulihkan; salinan signing sementara di worktree telah dihapus setelah diverifikasi identik dengan sumber. Paket Play Store masih terpasang dari `com.android.vending`, versi 1.2.3+4. Artefak tidak memuat data usaha pengguna, kredensial, atau keystore. Perubahan belum di-commit/push/deploy.
