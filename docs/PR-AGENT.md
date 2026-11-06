# Reviewer PR mandiri

Deployment PR-Agent menggunakan GitHub App dan provider Responses API yang
dikonfigurasi operator. Source upstream dipin ke
`251eddf09e168f3abc15acfeed5062368540cdbf`; image `pujangga-pr-agent:251eddf`.
File publik yang dapat ditinjau berada di `ops/pr-agent/`.

Dokumen ini memakai placeholder. `<ssh-host>` adalah alias SSH operator dan
`<deployment-dir>` adalah direktori absolut deployment. Hostname, akun server,
alamat provider, lokasi kredensial, serta identitas instalasi aktual disimpan
dalam panduan operasi privat. Jangan menyalin nilai tersebut ke PR atau log publik.

## Persiapan deployment baru

Gunakan akun deployment dengan Docker Compose, Git, dan Python 3.11+ yang sudah
tersedia. Siapkan provider bernama `codex-lb` dengan `wire_api = "responses"`
dalam konfigurasi provider privat. File kredensial memakai format
`NAMA_ENV_KEY='nilai-token'`, sesuai `env_key` provider, dimiliki akun tersebut,
dan berizin `600`. Helper membaca file tanpa menjalankannya sebagai shell.

Salin file `ops/pr-agent/` ke direktori deployment baru. Jangan menimpa instalasi
aktif. Di host deployment, jalankan urutan berikut setelah mengganti placeholder:

```bash
cd <deployment-dir>
mkdir -m 750 private
cp deployment.example.toml private/deployment.toml
chmod 600 private/deployment.toml
# Edit file privat: webhook_url, app_name, provider_config, credential_file.
git clone --no-checkout https://github.com/qodo-ai/pr-agent.git source
git -C source checkout --detach 251eddf09e168f3abc15acfeed5062368540cdbf
git -C source rev-parse HEAD
python3 manage.py configure
docker compose build reviewer
docker compose up -d reviewer
python3 manage.py verify
```

Pastikan SHA sama persis dengan pin di atas. `configure` menolak revisi berbeda
dan menghasilkan konfigurasi runtime privat beserta allowlist endpoint dari
provider lokal. Ia tidak mencetak nilai kredensial. Sesuaikan `group_add` pada
Compose dengan grup pemilik file privat jika host memakai GID berbeda.

## Route publik dan GitHub App

1. Pada tunnel atau reverse proxy, arahkan hostname webhook ke
   `http://127.0.0.1:8095`. Endpoint `/api/v1/github_webhooks` tidak memakai login
   browser atau cache; autentikasinya menggunakan HMAC GitHub.
2. Dari komputer operator, buka forwarding ke helper registrasi:

   ```bash
   ssh -L 8096:127.0.0.1:8096 <ssh-host> 'python3 <deployment-dir>/manage.py register'
   ```

3. Buka `http://127.0.0.1:8096` pada browser yang sudah login ke GitHub.
   Daftarkan App lalu pilih **Only select repositories** dan `pujangga-pos`.
   Callback manifest menggunakan `http://localhost:8096/callback`; jangan
   menggantinya dengan alamat IP atau menambahkan query pada `redirect_url`.
   Helper memeriksa `state`, menyimpan rahasia secara privat, dan memulai ulang
   container. Hentikan helper dan forwarding setelah App terpasang.
4. Periksa pengiriman webhook di pengaturan App. Ping sah harus mendapat 200;
   permintaan tanpa tanda tangan harus mendapat 403. Bila ping awal gagal
   sebelum konfigurasi App selesai, redeliver setelah layanan siap.
5. Uji `/review` pada PR, lalu verifikasi pemicu otomatis pada PR non-draft
   dan pembaruan commit. Periksa hasil komentar bot, bukan hanya status webhook.

Jangan mendaftarkan App kedua pada deployment aktif. Helper menolak menimpa
App yang sudah tersimpan. Catat identitas App dan instalasinya secara privat.

## Perilaku dan izin

- Bot dibatasi pada repository ini. Komentar bot dan repository lain diabaikan.
  Komentar manual harus persis `/review`; override konfigurasi ditolak.
- PR draft dilewati. Event `opened`, `reopened`, `ready_for_review`, dan pembaruan
  commit memicu review. Bot tidak menjalankan autofix atau merge.
- App membutuhkan Contents/Metadata read serta Pull requests/Issues write.
  PAT operator tidak diperlukan untuk operasi normal.
- Model dan perilaku dikendalikan server. Konfigurasi dari PR tidak dimuat.
  Konteks review mencakup `AGENTS.md` dan tiga dokumen produk canonical.
- Bot mengambil diff melalui GitHub API dan mengirim konteks ke provider model.
  Bot tidak menjalankan kode PR atau pengujian aplikasi.
- PR-Agent gratis; biaya dan kuota model mengikuti provider yang digunakan.

## Status review, notifikasi, dan persetujuan

Alur GitHub: event PR → review agen → catatan hasil dan review formal → job
**Agent review** menampilkan hasil di Checks. Review formal memakai notifikasi
bawaan GitHub sesuai preferensi notifikasi pengguna.

- **Approve** diberikan hanya untuk review lengkap tanpa temuan aktif maupun
  indikasi keamanan. Commit yang direview dicantumkan secara eksplisit.
