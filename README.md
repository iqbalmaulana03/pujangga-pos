# Pujangga POS

Skeleton awal Flutter Android untuk MVP `Pujangga POS` dengan pendekatan local-first, modular per feature, dan fondasi SQLite.

## Keputusan Teknis

- Platform target: Android
- State management dan DI: `flutter_riverpod`
- Routing: `go_router`
- Persistence lokal: `sqflite`
- Formatter: `intl`
- Logging debug: `logging`

## Struktur Folder

```text
lib/
  app/
    app.dart
    router/
    theme/
  core/
    constants/
    database/
    errors/
    services/
    utils/
  features/
    beranda/
    katalog/
    laporan/
    pengaturan/
    riwayat/
    setup_usaha/
    stok/
    transaksi/
  shared/
    extensions/
    models/
    widgets/
```

Setiap feature utama mengikuti boundary:

- `presentation`: page, widget, controller, state UI
- `domain`: entity, contract repository, use case tipis bila diperlukan
- `data`: datasource lokal, model database, repository implementation

## Route Dasar

- `/setup`
- `/home`
- `/catalog`
- `/catalog/create`
- `/catalog/edit/:id`
- `/transaction`
- `/history`
- `/history/:id`
- `/stock`
- `/stock/:itemId`
- `/reports`
- `/settings`

Bottom navigation utama mengikuti canonical screen set:

- `Beranda`
- `Katalog`
- `Transaksi`
- `Stok`
- `Laporan`

`Riwayat Transaksi` dan `Pengaturan` tetap menjadi subflow di luar tab utama.

## Menjalankan Project

```bash
rtk flutter pub get
rtk flutter run
```

## Verifikasi Dasar

```bash
rtk dart format .
rtk flutter analyze
rtk flutter test
```

## Catatan Fondasi Issue #1

- App start menginisialisasi SQLite lalu mengecek status setup bisnis.
- Jika profil usaha belum ada, aplikasi masuk ke `/setup`.
- Form setup placeholder menyimpan profil usaha ke SQLite melalui repository.
- Placeholder screen untuk semua modul MVP sudah tersambung sehingga flow navigasi bisa diuji lebih awal.
