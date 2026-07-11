# Product Requirements Document (PRD)

## Pujangga-POS

## 1. Ringkasan Produk

Pujangga-POS adalah aplikasi mobile Android berbasis Flutter untuk membantu pemilik usaha kecil dan menengah mencatat transaksi penjualan secara cepat, rapi, dan mudah dipahami. Aplikasi ini ditujukan untuk berbagai jenis usaha seperti toko ikan, kedai kopi, toko bangunan, minimarket, dan barbershop, sehingga harus mendukung penjualan barang maupun jasa dalam satu aplikasi.

Pujangga-POS dirancang sebagai aplikasi single-user. Seluruh data usaha disimpan secara lokal di perangkat Android pengguna menggunakan SQLite. Aplikasi ini tidak memerlukan login, registrasi, atau akses multi-user.

## 2. Latar Belakang Masalah

Banyak pelaku usaha masih mencatat transaksi secara manual melalui buku tulis, kalkulator, atau chat. Dampaknya:

- Transaksi harian sulit direkap.
- Stok sering tidak akurat.
- Pemilik usaha sulit mengetahui produk atau layanan paling laris.
- Pemilik usaha sulit mengetahui modal yang sudah dikeluarkan dan margin yang dihasilkan.
- Kesalahan pencatatan kas sering terjadi.
- Riwayat transaksi sulit dicari saat dibutuhkan.

Pujangga-POS dibuat untuk mengatasi masalah tersebut melalui aplikasi Android yang ringan, sederhana, dan dapat dipakai langsung tanpa proses setup yang rumit.

## 3. Tujuan Produk

### Tujuan Bisnis

- Menjadi aplikasi POS Android yang mudah diadopsi oleh UMKM Indonesia.
- Menjangkau berbagai vertikal usaha tanpa perlu membuat aplikasi terpisah.
- Menjadi alat operasional harian yang benar-benar dipakai oleh pemilik usaha.

### Tujuan Pengguna

- Mencatat transaksi dalam waktu kurang dari 30 detik.
- Mengetahui omzet harian secara cepat.
- Mengetahui modal awal, biaya dasar item, dan margin secara lebih jelas.
- Melihat stok barang dengan lebih akurat.
- Mencatat layanan jasa seperti potong rambut, shaving, atau servis.
- Mengurangi ketergantungan pada pencatatan manual.

## 4. Target Pengguna

### Persona 1: Pemilik Toko Ikan

Karakteristik:

- Menjual produk yang cepat habis dan stoknya berubah cepat.
- Membutuhkan input harga dan kuantitas secara cepat.
- Sering menjual berdasarkan berat atau satuan.

Kebutuhan utama:

- Transaksi cepat.
- Dukungan satuan produk.
- Rekap penjualan harian.

### Persona 2: Pemilik Kedai Kopi

Karakteristik:

- Menjual makanan dan minuman dengan varian.
- Memiliki transaksi berulang sepanjang hari.

Kebutuhan utama:

- Katalog produk yang mudah dipilih.
- Catatan diskon dan metode pembayaran.
- Laporan produk terlaris.

### Persona 3: Pemilik Toko Bangunan / Minimarket

Karakteristik:

- Banyak SKU.
- Membutuhkan kontrol stok yang lebih rapi.

Kebutuhan utama:

- Manajemen produk dan stok.
- Riwayat transaksi.
- Pencarian item yang cepat.

### Persona 4: Pemilik Barbershop

Karakteristik:

- Menjual jasa dan kadang produk tambahan.
- Membutuhkan pencatatan layanan yang sederhana.

Kebutuhan utama:

- Input layanan seperti haircut, shaving, coloring.
- Dukungan transaksi campuran jasa + produk.
- Laporan pendapatan per layanan.

## 5. Ruang Lingkup Produk

Pujangga-POS harus mendukung dua model utama:

- Penjualan barang.
- Penjualan jasa.

Aplikasi juga harus mendukung transaksi campuran, misalnya barbershop yang menjual pomade atau kedai kopi yang menjual biji kopi kemasan.

## 6. Value Proposition

- Satu aplikasi POS untuk banyak jenis usaha.
- Antarmuka sederhana untuk pengguna non-teknis.
- Tidak memerlukan internet untuk operasional inti.
- Seluruh data tersimpan lokal di perangkat Android pengguna.
- Mendukung operasional barang dan jasa dalam satu alur.

## 7. Fitur Utama MVP

### 7.1 Setup Awal Aplikasi

Saat pertama kali membuka aplikasi, pengguna dapat:

- Mengisi profil usaha.
- Memilih jenis usaha.
- Mengatur informasi dasar yang akan digunakan aplikasi.

Data profil usaha minimum:

