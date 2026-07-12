# 📌 Progress & Pembagian Tugas Pengembangan KosKu

Berikut adalah pembagian tugas pengembangan aplikasi KosKu berdasarkan modul/folder. 

Tim silakan mengisi nama dan status di masing-masing modul pada bagian heading menggunakan format: **`[Nama, Status]`** (Contoh: `[Vikri, Selesai]` atau `[Faiz, Selesai]`).

## rancangan desain aplikasi / ui `[Nama, Status]`
berisi terkait rancangan desain aplikasi / ui, untuk mempermudah pengerjaan kedepannya

## manajemen database `[vikri, done]`
berisi terkait penetuan kebutuhan database, untuk mempermudah pengerjaan kedepannyaa

---

## 🔒 1. Modul Otentikasi (`lib/screens/auth/`) ➡️ `[vikri, done]`
*   `login_screen.dart` (Halaman Masuk)
*   `register_screen.dart` (Daftar Akun Admin/Pemilik)
*   `register_penghuni_screen.dart` (Daftar Akun Penghuni)
*   `pilih_role_screen.dart` (Pilih Peran Akun)
*   `forgot_password_screen.dart` (Minta OTP Reset Sandi)
*   `verify_otp_screen.dart` (Input & Validasi OTP)
*   `reset_password_screen.dart` (Buat Kata Sandi Baru)

---

## 👑 2. Fitur Admin/Pengelola (`lib/screens/admin/`)

### 🚪 Modul dashboard (`admin/dashboard/`) ➡️ `[Nama, Status]`

### 🚪 Modul Kamar (`admin/kamar/`) ➡️ `[Nama, Status]`
*   `kamar_list_screen.dart` (Daftar Semua Kamar)
*   `kamar_form_screen.dart` (Tambah/Edit Kamar Baru)
*   `kamar_detail_screen.dart` (Detail Kamar & Manajemen Penghuni)
*   `detail_kamar_screen.dart` (Detail Informasi Kamar)
*   `konfirmasi_penghuni_screen.dart` (Persetujuan Gabung Kos)

### 💸 Modul Transaksi (`admin/transaksi/`) ➡️ `[Aqila, Done]`
*   `daftar_transaksi_screen.dart` (Daftar Transaksi Kos)
*   `transaksi_detail_screen.dart` (Detail Transaksi & Bukti Bayar)
*   `tambah_transaksi_screen.dart` (Buat Invoice Baru)
*   `preview_invoice_screen.dart` (Cetak/Bagikan PDF Invoice)

### 📒 Modul Buku Kas (`admin/buku_kas/`) ➡️ `[Nama, Status]`
*   `buku_kas_screen.dart` (Laporan Arus Kas Masuk & Keluar)
*   `pengeluaran_form.dart` (Pencatatan Biaya Pengeluaran)
*   `detail_pengeluaran_screen.dart` (Detail Riwayat Pengeluaran)

### 👤 Modul Profil Admin (`admin/profile/`) ➡️ `[Nama, Status]`
*   `profile_screen.dart` (Profil Admin & Uji Coba Suara Notifikasi)
*   `edit_profile_screen.dart` (Ubah Biodata & Nama Kost)

---

## 👥 3. Fitur Penyewa/User (`lib/screens/user/`)

### 🏠 Modul Dashboard (`user/dashboard/`) ➡️ `[vikri, done]`
*   `dashboard_penghuni_screen.dart` (Menu Utama & Informasi Jatuh Tempo)

### 🔑 Modul Join (`user/join/`) ➡️ `[Nama, Status]`
*   `input_kode_screen.dart` (Masukkan Token Pendaftaran Kamar)

### 🧾 Modul Tagihan & Invoice (`user/tagihan/`) ➡️ `[Aqila, Done]`
*   `tagihan_screen.dart` (Riwayat Histori Seluruh Pembayaran)
*   `detail_tagihan_screen.dart` (Form Upload Bukti Transfer Bank)
*   `invoice_penghuni_screen.dart` (Tampilan Lembar Invoice Tagihan)

### 👤 Modul Profil Penyewa (`user/profil/`) ➡️ `[Nama, Status]`
*   `profil_penghuni_screen.dart` (Profil Penyewa & Uji Coba Suara Notifikasi)
*   `lengkapi_data_diri_screen.dart` (Unggah KTP & Lengkapi Biodata)

---

## 🔔 4. Layanan Sistem & Notifikasi ➡️ `[vikri, sudah muncul, tp masih belum bisa menampilkan notifikasi by sistem]`
*   `lib/services/notification_service.dart` (Pusat API / Logika Notifikasi Database)
*   `lib/screens/notification/notification_list_screen.dart` (Layar Riwayat Log Notifikasi)
*   `lib/main.dart` (Pusat Navigasi & Listener Notifikasi Realtime HP)