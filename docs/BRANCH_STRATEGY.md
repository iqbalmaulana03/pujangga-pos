# Branch Strategy

Dokumen ini menjelaskan strategi branch untuk tim pada repo `amaris-barbershop-backend`.

## Branch Utama

- `main`

Fungsi:

- Menyimpan kode yang dianggap stabil
- Menjadi sumber branch untuk semua pekerjaan baru
- Menjadi target akhir Pull Request

Aturan:

- Tidak boleh ada commit langsung ke `main`
- Semua perubahan masuk lewat Pull Request
- Branch protection sebaiknya aktif

## Branch Kerja

Gunakan branch pendek sesuai jenis pekerjaan:

- `feature/*` untuk fitur baru
- `fix/*` untuk bug fix
- `chore/*` untuk setup, tooling, atau maintenance
- `docs/*` untuk dokumentasi
- `refactor/*` untuk perubahan struktur internal tanpa ubah behavior utama

Format branch yang disarankan:

- `<jenis-branch>/<nomor-issue>-<slug-task>`

Contoh:

- `feature/1-project-foundation`
- `feature/4-booking-api`
- `feature/6-pos-transaction-api`
- `feature/8-attendance-api`
- `docs/11-contribution-guide`

## Aturan Pemakaian

- Satu branch untuk satu issue utama
- Hindari mencampur beberapa fitur besar dalam satu branch
- Jika pekerjaan terlalu besar, pecah menjadi beberapa issue dan beberapa branch

## Alur Branch

1. Update `main`
2. Buat branch baru
3. Kerjakan task
4. Push branch
5. Buat Pull Request ke `main`
6. Review
7. Merge setelah approval

Contoh:

```bash
git checkout main
git pull origin main
git checkout -b feature/6-pos-transaction-api
```

Setelah selesai:

```bash
git add .
git commit -m "feat[6]: add POS transaction API"
git push -u origin feature/6-pos-transaction-api
```

## Mapping dengan Issue

Sebaiknya nama branch mengikuti issue atau konteks task.

Contoh:

- Issue `#6 build POS transaction API`
- Branch `feature/6-pos-transaction-api`

## Commit Message

Format commit message yang digunakan:

- `<prefix>[<nomor-issue>]: <deskripsi-singkat>`

Contoh:

- `feat[6]: add POS transaction create endpoint`
- `fix[7]: correct commission split for service totals`
- `docs[11]: add contribution and branch strategy docs`
- `refactor[5]: simplify queue status transition logic`

Nomor issue wajib dicantumkan minimal pada:

- nama branch
- deskripsi Pull Request
- referensi penutupan issue di PR

## Strategy untuk Sprint Awal

Karena backlog awal sudah dibagi per modul, workflow yang disarankan:

- Selesaikan fondasi project lebih dulu
- Kerjakan master data sebelum modul transaksi
- Jangan campur ticket booking, queue, POS, dan attendance dalam satu branch
- Jika ada dependency lintas issue, sebutkan di Pull Request

## Review Policy

- Minimal satu reviewer
- PR kecil lebih cepat direview daripada PR besar
- Jika ada perubahan API contract, jelaskan impact-nya di PR
- Jika ada perubahan migration, reviewer harus cek impact schema

## Merge Policy

Disarankan menggunakan `Squash and merge` agar:

- History lebih bersih
- Satu PR menjadi satu commit utama di `main`
- Mudah ditelusuri ke issue yang diselesaikan

## Release Flow Sederhana

Jika tim masih kecil, cukup gunakan:

- `main` untuk branch stabil
- branch fitur untuk development harian

Tidak perlu menambah `develop` kecuali ritme tim sudah menuntut parallel release flow yang lebih kompleks.
