# 📄 PRODUCT REQUIREMENT DOCUMENT (PRD) - KOSKU APP (V4 MULTI-TENANT & USER SYNC)

## 1. Project Overview & Architecture
* **Project Name:** KosKu
* **Objective:** Aplikasi manajemen kos multi-tenant yang menghubungkan Pemilik Kos (Admin) dan Penghuni Kos (User) secara *real-time* untuk mengelola properti, tagihan multi-komponen, pengajuan masuk, serta pembukuan kas.
* **Tech Stack:** Flutter (Frontend), Supabase (Backend Auth, Storage, & Realtime Database).
* **State Management:** `StreamBuilder` & `FutureBuilder` (Supabase Native Client).
* **Design Core Color:** Dark Green (`Color(0xFF004D40)`) & Accent Orange (`Color(0xFFFFA834)`).

---

## 2. User Authentication & Onboarding Workflow (Epics 1)

### 2.1 Splash Screen
* **File Reference:** `assets/kosku_new_update/0_splash screen/1_Splash Screen.png`
* **Route Name:** `/splash`
* **Logic:** Memeriksa sesi login aktif via Supabase Auth. Jika sesi valid, periksa ID di tabel `public.profil_admin`. Jika terdaftar sebagai admin ➡️ `/dashboard`, jika terdaftar sebagai penghuni kos ➡️ `/dashboard-user`. Jika kosong ➡️ `/login`.

### 2.2 Login Screen
* **File Reference:** `assets/kosku_new_update/1_login/2_Login.png`
* **Route Name:** `/login`
* **Logic:** Form input `Alamat Email` dan `Kata Sandi`. Menjalankan fungsi `signInWithPassword()`. Tombol "Daftar Akun" mengarahkan ke halaman `/daftar-sebagai`.

### 2.3 Daftar Sebagai Screen
* **File Reference:** `assets/kosku_new_update/1_login/3_Daftar Sebagai.png`
* **Route Name:** `/daftar-sebagai`
* **Logic:** Opsi pemilihan peran antara "Pemilik Kos" atau "Penghuni Kos". Jika Pemilik Kos ➡️ `/register-admin`. Jika Penghuni Kos ➡️ `/register-user`.

### 2.4 Register Admin Screen
* **File Reference:** `assets/kosku_new_update/admin/1_register admin/1_Register admin.png`
* **Route Name:** `/register-admin`
* **Logic:** Form pendaftaran admin (`Nama Lengkap`, `Nama Kost`, `Alamat Email`, `Kata Sandi`, `Konfirmasi Kata Sandi`). Menjalankan fungsi `signUp()`. Setelah user terbuat di auth, lakukan `.insert()` data ke tabel `public.profil_admin`.

### 2.5 Register User Screen
* **File Reference:** `assets/kosku_new_update/user/1_register user/4_Register.png`
* **Route Name:** `/register-user`
* **Logic:** Form pendaftaran penghuni baru (`Nama Lengkap`, `Alamat Email`, `Kata Sandi`). Menjalankan fungsi `signUp()`. Jika sukses, user otomatis diarahkan ke halaman `/input-kode-kamar`.

---

## 3. Core Modules - SISI ADMIN (Epics 2)

### 3.1 Main Dashboard Admin (Beranda)
* **File Reference:** `assets/kosku_new_update/admin/2_dashboard/Dashboard.png`
* **Route Name:** `/dashboard`
* **Data Mapping (Wajib Filter `id_admin = currentUser`):**
  * **Pemasukan Bulan Ini:** Agregat total (`SUM`) dari nominal pembayaran invoice lunas bulan ini.
  * **Status Kamar Terisi / Kosong:** Total hitungan baris (`COUNT`) dari tabel `kamar` berdasarkan statusnya.
  * **Hampir Jatuh Tempo:** List tagihan dari tabel `invoice` dengan status 'Belum'.
  * **Bukti Bayar Masuk:** Menampilkan data pembayaran masuk dengan `status_pembayaran = 'Menunggu Verifikasi'` untuk divalidasi manual oleh admin.

