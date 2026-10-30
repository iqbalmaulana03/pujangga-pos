# Pujangga POS

Aplikasi point of sale (POS) Android berbasis Flutter untuk membantu usaha kecil mencatat penjualan barang dan jasa, memantau stok, dan melihat ringkasan usaha. Aplikasi dirancang **local-first**: data operasional disimpan di perangkat menggunakan SQLite dan fitur inti tidak memerlukan akun atau koneksi internet.

Proyek ini terbuka untuk kontribusi. Mulai dengan membaca [panduan kontribusi](CONTRIBUTING.md), lalu lihat [fitur dan alur produk](PRD-Pujangga-POS.md) atau [user flow](USER-FLOW-Pujangga-POS.md) untuk memahami konteksnya.

## Fitur

- Setup profil usaha.
- Katalog barang dan jasa.
- Pencatatan transaksi dan riwayat transaksi.
- Pemantauan serta penyesuaian stok barang.
- Dashboard dan laporan penjualan, termasuk ringkasan margin.
- Pengaturan usaha.

Ruang lingkup produk saat ini dijelaskan dalam [PRD](PRD-Pujangga-POS.md). Pujangga POS belum menggunakan backend atau sinkronisasi cloud.

## Teknologi dan struktur

- Flutter dan Dart untuk aplikasi Android.
- Riverpod untuk state management, GoRouter untuk navigasi, dan SQLite melalui `sqflite` untuk penyimpanan lokal.
- Kode aplikasi berada di `lib/`, dikelompokkan menjadi `app/`, `core/`, `features/`, dan `shared/`.
- Feature umumnya memisahkan `presentation/`, `domain/`, dan `data/`.

Navigasi utama memiliki lima bagian: **Beranda**, **Katalog**, **Transaksi**, **Stok**, dan **Laporan**. Riwayat transaksi dan Pengaturan adalah alur lanjutan, bukan tab utama.

## Menjalankan aplikasi

Gunakan Flutter **3.47.9** agar sama dengan CI, Android SDK, dan emulator Android atau perangkat yang tersambung. Batas minimum proyek adalah Flutter **3.47.8** dan Dart **3.13.7**, yang menyertakan perbaikan keamanan [GHSA-frr6-h895-5pxp](https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp). Dart mengikuti versi bawaan Flutter. Pastikan `flutter doctor` tidak melaporkan kebutuhan Android yang belum terpenuhi.

```bash
flutter pub get
flutter run
```

Pilih perangkat Android jika Flutter mendeteksi lebih dari satu target. Untuk menjalankan pemeriksaan lokal:

```bash
flutter analyze --fatal-infos
flutter test
```

## Kontribusi

Issue dan pull request dipersilakan. Baca [CONTRIBUTING.md](CONTRIBUTING.md) untuk alur kerja, pemeriksaan sebelum mengirim perubahan, dan panduan UI. Keputusan desain yang sudah dikunci tercatat dalam [STITCH-FINAL-SCREENS.md](STITCH-FINAL-SCREENS.md).

## CI dan rilis

GitHub Actions menjalankan analisis Dart dan test pada pull request menuju `main`. Panduan pipeline dan rilis Android tersedia di [docs/CI-CD.md](docs/CI-CD.md).
