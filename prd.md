# 📄 PRODUCT REQUIREMENT DOCUMENT (PRD) - KOSKU APP (V3 DIRECTORY SYNC)

## 1. Project Overview & Architecture
* **Project Name:** KosKu
* **Objective:** Aplikasi manajemen kos untuk membantu pemilik kos (Admin) memantau kamar, data penghuni, invoice tagihan, transaksi pemasukan, dan pengeluaran secara *real-time*.
* **Tech Stack:** Flutter (Frontend), Supabase (Backend, Auth, Realtime Database).
* **State Management:** `StreamBuilder` (Supabase Native Stream terhubung ke publikasi `supabase_realtime`).
* **Design Core Color:** Dark Green (`Color(0xFF004D40)`) & Accent Orange (`Color(0xFFF2A32B)`).

---

## 2. User Authentication Workflow (Epics 1)

### 2.1 Splash Screen
* **File Reference:** `assets/ui kosku/0_splash screen/1_Splash Screen.png`
* **Route Name:** `/splash`
* **Logic:** Memeriksa sesi login aktif via Supabase Auth. Jika sesi valid ➡️ `/dashboard`, jika kosong ➡️ `/login`.

### 2.2 Login Screen
* **File Reference:** `assets/ui kosku/1_login/1_Login.png`
* **Route Name:** `/login`
* **Logic:** Form input `Alamat Email` dan `Kata Sandi`. Menjalankan fungsi `signInWithPassword()`. Menampilkan opsi untuk menavigasi ke halaman Register.

### 2.3 Register Screen
* **File Reference:** `assets/ui kosku/1_login/2_Register.png`
* **Route Name:** `/register`
* **Logic:** Form pendaftaran admin kos baru (`Nama Lengkap`, `Nama Kost`, `Alamat Email`, `Kata Sandi`, `Konfirmasi Kata Sandi`) menggunakan fungsi `signUp()`.

---

## 3. Core Modules & Navigation (Epics 2)

### 3.1 Main Dashboard (Beranda)
* **File Reference:** `assets/ui kosku/2_dashboard/1_Dashboard.png`
* **Route Name:** `/dashboard`
* **Data Mapping:**
  * **Pemasukan Bulan Ini:** Agregat total (SUM) kolom `nominal_masuk` dari tabel `pemasukan`.
  * **Status Kamar Terisi / Kosong:** Total hitungan baris data (COUNT) berdasarkan string nilai `status_kamar` pada tabel `kamar`.
  * **Hampir Jatuh Tempo & Belum Bayar:** Menampilkan daftar relasi dari tabel `invoice` dengan kondisi `status_pembayaran = 'Belum Lunas'` yang diurutkan berdasarkan tanggal terdekat.

### 3.2 Kamar List Screen
* **File Reference:** `assets/ui kosku/3_kamar/1_Kamar.png`
* **Route Name:** `/kamar`
* **Data Mapping:** Mengambil data *stream* dari tabel `kamar`. Filter tab berdasarkan status kamar. Tombol Floating Action Button `+` mengarahkan ke form penambahan kamar.

### 3.3 Transaksi Log Screen
* **File Reference:** `assets/ui kosku/4_transaksi/1_Transaksi.png`
* **Route Name:** `/transaksi`
* **Data Mapping:** Menampilkan histori pembayaran bulanan dari tabel `pemasukan`. Tombol `+` mengarahkan ke form tambah transaksi.

### 3.4 Buku Kas Screen
* **File Reference:** `assets/ui kosku/5_buku kas/1_Buku kas.png`
* **Route Name:** `/buku-kas`
* **Data Mapping:** Menampilkan neraca (Total Pemasukan - Total Pengeluaran) serta menampilkan list kronologis dari tabel `pengeluaran`. Tombol `+` mengarahkan ke form tambah pengeluaran.

### 3.5 Profil Admin Screen
* **File Reference:** `assets/ui kosku/6_profil/1_Profil.png`
* **Route Name:** `/profil`
* **Logic:** Manajemen sesi akun admin, memuat informasi jumlah kamar, dan mengintegrasikan fungsi keluar aplikasi (`signOut()`).

---

## 4. Sub-Screens & Data Mutation (Epics 3)

