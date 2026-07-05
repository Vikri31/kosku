import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'transaksi_models.dart';

class PreviewInvoiceScreen extends StatefulWidget {
  final TransactionItem item;

  const PreviewInvoiceScreen({super.key, required this.item});

  @override
  State<PreviewInvoiceScreen> createState() => _PreviewInvoiceScreenState();
}

class _PreviewInvoiceScreenState extends State<PreviewInvoiceScreen> {
  // Theme colors
  static const Color primaryColor = Color(0xFF004D40); // Teal
  static const Color accentColor = Color(0xFFFFA834);  // Orange
  static const Color backgroundColor = Color(0xFFF5F7F8);

  bool _isSending = false;

  // Formatting currency to Rupiah
  String _formatRupiah(num number) {
    final str = number.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return 'Rp ${buffer.toString().split('').reversed.join('')}';
  }

  // Formatting date to Indonesian format
  String _formatDate(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // Logic to send invoice (Update status in database)
  Future<void> _kirimInvoice() async {
    setState(() => _isSending = true);
    try {
      final client = Supabase.instance.client;

      // Update status_pembayaran to 'Belum Bayar' (or columns for realtime side)
      await client
          .from('invoice')
          .update({
            'status_pembayaran': 'Belum Bayar',
          })
          .eq('id_invoice', int.parse(widget.item.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice berhasil dikirim ke aplikasi penyewa!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Return true to trigger refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim invoice: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic values for calculations
    final num sewaKamar = widget.item.amount;
    const num biayaListrik = 150000;
    const num biayaKebersihan = 50000;
    final num totalTagihan = sewaKamar + biayaListrik + biayaKebersihan;

    // Estimate due date (7 days from invoice date)
    final dueDate = widget.item.paymentDate.add(const Duration(days: 7));

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Invoice',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview Invoice',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Pastikan data sudah benar sebelum dikirim.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- MAIN NOTA CARD ---
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Decorative Teal accent line at top
                        Container(
                          width: double.infinity,
                          height: 6,
                          color: primaryColor,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title & Status row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'KosKu',
                                    style: TextStyle(
                                      color: Colors.teal.shade800,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: accentColor, width: 1.2),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.schedule, color: accentColor, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Menunggu Kirim',
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.item.invoiceNumber,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              const SizedBox(height: 20),
                              const Divider(height: 1, color: Color(0xFFEEEEEE)),
                              const SizedBox(height: 18),

                              // Tagihan Untuk Section
                              const Text(
                                'TAGIHAN UNTUK',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.item.tenantName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kamar ${widget.item.room}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Jatuh Tempo Section
                              const Text(
                                'TANGGAL JATUH TEMPO',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatDate(dueDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Divider(height: 1, color: Color(0xFFEEEEEE)),
                              const SizedBox(height: 20),

                              // Rincian Biaya
                              const Text(
                                'Rincian Tagihan',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 14),

                              _buildBillRow(
                                Icons.meeting_room_outlined,
                                'Sewa Kamar (1 Bulan)',
                                _formatRupiah(sewaKamar),
                              ),
                              const SizedBox(height: 12),
                              _buildBillRow(
                                Icons.electric_bolt_outlined,
                                'Listrik (Token/Meter)',
                                _formatRupiah(biayaListrik),
                              ),
                              const SizedBox(height: 12),
                              _buildBillRow(
                                Icons.cleaning_services_outlined,
                                'Biaya Kebersihan',
                                _formatRupiah(biayaKebersihan),
                              ),
                              const SizedBox(height: 20),
                              const Divider(height: 1, color: Color(0xFFEEEEEE)),
                              const SizedBox(height: 20),

                              // Subtotal & Total
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Subtotal',
                                    style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    _formatRupiah(totalTagihan),
                                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Tagihan',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _formatRupiah(totalTagihan),
                                    style: const TextStyle(
                                      color: primaryColor,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // --- INFO BANNER ---
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: primaryColor, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Invoice akan muncul di menu Tagihan penghuni secara otomatis setelah Anda mengirimkannya.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- ACTION BUTTONS ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isSending
                    ? const Center(child: CircularProgressIndicator(color: primaryColor))
                    : ElevatedButton.icon(
                        onPressed: _kirimInvoice,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Kirim Invoice ke Penyewa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: primaryColor, width: 1.5),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: primaryColor.withValues(alpha: 0.7), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
