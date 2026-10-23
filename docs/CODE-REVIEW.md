# Review kode dengan Codex dan CodeRabbit

CodeRabbit GitHub App melakukan review PR secara otomatis. Di `starfish-dev`,
CodeRabbit CLI dan plugin Codex mendukung review dari terminal. Codex tetap memakai
provider `codex-lb` dan model `gpt-6.1-sol`; CodeRabbit melakukan analisis melalui
layanan dan kuota akun CodeRabbit sendiri.

## Isi token di server

Masuk sebagai akun `pujangga` melalui alias SSH yang sudah dikonfigurasi:

```bash
ssh starfish-dev
nano /home/pujangga/.config/codex-coderabbit/credentials.env
```

File privat tersebut sudah disiapkan dengan isi kosong:

```bash
CODEX_LB_API_KEY=''
CODERABBIT_API_KEY=''
```

- `CODEX_LB_API_KEY`: token API `codex-lb` untuk Codex.
- `CODERABBIT_API_KEY`: **Agentic API key** dari
  [pengaturan API Keys CodeRabbit](https://app.coderabbit.ai/settings/api-keys),
  untuk akun/organisasi yang akan menjalankan review.

Isi nilai di dalam tanda kutip tunggal. File harus tetap berizin `600`, direktori
induknya `700`. Jangan memasukkan file atau nilai token ke Git, PR, atau chat.
Pengaturan provider dan model tetap berada di
`/home/pujangga/.codex/config.toml`; helper memuat token dari file privat saat
dijalankan. Instalasi Codex dan Node yang sudah ada tetap digunakan.

## Login dan penggunaan terminal

Helper menggunakan lokasi executable yang terpasang, sehingga bisa dipanggil
meskipun PATH sesi SSH belum memuat Node dari NVM atau direktori `~/.local/bin`.

```bash
# Memeriksa versi dan apakah token sudah diisi, tanpa mencetak nilainya.
/home/pujangga/.local/bin/codex-coderabbit status

# Login CodeRabbit sekali setelah mengisi Agentic API key.
/home/pujangga/.local/bin/codex-coderabbit login
```

Dari direktori Git yang ingin ditinjau, jalankan salah satu cara berikut:

```bash
# Review perubahan branch terhadap main.
/home/pujangga/.local/bin/codex-coderabbit review --base main

# Buka Codex dengan provider codex-lb dan plugin CodeRabbit.
/home/pujangga/.local/bin/codex-coderabbit codex
```

Di sesi Codex, minta: `Review perubahan saya dengan CodeRabbit`. Minta perbaikan
kode secara terpisah bila diperlukan. Helper tidak mengaktifkan `--use-credits`
atau mematikan sandbox. Jika akses autentikasi CodeRabbit terhalang sandbox,
ikuti persetujuan untuk command CodeRabbit sesuai
[panduan integrasi resmi](https://docs.coderabbit.ai/cli/codex-integration).

## Aktifkan review PR GitHub

1. Login ke [CodeRabbit](https://app.coderabbit.ai/login) menggunakan GitHub.
2. Buka [instalasi CodeRabbit GitHub App](https://github.com/apps/coderabbitai/installations/new).
3. Pilih akun `iqbalmaulana03`, lalu **Only select repositories** dan
   `pujangga-pos`.
4. Periksa izin aplikasi dan selesaikan **Install & Authorize**.
5. Pada PR yang sudah ada, minta review dengan komentar `@coderabbitai review`.
   PR baru yang bukan draft akan direview otomatis setelah aplikasi aktif.

Konfigurasi `.coderabbit.yaml` meminta hasil dalam bahasa Indonesia melalui
`tone_instructions`, karena schema resmi belum menerima `id-ID` pada field
`language`. Bahasa hasil perlu dikonfirmasi pada review pertama. Review otomatis
berlaku untuk PR menuju `main` atau `release/*`, termasuk pembaruan commit. Batas kuota
dan jeda review mengikuti akun serta pengaturan bawaan CodeRabbit. GitHub App
tidak membutuhkan token `codex-lb` atau token CodeRabbit di repository secrets.

Konfigurasi ini tidak mengubah aturan perlindungan branch. Ajukan perubahan
melalui branch kerja dan PR; jangan push langsung ke `main` atau `release/*`.

## Pemeriksaan setelah autentikasi

- Pastikan login CodeRabbit berhasil pada server setelah token diisi.
- Jalankan satu review CLI terhadap branch yang memiliki perubahan dan pastikan
  proses selesai tanpa error autentikasi atau review parsial.
- Pastikan PR GitHub mendapat hasil review dari `coderabbitai`, bukan sekadar
  status instalasi atau pesan kegagalan.
- Verifikasi status check dan komentar untuk commit PR yang sedang ditinjau.

Pemasangan CLI/plugin dan validasi konfigurasi dapat selesai sebelum token
diisi. Review sebenarnya tetap menunggu autentikasi CodeRabbit serta otorisasi
GitHub App; status terpasang saja tidak membuktikan review berhasil.