- Nama usaha.
- Jenis usaha.
- Alamat opsional.
- Nomor kontak opsional.
- Nama pemilik opsional.

### 7.2 Manajemen Produk dan Jasa

Pengguna dapat membuat item katalog dengan tipe:

- Barang.
- Jasa.

Field minimum item:

- Nama item.
- Kategori.
- Tipe item.
- Harga jual.
- SKU atau kode item opsional.
- Satuan opsional.
- Stok awal untuk barang.
- Status aktif/nonaktif.

Contoh satuan:

- Ekor.
- Kg.
- Pcs.
- Cup.
- Botol.
- Layanan.

Kebutuhan tambahan:

- Kategori produk/jasa.
- Pencarian item cepat.
- Filter berdasarkan kategori dan tipe.
- Input harga modal atau biaya dasar item untuk kebutuhan hitung margin.

### 7.3 Transaksi Penjualan

Alur utama transaksi:

1. Pengguna memilih item dari katalog.
2. Pengguna dapat menambah kuantitas atau jumlah layanan.
3. Sistem menghitung subtotal otomatis.
4. Pengguna dapat memberi diskon per item atau total transaksi.
5. Pengguna memilih metode pembayaran.
6. Sistem menyimpan transaksi ke SQLite dan mengurangi stok untuk item barang.
7. Sistem menampilkan bukti transaksi sederhana.

Kebutuhan detail:

- Dukungan transaksi barang, jasa, dan campuran.
- Catatan pelanggan opsional.
- Catatan transaksi opsional.
- Diskon nominal dan persentase.
- Pajak opsional.
- Pembayaran tunai, transfer, QRIS, e-wallet, dan kartu sebagai label metode pembayaran.
- Hitung kembalian untuk pembayaran tunai.
- Nomor invoice otomatis.

### 7.4 Riwayat Transaksi

Pengguna dapat:

- Melihat daftar transaksi.
- Mencari transaksi berdasarkan nomor invoice atau nama item.
- Memfilter berdasarkan tanggal dan metode pembayaran.
- Membuka detail transaksi.

Untuk MVP minimum:

- Lihat daftar transaksi.
- Lihat detail transaksi.
- Filter tanggal.

### 7.5 Manajemen Stok Dasar

Khusus item barang:

- Stok berkurang otomatis saat transaksi berhasil.
- Pengguna dapat melakukan penyesuaian stok manual.
- Sistem menyimpan histori penyesuaian stok.

Untuk MVP minimum:

- Stok awal.
- Pengurangan otomatis dari transaksi.
- Penyesuaian manual.

### 7.6 Dashboard dan Laporan Dasar

Dashboard menampilkan:

- Omzet hari ini.
- Margin hari ini.
- Jumlah transaksi hari ini.
- Item terlaris.
- Metode pembayaran teratas.

Laporan minimum:

- Penjualan harian.
- Penjualan mingguan.
- Penjualan bulanan.
- Rekap per produk/jasa.
- Ringkasan modal dan margin.

### 7.7 Pengaturan Usaha

Pengguna dapat mengatur:

- Nama usaha.
- Logo usaha.
- Alamat.
- Nomor kontak.
- Modal awal usaha.
- Mata uang default rupiah.
- Format tampilan struk sederhana.

## 8. Fitur Fase Lanjutan

Fitur berikut tidak wajib untuk rilis MVP, tetapi perlu masuk roadmap:

- Backup dan restore data lokal.
- Ekspor PDF/Excel.
- Integrasi printer bluetooth.
- Integrasi scanner barcode.
- Manajemen supplier.
- Pembelian dan stok masuk.
- Promo bundling.
- Membership pelanggan.
- Booking layanan untuk barbershop.
- Notifikasi stok menipis.
- Sinkronisasi cloud opsional di masa depan.

## 9. User Stories Prioritas

### Pemilik Usaha

- Sebagai pemilik usaha, saya ingin membuat katalog produk dan jasa agar transaksi lebih cepat.
- Sebagai pemilik usaha, saya ingin melihat omzet harian agar saya tahu performa usaha hari ini.
- Sebagai pemilik usaha, saya ingin mencatat modal awal dan biaya dasar item agar saya bisa melihat margin usaha.
- Sebagai pemilik usaha, saya ingin memantau stok barang agar tidak kehabisan produk.
- Sebagai pemilik usaha, saya ingin mencari riwayat transaksi agar mudah mengecek transaksi sebelumnya.

### Pengguna Operasional

- Sebagai pengguna aplikasi, saya ingin mencari item dengan cepat agar pencatatan transaksi tidak lama.
- Sebagai pengguna aplikasi, saya ingin mencatat pembayaran tunai dan menghitung kembalian otomatis agar transaksi akurat.
- Sebagai pengguna aplikasi, saya ingin menjual barang dan jasa dalam satu transaksi agar pencatatan tetap sederhana.

