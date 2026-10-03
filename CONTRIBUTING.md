# Panduan Kontribusi

Terima kasih sudah membantu mengembangkan Pujangga POS. Panduan ini menjelaskan cara menyiapkan proyek, membuat perubahan yang selaras dengan produk, dan mengirimkannya untuk ditinjau.

## Sebelum mulai

- Untuk perubahan besar atau fitur baru, buka issue atau diskusikan usulannya terlebih dahulu agar ruang lingkupnya jelas.
- Periksa issue yang sudah ada sebelum mulai mengerjakan hal yang sama.
- Jaga setiap pull request tetap fokus pada satu perubahan yang bisa ditinjau.

## Siapkan proyek

Pasang Flutter SDK yang memenuhi batas Dart di `pubspec.yaml`, Android SDK, dan emulator atau perangkat Android. Dari direktori proyek, jalankan:

```bash
flutter pub get
flutter run
```

## Kerjakan perubahan

1. Buat branch kerja dari `main` terbaru. Gunakan nama singkat yang menjelaskan pekerjaan, misalnya `feat/stock-alert` atau `docs/contribution-guide`.
2. Implementasikan perubahan sesuai ruang lingkup issue. Hindari memasukkan refactor atau fitur lain yang tidak terkait.
3. Tambahkan atau perbarui test saat mengubah behavior aplikasi.
4. Perbarui dokumentasi jika perubahan memengaruhi setup, alur pengguna, atau cara kerja fitur.

## Panduan untuk perubahan UI

Sebelum mengubah UI, baca dokumen berikut:

- [STITCH-FINAL-SCREENS.md](STITCH-FINAL-SCREENS.md) untuk layar dan keputusan desain yang dikunci.
- [USER-FLOW-Pujangga-POS.md](USER-FLOW-Pujangga-POS.md) untuk alur pengguna.
- [PRD-Pujangga-POS.md](PRD-Pujangga-POS.md) untuk ruang lingkup dan kebutuhan produk.

> Pujangga POS menggunakan navigasi utama lima tab: Beranda, Katalog, Transaksi, Stok, dan Laporan. Riwayat Transaksi dan Pengaturan berada di luar tab utama. Jika keterbatasan implementasi mengharuskan perubahan dari desain canonical, jelaskan alasannya di pull request.

## Penyimpanan lokal

Data aplikasi disimpan di SQLite pada perangkat. Jika mengubah schema atau model data, pertahankan data pengguna yang sudah tersimpan dan sertakan migrasi database bila diperlukan. Jelaskan dampak perubahan data pada pull request.

## Periksa perubahan

Jalankan pemeriksaan yang relevan sebelum mengirim pull request:

```bash
flutter analyze --fatal-infos
flutter test
```

GitHub Actions juga menjalankan analisis dan test pada pull request menuju `main`. Jika pemeriksaan tidak dapat dijalankan, sebutkan alasannya dan pemeriksaan yang sudah dilakukan.

## Kirim pull request

Targetkan pull request ke `main`. Sertakan:

- Ringkasan perubahan dan alasan perubahan.
- Referensi issue terkait, jika ada.
- Langkah verifikasi serta hasilnya.
- Dampak pada UI, penyimpanan lokal, atau dokumentasi jika relevan.
- Screenshot atau rekaman singkat untuk perubahan UI.

Tinjau kembali diff sebelum mengirim: pastikan perubahan tetap dalam ruang lingkup, tidak menyertakan file lokal atau rahasia, dan dokumentasi sesuai dengan behavior yang diubah.
