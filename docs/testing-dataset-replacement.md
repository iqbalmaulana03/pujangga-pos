# Android E2E: pergantian dataset

Jalankan dari checkout yang memakai Flutter 3.47.9 dengan dependensi sesuai
`pubspec.lock`. Siapkan perangkat Android ARM64 yang terbuka kuncinya dan
izinkan pemasangan USB jika diminta:

```powershell
flutter pub get --enforce-lockfile
python tools/run_dataset_e2e.py --device <serial-adb> --flutter <path-flutter.bat>
```

Runner memverifikasi manifest APK memakai paket khusus
`com.pujanggapos.pujangga_pos.pr61e2e` sebelum pemasangan. Jangan menjalankan
target Dart ini pada paket produksi/debug biasa: harness memeriksa direktori
sandbox sebelum membuka database. Database aktif, fixture dan backup seluruhnya
dibuat di direktori sementara paket uji dan dibersihkan setelah tes. Runner tidak
membersihkan data atau menghapus paket aplikasi utama.

Tes memakai `ProviderScope` yang sama sepanjang alur dan menjalankan UI aplikasi:

1. Pilih Andi (ID 1, komisi 10%) di keranjang.
2. Pulihkan file backup Budi (ID 1, komisi 20%) melalui konfirmasi Pengaturan.
   Pastikan Beranda dibangun tanpa error Flutter/Riverpod, pilihan lama hilang,
   dan keranjang serta employeeId sebelumnya dibersihkan.
3. Pilih Budi dan selesaikan pembayaran QRIS untuk jasa Rp100.000. Periksa
   snapshot transaksi, komisi Rp20.000, serta biaya komisi di SQLite Android.
4. Pulihkan backup tanpa karyawan. Pastikan dropdown tidak memuat Andi/Budi.
5. Pulihkan Budi lagi, pilih di keranjang, lalu jalankan Reset Data Aplikasi.
   Isi setup bisnis baru melalui UI; periksa daftar karyawan dan keranjang kosong,
   profil baru tersimpan, tidak ada transaksi lama, serta integritas SQLite.

Batas platform yang diganti hanya pemilihan file backup dengan fixture picker.
Parser file, validasi, konfirmasi UI, restore, query/cache provider, checkout dan
reset memakai implementasi aplikasi sebenarnya. Dialog pemilih file native
tidak tercakup. Data awal disiapkan oleh harness; tes tidak menilai form CRUD
katalog/karyawan.

Log, screenshot, SHA-256 APK dan inventaris paket sebelum/sesudah disimpan di
`build/dataset-e2e/`. Runner hanya mengambil screenshot ketika paket uji berada
di foreground. Gunakan exit code dan hasil assertion tes sebagai bukti kelulusan;
log bahwa restore selesai saja tidak membuktikan navigasi setelah restore aman.

Generasi dataset harus menjadi dependensi provider hasil query dan draft.
Repository/data source tetap stabil agar pembacaan ulang secara lazy saat layar
baru dibangun tidak menotifikasi konsumen lain melalui pergantian objek layanan.
