-- 0. Update struktur tabel invoice jika kolom tambahan belum ada
ALTER TABLE invoice ADD COLUMN IF NOT EXISTS periode_sewa text;
ALTER TABLE invoice ADD COLUMN IF NOT EXISTS biaya_sewa_pokok int8 DEFAULT 0;
ALTER TABLE invoice ADD COLUMN IF NOT EXISTS biaya_listrik int8 DEFAULT 0;
ALTER TABLE invoice ADD COLUMN IF NOT EXISTS biaya_kebersihan int8 DEFAULT 0;
ALTER TABLE invoice ADD COLUMN IF NOT EXISTS bukti_transfer_url text;

-- 1. Mengaktifkan ekstensi pg_cron di schema extensions jika belum aktif
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- 2. Membuat Stored Procedure / Function untuk generate invoice bulanan otomatis
CREATE OR REPLACE FUNCTION generate_monthly_invoices()
RETURNS void AS $$
DECLARE
    r RECORD;
    next_billing_date date;
    generation_date date;
    new_invoice_no text;
    periode text;
BEGIN
    -- Memindai semua kontrak sewa yang berstatus 'Aktif'
    FOR r IN 
        SELECT 
            s.id_sewa,
            s.id_kamar,
            s.id_penyewa,
            s.tanggal_masuk,
            k.harga_sewa_dasar,
            k.nomor_kamar,
            COUNT(i.id_invoice) as invoice_count
        FROM sewa s
        JOIN kamar k ON s.id_kamar = k.id_kamar
        LEFT JOIN invoice i ON s.id_sewa = i.id_sewa
        WHERE s.status_sewa = 'Aktif'
        GROUP BY s.id_sewa, s.id_kamar, s.id_penyewa, s.tanggal_masuk, k.harga_sewa_dasar, k.nomor_kamar
    LOOP
        -- Hitung tanggal jatuh tempo berikutnya: tanggal_masuk + (jumlah_invoice_terbit * 1 bulan)
        next_billing_date := (r.tanggal_masuk + (r.invoice_count * interval '1 month'))::date;
        
        -- Hitung tanggal pembuatan (H-3 sebelum jatuh tempo siklus berikutnya)
        generation_date := (next_billing_date - interval '3 days')::date;
        
        -- Jika hari ini (CURRENT_DATE) adalah tanggal pembuatan, maka buat invoice
        IF CURRENT_DATE = generation_date THEN
            -- Format Nomor Invoice: INV/YYYYMMDD/KM-{no_kamar}/{id_sewa}-{urutan_invoice}
            new_invoice_no := 'INV/' || to_char(CURRENT_DATE, 'YYYYMMDD') || '/KM-' || r.nomor_kamar || '/' || r.id_sewa || '-' || (r.invoice_count + 1);
            
            -- Format Periode: Nama Bulan & Tahun (misal: "July 2026")
            periode := to_char(next_billing_date, 'Month YYYY');
            
            -- Melakukan insert otomatis ke tabel invoice
            INSERT INTO invoice (
                id_sewa,
                nomor_invoice,
                periode_sewa,
                biaya_sewa_pokok,
                biaya_listrik,
                biaya_kebersihan,
                total_tagihan,
                status_pembayaran,
                tanggal_dibuat,
                tanggal_jatuh_tempo
            ) VALUES (
                r.id_sewa,
                new_invoice_no,
                trim(periode),
                r.harga_sewa_dasar,
                0, -- default biaya listrik (dapat diubah manual nanti)
                0, -- default biaya kebersihan
                r.harga_sewa_dasar, -- total tagihan awal = sewa pokok
                'Belum Bayar',
                CURRENT_DATE,
                next_billing_date
            );
            
            RAISE NOTICE 'Invoice otomatis berhasil dibuat untuk Sewa ID % (Nomor: %)', r.id_sewa, new_invoice_no;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 3. Menjadwalkan Stored Procedure di pg_cron agar berjalan setiap hari pada pukul 00:00 WIB (17:00 UTC)
-- Supabase Cloud menggunakan zona waktu UTC, sehingga 17:00 UTC = 00:00 WIB
SELECT cron.schedule(
    'generate-monthly-invoices-cron', -- Nama cron job
    '0 17 * * *',                      -- Cron expression: Setiap hari jam 17:00 UTC (00:00 WIB)
    $$ SELECT generate_monthly_invoices(); $$
);

-- 4. Membuat Trigger untuk generate invoice awal secara otomatis setelah kontrak sewa baru di-INSERT
CREATE OR REPLACE FUNCTION create_initial_invoice()
RETURNS TRIGGER AS $$
DECLARE
    room_price int8;
    room_no text;
    new_invoice_no text;
    periode text;
BEGIN
    -- Ambil harga sewa dan nomor kamar dari tabel kamar
    SELECT harga_sewa_dasar, nomor_kamar INTO room_price, room_no
    FROM kamar
    WHERE id_kamar = NEW.id_kamar;
    
    -- Format nomor invoice unik: INV/YYYYMMDD/KM-{no_kamar}/{id_sewa}-1
    new_invoice_no := 'INV/' || to_char(NEW.tanggal_masuk, 'YYYYMMDD') || '/KM-' || room_no || '/' || NEW.id_sewa || '-1';
    
    -- Format periode sewa, misal: "July 2026"
    periode := to_char(NEW.tanggal_masuk, 'Month YYYY');
    
    -- Sisipkan invoice awal dengan status 'Belum Bayar'
    INSERT INTO invoice (
        id_sewa,
        nomor_invoice,
        periode_sewa,
        biaya_sewa_pokok,
        biaya_listrik,
        biaya_kebersihan,
        total_tagihan,
        status_pembayaran,
        tanggal_dibuat,
        tanggal_jatuh_tempo
    ) VALUES (
        NEW.id_sewa,
        new_invoice_no,
        trim(periode),
        room_price,
        0,
        0,
        room_price,
        'Belum Bayar',
        NEW.tanggal_masuk,
        NEW.tanggal_masuk -- Jatuh tempo hari pertama masuk
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_create_initial_invoice
AFTER INSERT ON sewa
FOR EACH ROW
WHEN (NEW.status_sewa = 'Aktif')
EXECUTE FUNCTION create_initial_invoice();
