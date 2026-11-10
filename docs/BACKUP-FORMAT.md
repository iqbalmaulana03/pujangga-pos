# Cadangan terenkripsi

`Cadangkan Data` di Pengaturan memakai enkripsi secara default. Gunakan kata
sandi minimal 12 karakter dan ulangi untuk konfirmasi. Simpan kata sandi di tempat
aman: aplikasi tidak menyimpannya dan tidak dapat meresetnya. Kata sandi yang sama
diperlukan untuk pemulihan di perangkat lain, tanpa akun atau kunci perangkat asal.

Untuk kebutuhan kompatibilitas, pengguna dapat mematikan enkripsi secara eksplisit.
Dialog menampilkan peringatan bahwa profil, transaksi, harga modal, dan gaji dapat
dibaca siapa pun yang memperoleh file. Impor JSON lama tetap tersedia tanpa kata
sandi. Pemulihan terenkripsi meminta kata sandi sebelum menampilkan konfirmasi
penggantian data; membatalkan dialog tidak memulihkan data.

## Format envelope versi 1

File tetap berekstensi `.json` agar dapat dipilih melalui pemilih backup yang ada.
Envelope berisi:

| Field | Nilai |
| --- | --- |
| `format` | `pujangga_pos_encrypted_backup` |
| `format_version` | `1` |
| `cipher` | `AES-256-GCM` |
| `kdf` | `PBKDF2-HMAC-SHA256` |
| `iterations` | `600000` |
| `salt` | 16 byte acak, Base64 |
| `nonce` | 12 byte acak baru, Base64 |
| `ciphertext` | Payload backup JSON UTF-8 terenkripsi, Base64 |
| `tag` | Tag autentikasi 16 byte, Base64 |

Kunci 32 byte diturunkan dari kata sandi UTF-8 tanpa trimming atau normalisasi,
menggunakan salt envelope. AEAD memakai AAD UTF-8 persis:

```text
pujangga_pos_encrypted_backup:1:AES-256-GCM:PBKDF2-HMAC-SHA256:600000
```

Parameter dan panjang field harus sesuai versi ini sebelum KDF dijalankan. Versi
baru harus memiliki definisi tersendiri; file tidak dapat meminta jumlah iterasi
sewenang-wenang. Batas payload terenkripsi adalah 64 MiB sebelum Base64. KDF dan
enkripsi/dekripsi berjalan pada isolate agar tidak memblokir UI. Implementasi
memakai paket `cryptography`, termasuk sumber acak aman dari paket tersebut.

Payload di dalamnya mempertahankan format backup yang sudah ada, termasuk logo.
Autentikasi harus berhasil sebelum payload diparsing atau database dibuka untuk
inspeksi. Kata sandi salah dan manipulasi ciphertext/tag/salt/nonce menghasilkan
pesan yang sama. Ekspor terenkripsi langsung menulis envelope, tanpa file polos
sementara; kata sandi tidak dimasukkan ke envelope, state controller, atau log.

## Verifikasi

`test/encrypted_backup_test.dart` menguji pemulihan seluruh tabel ke database
SQLite sementara yang berbeda, integritas data tujuan saat autentikasi gagal,
salt/nonce baru, kompatibilitas JSON lama, serta pembatalan permintaan kata sandi.
Fixture `test/fixtures/encrypted_backup_v1.json` dibuat dengan Python
`cryptography` 47.0.0 sebagai pemeriksaan interoperabilitas independen, menggunakan
kata sandi sintetis `fixture-password-52`, salt `bytes(range(16))`, nonce
`bytes(range(12))`, dan plaintext `Cadangan portabel sintetis 52`.
Salt/nonce deterministik tersebut hanya untuk fixture, bukan ekspor aplikasi.

`test/backup_password_dialog_test.dart` memeriksa enkripsi default, validasi kata
sandi dan konfirmasi, peringatan ekspor polos, serta pembatalan dialog. Dialog
kata sandi merupakan tambahan yang diperlukan issue #52 pada layar canonical
Pengaturan `575d0f627212423f83fa661c29db4395`; struktur layar dan navigasinya tetap.
