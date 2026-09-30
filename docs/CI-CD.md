# CI/CD Android dan Google Play

Workflow berada di `.github/workflows/android-ci-cd.yml`.

## Otomatisasi

- Pull request menuju `main` dan push ke `main`: Flutter `3.44.1` menjalankan `flutter analyze --fatal-infos` dan `flutter test` pada runner GitHub Actions.
- Push tag rilis `v<major>.<minor>.<patch>+<versionCode>`: setelah verifikasi lulus, workflow membangun AAB bertanda tangan, menyimpan artefak selama 30 hari, dan mengunggahnya ke Internal testing.
- Menjalankan workflow secara manual pada ref tag dengan track `production`: setelah approval environment GitHub, workflow mempromosikan versionCode yang sama dari Internal testing dan memulai staged rollout 10% ke Production.

Contoh tag: `v1.2.2+3`. Angka setelah `+` menjadi Android `versionCode`. Sebelum membuat tag, cek Play Console dan pilih angka yang lebih tinggi daripada semua kode versi yang sudah pernah diunggah. Workflow tidak membaca Play Console untuk menentukan angka ini.

## Persiapan satu kali

1. Pastikan file keystore yang dirujuk oleh `storeFile` di `android/key.properties` adalah upload key yang sama dengan yang dipakai untuk aplikasi Play Store. File itu ada di workspace lokal dan diabaikan Git; workflow memerlukan salinan file tersebut sebagai secret. Jangan membuat keystore baru untuk menggantikannya. Jika memakai Play App Signing, CI perlu upload key, bukan app signing key milik Google.
2. Pada GitHub repository, buka **Settings → Environments** dan buat dua environment: `google-play-internal` serta `google-play-production`. Buat secrets dengan cakupan environment berikut:

   Untuk `google-play-internal`:

   - `ANDROID_KEYSTORE_BASE64`: isi upload keystore yang sama dalam format Base64.
   - `ANDROID_KEYSTORE_PASSWORD`: password keystore.
   - `ANDROID_KEY_ALIAS`: alias upload key.
   - `ANDROID_KEY_PASSWORD`: password upload key.
   - `PLAY_SERVICE_ACCOUNT_JSON`: seluruh JSON service account Google Play Developer API.

   Untuk `google-play-production`, tambahkan `PLAY_SERVICE_ACCOUNT_JSON` yang sama. Atur deployment branch/tag rules kedua environment agar hanya mengizinkan tag `v*`. Jangan aktifkan approval pada environment Internal; wajibkan reviewer pada environment Production.

   Pada perintah pertama, gunakan file yang dirujuk oleh `storeFile` di `android/key.properties`. Contoh mengirim file ke secret GitHub melalui GitHub CLI di PowerShell tanpa mencetak isi ke terminal:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\secure\upload-key.jks')) | gh secret set ANDROID_KEYSTORE_BASE64 --env google-play-internal
   Get-Content -Raw 'C:\secure\play-service-account.json' | gh secret set PLAY_SERVICE_ACCOUNT_JSON --env google-play-internal
   Get-Content -Raw 'C:\secure\play-service-account.json' | gh secret set PLAY_SERVICE_ACCOUNT_JSON --env google-play-production
   ```

   Set tiga nilai password/alias sebagai environment secrets untuk `google-play-internal`. Jangan menaruhnya dalam file repo, commit, log, atau chat.

3. Siapkan Google Play Developer API: kaitkan Play Console dengan Google Cloud project, aktifkan Android Publisher API, buat service account, lalu beri akses minimum ke aplikasi ini untuk mengelola rilis testing dan production. Unduh JSON key secara aman dan simpan hanya sebagai secret `PLAY_SERVICE_ACCOUNT_JSON`.
4. Di environment `google-play-production`, pastikan required reviewer sudah dikonfigurasi sebelum menjalankan workflow ke production. GitHub dapat membuat environment baru tanpa aturan approval secara otomatis jika belum dibuat di Settings.
5. Lindungi branch `main` dan tag rilis `v*`. Wajibkan job `Analyze and test` untuk merge; batasi pembuatan tag rilis ke maintainer yang berwenang.
6. Periksa bahwa `pubspec.lock` ikut dilacak dan jangan mengganti versi Flutter workflow tanpa memperbarui/mengecek SDK constraint proyek.

## Merilis

1. Naikkan `version:` di `pubspec.yaml` untuk mencerminkan versi aplikasi yang dirilis dan pastikan kode build lebih besar daripada versi yang pernah diunggah ke Play Console. Tag harus sama persis dengan versi itu, termasuk angka setelah `+`.
2. Merge perubahan ke `main` dan pastikan workflow `Analyze and test` berhasil.
3. Buat serta push tag pada commit rilis, misalnya `v1.2.2+3`. Push tag langsung mengunggah rilis ke Internal testing.
4. Uji AAB melalui Internal testing dan verifikasi artefak/run pada tab **Actions**.
5. Untuk production, buka workflow **Android CI/CD**, pilih **Run workflow**, pilih ref tag yang sama, lalu pilih track `production`. Reviewer yang diwajibkan oleh environment `google-play-production` harus menyetujui deployment. Workflow mempromosikan rilis Internal yang versionCode-nya cocok (tidak mengunggah ulang AAB), lalu memulai rollout 10%; pantau Play Console dan hentikan rollout di sana jika ada masalah.

Workflow tidak mengirim perubahan langsung ke Production dari push/tag biasa. Kredensial hanya digunakan pada job rilis berbasis tag; job pull request tidak menerima secret.
