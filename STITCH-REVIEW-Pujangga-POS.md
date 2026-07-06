# Stitch Review

## Pujangga-POS

## 1. Cakupan Screen Saat Ini

Screen yang sudah ada di project Stitch:

- Business Setup
- Dashboard
- Catalog
- Add/Edit Item
- New Sale
- Transaction Success
- Stock Management
- Reports
- Transaction History
- Transaction History (Empty State)
- Transaction Detail
- Settings

## 2. Review Konsistensi

### Yang Sudah Konsisten

- Tema visual utama sudah cukup konsisten: warna teal, kartu rounded, spacing lega, dan tone operasional yang rapi.
- Hampir semua screen sudah mengikuti arah desain `Warm Operational Minimalism`.
- Struktur informasi utama per screen sudah sesuai kebutuhan MVP.
- Screen inti POS sudah terbentuk lengkap untuk alur dasar: setup, katalog, transaksi, stok, laporan, riwayat, pengaturan.

### Ketidakkonsistenan yang Paling Jelas

#### A. Pola Bottom Navigation belum konsisten

Masalah:

- Sebagian besar flow awal menggunakan 5 item utama:
  - Home
  - Catalog
  - Transactions
  - Stock
  - Reports
- Screen `Settings` justru mendorong `Settings` menjadi tab bawah tambahan.

Dampak:

- Struktur navigasi global jadi ambigu.
- Pengguna tidak punya mental model yang konsisten untuk berpindah halaman.
- Developer nanti juga bingung apakah pakai 5-tab atau 6-tab navigation.

Rekomendasi:

- Tetapkan satu pola final.
- Untuk MVP, lebih rapi jika `Settings` tidak menjadi tab bawah utama.
- `Settings` sebaiknya diakses dari `Home`, avatar, app bar, atau menu `More`.

#### B. Bahasa UI belum konsisten

Masalah:

- Nama screen dan prompt hasil Stitch masih dominan berbahasa Inggris.
- Produk ditujukan untuk UMKM Indonesia, tetapi hasil wireframe belum sepenuhnya berbahasa Indonesia.

Dampak:

- UX belum terasa lokal.
- Hasil review ke stakeholder lokal akan kurang natural.

Rekomendasi:

- Semua label, button, helper text, dan empty state harus diubah ke Bahasa Indonesia.

#### C. Ukuran frame screen tidak sepenuhnya konsisten

Masalah:

- Beberapa screen menggunakan lebar `780`.
- Beberapa screen lain menggunakan lebar `834`.

Dampak:

- Ada risiko variasi layout yang tidak disengaja.
- Visual continuity antar screen bisa terasa tidak seragam.

Rekomendasi:

- Tetapkan satu baseline mobile frame untuk seluruh screen MVP Android.
- Gunakan satu ukuran yang konsisten untuk semua refinement berikutnya.

#### D. Positioning layar riwayat terhadap transaksi belum sepenuhnya jelas

Masalah:

- `Transaction History` terasa sebagai modul terpisah.
- Belum jelas apakah ia berada di bawah tab `Transactions`, sebagai subpage, atau screen mandiri dari dashboard.

Dampak:

- Potensi kebingungan navigasi setelah transaksi selesai.

Rekomendasi:

- Tetapkan bahwa `Transaction History` adalah subflow dari `Transactions` atau shortcut dari `Dashboard`, bukan tab bawah baru.

## 3. UX Gaps Paling Jelas

### Gap 1: Navigasi global belum final

Ini gap paling besar.

Gejala:

- `Settings` masuk ke bottom nav.
- Riwayat transaksi belum jelas posisinya.
- Belum ada keputusan final apakah `Home` atau `Transactions` menjadi landing tab utama setelah setup selesai.

Yang perlu diputuskan:

- Apakah bottom nav final berisi 5 item:
  - Beranda
  - Katalog
  - Transaksi
  - Stok
  - Laporan
- Lalu `Settings` masuk lewat ikon/profile/menu tambahan.

### Gap 2: Aksi utama per screen belum selalu paling dominan

Contoh:

- `Transaction Success` masih membawa terlalu banyak aksi sekunder seperti print/share.
- Untuk MVP, aksi utama seharusnya sangat jelas:
  - `Transaksi Baru`
  - `Selesai`

Dampak:

- Beban keputusan user bertambah.
- Fokus operasional jadi melemah.

### Gap 3: Setup ke operasional belum terasa cukup mengalir

Masalah:

- Setelah `Business Setup`, perlu lebih jelas jalur berikutnya:
  - tambah item dulu
  - atau langsung transaksi

