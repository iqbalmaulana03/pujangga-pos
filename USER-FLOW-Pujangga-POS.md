# User Flow Utama

## Pujangga-POS

## 1. Tujuan Dokumen

Dokumen ini menjabarkan user flow utama untuk MVP Android Pujangga-POS. Flow difokuskan pada lima area inti:

- Setup usaha
- Katalog
- Transaksi
- Stok
- Laporan

Dokumen ini ditujukan sebagai acuan untuk:

- Wireframe
- Navigasi aplikasi
- Breakdown task engineering
- Validasi scope MVP

## 2. Prinsip Alur MVP

- Aplikasi single-user tanpa login.
- Semua data tersimpan lokal di SQLite.
- Alur harus sederhana dan cepat dipahami pengguna non-teknis.
- Pengguna harus bisa mulai transaksi secepat mungkin setelah setup awal.
- Aksi yang paling sering dipakai harus bisa dicapai dengan sedikit tap.

## 3. Struktur Navigasi Utama

Struktur navigasi utama yang direkomendasikan:

- Beranda
- Katalog
- Transaksi
- Stok
- Laporan
- Pengaturan

Catatan:

- `Transaksi` harus menjadi entry point utama untuk operasional harian.
- `Beranda` menampilkan ringkasan bisnis dan shortcut ke aksi penting.
- `Pengaturan` memuat profil usaha dan preferensi dasar.

## 4. Flow 1: Setup Usaha Pertama Kali

### Tujuan

Memastikan pengguna dapat menyelesaikan setup awal dan langsung mulai memakai aplikasi.

### Trigger

- Aplikasi dibuka pertama kali.
- Database lokal belum memiliki profil usaha.

### Alur Utama

1. Pengguna membuka aplikasi.
2. Sistem mengecek apakah profil usaha sudah ada di SQLite.
3. Jika belum ada, sistem menampilkan layar welcome/setup awal.
4. Pengguna menekan tombol `Mulai`.
5. Pengguna mengisi form profil usaha.
6. Pengguna memilih jenis usaha.
7. Pengguna menekan tombol `Simpan dan Lanjutkan`.
8. Sistem memvalidasi input wajib.
9. Jika valid, sistem menyimpan profil usaha ke SQLite.
10. Sistem mengarahkan pengguna ke beranda kosong dengan prompt untuk menambah katalog.

### Field Wajib

- Nama usaha
- Jenis usaha

### Field Opsional

- Alamat
- Nomor kontak
- Nama pemilik

### Empty State Setelah Setup

Setelah setup berhasil, beranda menampilkan:

- Ringkasan bahwa usaha sudah siap digunakan
- Shortcut `Tambah Item`
- Shortcut `Buat Transaksi`

### Alternate Flow

- Jika pengguna menutup aplikasi sebelum menyimpan, saat membuka kembali aplikasi akan kembali ke setup awal.
- Jika field wajib kosong, sistem menampilkan validasi inline dan tidak menyimpan data.

### Outcome

- Profil usaha tersimpan lokal.
- Pengguna masuk ke aplikasi utama.

## 5. Flow 2: Manajemen Katalog Produk dan Jasa

### Tujuan

Memungkinkan pengguna membuat katalog barang dan jasa sebelum melakukan transaksi.

### Entry Point

- Menu `Katalog`
- Shortcut `Tambah Item` dari beranda
- Prompt setelah setup awal

### Alur Utama Tambah Item

1. Pengguna membuka halaman `Katalog`.
2. Sistem menampilkan daftar item atau empty state jika belum ada data.
3. Pengguna menekan tombol `Tambah Item`.
4. Pengguna memilih tipe item:
   - Barang
   - Jasa
5. Pengguna mengisi form item.
6. Jika tipe item adalah barang, sistem menampilkan field stok awal.
7. Pengguna menekan tombol `Simpan`.
8. Sistem memvalidasi data.
9. Sistem menyimpan item ke SQLite.
10. Sistem kembali ke daftar katalog dan menampilkan item baru.

### Field Item

- Nama item
- Kategori
- Tipe item
- Harga jual
- SKU opsional
- Satuan opsional
- Stok awal untuk barang
- Status aktif/nonaktif

### Alur Edit Item

1. Pengguna membuka daftar katalog.
2. Pengguna memilih item.
3. Sistem menampilkan detail singkat atau form edit.
4. Pengguna mengubah data item.
5. Pengguna menekan `Simpan`.
6. Sistem memperbarui data di SQLite.

### Alur Nonaktifkan Item

1. Pengguna membuka item.
2. Pengguna memilih aksi `Nonaktifkan`.
3. Sistem meminta konfirmasi.
4. Sistem mengubah status item menjadi nonaktif.
5. Item tidak muncul di pemilihan transaksi.

