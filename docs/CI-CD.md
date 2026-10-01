# CI/CD Android dan Google Play

Workflow berada di `.github/workflows/android-ci-cd.yml`.

## Otomatisasi

- Pull request menuju `main` dan push ke `main`: Flutter `3.44.1` menjalankan `flutter analyze --fatal-infos` dan `flutter test` pada runner GitHub Actions.
- Push tag rilis `v<major>.<minor>.<patch>+<versionCode>`: setelah verifikasi lulus dan approval environment Production, workflow membangun AAB bertanda tangan dan mengunggahnya langsung ke track Production dengan staged rollout 10%. Artefak AAB disimpan selama 30 hari.
- Workflow dapat dijalankan manual dengan memilih ref tag rilis. Job rilis tetap menunggu approval environment Production.

Contoh tag: `v1.2.2+3`. Angka setelah `+` menjadi Android `versionCode`. Sebelum membuat tag, cek Play Console dan pilih angka yang lebih tinggi daripada semua kode versi yang sudah pernah diunggah. Workflow tidak membaca Play Console untuk menentukan angka ini.

## Persiapan satu kali

1. Pastikan file keystore yang dirujuk oleh `storeFile` di `android/key.properties` adalah upload key yang sama dengan yang dipakai untuk aplikasi Play Store. Jangan membuat keystore baru untuk menggantikannya. Jika memakai Play App Signing, CI perlu upload key, bukan app signing key milik Google.
2. Pada GitHub repository, buka **Settings → Environments** dan siapkan environment `google-play-production`. Tambahkan secrets berikut ke environment tersebut:

   - `ANDROID_KEYSTORE_BASE64`: upload keystore yang sama dalam format Base64.
   - `ANDROID_KEYSTORE_PASSWORD`: password keystore.
   - `ANDROID_KEY_ALIAS`: alias upload key.
   - `ANDROID_KEY_PASSWORD`: password upload key.
   - `PLAY_SERVICE_ACCOUNT_JSON`: seluruh JSON service account Google Play Developer API.

   Workflow hanya menggunakan environment `google-play-production`. Atur deployment tag rule Production agar hanya mengizinkan tag `v*`, dan wajibkan reviewer untuk menyetujui rilis.

   Gunakan file yang dirujuk `storeFile` di `android/key.properties`. Contoh mengirim secret ke GitHub melalui GitHub CLI di PowerShell tanpa mencetak isi ke terminal:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\secure\upload-key.jks')) | gh secret set ANDROID_KEYSTORE_BASE64 --env google-play-production
   Get-Content -Raw 'C:\secure\play-service-account.json' | gh secret set PLAY_SERVICE_ACCOUNT_JSON --env google-play-production
   ```

   Set tiga nilai password/alias sebagai environment secrets di `google-play-production`. Jangan menaruh credential dalam repo, commit, log, atau chat.

3. Siapkan Google Play Developer API: tautkan Play Console dengan Google Cloud project, aktifkan Android Publisher API, buat service account, lalu beri akses minimum ke aplikasi ini untuk mengelola rilis Production. Unduh JSON key secara aman dan simpan sebagai secret `PLAY_SERVICE_ACCOUNT_JSON`.
4. Lindungi branch `main` dan tag rilis `v*`. Wajibkan job `Analyze and test` untuk merge; batasi pembuatan tag rilis ke maintainer yang berwenang.
5. Periksa bahwa `pubspec.lock` ikut dilacak dan jangan mengganti versi Flutter workflow tanpa memperbarui/mengecek SDK constraint proyek.

## Merilis

1. Naikkan `version:` di `pubspec.yaml` dan pastikan kode build lebih besar daripada semua versi yang pernah diunggah ke Play Console. Tag harus sama persis dengan versi tersebut, termasuk angka setelah `+`.
2. Merge perubahan ke `main` dan pastikan workflow `Analyze and test` berhasil.
3. Buat serta push tag pada commit rilis, misalnya `v1.2.2+3`. Workflow memverifikasi versi, membangun AAB, dan mengunggahnya langsung ke Production setelah approval reviewer.
4. Pantau staged rollout 10% di Play Console. Perluas rollout atau hentikan jika ditemukan masalah.

Job pull request tidak menerima secret. Kredensial hanya digunakan oleh job rilis berbasis tag yang menunggu approval Production.
