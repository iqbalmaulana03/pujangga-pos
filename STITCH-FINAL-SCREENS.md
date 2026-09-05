# Stitch Final Screens

## Pujangga-POS

Dokumen ini menetapkan screen Stitch yang dipakai sebagai kandidat final wireframe MVP Android.

Karena project Stitch saat ini menyimpan screen lama dan screen hasil refinement secara berdampingan, daftar ini dipakai sebagai acuan canonical set untuk implementasi Flutter dan review berikutnya.

Status saat ini:

- `LOCKED FOR IMPLEMENTATION`
- Canonical set di bawah ini yang harus dipakai untuk implementasi Flutter sampai ada keputusan refinement baru yang eksplisit.

Project ID Stitch:

- `3855424189443229582`

Design system utama:

- `Warm Operational Minimalism`
- Asset ID: `3e715e741f7440ba841712065bb137f9`

## 1. Canonical Screen Set

### Alur Setup

- `Siapkan Bisnis`
  - Screen ID: `3a95eeb4db5c4eaba51876c6c11b6f9c`
  - Fungsi: onboarding awal usaha
  - Terkait issue: `#2`

### Alur Beranda dan Ringkasan

- `Beranda (Margin Insights)`
  - Screen ID: `3e1e0f8b40a642d7a78dd71a77bc45e1`
  - Fungsi: landing screen utama setelah setup dengan ringkasan omzet dan margin hari ini
  - Terkait issue: `#6`

### Alur Katalog

- `Katalog`
  - Screen ID: `143f9b18db9d4fcca87cf6f9beac08e5`
  - Fungsi: daftar barang dan jasa
  - Terkait issue: `#3`

- `Tambah Barang (Margin Integration)`
  - Screen ID: `b0e520e7ed2d4d7481c7b29017fa4e57`
  - Fungsi: form tambah/edit item dengan pemisahan jelas antara produk dan jasa serta input harga modal/biaya dasar
  - Terkait issue: `#3`

### Alur Transaksi

- `Transaksi Baru`
  - Screen ID: `20c72054c3824a1ab13cf4a2497158be`
  - Fungsi: checkout / input transaksi
  - Terkait issue: `#4`

- `Transaksi Berhasil (Refined)`
  - Screen ID: `5850c03fe09249a58f10b4d3073297d1`
  - Fungsi: ringkasan hasil transaksi dan CTA lanjutan
  - Terkait issue: `#4`

### Alur Stok

- `Manajemen Stok (Refined)`
  - Screen ID: `492ac73ccb0c49a7aa4277b70cef2b67`
  - Fungsi: ringkasan stok, alert stok menipis, dan entry point penyesuaian stok
  - Terkait issue: `#9`

### Alur Laporan

- `Laporan (Margin Refined)`
  - Screen ID: `0b87761dc37d4db3a89f40a1fdca0232`
  - Fungsi: laporan operasional utama dengan ringkasan margin kotor
  - Terkait issue: `#6`

### Alur Riwayat Transaksi

- `Riwayat Transaksi (Refined)`
  - Screen ID: `bc9d71eefe764dabbb279f9f8cadb250`
  - Fungsi: daftar transaksi sebelumnya
  - Terkait issue: `#8`

- `Riwayat Transaksi (Kosong)`
  - Screen ID: `fe7da2c17da346fd929e40456b61eae1`
  - Fungsi: empty state riwayat transaksi
  - Terkait issue: `#8`

- `Detail Transaksi`
  - Screen ID: `4d7d925fe610423880d0eafb586073ba`
  - Fungsi: detail transaksi seperti ringkasan struk
  - Terkait issue: `#8`

### Alur Pengeluaran Operasional

- `Tambah Pengeluaran`
  - Screen ID: `ba07a54505bf424ba01b0adb920cead6`
  - Fungsi: form pencatatan biaya operasional harian

### Alur Pengaturan

- `Pengaturan (Capital Feature)`
  - Screen ID: `575d0f627212423f83fa661c29db4395`
  - Fungsi: pengaturan usaha dengan modal awal usaha, preferensi operasional, dan manajemen data lokal tanpa konsep login atau logout
  - Terkait issue: `#7`

## 2. Aturan Navigasi Final

- Bottom navigation final harus konsisten dengan 5 item:
  - `Beranda`
  - `Katalog`
  - `Transaksi`
  - `Stok`
  - `Laporan`
- `Pengaturan` bukan tab utama.
- `Riwayat Transaksi` adalah subflow dari transaksi atau shortcut dari beranda, bukan tab baru.
- Screen form seperti `Tambah Barang` sebaiknya memakai app bar dengan tombol kembali, bukan bottom navigation utama.

## 3. Screen Lama yang Tidak Lagi Jadi Acuan

Screen berikut tidak dipakai sebagai referensi utama jika sudah ada versi refined atau versi berbahasa Indonesia:

- `Business Setup` - `fddc9b922cfe470799df2b00de130cdf`
- `Dashboard` - `83e192048f794f6681c8c7b2d8d8a34d`
- `Catalog` - `a3fa1349fd3947578dd2bdaa195e04e0`
- `Add/Edit Item` - `6f3d7a788bd547e18b65b2289e70dfb7`
- `New Sale` - `405698dbea0844b3839fa27ef21c54b6`
- `Transaction Success` - `5c9a8866a8a040a9a1e36d615e885234`
- `Stock Management` - `64f118bd35034f1a876230fc784334c7`
- `Reports` - `977f5a77fe2249e29705dcfb608e7b58`
- `Transaction History` - `5640a8e70acf43f78bfe85ac31e32d59`
- `Transaction Detail` - `90f8f1bf8be349a2a1180c11120e0b21`
- `Settings` - `51a67eb42b894b57962755d0241814f8`
- `Beranda` - `cc1e8b29c9d8417f96196e6a65046720`
- `Beranda (Refined)` - `78fea7bf17994ea1bbcf5ca3de51c0b6`
- `Laporan` - `c24c1bf5bdfc4d04b3434a5e5f444f1b`
- `Laporan (Refined)` - `62e0feb2c1cd431da53b60664d970555`
- `Riwayat Transaksi` - `83445c138f0945a8a8c4b20154fa48e7`
- `Tambah Barang` - `c526e0a669c14ecaa3518df5325b2df6`
- `Tambah Barang (Refined)` - `69e916e132b549ed87c38241c2748851`
- `Manajemen Stok` - `65f87a1902b04cde9ad0deb2fbf29e1a`
- `Pengaturan` - `0030e516d208429c827c3a444beea7fe`
- `Pengaturan (Refined)` - `19b70ffb87c84cf2a3878aefa3f825d3`
- `Pengaturan (Refined Local-First)` - `3eadc083cfe94d7a8210c1f1e82e3cfe`

## 4. Status Final

Untuk scope MVP saat ini, canonical screen set di atas dianggap final dan siap dipakai sebagai acuan implementasi Flutter.

Artinya:

- tidak ada refinement desain yang masih wajib dikerjakan sebelum implementasi
- `Laporan (Margin Refined)` sudah dianggap final untuk MVP
- refinement tambahan hanya dilakukan jika nanti ada keputusan produk baru, temuan QA, atau kebutuhan implementasi yang benar-benar memaksa perubahan