### Alur Pencarian dan Filter

1. Pengguna membuka halaman katalog.
2. Pengguna mengetik kata kunci atau memilih filter.
3. Sistem menampilkan hasil berdasarkan nama, kategori, atau tipe item.

### Empty State

Jika belum ada item, tampilkan:

- Pesan bahwa katalog masih kosong
- Tombol `Tambah Item Pertama`

### Outcome

- Katalog siap dipakai untuk transaksi.

## 6. Flow 3: Transaksi Penjualan

### Tujuan

Memastikan pengguna dapat mencatat penjualan barang, jasa, atau transaksi campuran dengan cepat.

### Entry Point

- Menu `Transaksi`
- Shortcut `Buat Transaksi` dari beranda

### Alur Utama Transaksi

1. Pengguna membuka halaman `Transaksi`.
2. Sistem menampilkan keranjang kosong dan daftar item aktif.
3. Pengguna mencari atau memilih item.
4. Pengguna menambahkan item ke keranjang.
5. Pengguna mengubah kuantitas atau jumlah layanan.
6. Sistem menghitung subtotal otomatis.
7. Pengguna dapat menambahkan diskon item atau diskon total.
8. Pengguna dapat menambahkan pajak jika diperlukan.
9. Pengguna memilih metode pembayaran.
10. Jika metode tunai, pengguna memasukkan nominal bayar.
11. Sistem menghitung total dan kembalian.
12. Pengguna menekan tombol `Simpan Transaksi`.
13. Sistem memvalidasi keranjang dan pembayaran.
14. Sistem membuat nomor invoice otomatis.
15. Sistem menyimpan transaksi header dan detail item ke SQLite.
16. Sistem mengurangi stok untuk item bertipe barang.
17. Sistem menampilkan bukti transaksi sederhana.
18. Pengguna memilih:
   - Selesai
   - Buat transaksi baru

### Transaksi Campuran

Flow transaksi harus tetap sama untuk:

- Barang saja
- Jasa saja
- Barang + jasa

Perbedaan:

- Item jasa tidak mengurangi stok.
- Item barang mengurangi stok otomatis.

### Validasi Minimum

- Keranjang tidak boleh kosong.
- Kuantitas harus lebih dari 0.
- Untuk pembayaran tunai, nominal bayar harus cukup.

### Alternate Flow

- Jika pengguna membatalkan transaksi sebelum simpan, data tidak disimpan.
- Jika item nonaktif terlanjur ada di keranjang karena data berubah, sistem harus mencegah transaksi dilanjutkan sampai item diperbarui.
- Jika stok barang tidak cukup dan sistem menerapkan validasi stok, tampilkan pesan error sebelum transaksi disimpan.

### Outcome

- Transaksi tercatat di SQLite.
- Bukti transaksi tampil.
- Stok barang ter-update.

## 7. Flow 4: Manajemen Stok

### Tujuan

Memungkinkan pengguna memantau stok barang dan melakukan penyesuaian manual saat diperlukan.

### Entry Point

- Menu `Stok`
- Detail item barang dari katalog

### Alur Lihat Stok

1. Pengguna membuka halaman `Stok`.
2. Sistem menampilkan daftar item barang beserta stok saat ini.
3. Pengguna dapat mencari item atau memfilter kategori.
4. Pengguna memilih salah satu item untuk melihat detail stok.

### Alur Penyesuaian Stok Manual

1. Pengguna membuka detail stok item.
2. Pengguna menekan tombol `Sesuaikan Stok`.
3. Pengguna memilih jenis penyesuaian:
   - Tambah stok
   - Kurangi stok
   - Set stok akhir
4. Pengguna memasukkan jumlah penyesuaian.
5. Pengguna menambahkan catatan opsional.
6. Pengguna menekan `Simpan`.
7. Sistem memvalidasi nilai penyesuaian.
8. Sistem menyimpan histori penyesuaian ke SQLite.
9. Sistem memperbarui stok item.

### Alur Histori Stok

1. Pengguna membuka detail stok item.
2. Sistem menampilkan histori perubahan stok.
3. Histori dapat berasal dari:
   - Transaksi penjualan
   - Penyesuaian manual

### Validasi Minimum

- Penyesuaian tidak boleh kosong.
- Jika jenis penyesuaian adalah kurangi stok, hasil akhir tidak boleh negatif, kecuali sistem memang mengizinkan stok minus.

### Outcome

- Pengguna dapat memantau dan memperbaiki stok barang dengan cepat.

## 8. Flow 5: Riwayat dan Detail Transaksi

### Tujuan

Memungkinkan pengguna mengecek transaksi yang sudah terjadi.

### Entry Point