- Jika ada temuan, review formal berisi **Belum disetujui** dan job gagal.
- Jika inferensi gagal, cakupan parsial, atau bukti review tidak lengkap,
  bot tidak memberikan persetujuan; hasil formal menjelaskan bahwa review
  belum lengkap. Job gagal jika hasil tidak diterima dalam 10 menit.
- Saat review ulang dimulai, bot mencabut approval terdahulu yang dibuatnya
  melalui fitur ini. Review diserialkan antarworker. Head dan status PR diperiksa
  kembali sebelum serta setelah approval agar persetujuan commit lama tidak
  dipakai untuk commit baru.
- Komentar **PR Reviewer Guide** tetap memuat detail temuan dan diperbarui pada
  review berikutnya. Review formal menyediakan hasil yang lebih terlihat.

Atur repository variable `PR_AGENT_BOT_LOGIN` pada GitHub Actions dengan login
bot App yang terpasang (termasuk akhiran `[bot]`). Nilai aktual tidak ditulis
di source publik. Workflow hanya membaca metadata review; tidak menjalankan
kode PR dan tidak membutuhkan token provider atau izin Actions write.
Hanya ada satu job **Agent review**, yang dipicu saat review formal diterbitkan
atau approval dicabut. Sebelum hasil review tersedia, check wajib berstatus
menunggu; webhook server tetap memicu inferensi otomatis pada perubahan PR.
Komentar `/review`
tetap diproses server; event review formal berikutnya memperbarui check PR
tanpa job retry terpisah. Review manusia tidak dianggap sebagai approval bot.

Job **Agent review** hijau berarti agen menyetujui SHA tersebut. Kesiapan merge
juga memerlukan CI aplikasi, tidak ada konflik, dan syarat perlindungan branch
yang berlaku. Check **Agent review** dari GitHub Actions diwajibkan oleh ruleset
untuk `main` dan `release/*_apps`, mengikuti cakupan perlindungan yang sudah ada.
Syarat CI yang ada dipertahankan. Tidak ada auto-merge atau bypass baru.
Branch atau PR yang belum memuat workflow ini perlu diperbarui agar dapat
menghasilkan check wajib tersebut.

## File privat dan kompatibilitas

`private/deployment.toml` berisi nilai deployment aktual; contoh publik hanya
memakai domain contoh. `private/app.json` (600) berisi identitas App, private key,
dan webhook secret. `private/.secrets.toml` (640) memuat runtime settings dan
token provider. Direktori `private/` (750) dan `source/` tidak dilacak Git.
Container non-root membaca mount privat melalui grup yang ditetapkan Compose.

Shim `codex_lb.py` mendukung provider Responses streaming dengan memindahkan
pesan system/developer ke `instructions` dan memaksa `store=false`. Alamat model
harus sama persis dengan allowlist privat; allowlist kosong menolak startup.
HTTPS diwajibkan. Perubahan endpoint harus dilakukan operator melalui konfigurasi
provider privat dan `manage.py configure`, bukan argumen komentar PR.

Katalog `id.toml` menerjemahkan label review dan rincian eksekusi. Beberapa judul
dan label kepatuhan tiket masih mengikuti teks upstream.

## Operasi dan validasi

Pada direktori deployment di host:

```bash
docker compose ps
python3 manage.py verify
docker compose run --rm --no-deps reviewer python /deployment/smoke.py
docker compose run --rm --no-deps \
  -v "$PWD/test_deployment.py:/app/test_deployment.py:ro" \
  -v "$PWD/test_formal_review.py:/app/test_formal_review.py:ro" \
  reviewer python -m unittest test_deployment test_formal_review -v
```

`verify` memeriksa health dan HMAC tanpa inferensi atau akses database aplikasi.
`smoke.py` menjalankan inferensi sintetis tanpa publikasi GitHub. Pengujian unit
memeriksa transport, allowlist, pembatasan perintah, dan katalog bahasa.
Pengujian review formal juga memeriksa kegagalan, cakupan parsial, SHA berubah,
temuan aktif, revokasi persetujuan, dan mode dry-run tanpa publikasi.
Peringatan serializer usage LiteLLM/Pydantic dapat muncul meski inferensi berhasil.

`preview.py` merupakan alat validasi privat satu kali yang mengunci PR dan SHA;
hasilnya bukan bukti pemasangan App atau keberhasilan pemicu otomatis.
Deployment ini telah diverifikasi melalui review manual dan otomatis. Simpan
bukti host, waktu, identitas instalasi, dan hasil pemeriksaan pada catatan privat.

Untuk rotasi token, perbarui file kredensial privat, jalankan
`python3 manage.py configure`, lalu `docker compose up -d --force-recreate`.
Hindari mencetak isi konfigurasi runtime, prompt, atau log mentah ke publik.
Log container dibatasi 3 × 10 MB.

## Pembaruan dan rollback

Pilih revisi upstream secara eksplisit; simpan image dan file deployment lama.
Uji ulang unit test, smoke, HMAC, serta hasil review sebelum aktivasi. Jangan
mengganti pin dengan branch bergerak tanpa pengujian kompatibilitas.

Untuk menghentikan bot, nonaktifkan webhook App lalu jalankan
`docker compose stop`. Untuk rollback, pulihkan image, kode, dan konfigurasi
privat yang sesuai, lalu `docker compose up -d --force-recreate`. Jangan
menghapus private key atau mengubah tunnel dan layanan lain.
