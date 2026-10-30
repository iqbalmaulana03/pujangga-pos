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
Simpan baseline sebelum mengubah resource. Jalankan ulang langkah berikut untuk
hasil optimasi dengan nama output berbeda:

```sh
flutter pub get --enforce-lockfile
flutter --version --machine > build/flutter-version.json
flutter build appbundle --release --no-pub
java -jar /path/to/bundletool-all-1.18.3.jar get-device-spec --output=build/device.json
python tools/android_size_report.py \
  --bundle build/app/outputs/bundle/release/app-release.aab \
  --bundletool /path/to/bundletool-all-1.18.3.jar \
  --device-spec build/device.json \
  --flutter-version-file build/flutter-version.json \
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

## CI dan publikasi

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
