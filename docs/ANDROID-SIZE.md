# Pengukuran ukuran Android

Ukuran unggahan AAB, jumlah byte APK yang dipilih untuk perangkat, ukuran
terpasang Android (termasuk optimasi kode), dan transfer unduhan Play adalah
metrik berbeda. Jangan memakai ukuran AAB sebagai ukuran unduhan pengguna.

## Ikon dan batas CI

Lima resource `ic_launcher.png` wajib berukuran 48/72/96/144/192 piksel untuk
mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi, dengan jumlah maksimum 250.000 byte.
`python tools/launcher_icons.py` memeriksa keduanya di job verifikasi CI.
Artwork master dan petunjuk regenerasi ada di `tools/artwork/`; master tidak
dimasukkan ke Android resources atau aset Flutter.

## Perbandingan lokal

Gunakan SDK Flutter yang dipin pada workflow CI (saat ini 3.47.9), lockfile yang
sama, signing/configuration yang sama, dan bundletool 1.18.3 untuk kedua build.
SHA-256 bundletool resmi:
`a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29`.
Simpan baseline sebelum mengubah resource. Buat device spec sekali sebelum
kedua pengukuran, lalu gunakan file yang sama agar profil tetap identik:

```sh
mkdir -p build
java -jar /path/to/bundletool-all-1.18.3.jar get-device-spec --output=build/device.json
```

Jalankan langkah berikut untuk setiap build; gunakan `before.json` untuk
baseline dan `after.json` untuk hasil optimasi. Simpan kedua laporan beserta
file `.apks` hasilnya sebelum membersihkan build. Jika menjalankan `flutter clean`,
salin device spec terlebih dahulu ke luar `build` dan pulihkan file yang sama:

```sh
flutter pub get --enforce-lockfile
mkdir -p build
flutter --version --machine > build/flutter-version.json
flutter build appbundle --release --no-pub --split-debug-info=build/android-symbols
python tools/android_size_report.py \
  --bundle build/app/outputs/bundle/release/app-release.aab \
  --bundletool /path/to/bundletool-all-1.18.3.jar \
  --device-spec build/device.json \
  --flutter-version-file build/flutter-version.json \
  --dart-symbols build/android-symbols \
  --output build/android-size/after.json
```

`bundletool build-apks` memakai key debug lokal secara default untuk APK
pengukuran. AAB tetap menggunakan signing release yang dikonfigurasi lokal.
Jangan memasang APK pengukuran di atas aplikasi Play; gunakan paket uji dengan
application ID dan data terpisah untuk uji fungsional.

Laporan mencatat revision, status checkout, hash lockfile/SDK/artefak, ukuran AAB,
resource ikon, APK terpilih, dan estimasi download minimum/maksimum. Pastikan
selisih source runtime hanya perubahan optimasi. Untuk artefak CI lama gunakan
`--source-revision <sha-ci>` dan jangan memasukkan metadata SDK build lokal.
Status checkout dan hash lockfile dihilangkan untuk artefak eksternal tersebut.

Untuk build lokal, `lockfile_sha256` mempertahankan hash byte asli dan
`lockfile_lf_sha256` mencatat hash setelah CRLF dinormalisasi menjadi LF.
Gunakan fingerprint LF untuk membandingkan isi lockfile Windows dan CI;
catat juga hash sebelum/sesudah build untuk membuktikan input tidak berubah.
Jika `--dart-symbols` diberikan, laporan wajib menemukan file simbol untuk
setiap ABI yang memuat `libapp.so` dalam bundle. ABI yang hanya memuat library
plugin tidak memerlukan simbol Dart. Simbol ABI yang hilang menggagalkan
laporan sebelum JSON ditulis.

## CI dan publikasi

Build rilis memisahkan informasi diagnostik Dart dengan `--split-debug-info`,
tanpa `--obfuscate`. Simbol tidak dikirim ke perangkat. Pipeline menyimpan
artefak `dart-symbols-<versi>-<commit>` selama 90 hari, berisi semua ABI dan
`release.json` dengan checksum AAB serta setiap file simbol. Unduh dan arsipkan
keduanya sebelum masa retensi berakhir, dan pertahankan selama versi tersebut
masih digunakan. Jangan mencampur simbol dari build, versi, atau ABI berbeda.
Untuk menerjemahkan stack trace, gunakan:

```sh
python tools/symbolize_dart.py --input stacktrace.txt \
  --symbols app.android-arm64.symbols --output decoded.txt
```

Helper memakai flutter symbolize. Untuk snapshot terpadu Dart 3.13 pada SDK
3.47.9, helper mempertahankan build ID dan alamat virtual, lalu menghilangkan
header alamat muat yang memicu decoder lama mencari simbol isolate terpisah.
Trace format lama diteruskan utuh. Uji perangkat membuktikan fungsi serta lokasi
source dari exception QA dapat dipulihkan. Trace asli tetap disimpan oleh pemilik.

Workflow pengukuran memakai flag build yang sama dan menyimpan simbol bersama
artefak ukur. Laporan juga mencatat ukuran setiap library native dan total DEX;
simbol di luar aplikasi tidak dihitung sebagai penghematan data pengguna/cache.

Data tanggal produksi hanya mendaftarkan `id` (termasuk fallback `id_ID`) dan
`en_US`, sesuai format Indonesia dan format default aplikasi. Saat memperbarui
`intl`, regenerasi data dari dependency yang terkunci dan jalankan tes
kesetaraan CLDR sebelum build:

```sh
dart run tools/generate_date_locales.dart
dart format lib/core/utils/app_date_formatting.dart
flutter test test/app_date_formatting_test.dart
```

Tes menggunakan data referensi seluruh locale dari `intl`; import referensi
tersebut harus tetap berada di tools/test, bukan entrypoint produksi.

Workflow manual **Android size measurement (no publishing)** membangun mode
release dengan key pengukuran sekali pakai. Workflow ini tidak menggunakan
credential Play atau menjalankan upload/rollout. Profil tetap di
`tools/android-size-device.json` adalah ARM64, Android 13, density 440, locale
Indonesia; gunakan profil ADB yang sama untuk perbandingan perangkat tertentu.
Unduh artefaknya untuk mendapatkan AAB, APK terpilih (`.apks`), metadata SDK,
checksum, dan estimasi unduhan.

Pipeline release yang sudah ada menyertakan `release.json` bersama AAB; laporan
ini hanya mencatat ukuran artefak unggahan dan checksum, tanpa estimasi download.
Ukuran download Play yang pasti diperiksa di Play Console setelah upload rilis
yang diotorisasi terpisah. Workflow pengukuran tidak memublikasikan aplikasi.

Sasaran awal untuk perangkat audit adalah estimasi download di bawah 35 MB
(35.000.000 byte). Ini sasaran diagnosis, bukan alasan untuk menghapus fitur
offline atau arsitektur perangkat. Jika terlewati, laporkan komponen yang tersisa
dan jangan menyebut target tercapai. Regresi ikon wajib menggagalkan CI.
