# Perbaikan logo usaha

Mode: `implement`, 31 Oktober 2026. Checkout `build/size-optimization`, branch `perf/reduce-android-download`, basis `df08f4bf7aa22ea0cc68ca44266f6f5a09f8c765` ditambah perubahan lokal optimasi ukuran/RAM sebelumnya. Belum di-commit, push, atau dipublikasikan.

## Perilaku akhir

- Logo kanan atas, katalog, dan pemilihan item transaksi memakai sumber lokal yang sama. Gambar internet yang dipilih berdasarkan nama produk dihapus; nama seperti Arabica, Mesin Kopi, atau French Press tidak memicu permintaan gambar internet.
- Logo hilang/rusak menampilkan ikon toko, bukan bidang kosong. `BoxFit.contain` menampilkan seluruh logo; dekode mengikuti ukuran tampilan/DPR dengan cache bersama 24 MiB / 100 entri.
- Setup dan edit profil menyediakan Pilih Logo, pratinjau, dan Hapus Logo. Input path manual pada form profil lama juga diganti. Picker memakai `file_picker` yang sudah ada; tidak ada dependensi atau izin penyimpanan menyeluruh baru.
- Sumber PNG/JPEG/WebP statis dibatasi 10 MiB, 16.777.216 piksel, dan 8.192 piksel per sisi. Gambar dinormalisasi ke PNG maksimal 1.024 piksel pada sisi terpanjang tanpa upscaling, dengan transparansi dipertahankan. Animasi ditolak.
- File tersimpan dalam folder privat `business_logos` dengan nama acak baru setiap penggantian; draft berada dalam folder sementara `logo_drafts`. Pembatalan membersihkan draft, kegagalan simpan mempertahankan logo lama, dan penghapusan hanya berlaku untuk file milik folder aplikasi. File sumber pengguna tidak dihapus.
- Logo lama yang masih terbaca diimpor saat profil disimpan. Referensi lama yang rusak tetap bisa dipertahankan ketika pengguna hanya mengubah profil; UI menawarkan memilih ulang atau menghapusnya.
- Simpan profil dan riwayat modal terkait berjalan dalam satu transaksi. Kegagalan controller diteruskan ke UI; dialog tidak ditutup pada kegagalan. Edit profil hanya memperbarui provider profil dan tidak menginvalidasi startup/router, agar navigasi dan state tab tetap terjaga.
- Startup membersihkan file terkelola yang tidak direferensikan. Reset membersihkan logo setelah reset database berhasil. Kegagalan pembersihan tidak membatalkan simpan yang sudah commit.

## Backup dan kompatibilitas

Ekspor baru menggunakan `format_version: 3` dengan `assets.business_logo` berisi `mime_type: image/png` dan `data_base64`, atau `null`. `logo_path` pada profil yang diekspor dikosongkan; path perangkat asal tidak dibawa.

Reader menerima versi 2 dan 3, tetap menolak versi 1. Backup versi 2 memulihkan data usaha tetapi mengosongkan path logo dan memberi pemberitahuan untuk memilih gambar ulang. Aplikasi lama yang hanya mendukung versi 2 tidak dapat membaca backup versi 3; gunakan aplikasi yang telah diperbarui untuk restore backup baru.

Aset restore harus berupa PNG statis valid, maksimal 5 MiB setelah decode Base64 dan 1.024 piksel per sisi. Validasi dilakukan sebelum penggantian data. File baru disiapkan sebelum transaksi SQLite; rollback membersihkannya dan mempertahankan logo lama. Restore membuat path privat baru dan tidak mempercayai path dari backup. Jika logo sumber ekspor hilang/rusak, data tetap dicadangkan dengan pemberitahuan tanpa aset logo.

Tidak ada perubahan skema database. API internal menambahkan hasil warning pada backup/restore dan byte logo pada kandidat restore; `BusinessProfile.copyWith(logoPath: null)` kini berarti menghapus logo secara eksplisit.

## Referensi UI

Mengikuti Siapkan Bisnis `3a95eeb4db5c4eaba51876c6c11b6f9c`, Katalog `143f9b18db9d4fcca87cf6f9beac08e5`, Transaksi Baru `20c72054c3824a1ab13cf4a2497158be`, dan Pengaturan `575d0f627212423f83fa661c29db4395`. Lima tab utama dan urutan bagian dipertahankan.