## 10. Kebutuhan Fungsional

### 10.1 Setup Usaha

- Sistem harus menampilkan setup awal saat aplikasi pertama kali dibuka.
- Sistem harus menyimpan profil usaha secara lokal di SQLite.
- Sistem harus memungkinkan pengguna mengubah profil usaha dari menu pengaturan.

### 10.2 Master Data

- Sistem harus memungkinkan pembuatan, perubahan, dan penonaktifan item.
- Sistem harus membedakan item barang dan jasa.
- Sistem harus mendukung kategori item.
- Sistem harus menyimpan harga modal atau biaya dasar item untuk kebutuhan analisis margin.

### 10.3 Penjualan

- Sistem harus dapat membuat transaksi baru.
- Sistem harus menghitung subtotal, diskon, pajak, total, pembayaran, dan kembalian.
- Sistem harus menghasilkan nomor invoice unik.
- Sistem harus mengurangi stok item barang secara otomatis.
- Sistem harus menyimpan header transaksi dan detail item transaksi ke SQLite.

### 10.4 Laporan

- Sistem harus menampilkan ringkasan omzet berdasarkan rentang waktu.
- Sistem harus menampilkan ringkasan margin berdasarkan rentang waktu.
- Sistem harus menampilkan rekap item terjual.
- Sistem harus dapat menghitung margin per item dan margin total transaksi berdasarkan harga jual dikurangi harga modal atau biaya dasar.
- Sistem harus menampilkan jumlah transaksi per hari.

### 10.4.1 Modal dan Margin

- Sistem harus memungkinkan pengguna menyimpan modal awal usaha pada pengaturan usaha.
- Sistem harus memungkinkan pengguna mengisi harga modal untuk item barang.
- Sistem harus memungkinkan pengguna mengisi biaya dasar untuk item jasa bila relevan.
- Sistem harus menghitung estimasi margin kotor pada level item, transaksi, dan laporan.
- Sistem harus tetap dapat berfungsi jika sebagian item belum memiliki harga modal, dengan menandai margin sebagai belum lengkap.

### 10.5 Stok

- Sistem harus menyimpan stok awal barang.
- Sistem harus mengizinkan penyesuaian stok manual.
- Sistem harus menyimpan histori perubahan stok.

### 10.6 Penyimpanan Lokal

- Sistem harus menggunakan SQLite sebagai database utama aplikasi.
- Sistem harus dapat membaca data dengan cepat pada perangkat Android kelas menengah.
- Sistem harus tetap dapat berfungsi tanpa koneksi internet untuk fitur inti POS.

## 11. Kebutuhan Non-Fungsional

### Performa

- Waktu buka halaman transaksi maksimal 2 detik pada perangkat Android mid-range.
- Penyimpanan transaksi harus terasa instan bagi pengguna.

### Kemudahan Penggunaan

- Alur transaksi harus bisa dipelajari tanpa training formal.
- Tombol utama harus mudah dijangkau dengan satu tangan pada ponsel Android.

### Reliabilitas

- Data transaksi tidak boleh hilang saat aplikasi ditutup normal.
- SQLite harus menjadi sumber data utama untuk transaksi, stok, katalog, dan pengaturan usaha.
- SQLite harus menjadi sumber data utama untuk modal awal, harga modal item, dan data margin turunan.

### Keamanan

- Data lokal harus tersimpan secara konsisten dan tidak mudah rusak akibat crash aplikasi.
- Akses aplikasi diasumsikan hanya oleh satu pengguna pada satu perangkat.

### Skalabilitas

- Arsitektur aplikasi harus memungkinkan penambahan fitur backup, restore, dan sinkronisasi cloud di fase berikutnya tanpa perlu merombak seluruh modul inti.

## 12. Asumsi Teknis Awal

- Platform: Android saja.
- Framework: Flutter.
- Bahasa: Dart.
- Database lokal utama: SQLite.
- Aplikasi berjalan dengan pendekatan local-first.
- Tidak ada backend pada MVP.
- Tidak ada autentikasi, registrasi, login, atau manajemen multi-user.

Rekomendasi implementasi teknis:

- Gunakan SQLite sebagai sumber data utama untuk seluruh modul.
- Pisahkan tabel master dan tabel transaksi agar query laporan tetap efisien.
- Siapkan lapisan repository agar mudah ditambah fitur backup/export di masa depan.

## 13. Arsitektur Modul Produk

Modul utama aplikasi:

- Setup awal usaha.
- Profil usaha.
- Katalog item.
- Transaksi penjualan.
- Riwayat transaksi.
- Stok.
- Dashboard dan laporan.
- Modal dan margin.
- Pengaturan.
- Database lokal SQLite.