### 3.2 Kamar List Screen
* **File Reference:** `assets/kosku_new_update/admin/3_kamar/1_Kamar.png`
* **Route Name:** `/kamar`
* **Data Mapping:** Mengambil data stream dari tabel `kamar` terfilter per `id_admin`. Tombol Floating Action Button `+` mengarahkan ke form penambahan kamar.

### 3.3 Transaksi Log Screen
* **File Reference:** `assets/kosku_new_update/admin/4_transaksi/1_Transaksi.png`
* **Route Name:** `/transaksi`
* **Data Mapping:** Menampilkan histori manifest tagihan global milik properti admin dari tabel `invoice`.

### 3.4 Buku Kas Screen
* **File Reference:** `assets/kosku_new_update/admin/5_buku/1_Buku kas.png`
* **Route Name:** `/buku-kas`
* **Data Mapping:** Menampilkan grafik neraca serta list pengeluaran dari tabel `pengeluaran` yang difilter khusus berdasarkan `id_admin` pengelola.

### 3.5 Profil Admin Screen
* **File Reference:** `assets/kosku_new_update/admin/6_profil/1_Profil admin.png`
* **Route Name:** `/profil-admin`
* **Logic:** Menampilkan jumlah total kamar yang dikelola dan mengintegrasikan fungsi keluar aplikasi (`signOut()`).

---

## 4. Sub-Screens & Data Mutation - SISI ADMIN (Epics 3)

### 4.1 Detail Kamar (Kamar Kosong vs Terisi)
* **File References:** 
  * `assets/kosku_new_update/admin/3_kamar/2_Detail Kamar Sebelum.png` (Kosong - menampilkan string token `kode_kamar` & tombol klaim pengajuan)
  * `assets/kosku_new_update/admin/3_kamar/3_Detail Kamar Sesudah.png` (Terisi - menampilkan profil penyewa & riwayat bayar)
* **Route Name:** `/detail-kamar`
* **Arguments:** `id_kamar` (int8)

### 4.2 Konfirmasi Penghuni Screen
* **File Reference:** `assets/kosku_new_update/admin/3_kamar/4_Konfirmasi Penghuni.png`
* **Route Name:** `/konfirmasi-penghuni`
* **Logic:** Memproses data pengajuan masuk dari tabel `request_join`. Tombol "Setujui" akan otomatis membuat baris data di tabel `sewa` dan `penyewa`, serta mengubah `status_kamar` menjadi 'Terisi'.

### 4.3 Detail Transaksi Per Kamar
* **File Reference:** `assets/kosku_new_update/admin/3_kamar/5_Detail Transaksi kamar.png`
* **Route Name:** `/detail-transaksi-kamar`
* **Logic:** Rincian invoice per kamar tertentu. Menampilkan lampiran berkas `bukti_transfer_url` dari penyewa serta tombol verifikasi konfirmasi lunas.

### 4.4 Form Tambah/Edit Kamar
* **File Reference:** `assets/kosku_new_update/admin/3_kamar/6_tambah or Edit Kamar.png`
* **Route Name:** `/edit-kamar`
* **Logic:** Input properti kamar. Menyisipkan string token `kode_kamar` otomatis saat *create*. Dilengkapi fungsi **client-side compression** otomatis untuk mengunggah berkas gambar ke Supabase Storage bucket `foto_kamar`.

### 4.5 Form Tambah/Edit Penyewa (Manual)
* **File Reference:** `assets/kosku_new_update/admin/3_kamar/7_tambah or Edit Penyewa.png`
* **Route Name:** `/edit-penyewa-manual`

### 4.6 Preview Invoice & Breakdown Multi-Komponen
* **File Reference:** `assets/kosku_new_update/admin/4_transaksi/4_Preview Invoice.png`
* **Route Name:** `/preview-invoice`
* **Logic:** Menginput rincian tagihan bulanan terpisah: `biaya_sewa_pokok`, `biaya_listrik`, dan `biaya_kebersihan` untuk dihitung menjadi `total_tagihan` di dalam tabel `invoice`.

