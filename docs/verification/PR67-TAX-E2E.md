# PR #67 — pajak setelah diskon dan keranjang dengan keyboard

Status: **LULUS** pada perangkat fisik Xiaomi 2201116TG, Android 13.
Eksekusi: 11 November 2026, 16:13–16:18 WIB, Flutter 3.47.9 / Dart 3.13.7.
Implementasi yang diuji: `2a798e83c69696aff8631650323f96eca1e57f01`.

## Masalah dan perbaikan

Pada head sebelumnya (`4390e68`), ketiga tes perangkat gagal karena keranjang
memicu RenderFlex overflow saat keyboard/sheet diskon mengurangi tinggi layar.
Ringkasan pembayaran berada di luar daftar yang dapat digulir dan membutuhkan
lebih banyak tinggi daripada viewport. Dalam mode tunai, kontrol diskon item
juga terpotong oleh panel pembayaran.

Keranjang sekarang menggunakan satu CustomScrollView dengan controller dari
DraggableScrollableSheet. Header, item, ringkasan, dan pembayaran dapat digulir
bersama ketika ruang terbatas. SliverFillRemaining mempertahankan ringkasan di
bawah saat ruang cukup; ringkasan memakai tinggi kontennya sendiri.

Acuan canonical: `Transaksi Baru`, screen Stitch
`20c72054c3824a1ab13cf4a2497158be`, project `3855424189443229582`.
Urutan bagian, label, navigasi, dan prioritas CTA dipertahankan. Adaptasi terhadap
ruang sempit adalah menggulir seluruh keranjang, termasuk header dan ringkasan,
agar kontrol tetap dapat dijangkau saat keyboard terbuka.

## Bukti pengujian

- Tes perangkat: **3/3 lulus**, exit code 0, tanpa exception layout atau tap yang meleset.
- **24 checkout**: delapan per mata uang IDR, USD, dan SGD.
- Diskon item dan transaksi dengan nominal sama menghasilkan pajak/total sama:
  IDR Rp8.000/Rp88.000, USD/SGD 8,00/88,00 pada subtotal 100.000/100 dan diskon 20.000/20.
- Diskon dihapus/dipasang kembali, diskon gabungan/penuh, dan kuantitas berubah:
  pajak otomatis mengikuti dasar terkini dan tidak menjadi negatif.
- Nominal pajak manual 7 maupun nol tetap bertahan saat diskon/kuantitas berubah.
  Mode draft berikutnya kembali otomatis setelah transaksi selesai.
- Checkout tunai mempertahankan mode tunai selama pengeditan kedua diskon.
  Keyboard Android benar-benar terbuka saat nominal bayar dimasukkan; pajak,
  total, pembayaran, dan kembalian diperiksa melalui state dan baris SQLite.
- Pembulatan setelah diskon: dasar 145/1,45 pada 10% menghasilkan 15/0,15.
- Setiap mata uang memiliki delapan transaksi dan delapan pergerakan stok.
  Stok produk utama 100 → 93, produk pembulatan 100 → 99.
- Setelah koneksi SQLite/provider ditutup dan dibuka kembali, delapan header
  transaksi tetap identik, integrity_check = ok, foreign_key_check kosong,
  dan draft baru menggunakan pajak otomatis.
- **32 tes lokal terpilih lulus**, termasuk dua regresi viewport dengan keyboard
  untuk layout ponsel dan layar lebar; repository palsu dan akses DB aplikasi diblokir.
- CI implementasi: [run 42993513437](https://github.com/iqbalmaulana03/pujangga-pos/actions/runs/42993513437),
  **246 tes Flutter + 10 tes alat bantu lulus**, analyzer tanpa temuan.

[Hasil terstruktur dan identitas APK](pr67-tax-e2e/result.json) mencatat hash
blob sumber agar build dapat dicocokkan dengan implementasi yang diuji. Build
dimulai dari working tree berbasis `4390e68`; konten yang sama kemudian dicommit
sebagai `2a798e8` tanpa perubahan file selama eksekusi.

## Isolasi dan batas bukti

Manifest APK diperiksa sebagai `com.pujanggapos.pujangga_pos.pr67e2e` sebelum
instalasi. Tes memverifikasi path cache paket tersebut sebelum membuat database
unik dan menyuntikkan AppDatabase itu ke seluruh repository aplikasi. Semua data
sintetis. Tidak ada clear/uninstall/reset untuk aplikasi utama. Inventaris paket
sebelum/sesudah sama, tiga database uji dibersihkan, dan cache paket uji kosong
pada pemeriksaan ADB setelah runner selesai. Paket uji tetap terpasang.

Pajak manual disetel lewat controller publik karena belum memiliki kontrol UI;
pengeditan diskon, kuantitas, dan pembayaran dilakukan lewat UI asli. Buka ulang
berarti menutup SQLite/provider dan memasang ulang widget aplikasi pada proses
yang sama, bukan force-stop Android. Ini bukan pengujian APK release atau semua
fitur aplikasi. Screenshot hanya menampilkan data sintetis; kredensial, data
usaha nyata, serial perangkat, dan stack trace mentah tidak dipublikasikan.

## Screenshot yang diperiksa

- [Diskon transaksi IDR](pr67-tax-e2e/order-discount.png)
- [Diskon item IDR dengan hasil setara](pr67-tax-e2e/item-discount.png)
- [Pembayaran tunai saat keyboard Android terbuka](pr67-tax-e2e/cash-keyboard.png)
- [Draft otomatis setelah SQLite dibuka kembali](pr67-tax-e2e/reopened.png)

## Reproduksi

```powershell
rtk proxy python tools/run_tax_e2e.py --device <serial-adb> --flutter <path-flutter.bat>
```

Jalankan setelah `flutter pub get --enforce-lockfile`, dari checkout yang bersih.
Runner menetapkan `PUJANGGA_TAX_E2E=1`, memvalidasi paket APK, dan menyimpan log,
hash APK, inventaris, serta screenshot di `build/tax-e2e/`. Screenshot hanya
diambil setelah foreground activity terbukti berasal dari paket uji.
