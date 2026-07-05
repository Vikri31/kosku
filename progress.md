# 📌 PRD & Checklist Pembagian Tugas Proyek KosKu

**Status Proyek:** 🛠️ Tahap Pengembangan Sisi Admin  
**Database:** Supabase Realtime & PostgreSQL

---

# 👥 Tim & Pembagian Tugas

## 👨‍💻 Vikri (Gatekeeper / Admin)

Bertanggung jawab terhadap:

- Pengembangan seluruh fitur **Admin/Pemilik Kos**
- Struktur database utama
- Integrasi Supabase
- Routing pada `main.dart`
- Review dan merge kode
- Push ke repository GitHub utama

---

## 👨‍💻 Rekan Kelompok (Sisi User)

Bertanggung jawab terhadap:

- Seluruh fitur **User/Anak Kos**
- Membuat file baru pada folder:

```text
lib/screens/user/
```

Tidak diperbolehkan mengubah:

- `main.dart`
- Folder `admin/`
- Struktur routing utama

---

# 🏗️ Struktur Folder Proyek

```text
lib/
├── main.dart                     # Pusat Routing (Vikri)
├── models/
└── screens/
    ├── auth/
    │   ├── login_screen.dart
    │   ├── register_screen.dart
    │   └── pilih_role_screen.dart
    │
    ├── admin/                    # Porsi Vikri
    │   ├── kamar/
    │   │   ├── kamar_list_screen.dart
    │   │   ├── kamar_form_screen.dart
    │   │   ├── detail_kamar_screen.dart
    │   │   └── konfirmasi_penghuni_screen.dart
    │   │
    │   ├── transaksi/
    │   │   ├── daftar_transaksi_screen.dart
    │   │   ├── detail_transaksi_screen.dart
    │   │   ├── tambah_transaksi_dialog.dart
    │   │   └── preview_invoice_screen.dart
    │   │
    │   └── buku_kas/
    │       ├── buku_kas_screen.dart
    │       ├── pengeluaran_form.dart
    │       └── detail_pengeluaran_screen.dart
    │
    └── user/                     # Porsi Rekan Kelompok
        ├── join/
        ├── dashboard/
        └── invoice/
```

---

# ✅ Checklist Progress Pengembangan

> Ganti `[ ]` menjadi `[v]` setelah fitur selesai dikembangkan, diuji, dan siap digunakan.

---

# 🏢 FASE 1 — Admin & Fondasi Database

## 📂 Modul Kamar (`lib/screens/admin/kamar/`)

### Manajemen Kamar

- [v] Kamar List Screen
- [v] Kamar Form Screen
- [v] Detail Kamar (Kondisi Kosong)
- [v] Detail Kamar (Kondisi Terisi)

### Konfirmasi Penghuni

- [ ] Konfirmasi Penghuni Screen
- [ ] Tombol **Setujui**
  - ubah status request menjadi **Disetujui**
  - ubah status kamar menjadi **Terisi**
  - otomatis insert ke tabel **sewa**

- [ ] Tombol **Tolak**
  - ubah status request menjadi **Ditolak**

---

## 💰 Modul Transaksi (`lib/screens/admin/transaksi/`)

- [ ] Daftar Transaksi Screen

- [ ] Detail Transaksi Screen
  - review bukti transfer
  - konfirmasi pembayaran lunas

- [ ] Tambah Transaksi Dialog
  - membuat invoice bulanan
  - biaya tambahan

- [ ] Preview Invoice
  - siap cetak
  - siap dibagikan ke WhatsApp

---

## 📊 Modul Buku Kas (`lib/screens/admin/buku_kas/`)

- [ ] Buku Kas Screen
  - total pemasukan
  - total pengeluaran
  - saldo

- [ ] Form Pengeluaran

- [ ] Detail Pengeluaran

---

# 👤 FASE 2 — User / Anak Kos

*(Dikerjakan setelah fondasi Admin stabil.)*

---

## 🏠 Join Kos (`lib/screens/user/join/`)

- [ ] Join Kos Screen

- [ ] Validasi Token Kamar

- [ ] Kirim data ke tabel `request_join`
  - status awal = **Menunggu Konfirmasi**

---

## 📱 Dashboard User (`lib/screens/user/dashboard/`)

- [ ] Dashboard User
  - nama kos
  - nomor kamar
  - kontak pemilik
  - status tagihan

- [ ] Lengkapi Profil
  - NIK
  - Foto KTP
  - Nomor WhatsApp

---

## 🧾 Invoice User (`lib/screens/user/invoice/`)

- [ ] Daftar Tagihan

- [ ] Detail Tagihan

- [ ] Upload Bukti Transfer
  - upload ke Supabase Storage

---

# 🗄️ Flow Database

```text
Admin
   │
   ▼
Tabel kamar
   │
Generate Token
   │
   ▼
User memasukkan token
   │
   ▼
request_join
(status = Menunggu)
   │
   ▼
Admin Konfirmasi
   │
   ├── Ditolak
   │
   └── Disetujui
          │
          ├── kamar.status = Terisi
          └── insert ke tabel sewa
                     │
                     ▼
             Generate Invoice
                     │
                     ▼
                 invoice
                     │
                     ▼
          User Upload Bukti Transfer
                     │
                     ▼
           Admin Verifikasi Pembayaran
                     │
                     ▼
               status = Lunas
                     │
                     ▼
              Masuk Buku Kas
```

---

# 🚨 Aturan Git & Kolaborasi

## File Global

Hanya **Vikri** yang boleh mengubah:

```text
lib/main.dart
```

Tujuannya untuk menghindari merge conflict pada routing aplikasi.

---

## File Baru

Rekan kelompok hanya boleh membuat file di dalam:

```text
lib/screens/user/
```

Tidak diperbolehkan mengubah:

- Folder `admin`
- `main.dart`
- konfigurasi routing

---

## Mekanisme Merge

1. Rekan membuat fitur.
2. Commit ke branch masing-masing.
3. Push ke GitHub.
4. Vikri melakukan review.
5. Merge ke branch utama.

---

## Testing

Pengujian dilakukan menggunakan:

- Supabase Dashboard
- Table Editor
- Realtime Database
- Supabase Storage

Seluruh manipulasi data seperti:

- `request_join`
- `invoice`
- `pengeluaran`
- `sewa`

dapat diuji langsung melalui dashboard Supabase.

---

# 📌 Status Progress

## Admin

- 🟩 Modul Kamar : **4/7 selesai**
- 🟨 Modul Transaksi : **0/4**
- 🟨 Modul Buku Kas : **0/3**

---

## User

- 🟨 Join Kos : **0/3**
- 🟨 Dashboard : **0/2**
- 🟨 Invoice : **0/3**

---

**Total Progress:** **4 / 19 fitur selesai** 🚀