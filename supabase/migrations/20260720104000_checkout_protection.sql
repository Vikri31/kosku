-- SQL Migration: Proteksi Keluar Kos (Checkout Protection Trigger)
-- Berkas ini menjamin proteksi di level database PostgreSQL (Supabase)
-- Mencegah update status sewa menjadi 'Selesai' jika penyewa masih memiliki invoice yang belum 'Lunas'

-- 1. Membuat Fungsi Trigger
CREATE OR REPLACE FUNCTION check_unpaid_invoices_before_leave()
RETURNS TRIGGER AS $$
BEGIN
  -- Memeriksa jika status_sewa diubah menjadi 'Selesai' (keluar kos) dari status sebelumnya
  IF NEW.status_sewa = 'Selesai' AND OLD.status_sewa != 'Selesai' THEN
    -- Memeriksa jika ada invoice terkait id_sewa ini yang belum 'Lunas'
    IF EXISTS (
      SELECT 1 FROM public.invoice 
      WHERE id_sewa = NEW.id_sewa 
      AND status_pembayaran != 'Lunas'
    ) THEN
      RAISE EXCEPTION 'Penyewa tidak dapat keluar kos (masa sewa selesai) karena masih memiliki tagihan invoice yang belum dilunasi. Selesaikan pembayaran terlebih dahulu.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Memasang Trigger ke Tabel sewa
DROP TRIGGER IF EXISTS trg_check_unpaid_invoices ON public.sewa;
CREATE TRIGGER trg_check_unpaid_invoices
BEFORE UPDATE ON public.sewa
FOR EACH ROW
EXECUTE FUNCTION check_unpaid_invoices_before_leave();