---

## 5. Core Modules & Sub-Screens - SISI USER / PENGHUNI (Epics 4)

### 5.1 Halaman Sebelum Join (Input Kode)
* **File Reference:** `assets/kosku_new_update/user/2_halaman sebelum join/1_Input Kode Kamar.png`
* **Route Name:** `/input-kode-kamar`
* **Logic:** Input token kamar pengelola. Sistem melakukan validasi ke tabel `kamar`. Jika token cocok, sistem membuat baris data baru dengan status 'Menunggu Konfirmasi' pada tabel `request_join`.

### 5.2 Dashboard Penghuni (Beranda User)
* **File Reference:** `assets/kosku_new_update/user/3_halaman setelah join/3.1_dashboard/1_Dashboard Penghuni.png`
* **Route Name:** `/dashboard-user`
* **Logic:** Menampilkan info nomor kamar, sisa hari jatuh tempo sewa, nama pemilik kos, serta list tagihan bulanan terakhir.

### 5.3 Detail & Berkas Tagihan Penghuni
* **File References:** 
  * `assets/kosku_new_update/user/3_halaman setelah join/3.2_tagihan/1_Tagihan Penghuni.png` (Daftar Tagihan)
  * `assets/kosku_new_update/user/3_halaman setelah join/3.2_tagihan/2_Detail Tagihan Penghuni.png` (Form upload struk transfer)
  * `assets/kosku_new_update/user/3_halaman setelah join/3.3_profil/1_Profil Penghuni.png` (Nota bukti lunas)
* **Logic:** User melihat breakdown iuran bulanan. User dapat mengunggah foto struk pembayaran dari galeri ke kolom `bukti_transfer_url` di tabel `invoice` yang otomatis mengubah status invoice menjadi 'Menunggu Verifikasi'.

### 5.4 Profil & Kelola Data Diri User
* **File References:** 
  * `assets/kosku_new_update/user/3_halaman setelah join/3.3_profil/1_Profil Penghuni.png`
  * `assets/kosku_new_update/user/3_halaman setelah join/3.3_profil/2_Data Diri Penghuni.png` (Form NIK & Upload KTP)
* **Logic:** Tempat user melengkapi biodata legalitas tinggal di tabel `detail_penyewa` (mengisi NIK, foto KTP, No WA, alamat asal).

---

## 6. Active Database Schema (V4 Production Ready)
```sql
-- 1. public.profil_admin (id_admin uuid PK, nama_lengkap, nama_kost, updated_at)
-- 2. public.kamar (id_kamar PK, id_admin FK, nomor_kamar, harga_sewa_dasar, status_kamar, kode_kamar, fasilitas text[], foto_kamar text[])
-- 3. public.detail_penyewa (nik PK, id_user uuid FK, tempat_lahir, tanggal_lahir, jenis_kelamin, alamat_ktp, pekerjaan, foto_ktp_url)
-- 4. public.penyewa (id_penyewa PK, nik FK, nomor_whatsapp, nama_lengkap)
-- 5. public.request_join (id_request PK, id_user uuid FK, id_kamar FK, status_request, tanggal_pengajuan)
-- 6. public.sewa (id_sewa PK, id_kamar FK, id_penyewa FK, tanggal_masuk, durasi_bulan, status_sewa)
-- 7. public.invoice (id_invoice PK, id_sewa FK, nomor_invoice, periode_sewa, biaya_sewa_pokok, biaya_listrik, biaya_kebersihan, total_tagihan, status_pembayaran, bukti_transfer_url, tanggal_dibuat, tanggal_jatuh_tempo)
-- 8. public.pemasukan (id_pemasukan PK, id_invoice FK, tanggal_bayar, nominal_masuk, metode_bayar, catatan)
-- 9. public.pengeluaran (id_pengeluaran PK, id_admin FK, kategori, deskripsi, tanggal_keluar, nominal_keluar)