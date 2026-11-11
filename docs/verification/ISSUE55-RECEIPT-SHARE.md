# Berbagi struk digital — issue #55

Implementasi menggunakan receipt yang dibaca ulang dari repository berdasarkan
invoice halaman berhasil. Formatter memilih field pelanggan secara eksplisit:
nama/alamat/kontak usaha, invoice, waktu, nama item, kuantitas/satuan, harga,
diskon item/transaksi, pajak, total, metode bayar, serta bayar/kembalian tunai.
Profil usaha memakai data saat berbagi; item dan nominal memakai snapshot transaksi.
Mata uang mengikuti pengaturan aplikasi, sama seperti halaman receipt yang ada.
Tidak ada serialisasi object, modal, margin, pemilik, karyawan, gaji, atau komisi.

Controller memanggil `SharePlus.instance.share` dan menahan tap berulang sampai
Sharesheet selesai. Pembatalan tidak menampilkan sukses palsu; kegagalan menampilkan
pesan yang bisa dicoba ulang tanpa menulis ulang penjualan. Status hasil berbagi
yang tidak tersedia dijelaskan tanpa mengklaim struk sudah terkirim.

Struktur halaman tetap mengikuti `Transaksi Berhasil (Refined)`, screen
`5850c03fe09249a58f10b4d3073297d1`: Cetak/Bagikan sebagai aksi sekunder,
Transaksi Baru sebagai CTA utama dan Selesai sebagai CTA berikutnya. Tidak ada
perubahan layout atau navigasi. Cetak sekarang menjelaskan bahwa fitur belum
tersedia; integrasi printer tetap pekerjaan terpisah.

## Verifikasi otomatis

Flutter 3.47.9 / Dart 3.13.7, 12 November 2026:

- `flutter analyze --no-pub --fatal-infos`: bersih.
- `flutter test --no-pub`: 260 tes lulus, termasuk 14 tes formatter/controller/widget
  dan kanal platform SharePlus di `test/receipt_share_test.dart`.
- `flutter test --no-pub test/receipt_share_storage_test.dart`: satu tes tambahan
  lulus. Database SQLite dibuat dalam direktori sementara unik dan path efektif
  diperiksa sebelum dibuka. Tes membuktikan snapshot nama/harga tetap dipakai
  setelah katalog diedit, serta semua tabel identik sebelum/sesudah pembatalan
  dan kegagalan share.
- Tes formatter mencakup barang, jasa, campuran, kuantitas pecahan, diskon item dan
  transaksi, pajak, tunai, seluruh metode nontunai, presisi USD, dan pengecualian
  field internal. Tes widget mencakup kegagalan, retry, batal dan status cetak.

## Reproduksi perangkat

Hasil perangkat pada 12 November 2026 sekitar 00:10 WIB: **lulus**, satu tes
integration pada Redmi 2201116TG / Android 13. Host mengonfirmasi activity chooser
native foreground (`HOST_NATIVE_CHOOSER_VERIFIED`); setelah Back, tes mengonfirmasi
semua tabel identik (`E2E_SHARE_CANCEL_PRESERVED_ALL_TABLES`). Inventory paket
sebelumnya tetap terpasang. Data uji dibersihkan hanya dari direktori database
sementara milik paket tes. Tidak ada pengiriman ke aplikasi penerima; verifikasi
invoice/nominal payload dilakukan melalui tes kanal SharePlus dan snapshot SQLite
di atas, bukan klaim bahwa penerima sudah menerima struk.

```powershell
rtk proxy <flutter.bat> pub get --enforce-lockfile
rtk proxy python tools/run_receipt_share_e2e.py --device <serial> --flutter <flutter.bat>
```

Runner memverifikasi application ID APK sebelum menjalankan tes, memakai paket
`com.pujanggapos.pujangga_pos.issue55e2e`, tidak uninstall/clear-data, serta
memeriksa bahwa paket yang sudah ada tetap terpasang. Tes membuat database unik di
cache paket khusus ini dan memeriksa path sebelum membuka database. Host memeriksa
`ChooserActivity` benar-benar foreground, lalu menekan Back. Tes kemudian
membandingkan seluruh tabel dan memeriksa halaman berhasil masih tampil.
Tidak ada pemilihan penerima atau pengiriman struk. Log aktivitas yang disimpan
hanya identitas activity, tanpa kontak/rekomendasi aplikasi tujuan.

Artefak lokal: `build/receipt-share-e2e/{build.log,run.log,chooser-activity.txt,result.json}`.
