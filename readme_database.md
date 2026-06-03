# 📑 PANDUAN UTUH DATABASE KELOMPOK - APLIKASI KOSKU

Dokumen ini berisi panduan lengkap mengenai arsitektur database, spesifikasi tabel, konfigurasi awal bagi anggota tim, hingga alur kerja kolaborasi menggunakan **Supabase** dan **GitHub** tanpa menggunakan Docker.

---

## 🏛️ 1. PEMAHAMAN ARSITEKTUR DATABASE

Proyek UAS ini menggunakan database cloud berbasis **PostgreSQL** yang disediakan oleh Supabase. Hierarki lingkup project kita adalah sebagai berikut:
`Organization` ➡️ `Project (Vikri31's Project)` ➡️ `Database (postgres)` ➡️ `Tabel-Tabel KosKu`

Semua data tersentralisasi secara *online* di cloud server Supabase wilayah Tokyo. Aplikasi Flutter kita bertiga akan menembak database remote yang sama ini.

---

## 📊 2. REKAPITULASI & SPESIFIKASI TABEL (POSTGRESQL)

Berikut adalah struktur tabel yang diimplementasikan ke Supabase berdasarkan rancangan diagram ERD kelompok kita. Semua tipe data telah disesuaikan dari standar MySQL ke PostgreSQL (`int8` untuk bigint, `int4` untuk integer, dan `text` untuk varchar).

### A. Tabel: `kamar` (🔴 ENABLE REALTIME)
*Digunakan untuk memantau status hunian kamar secara instan di HP Admin/Penjaga.*
* **`id_kamar`** (`int8`, Primary Key, Generated Identity)
* **`nomor_kamar`** (`text`, Not Null)
* **`harga_sewa_dasar`** (`int8`, Not Null)
* **`status_kamar`** (`text`, Not Null) ➡️ *Pilihan isi: 'Kosong', 'Terisi', 'Perbaikan'*

### B. Tabel: `detail_penyewa` (⚪ OFF REALTIME)
*Menampung data biodata identitas KTP penyewa yang bersifat statis.*
* **`nik`** (`text`, Primary Key)
* **`tempat_lahir`** (`text`, Not Null)
* **`tanggal_lahir`** (`date`, Not Null)
* **`jenis_kelamin`** (`text`, Not Null)
* **`alamat_ktp`** (`text`, Not Null)
* **`pekerjaan`** (`text`, Not Null)

### C. Tabel: `penyewa` (⚪ OFF REALTIME)
*Data master kontak penyewa.*
* **`id_penyewa`** (`int8`, Primary Key, Generated Identity)
* **`nik`** (`text`, Not Null, Foreign Key ➡️ `detail_penyewa.nik`)
* **`nomor_whatsapp`** (`text`, Not Null)
* **`nama_lengkap`** (`text`, Not Null)

### D. Tabel: `sewa` (🔴 ENABLE REALTIME)
*Mencatat riwayat transaksi sewa aktif.*
* **`id_sewa`** (`int8`, Primary Key, Generated Identity)
* **`id_kamar`** (`int8`, Not Null, Foreign Key ➡️ `kamar.id_kamar`)
* **`id_penyewa`** (`int8`, Not Null, Foreign Key ➡️ `penyewa.id_penyewa`)
* **`tanggal_masuk`** (`date`, Not Null)
* **`durasi_bulan`** (`int4`, Not Null)
* **`status_sewa`** (`text`, Not Null) ➡️ *Pilihan isi: 'Aktif', 'Selesai', 'Batal'*

### E. Tabel: `invoice` (🔴 ENABLE REALTIME)
*Mengatur manajemen tagihan bulanan.*
* **`id_invoice`** (`int8`, Primary Key, Generated Identity)
* **`id_sewa`** (`int8`, Not Null, Foreign Key ➡️ `sewa.id_sewa`)
* **`nomor_invoice`** (`text`, Unique, Not Null)
* **`tanggal_dibuat`** (`date`, Not Null)
* **`tanggal_jatuh_tempo`** (`date`, Not Null)
* **`total_tagihan`** (`int8`, Not Null)
* **`status_pembayaran`** (`text`, Not Null) ➡️ *Pilihan isi: 'Lunas', 'Belum Bayar'*

### F. Tabel: `pemasukan` (⚪ OFF REALTIME)
*Jurnal log keuangan masuk dari pembayaran invoice.*
* **`id_pemasukan`** (`int8`, Primary Key, Generated Identity)
* **`id_invoice`** (`int8`, Not Null, Foreign Key ➡️ `invoice.id_invoice`)
* **`tanggal_bayar`** (`date`, Not Null)
* **`nominal_masuk`** (`int8`, Not Null)
* **`metode_bayar`** (`text`, Not Null) ➡️ *Contoh: 'Transfer BCA', 'Tunai'*

### G. Tabel: `pengeluaran` (⚪ OFF REALTIME)
*Buku catatan operasional dan pengeluaran kos.*
* **`id_pengeluaran`** (`int8`, Primary Key, Generated Identity)
* **`kategori`** (`text`, Not Null) ➡️ *Contoh: 'Listrik', 'Air', 'Perbaikan'*
* **`deskripsi`** (`text`, Not Null)
* **`tanggal_keluar`** (`date`, Not Null)
* **`nominal_keluar`** (`int8`, Not Null)

---

## 🛠️ 3. LANGKAH SETUP BAGI ANGGOTA TIM (SETELAH GIT CLONE)

Jika kamu baru saja mengunduh proyek ini lewat `git clone`, lakukan 3 langkah ini di VS Code laptopmu agar aplikasi bisa dijalankan:

### Langkah A: Membuat File `.env` (Lokal)
Karena file rahasia API Key tidak di-upload ke GitHub, kamu wajib membuatnya manual di laptopmu.
1. Di VS Code, buat file baru bernama `.env` di **folder paling luar** proyek (root), sejajar dengan file `pubspec.yaml`.
2. Isi file `.env` dengan kode berikut:
```env
   untuk file env nya nanti saya kirim di grup