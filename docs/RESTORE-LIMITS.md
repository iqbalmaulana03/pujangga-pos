# Batas sumber daya restore

Inspeksi backup memakai batas berikut (semuanya harus terpenuhi):

| Sumber daya | Batas |
| --- | --- |
| File UTF-8 | 20 MiB (20.971.520 byte) |
| Total baris seluruh tabel, termasuk tabel tidak dikenal | 50.000 |
| Kedalaman objek/array JSON, termasuk objek akar | 12 |
| Panjang nilai teks dan nama kunci | 65.536 unit UTF-16 |
| `assets.business_logo.data_base64` | 6.990.508 unit UTF-16 (PNG 5 MiB dalam base64) |
| Unit pemindaian di luar string dan whitespace | 2.000.000 |

Batas ini merupakan anggaran konservatif untuk POS lokal usaha kecil, bukan
hasil pengukuran batas crash perangkat. Targetnya ribuan transaksi beserta
detail item dan pergerakan stok, dengan ruang untuk katalog, pengeluaran, dan
logo. Batas byte dan kompleksitas berlaku bersama batas baris: 50.000 baris
bukan jaminan bahwa semua kombinasi kolom atau teks akan muat. Backup dengan
lebih banyak data memerlukan strategi arsip atau kenaikan anggaran yang diuji
ulang pada perangkat Android sasaran.

Worker isolate memeriksa `File.length` sebelum membaca. Pembacaan stream dibatasi
hingga batas + 1 byte dan diperiksa kembali, sehingga pertumbuhan file setelah
stat tidak dapat memicu pembacaan tanpa batas. UTF-8 kemudian dipindai tanpa
membangun pohon nilai: batas kedalaman, panjang nilai dan nama kunci, jumlah
baris, serta kompleksitas diperiksa sebelum `jsonDecode`. Hanya nama kunci yang
telah dibatasi panjangnya didekode saat pemindaian, untuk mengenali path tabel
dan pengecualian logo meski memakai Unicode escape. Escape dan tanda kurung di
dalam string tidak dihitung sebagai struktur. Ini juga membatasi input yang
tidak dikenal, bukan hanya tabel yang akhirnya dipulihkan. Decoder standar
kemudian memvalidasi sintaks JSON lengkap sebelum normalisasi/migrasi.

Pembacaan, decode, validasi anggaran, dan normalisasi berjalan di worker. Validasi
tipe/baris SQLite juga berjalan di worker dengan salinan definisi kolom; koneksi
database tetap pada isolate pemiliknya. Dekode gambar menggunakan layanan logo
Flutter dengan batas PNG yang sudah ada. Tidak ada desain atau navigasi layar
yang diubah.

Input berlebih ditolak dengan `AppException` berkode `backup_limit_exceeded`
dan pesan Indonesia yang menyebut batas terkait. JSON/UTF-8 rusak memakai
`backup_invalid`. Penolakan anggaran terjadi sebelum akses database; inspeksi
tidak menjalankan penghapusan atau insert data. Restore tetap membutuhkan
konfirmasi pengguna dan transaksi SQLite yang sudah ada.

Tes regresi mencakup batas tepat dan input berlebih, Unicode escape, array lebar,
struktur sangat dalam, logo, serta perbandingan seluruh tabel pada database FFI
di direktori sementara. Tes heartbeat event loop selama inspeksi file 20 MiB
merupakan pemeriksaan respons host yang kasar, bukan pengukuran FPS/memori atau
jaminan performa pada seluruh perangkat Android.