- Menu `Riwayat` atau bagian riwayat dari `Laporan`

### Alur Utama

1. Pengguna membuka halaman riwayat transaksi.
2. Sistem menampilkan daftar transaksi terbaru.
3. Pengguna dapat:
   - Mencari berdasarkan nomor invoice
   - Mencari berdasarkan nama item
   - Filter tanggal
   - Filter metode pembayaran
4. Pengguna memilih salah satu transaksi.
5. Sistem menampilkan detail transaksi:
   - Nomor invoice
   - Tanggal dan waktu
   - Daftar item
   - Total
   - Metode pembayaran
   - Catatan jika ada

### Outcome

- Pengguna dapat menemukan transaksi tertentu dan mengecek detailnya.

## 9. Flow 6: Dashboard dan Laporan

### Tujuan

Menyediakan ringkasan performa usaha tanpa membuat pengguna harus membaca data mentah transaksi satu per satu.

### Entry Point

- Menu `Beranda`
- Menu `Laporan`

### Alur Dashboard

1. Pengguna membuka `Beranda`.
2. Sistem mengambil data agregasi dari SQLite.
3. Sistem menampilkan:
   - Omzet hari ini
   - Jumlah transaksi hari ini
   - Item terlaris
   - Metode pembayaran teratas
4. Pengguna dapat menekan kartu ringkasan untuk masuk ke laporan yang relevan.

### Alur Laporan Penjualan

1. Pengguna membuka halaman `Laporan`.
2. Pengguna memilih jenis laporan:
   - Harian
   - Mingguan
   - Bulanan
   - Per produk/jasa
3. Sistem menampilkan data agregasi sesuai pilihan.
4. Pengguna dapat mengganti rentang tanggal jika flow laporan mendukung custom range pada MVP.

### Laporan Minimum MVP

- Omzet harian
- Omzet mingguan
- Omzet bulanan
- Jumlah transaksi
- Rekap per produk/jasa

### Empty State

Jika belum ada transaksi:

- Tampilkan pesan bahwa belum ada data laporan
- Tampilkan shortcut `Buat Transaksi`

### Outcome

- Pengguna dapat memahami performa usaha dari data yang sudah tercatat.

## 10. Flow 7: Pengaturan Usaha

### Tujuan

Memungkinkan pengguna memperbarui identitas usaha dan preferensi dasar aplikasi.

### Entry Point

- Menu `Pengaturan`

### Alur Utama

1. Pengguna membuka `Pengaturan`.
2. Sistem menampilkan data profil usaha saat ini.
3. Pengguna mengubah data yang diperlukan.
4. Pengguna menekan `Simpan`.
5. Sistem memperbarui data di SQLite.

### Pengaturan Minimum

- Nama usaha
- Alamat
- Nomor kontak
- Nama pemilik
- Mata uang default
- Format tampilan struk sederhana

### Outcome

- Informasi usaha selalu bisa disesuaikan tanpa mengulang setup awal.

## 11. Urutan Flow Pengguna Paling Umum

Untuk penggunaan pertama:

1. Buka aplikasi
2. Setup usaha
3. Tambah item katalog
4. Buat transaksi pertama
5. Lihat stok
6. Lihat laporan

Untuk penggunaan harian:

1. Buka aplikasi
2. Masuk ke transaksi
3. Simpan transaksi
4. Cek riwayat jika perlu
5. Cek stok jika ada koreksi
6. Lihat laporan di akhir hari

## 12. Dependensi Antar Flow

- Setup usaha harus selesai sebelum modul utama dipakai.
- Katalog harus tersedia sebelum transaksi dapat dilakukan secara normal.
- Transaksi menjadi sumber data untuk stok dan laporan.
- Stok barang bergantung pada data item bertipe barang dan data transaksi.
- Laporan bergantung pada transaksi yang sudah tersimpan.

## 13. Rekomendasi Wireframe Berdasarkan Flow

Layar minimum yang perlu dibuat:

- Splash / app init
- Setup awal usaha
- Beranda
- Daftar katalog
- Form tambah/edit item
- Halaman transaksi
- Bukti transaksi
- Daftar stok
- Detail stok dan penyesuaian
- Riwayat transaksi
- Detail transaksi
- Laporan
- Pengaturan

## 14. Open Questions

Beberapa keputusan UX yang masih perlu dipastikan:

- Apakah beranda atau transaksi menjadi tab default setelah setup selesai.
- Apakah kategori dibuat bebas oleh pengguna atau disediakan template default berdasarkan jenis usaha.
- Apakah validasi stok minus diizinkan pada MVP.
- Apakah laporan MVP cukup fixed period atau perlu custom date range.
- Apakah bukti transaksi hanya tampil di layar atau perlu opsi simpan/bagikan pada fase awal.

