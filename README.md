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

## CI/CD Android

Pipeline GitHub Actions dan panduan menyiapkan rilis Google Play ada di [docs/CI-CD.md](docs/CI-CD.md).

## Catatan Fondasi Issue #1

- App start menginisialisasi SQLite lalu mengecek status setup bisnis.
- Jika profil usaha belum ada, aplikasi masuk ke `/setup`.
- Form setup placeholder menyimpan profil usaha ke SQLite melalui repository.
- Placeholder screen untuk semua modul MVP sudah tersambung sehingga flow navigasi bisa diuji lebih awal.

## Skema SQLite MVP

Database lokal SQLite sekarang memakai tabel inti berikut:

- `business_profile`
- `app_settings`
- `categories`
- `items`
- `sales_transactions`
- `sales_transaction_items`
- `stock_movements`

Relasi utama:

- `categories` 1..n `items`
- `sales_transactions` 1..n `sales_transaction_items`
- `items` 1..n `sales_transaction_items`
- `items` 1..n `stock_movements`

Catatan implementasi:

- `business_profile` dan `app_settings` diasumsikan satu row aktif per perangkat.
- `items.item_type` disimpan sebagai `product` atau `service`.
- Snapshot histori transaksi disimpan di `sales_transaction_items` agar perubahan master item tidak mengubah histori lama.
- Pengurangan stok barang saat transaksi sukses otomatis membuat record di `stock_movements`.
- Schema lama seperti `catalog_items` dimigrasikan ke schema final issue `#5` saat upgrade database ke versi `5`.