Penambahan pemilih logo opsional sebelum CTA setup serta penggantian field path menjadi pemilih gambar merupakan perubahan UI sesuai rencana yang disetujui. Area logo menggunakan contain agar tidak terpotong. Tidak ada penambahan foto per produk atau perubahan cetakan struk. Screenshot diperiksa secara visual; perbandingan piksel dengan Stitch belum dilakukan.

## Bukti pengujian

`flutter analyze --no-pub` lulus; `flutter test --no-pub` lulus seluruh 93 tes. Delapan belas tes khusus logo mencakup validasi format/dimensi/transparansi, draft picker, pembatalan, file rusak/hilang, gagal tulis file, gagal commit profil, rollback restore, backup v2/v3, cleanup/reset, dan propagasi error controller. Tes tambahan memastikan nama produk tidak memilih gambar jaringan. APK QA release akhir berhasil dibangun serta dipasang.

QA perangkat memakai paket terpisah `com.pujanggapos.pujangga_pos.logoaudit` pada Redmi 2201116TG / Android 13. Entrypoint menolak seed di luar sandbox paket QA. Semua data adalah sintetis: 1.000 item, 10.000 transaksi, dan logo uji. Database unit/integrasi memakai SQLite FFI dalam direktori sementara yang dibuat dan dikonfigurasi khusus per tes; tes UI memakai override provider.

Pada perangkat: logo valid, hilang, rusak, dihapus, dan diganti diperiksa di katalog/transaksi; restore mengembalikan gambar dengan path baru. Pemilihan PNG melalui pemilih file Android diuji langsung, lalu file Downloads milik pengujian dihapus dan aplikasi di-restart: logo tetap tampil dari penyimpanan privat.

[Pemilih logo dan hasil setelah restart](business-logo-native-qa.png) · [Logo valid dan fallback](business-logo-fallback-qa.png). Pada APK akhir, simpan profil diuji kembali: layar pengaturan tetap terpasang dan navigasi ke katalog berhasil tanpa reset router.

Pengukuran release build akhir: median tiga restart proses, dengan skenario yang sama seperti audit RAM sebelumnya (startup, scroll katalog, dua putaran navigasi, riwayat, dan sepuluh kali buka/tutup scanner). Sumber logo sintetis tetap 4096×4096; perbaikan ini menyimpannya sebagai PNG 1024×1024 sebelum tampilan. Angka berikut MiB; sebelum adalah versi yang sudah dioptimasi RAM, sebelum perbaikan logo.

| Tahap | Resident PSS sebelum → akhir | RSS sebelum → akhir |
| --- | ---: | ---: |
| startup | 212.5 → 144.2 | 326.1 → 265.9 |
| catalog | 163.8 → 153.3 | 281.9 → 281.0 |
| history | 177.9 → 167.5 | 296.9 → 294.7 |
| navigation | 157.5 → 149.9 | 274.3 → 274.7 |
| scanner | 183.4 → 172.0 | 301.9 → 302.7 |

Cache katalog versi akhir 1,06 MiB / dua entri untuk 1.000 item. Avatar memakai 64 KiB karena ukuran dekode dikelompokkan per 64 piksel; versi sebelumnya memakai sekitar 30 KiB untuk avatar. Tambahan kecil ini tetap berada dalam batas cache 24 MiB. TOTAL PSS OEM menyertakan swap; resident dihitung dengan mengurangkan TOTAL SWAP PSS. Sampel terpisah, swap, Java/native/graphics, dan checksum APK ada di [BUSINESS-LOGO-MEASUREMENTS.json](BUSINESS-LOGO-MEASUREMENTS.json).

PSS/RSS perangkat memiliki variasi dan hasil ini bukan pembuktian bebas leak jangka panjang atau janji RAM di bawah 20 MiB. Tidak dilakukan pengambilan heap snapshot DevTools. Foto pribadi atau layar akun pemilih file tidak disertakan dalam artefak laporan.

Paket QA dan ADB forward telah dihapus. File uji Downloads telah dihapus setelah verifikasi hash; file pengguna lain tidak diubah. Application ID Gradle produksi telah dipulihkan, dan salinan signing sementara di worktree dihapus setelah dicocokkan dengan sumber. Paket Play Store tetap versi 1.2.3+4 dari `com.android.vending`; tidak digunakan untuk seed, reset, restore, atau pengujian transaksi. Checkout rilis tetap bersih. Artefak laporan hanya memuat data sintetis dan tidak menyertakan kredensial, keystore, atau data usaha pengguna. Perubahan kode masih lokal dan belum dipublikasikan.
