# Contributing Guide

Dokumen ini menjelaskan aturan kontribusi untuk repo `amaris-barbershop-backend`.

## Tujuan

Repository ini digunakan untuk backend sistem operasional barbershop yang mencakup:

- POS transaksi jasa dan produk
- Booking online
- Manajemen antrian
- Perhitungan komisi kapster
- Absensi kapster
- Reporting owner dan admin

Karena cakupan fiturnya saling terhubung, kontribusi perlu konsisten agar perubahan mudah direview dan aman digabung.

## Cara Mulai

1. Ambil issue yang jelas scope-nya.
2. Pastikan issue memiliki acceptance criteria.
3. Sync branch `main`.
4. Buat branch kerja baru.
5. Kerjakan perubahan secukupnya untuk satu issue.
6. Buat Pull Request ke `main`.

## Aturan Umum Kontribusi

- Jangan commit langsung ke `main`
- Semua perubahan masuk melalui Pull Request
- Satu branch untuk satu issue utama
- Hindari mencampur refactor besar dengan fitur baru dalam satu PR
- Jika ada perubahan API contract, jelaskan impact-nya di PR
- Jika ada perubahan schema database, sertakan migration yang relevan

## Struktur Branch

Gunakan jenis branch berikut:

- `feature/*` untuk fitur baru
- `fix/*` untuk bug fix
- `chore/*` untuk setup, tooling, dan maintenance
- `docs/*` untuk dokumentasi
- `refactor/*` untuk perubahan struktur internal tanpa ubah behavior utama

Format branch:

- `<jenis-branch>/<nomor-issue>-<slug-task>`

Contoh:

- `feature/6-pos-transaction-api`
- `feature/8-attendance-api`
- `docs/11-contribution-guide`
- `fix/7-commission-rounding`

Lihat detail tambahan pada [docs/BRANCH_STRATEGY.md](./docs/BRANCH_STRATEGY.md).

## Format Commit Message

Gunakan format:

- `<prefix>[<nomor-issue>]: <deskripsi-singkat>`

Contoh:

- `feat[6]: add POS transaction create endpoint`
- `fix[7]: correct commission calculation for service items`
- `docs[11]: add backend contribution guide`
- `chore[1]: setup project foundation`

Prefix yang dipakai:

- `feat`
- `fix`
- `docs`
- `chore`
- `refactor`
- `test`

## Pull Request Checklist

Sebelum membuat PR, pastikan:

- Branch berasal dari `main` terbaru
- Scope PR fokus pada satu issue utama
- Perubahan sudah dites secara lokal sesuai konteks
- Migration sudah dicek jika ada perubahan database
- Environment variable baru sudah ditambahkan ke `.env.example` jika perlu
- Dokumentasi diperbarui jika ada perubahan behavior atau workflow

## Isi Pull Request

PR minimal harus menjelaskan:

- Ringkasan perubahan
- Issue yang dikerjakan
- Perubahan schema atau contract API jika ada
- Langkah verifikasi
- Risiko atau area yang perlu perhatian reviewer

Contoh referensi issue di PR:

- `Closes #6`
- `Refs #8`

## Review Policy

- Minimal satu reviewer
- Reviewer fokus pada behavior, integrasi, dan risiko regresi
- PR kecil lebih diutamakan daripada PR besar
- Jika PR terlalu besar, pecah menjadi beberapa issue dan branch

## Database dan Migration

Jika perubahan menyentuh data model:

- Sertakan migration
- Pastikan naming migration jelas
- Hindari perubahan schema yang tidak terkait issue
- Jelaskan impact data pada deskripsi PR

## API Contract

Jika endpoint baru atau response berubah:

- Jelaskan request/response utama di PR
- Sebutkan apakah frontend atau integrasi lain perlu penyesuaian
- Jaga konsistensi naming field dan status code

## Dokumentasi

Kontributor diharapkan memperbarui dokumentasi jika:

- menambah modul baru,
- mengubah workflow kontribusi,
- mengubah strategi branch,
- atau mengubah setup project.

## Merge Policy

Disarankan menggunakan `Squash and merge` agar history `main` tetap ringkas dan mudah ditelusuri ke issue terkait.

## Catatan

Jika repository nanti sudah memiliki CI, aktifkan branch protection dan status checks sebagai syarat merge. Checklist-nya tersedia di [docs/BRANCH_PROTECTION_CHECKLIST.md](./docs/BRANCH_PROTECTION_CHECKLIST.md).