## 14. Metrik Keberhasilan

### Metrik Aktivasi

- Persentase pengguna yang berhasil menyelesaikan setup usaha pertama kali.
- Persentase pengguna yang menambahkan minimal 5 item katalog.
- Persentase pengguna yang membuat transaksi pertama pada hari yang sama setelah setup.

### Metrik Engagement

- Jumlah transaksi per perangkat per hari.
- Frekuensi penggunaan aplikasi per hari.
- Frekuensi pembukaan dashboard/laporan.

### Metrik Retensi

- Retensi 7 hari.
- Retensi 30 hari.
- Persentase pengguna yang masih aktif mencatat transaksi setelah 1 bulan.

### Metrik Operasional

- Waktu rata-rata membuat transaksi.
- Tingkat error penyimpanan transaksi.
- Jumlah koreksi stok manual.
- Persentase item yang sudah memiliki data harga modal.
- Frekuensi pembukaan laporan margin.

## 15. Risiko Produk

- Scope terlalu luas karena target usaha sangat beragam.
- Kebutuhan tiap vertikal bisa berbeda jauh jika tidak dibatasi dengan baik.
- Pengguna non-teknis bisa merasa aplikasi rumit bila terlalu banyak fitur di awal.
- Karena data hanya tersimpan lokal, risiko kehilangan data meningkat jika perangkat rusak, hilang, atau aplikasi dihapus.

Mitigasi:

- Fokus pada alur universal POS terlebih dahulu.
- Bedakan fitur inti dengan fitur vertikal-spesifik.
- Uji coba awal ke 2-3 jenis usaha berbeda.
- Masukkan fitur backup dan restore ke roadmap prioritas setelah MVP.

## 16. Batasan MVP

MVP tidak mencakup:

- Login, registrasi, dan multi-user.
- Sinkronisasi cloud.
- Akuntansi penuh.
- Multi-gudang kompleks.
- Integrasi marketplace.
- CRM lanjutan.
- Payroll karyawan.
- Booking dan antrian kompleks.
- Analitik tingkat enterprise.

## 17. Prioritas Rilis MVP

Prioritas 1:

- Setup awal usaha.
- Master produk/jasa.
- Transaksi penjualan.
- Riwayat transaksi.
- Laporan harian dasar.
- Input modal awal usaha.
- Input harga modal item dan tampilan margin dasar.
- Penyimpanan SQLite penuh untuk semua data inti.

Prioritas 2:

- Penyesuaian stok.
- Laporan mingguan dan bulanan.
- Filter transaksi lebih lengkap.

Prioritas 3:

- Backup dan restore lokal.
- Printer bluetooth.
- Barcode.
- Membership.

## 18. Kriteria Keberhasilan MVP

MVP dianggap berhasil jika:

- Pengguna dapat menyelesaikan setup awal usaha kurang dari 5 menit.
- Pengguna dapat mencatat transaksi barang atau jasa tanpa error kritis.
- Pengguna dapat melihat omzet harian dan riwayat transaksi.
- Pengguna dapat mengisi modal awal usaha dan melihat margin dasar dari transaksi yang memiliki data modal.
- Stok barang berkurang otomatis setelah penjualan.
- Seluruh data inti tersimpan dan dapat dibaca kembali dari SQLite dengan stabil.
- Aplikasi layak dipakai untuk operasional harian usaha kecil di perangkat Android.

## 19. Open Questions

Hal yang perlu diputuskan sebelum desain dan development detail:

- Apakah fitur backup lokal masuk MVP atau fase setelah MVP.
- Apakah laporan perlu bisa diekspor sejak MVP.
- Apakah printer struk bluetooth masuk MVP atau fase berikutnya.
- Apakah setiap jenis usaha butuh template katalog bawaan saat setup awal.
- Apakah perlu proteksi aplikasi sederhana seperti PIN lokal meskipun tidak ada login.
- Apakah margin cukup ditampilkan sebagai margin kotor pada MVP, tanpa memasukkan biaya operasional lain.
- Apakah modal awal usaha hanya sebagai angka referensi atau ikut masuk ke ringkasan profitabilitas.

## 20. Rekomendasi Langkah Berikutnya

Setelah PRD ini, tahap yang disarankan adalah:

1. Menyusun daftar fitur final MVP yang benar-benar masuk versi Android pertama.
2. Membuat user flow utama untuk setup usaha, katalog, transaksi, stok, dan laporan.
3. Mendesain struktur tabel SQLite untuk produk, jasa, transaksi, detail transaksi, stok, dan pengaturan usaha.
4. Membuat wireframe Flutter untuk setup awal, transaksi, katalog, dan dashboard.
5. Menentukan arsitektur teknis aplikasi Flutter Android yang local-first.
