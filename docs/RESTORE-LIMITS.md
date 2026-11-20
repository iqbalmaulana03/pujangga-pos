# Batas sumber daya restore

## Kontrak ekspor dan impor

Ekspor plaintext maupun terenkripsi memakai batas yang sama dengan impor.
Payload diserialisasi dan diperiksa di worker, lalu melewati parser metadata,
normalisasi, validasi kolom/semantik, dan validasi logo yang sama dengan inspeksi
restore. Snapshot tabel tetap diambil dalam satu transaksi SQLite, termasuk
pemeriksaan foreign key; pekerjaan file dilakukan setelah transaksi berakhir.

Untuk ekspor terenkripsi, plaintext hanya berada di memori. Envelope akhir juga
harus lolos batas 20 MiB, sehingga overhead base64 dapat membuat ekspor terenkripsi
ditolak meskipun versi plaintext masih muat. Batas impor tidak dinaikkan.

File ditulis dan di-flush dalam direktori staging unik pada filesystem tujuan,
diinspeksi kembali dari byte tersimpan, lalu di-rename ke nama final. Hanya setelah
rename berhasil aplikasi mengembalikan hasil ekspor dan mencatat sukses. Saat
operasi gagal, staging milik operasi dibersihkan tanpa mengubah data aktif atau backup lama.
Jika proses dihentikan paksa sebelum rename, staging mungkin tertinggal; file itu
bukan backup final dan tidak ditawarkan sebagai snapshot pemulihan.

Restore tetap mewajibkan snapshot terenkripsi yang lolos inspeksi. Jika data aktif
melampaui batas atau snapshot tidak dapat ditulis/diverifikasi, operasi dibatalkan
dengan kode `recovery_invalid`, penyebab dalam bahasa Indonesia, dan penegasan
bahwa data aktif belum diganti. Tidak ada bypass snapshot. Streaming dataset besar
merupakan pekerjaan terpisah.

## Anggaran dan pemeriksaan impor

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

E2E pada Redmi Note 11 Pro / Android 13 telah lulus pada 10 November 2026,
termasuk dua pemilihan file native, penolakan tanpa perubahan database,
kontrol positif tepat 20 MiB dengan 5.001 item, respons UI selama inspeksi,
restore, dan pembukaan ulang SQLite. Lihat [hasil dan batas interpretasi](verification/PR64-RESTORE-LIMITS-E2E.md).
