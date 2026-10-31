# Master ikon launcher

`launcher-master.png` adalah salinan artwork RGBA 2048 x 2048 yang sebelumnya
dipasang identik pada lima direktori mipmap. Gambar ini adalah sumber regenerasi,
bukan aset runtime. Jangan tambahkan direktori `tools/` ke daftar aset Flutter.

Regenerasi dari root repository:

```sh
python -m pip install -r tools/requirements-icons.txt
python tools/launcher_icons.py --generate
```

Skrip mempertahankan artwork dan transparansi, melakukan resize LANCZOS ke
48/72/96/144/192 piksel, lalu mengompresi PNG tanpa kuantisasi warna. Tidak ada
crop atau perubahan desain. Pemeriksaan CI tidak memerlukan Pillow:

```sh
python tools/launcher_icons.py
```
