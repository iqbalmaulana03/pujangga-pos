# CI/CD Android dan Google Play

Workflow berada di `.github/workflows/android-ci-cd.yml`.

Review PR Codex LB berada di `.github/workflows/codex-pr-review.yml`.

## Otomatisasi

- Pull request menuju `main` dan push ke `main`: Flutter `3.44.1` menjalankan `flutter analyze --fatal-infos` dan `flutter test` pada runner GitHub Actions.
- Pull request dari branch di repo yang sama: Codex LB meninjau diff dalam mode read-only dan membuat atau memperbarui satu komentar review. PR dari fork dilewati.
- Push ke branch rilis `release/<version>_apps`: setelah verifikasi lulus dan approval environment Production, workflow membangun AAB bertanda tangan dan mengunggahnya langsung ke track Production dengan staged rollout 10%. Artefak AAB disimpan selama 30 hari.
- Workflow dapat dijalankan manual dengan memilih branch rilis dan aksi `publish` atau `complete_rollout`. Job yang mengubah Play Store tetap menunggu approval environment Production.

Format branch: `release/<major>.<minor>.<patch>+<versionCode>_apps`, misalnya `release/1.2.2+3_apps`. Nilai versi di branch harus sama persis dengan `pubspec.yaml`; angka setelah `+` menjadi Android `versionCode`. Cek Play Console dan pastikan angkanya lebih besar daripada semua kode versi yang sudah pernah diunggah. Workflow tidak membaca Play Console untuk menentukan angka ini.

## Persiapan satu kali

1. Pastikan file keystore yang dirujuk oleh `storeFile` di `android/key.properties` adalah upload key yang sama dengan yang dipakai untuk aplikasi Play Store. Jangan membuat keystore baru untuk menggantikannya. Jika memakai Play App Signing, CI perlu upload key, bukan app signing key milik Google.
2. Pada GitHub repository, buka **Settings → Environments** dan siapkan environment `google-play-production`. Tambahkan secrets berikut ke environment tersebut:

   - `ANDROID_KEYSTORE_BASE64`: upload keystore yang sama dalam format Base64.
   - `ANDROID_KEYSTORE_PASSWORD`: password keystore.
   - `ANDROID_KEY_ALIAS`: alias upload key.
   - `ANDROID_KEY_PASSWORD`: password upload key.
   - `PLAY_SERVICE_ACCOUNT_JSON`: seluruh JSON service account Google Play Developer API.

   Workflow hanya menggunakan environment `google-play-production`. Atur deployment branch rule Production agar hanya mengizinkan `release/*_apps`, dan wajibkan reviewer untuk menyetujui rilis.

   Gunakan file yang dirujuk `storeFile` di `android/key.properties`. Contoh mengirim secret ke GitHub melalui GitHub CLI di PowerShell tanpa mencetak isi ke terminal:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\secure\upload-key.jks')) | gh secret set ANDROID_KEYSTORE_BASE64 --env google-play-production
   Get-Content -Raw 'C:\secure\play-service-account.json' | gh secret set PLAY_SERVICE_ACCOUNT_JSON --env google-play-production
   ```

   Set tiga nilai password/alias sebagai environment secrets di `google-play-production`. Jangan menaruh credential dalam repo, commit, log, atau chat.

3. Siapkan Google Play Developer API: tautkan Play Console dengan Google Cloud project, aktifkan Android Publisher API, buat service account, lalu beri akses minimum ke aplikasi ini untuk mengelola rilis Production. Unduh JSON key secara aman dan simpan sebagai secret `PLAY_SERVICE_ACCOUNT_JSON`.
4. Lindungi branch `main` dan branch rilis `release/*_apps`. Wajibkan job `Analyze and test` untuk merge; batasi pembuatan dan push ke branch rilis untuk maintainer yang berwenang.
5. Periksa bahwa `pubspec.lock` ikut dilacak dan jangan mengganti versi Flutter workflow tanpa memperbarui/mengecek SDK constraint proyek.

## Review PR dengan Codex LB

Workflow review memakai self-hosted GitHub Actions runner agar proses Codex dapat mengakses endpoint Codex LB lokal. Siapkan runner pada mesin yang menjalankan atau dapat menjangkau Codex LB, dan tambahkan label runner `codex-lb` selain label default `self-hosted`. Runner harus memiliki PowerShell 7 dan Codex CLI terpasang serta tersedia pada `PATH`. Instal Codex CLI satu kali saat menyiapkan runner dengan `npm install --global @openai/codex`; workflow tidak mengunduhnya ulang pada setiap PR. Node.js/npm diperlukan untuk instalasi awal. Batasi runner ini untuk repository ini; workflow hanya menerima PR dari branch di repository yang sama dan tidak berjalan untuk PR fork.

Di **Settings → Secrets and variables → Actions**, tambahkan:

- Repository secret `CODEX_API_KEY`: API key untuk Codex LB.
- Repository variable `CODEX_BASE_URL`: URL base endpoint Codex LB yang bisa dijangkau runner. Untuk layanan lokal, gunakan alamat dan port yang benar pada mesin runner.
- Repository variable `CODEX_MODEL`: nama model yang dikenali Codex LB.

Endpoint harus mendukung Responses API. Jangan commit API key ke file workflow atau repository. Pada setiap PR baru atau update commit, Codex hanya diminta membaca diff dan memberi temuan dalam komentar; hasil review tidak otomatis memblokir merge.

## Merilis

1. Naikkan `version:` di `pubspec.yaml` dan pastikan kode build lebih besar daripada semua versi yang pernah diunggah ke Play Console.
2. Merge perubahan ke `main` dan pastikan workflow `Analyze and test` berhasil.
3. Buat branch dari commit rilis dengan nama yang sesuai versi, misalnya `release/1.2.2+3_apps`, lalu push. Workflow memverifikasi nama/version, membangun AAB, dan mengunggahnya langsung ke Production setelah approval reviewer.
4. Pantau staged rollout 10% di Play Console. Untuk menyelesaikan rollout rilis yang sama ke 100%, buka **Actions → Android CI/CD → Run workflow**, pilih branch rilis yang sedang aktif, lalu pilih aksi `complete_rollout`. Verifikasi dan tes akan berjalan; setelah disetujui pada environment Production, job memeriksa bahwa versionCode branch cocok dengan satu-satunya rilis `inProgress` di track Production, lalu mengubah status rilis tersebut menjadi `completed`. Job ini tidak membangun atau mengunggah ulang AAB. Jika rilis sudah `completed`, job hanya melaporkan status tanpa perubahan. Perluas rollout hanya jika rilis yang dituju dan kondisi Play Console sudah benar; hentikan rollout jika ditemukan masalah.

Kredensial rilis Android hanya digunakan oleh job pada branch `release/*_apps` yang menunggu approval Production. Secret `CODEX_API_KEY` hanya digunakan oleh job review PR dari branch dalam repository yang sama.