Rekomendasi:

- Dashboard atau post-setup state harus punya 2 CTA yang sangat jelas:
  - `Tambah Item`
  - `Buat Transaksi`

### Gap 4: Katalog dan form item perlu hubungan visual yang lebih kuat

Masalah:

- `Catalog` dan `Add/Edit Item` sudah ada, tetapi kemungkinan belum cukup terasa sebagai satu alur yang saling terhubung.

Rekomendasi:

- Gunakan pola header, button label, dan section form yang benar-benar seragam.
- `Barang` vs `Jasa` perlu lebih jelas secara visual di form.

### Gap 5: Stok dan riwayat masih terasa seperti halaman terpisah, belum jadi workflow

Masalah:

- `Stock Management` sudah ada, tapi `Stock Adjustment Flow` belum ada.
- `Transaction History` ada, tetapi jalur ke `Transaction Detail` belum terasa sebagai sequence eksplisit.

Rekomendasi:

- Refinement berikutnya harus fokus pada hubungan antar screen, bukan hanya masing-masing screen berdiri sendiri.

### Gap 6: Laporan perlu lebih terarah ke insight praktis

Masalah:

- `Reports` sudah punya metrik dan chart, tapi perlu dijaga agar tidak terasa terlalu analitis untuk user UMKM.

Rekomendasi:

- Fokus pada insight yang langsung berguna:
  - omzet
  - jumlah transaksi
  - produk terlaris
  - metode pembayaran

## 4. Prioritas Refinement

Urutan refinement yang paling bernilai:

1. Finalisasi navigasi global.
2. Ubah semua copy ke Bahasa Indonesia.
3. Rapikan hierarchy CTA pada setup, transaksi, dan success state.
4. Samakan pola frame/layout antar screen.
5. Perjelas hubungan flow katalog, stok, dan riwayat.

## 5. Prompt Refinement yang Direkomendasikan

### Prompt 1: Finalisasi Bottom Navigation

```text
Refine the navigation structure across all Pujangga-POS screens. Use one consistent bottom navigation with exactly 5 items: Home, Catalog, Transactions, Stock, and Reports. Remove Settings from the bottom navigation and treat it as a secondary destination accessed from the Home screen or a top-right profile/settings icon. Keep the navigation pattern consistent across all screens.
```

### Prompt 2: Switch UI Copy to Bahasa Indonesia

```text
Switch all UI copy, screen titles, labels, buttons, filter chips, helper text, empty state messages, and section headings across all Pujangga-POS screens to Bahasa Indonesia. Keep the wording simple, practical, and natural for Indonesian small business owners.
```

### Prompt 3: Improve Setup-to-Action Flow

```text
Refine the Business Setup and Dashboard flow so the transition into daily operations feels clearer. After setup, the user should immediately understand the next two main actions: Tambah Item and Buat Transaksi. Make these two call-to-action buttons visually prominent on the Dashboard and any post-setup empty state.
```

### Prompt 4: Strengthen Catalog and Item Form Relationship

```text
Refine the Catalog and Add/Edit Item screens so they feel like one connected workflow. Use more consistent headers, section spacing, button styles, and field grouping. Make the difference between Barang and Jasa visually clearer in the item form, especially around the stock-related fields.
```

### Prompt 5: Simplify Transaction Success

```text
Refine the Transaction Success screen to prioritize the operational flow. Make the two main actions more prominent: Transaksi Baru and Selesai. Reduce the visual emphasis of secondary actions like Print Receipt and Share Receipt so the screen feels faster and more focused for checkout operations.
```

### Prompt 6: Clarify History-to-Detail Workflow

```text
Refine the Transaction History and Transaction Detail screens so they feel like a clear workflow. Make Transaction History feel like a natural extension of the Transactions module, and make the tap target from each history card to the detail view more obvious. Keep the detail screen structured like a clean receipt summary.
```

### Prompt 7: Make Reports More Practical

```text
Refine the Reports screen to feel more practical and less analytical. Prioritize the most useful small-business insights: total revenue, total transactions, top-selling items, and payment methods. Keep the chart simple and secondary to the summary cards.
```

## 6. Rekomendasi Langkah Berikutnya

Jika ingin paling efisien, refinement sebaiknya dijalankan dalam urutan ini:

1. Prompt 1
2. Prompt 2
3. Prompt 3
4. Prompt 5
5. Prompt 6
6. Prompt 7

Setelah itu baru review ulang hasil Stitch sebelum membuat refinement tambahan yang lebih kecil.
