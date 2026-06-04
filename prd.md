# 📄 PRODUCT REQUIREMENT DOCUMENT (PRD) - KOSKU APP (FINAL SYNC)

## 1. Project Overview & Architecture
* **Project Name:** KosKu
* **Objective:** Aplikasi manajemen kos untuk membantu pemilik kos (Admin) memantau kamar, data penghuni, invoice tagihan, transaksi pemasukan, dan pengeluaran secara *real-time*.
* **Tech Stack:** Flutter (Frontend), Supabase (Backend, Auth, Realtime Database).
* **State Management:** `StreamBuilder` (Supabase Native Stream terhubung ke publikasi `supabase_realtime`).

---

## 2. User Authentication Workflow (Epics 1)

### 2.1 Splash Screen
* **File Reference:** `assets/kosku_ui/1_Splash Screen.png`
* **Route Name:** `/splash`
* **Logic:** Memeriksa sesi login aktif via Supabase Auth. Jika ada, ke `/dashboard`. Jika tidak, ke `/login`.

### 2.2 Login Screen
* **File Reference:** `assets/kosku_ui/2_Login.png`
* **Route Name:** `/login`
* **Logic:** Input `Email` dan `Password`. Menjalankan fungsi `signInWithPassword()`.

### 2.3 Register Screen
* **File Reference:** `assets/kosku_ui/3_Register.png`
* **Route Name:** `/register`
* **Logic:** Pendaftaran admin kos baru via `signUp()`.

---

## 3. Core Modules & Navigation (Epics 2)

### 3.1 Main Dashboard (Beranda)
* **File Reference:** `assets/kosku_ui/4_Dashboard.png`
* **Route Name:** `/dashboard`
* **Data Mapping:**
  * **Pemasukan Bulan Ini:** Agregat total kolom `nominal_masuk` dari tabel `pemasukan`.
  * **Status Kamar:** Total hitungan card berdasarkan kolom `status_kamar` ('Kosong'/'Terisi') dari tabel `kamar`.
  * **Hampir Jatuh Tempo:** Membaca list dari tabel `invoice` yang memiliki `status_pembayaran = 'Belum Lunas'` mendekati `tanggal_jatuh_tempo`.

### 3.2 Kamar List Screen
* **File Reference:** `assets/kosku_ui/5_Kamar.png`
* **Route Name:** `/kamar`
* **Data Mapping:** Mengambil data *stream* dari tabel `kamar`. Filter tab berdasarkan teks properti `status_kamar`. Tombol `+` membuka `/edit-kamar`.

### 3.3 Transaksi Log Screen
* **File Reference:** `assets/kosku_ui/6_Transaksi.png`
* **Route Name:** `/transaksi`
* **Data Mapping:** Menampilkan *list view* riwayat dari tabel `pemasukan`. Mengambil relasi nama penyewa lewat `id_invoice` ➡️ `id_sewa` ➡️ `id_penyewa`. Tombol `+` membuka `/tambah-transaksi`.

### 3.4 Buku Kas Screen
* **File Reference:** `assets/kosku_ui/7_Buku kas.png`
* **Route Name:** `/buku-kas`
* **Data Mapping:**
  * **Grafik Pemasukan:** Data dari tabel `pemasukan`.
  * **List Pengeluaran:** Menampilkan daftar log dari tabel `pengeluaran`. Tombol `+` membuka `/tambah-pengeluaran`.

### 3.5 Profil Admin Screen
* **File Reference:** `assets/kosku_ui/8_Profil.png`
* **Route Name:** `/profil`
* **Logic:** Manajemen akun admin dan tombol aksi `signOut()`.

---

## 4. Sub-Screens & Data Mutation (Epics 3)

### 4.1 Detail Kamar
* **File Reference:** `assets/kosku_ui/9_Detail Kamar.png`
* **Route Name:** `/detail-kamar`
* **Arguments:** `id_kamar` (int8)
* **Logic:** Menampilkan data `kamar`. Jika statusnya 'Terisi', lakukan *join query* ke tabel `sewa` dan `penyewa` untuk menampilkan nama penghuni aktif.

### 4.2 Form Tambah/Edit Kamar
* **File Reference:** `assets/kosku_ui/Edit Kamar.png`
* **Route Name:** `/edit-kamar`
* **Logic:** Operasi `UPSERT` ke tabel `kamar` untuk kolom `nomor_kamar`, `harga_sewa_dasar`, dan `status_kamar`.

### 4.3 Form Edit/Tambah Penyewa
* **File Reference:** `assets/kosku_ui/Edit Penyewa.png` & `assets/kosku_ui/11_Detail Penyewa.png`
* **Route Name:** `/edit-penyewa`
* **Logic:** Melakukan insert data identitas ke tabel `detail_penyewa` (menggunakan `nik` sebagai primary key) baru kemudian memasukkan data kontak ke tabel `penyewa`.

### 4.4 Form Tambah Transaksi (Pembayaran)
* **File Reference:** `assets/kosku_ui/10_Tambah Transaksi.png`
* **Route Name:** `/tambah-transaksi`
* **Logic:** Input data set pembayaran baru ke tabel `pemasukan` berdasarkan referensi `id_invoice` yang dipilih. Otomatis mengubah `status_pembayaran` di tabel `invoice` menjadi 'Lunas'.

### 4.5 Detail Transaksi & Invoice Preview
* **File Reference:** `assets/kosku_ui/Detail Transaksi.png` & `assets/kosku_ui/Preview Invoice.png`
* **Route Name:** `/detail-transaksi`
* **Logic:** Menampilkan struk kuitansi. Tombol *Generate Invoice* membaca kolom `nomor_invoice`, `tanggal_dibuat`, dan `total_tagihan` dari tabel `invoice`.

### 4.6 Form Pengeluaran
* **File Reference:** `assets/kosku_ui/Edit Pengeluaran.png` & `assets/kosku_ui/Detail Pengeluaran.png`
* **Route Name:** `/tambah-pengeluaran`
* **Logic:** `INSERT` data pengeluaran operasional baru ke tabel `pengeluaran` (`kategori`, `deskripsi`, `tanggal_keluar`, `nominal_keluar`).

---

## 5. Active Supabase Database Schema Reference
```sql
-- Skema database yang digunakan (Sesuai dengan Supabase Cloud Production)
-- 1. kamar (id_kamar, nomor_kamar, harga_sewa_dasar, status_kamar)
-- 2. detail_penyewa (nik, tempat_lahir, tanggal_lahir, jenis_kelamin, alamat_ktp, pekerjaan)
-- 3. penyewa (id_penyewa, nik, nomor_whatsapp, nama_lengkap)
-- 4. sewa (id_sewa, id_kamar, id_penyewa, tanggal_masuk, durasi_bulan, status_sewa)
-- 5. invoice (id_invoice, id_sewa, nomor_invoice, tanggal_dibuat, tanggal_jatuh_tempo, total_tagihan, status_pembayaran)
-- 6. pemasukan (id_pemasukan, id_invoice, tanggal_bayar, nominal_masuk, metode_bayar)
-- 7. pengeluaran (id_pengeluaran, kategori, deskripsi, tanggal_keluar, nominal_keluar)