### 4.1 Detail Kamar
* **File Reference:** `assets/ui kosku/3_kamar/2_Detail Kamar.png`
* **Route Name:** `/detail-kamar`
* **Arguments:** `id_kamar` (int8)
* **Logic:** Memuat spesifikasi kamar. Jika statusnya 'Terisi', lakukan *join query* relasi ke tabel `sewa` dan `penyewa` untuk menampilkan data penghuni serta riwayat transaksinya.

### 4.2 Form Tambah/Edit Kamar
* **File Reference:** `assets/ui kosku/3_kamar/3_tambah or Edit Kamar.png`
* **Route Name:** `/edit-kamar`
* **Logic:** Form manipulasi properti kamar (Nomor Kamar, Harga Sewa, Fasilitas Checkbox). Menggunakan operasi `.upsert()` ke tabel `kamar`.

### 4.3 Form Tambah/Edit Penyewa
* **File Reference:** `assets/ui kosku/3_kamar/4_tambah or Edit Penyewa.png`
* **Route Name:** `/edit-penyewa`
* **Logic:** Entri data identitas penyewa baru ke tabel `detail_penyewa` (Primary Key: `nik`) dan menyisipkan data kontak ke tabel `penyewa`.

### 4.4 Detail Transaksi
* **File Reference:** `assets/ui kosku/4_transaksi/2_Detail Transaksi.png`
* **Route Name:** `/detail-transaksi`
* **Logic:** Menampilkan rincian struk kuitansi penerimaan dana yang bersumber dari tabel `pemasukan`.

### 4.5 Form Tambah Transaksi
* **File Reference:** `assets/ui kosku/4_transaksi/3_Tambah Transaksi.png`
* **Route Name:** `/tambah-transaksi`
* **Logic:** Menyisipkan baris transaksi pembayaran baru ke tabel `pemasukan`. Jika sukses, otomatis memperbarui properti `status_pembayaran` di tabel `invoice` terkait menjadi 'Lunas'.

### 4.6 Preview Invoice
* **File Reference:** `assets/ui kosku/4_transaksi/4_Preview Invoice.png`
* **Route Name:** `/preview-invoice`
* **Logic:** Menyusun pratinjau lembar tagihan digital berdasarkan baris data dari tabel `invoice`.

### 4.7 Form Tambah/Edit Pengeluaran
* **File Reference:** `assets/ui kosku/5_buku kas/2_tambah or Edit Pengeluaran.png`
* **Route Name:** `/tambah-pengeluaran`
* **Logic:** Operasi `INSERT` pengeluaran operasional baru ke tabel `pengeluaran` (`kategori`, `deskripsi`, `tanggal_keluar`, `nominal_keluar`).

### 4.8 Detail Pengeluaran
* **File Reference:** `assets/ui kosku/5_buku kas/3_Detail Pengeluaran.png`
* **Route Name:** `/detail-pengeluaran`
* **Logic:** Menampilkan rincian log nota biaya operasional tertentu dari tabel `pengeluaran`.

### 4.9 Edit Profil
* **File Reference:** `assets/ui kosku/6_profil/2_Edit Profil.png`
* **Route Name:** `/edit-profil`
* **Logic:** Form pembaruan informasi nama personal admin atau perubahan data nama instansi kos terkait di database.

---

## 5. Active Supabase Database Schema Reference
```sql
-- Skema database produksi yang aktif terhubung di backend (SINKRON DATA UI V3):
-- 1. kamar (id_kamar, nomor_kamar, harga_sewa_dasar, status_kamar, fasilitas text[], foto_kamar text[])
-- 2. detail_penyewa (nik, tempat_lahir, tanggal_lahir, jenis_kelamin, alamat_ktp, pekerjaan)
-- 3. penyewa (id_penyewa, nik, nomor_whatsapp, nama_lengkap)
-- 4. sewa (id_sewa, id_kamar, id_penyewa, tanggal_masuk, durasi_bulan, status_sewa)
-- 5. invoice (id_invoice, id_sewa, nomor_invoice, tanggal_dibuat, tanggal_jatuh_tempo, total_tagihan, status_pembayaran)
-- 6. pemasukan (id_pemasukan, id_invoice, tanggal_bayar, nominal_masuk, metode_bayar, catatan)
-- 7. pengeluaran (id_pengeluaran, kategori, deskripsi, tanggal_keluar, nominal_keluar)
-- 8. profil_admin (id_admin uuid, nama_lengkap, nama_kost)