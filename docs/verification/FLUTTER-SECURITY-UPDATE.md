# Verifikasi pembaruan keamanan Flutter/Dart

Tanggal: 30 Oktober 2026 (WIB).

## Sumber dan SDK

- Branch kerja: `fix/flutter-security-update`, dibuat dari `origin/main` pada `bfe413f13fc2067ffd4d2e8297f869655edfe8bd`.
- Versi aplikasi tetap `1.2.2+3`, sesuai sumber `main`; pekerjaan ini tidak menerbitkan versi baru.
- Flutter stable `3.47.9`, revision `c197ca5199e9ee5661e865596c9c07294dfab51c`.
- Dart bawaan `3.13.7`; engine `89c39edfdfae2949f6806e4a315c0c08522238b7`.
- Verifikasi menggunakan environment Puro terpisah `security-patch`; environment SDK default tetap Flutter `3.44.1`.
- Tag SDK diverifikasi terhadap repository resmi Flutter. [Advisori GHSA-frr6-h895-5pxp](https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp) menetapkan perbaikan minimum Flutter `3.47.8` dan Dart `3.13.7`.

## Perubahan dependency dan konfigurasi

Kedua job CI menggunakan Flutter `3.47.9`. Constraint proyek menetapkan Dart `^3.13.7` dan Flutter `>=3.47.8`.

Percobaan awal `flutter pub get --enforce-lockfile` menolak lockfile lama. Resolusi dengan SDK baru hanya mengubah enam dependency transitif: `matcher` `0.12.19` → `0.12.20`, `meta` `1.18.0` → `1.19.0`, `test` `1.31.0` → `1.31.1`, `test_api` `0.7.11` → `0.7.12`, `test_core` `0.6.17` → `0.6.18`, serta `vector_math` `2.2.0` → `2.4.4`. Versi package lainnya tetap.

Migrasi bawaan Flutter menambahkan pengecualian `build/**` dan `android/**` ke konfigurasi analyzer. Tidak ada perubahan kode produk, skema SQLite, atau UI.

## Pemeriksaan

Perintah dijalankan dengan executable Flutter dari environment `security-patch`, melalui proxy RTK.

| Pemeriksaan | Hasil |
| --- | --- |
| `flutter --version --machine` | Flutter dan Dart sesuai revision di atas |
| `flutter pub get --enforce-lockfile` setelah pembaruan lockfile | Lulus |
| `flutter analyze --fatal-infos --no-pub` | Lulus, tanpa temuan |
| `flutter test --no-pub --reporter expanded` | 70 tes lulus |
| `flutter build apk --debug --no-pub` | Lulus; package `com.pujanggapos.pujangga_pos.debug`, versionCode `3`, minSdk `24`, targetSdk `36` diverifikasi melalui `aapt` |
| `flutter build appbundle --release --no-pub` | Lulus; AAB bertanda tangan, runtime ARMv7, ARM64, dan x86_64 tersedia |
| `jarsigner -verify` pada AAB | Lulus, `jar verified.` dan exit code `0` |
| `git diff --check` | Lulus |

Sebelum tes, akses SQLite diperiksa: kelima suite yang membuka database menggunakan `databaseFactoryFfi`, `Directory.systemTemp.createTemp`, dan `setDatabasesPath` ke direktori sementara; teardown menghapus database sementara. Tes widget mengganti provider atau repository dengan implementasi pengujian. Tes ekspor CSV membangun teks tanpa membuka database. Tidak ada database perangkat atau layanan produksi yang digunakan.

## Artefak lokal

Artefak dan manifest bukti disimpan pada direktori `build/` di worktree, yang diabaikan Git. Manifest `build/security-update/manifest.json` mencatat revision sumber dan SDK, hasil pemeriksaan, ukuran, serta SHA-256 artefak.

| Artefak | Ukuran byte | SHA-256 |
| --- | --- | --- |
| `build/app/outputs/flutter-apk/app-debug.apk` | 210735673 | `82c6e5e079ca8714c42b8d55d7eea83f6f480e9a64c6e871f8f375551f44d53b` |
| `build/app/outputs/bundle/release/app-release.aab` | 83693237 | `50656e9b60dc3f07e83d9b89f98baffc131cb6b8c3d24961ccdc960a71822d24` |

## Batas bukti dan rilis

Build menampilkan peringatan bahwa `file_picker` dan `share_plus` masih menggunakan Kotlin Gradle Plugin yang perlu dimigrasikan untuk versi Flutter mendatang. Versi plugin dipertahankan karena build SDK yang ditargetkan tetap didukung. Ada pula peringatan ketidaksamaan versi parser metadata Android SDK; build APK tetap berhasil.

Pemeriksaan emulator/perangkat belum dilakukan: `adb devices` tidak menampilkan perangkat, dan Android SDK lokal tidak memiliki emulator maupun AVD. Verifikasi setup, katalog, transaksi, stok, laporan, dan gambar HTTPS pada Android tetap diperlukan sebelum distribusi.

Tes fungsional tidak menguji eksploit TLS. Bukti perbaikan keamanan adalah penggunaan SDK resmi yang ditambal dan build ulang dengan SDK tersebut. APK yang sudah terpasang belum menerima perbaikan sampai pengguna memperbarui aplikasinya.

Publikasi Google Play, perubahan rollout, dan push ke `main` atau `release/*` berada di luar pekerjaan ini. Rilis berikutnya memerlukan versionCode baru yang diverifikasi terhadap Play Console. Salinan material signing sementara di worktree dihapus setelah build dan verifikasi; material asli di checkout awal tetap dipertahankan. Nilainya tidak dicetak atau dimasukkan ke commit. Pemeriksaan ini bersifat lokal; hasil workflow GitHub Actions belum diverifikasi.
