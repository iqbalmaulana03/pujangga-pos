# Branch Protection Checklist

Gunakan checklist ini saat mengatur branch protection pada repo `amaris-barbershop-backend`.

## Branch Target

- [ ] Target branch adalah `main`

## Rule Wajib

- [ ] `Require a pull request before merging`
- [ ] `Require approvals`
- [ ] Minimal `1` approval
- [ ] `Require conversation resolution before merging`
- [ ] `Block force pushes`
- [ ] `Restrict deletions`

## Rule yang Disarankan

- [ ] `Require branches to be up to date before merging`
- [ ] `Require status checks to pass before merging` jika CI sudah tersedia
- [ ] `Dismiss stale pull request approvals when new commits are pushed`

## Aturan Tim

- [ ] Tidak ada direct push ke `main`
- [ ] Semua perubahan masuk lewat Pull Request
- [ ] Satu PR terkait ke issue yang jelas
- [ ] Nomor issue dicantumkan di branch dan Pull Request
- [ ] PR harus memiliki deskripsi dan langkah verifikasi

## Review Policy

- [ ] Reviewer minimal satu orang
- [ ] PR dengan perubahan API menjelaskan impact ke frontend atau service lain
- [ ] PR besar dipecah jika terlalu luas
- [ ] Migration dan perubahan schema ikut direview

## Merge Policy

- [ ] Gunakan `Squash and merge`
- [ ] Pastikan issue terkait ditulis di PR
- [ ] Pastikan komentar review penting sudah ditindaklanjuti

## Catatan

Jika nanti repository sudah punya CI, aktifkan status check sebagai syarat merge agar branch `main` tetap stabil.
