import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvoicePenghuniScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  const InvoicePenghuniScreen({super.key, required this.invoice});

  @override
  State<InvoicePenghuniScreen> createState() => _InvoicePenghuniScreenState();
}

class _InvoicePenghuniScreenState extends State<InvoicePenghuniScreen> {
  static const Color _primaryColor = Color(0xFF007461);
  static const Color _backgroundColor = Color(0xFFF4F6F7);

  bool _isLoading = true;
  String _namaKost = 'KosKu';
  String _nomorInvoice = '-';
  String _namaPenyewa = '-';
  String _nomorWhatsapp = '-';
  String _nomorKamar = '-';
  String _periodeSewa = '-';
  int _totalTagihan = 0;
  String _statusPembayaran = 'Belum Bayar';

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    try {
      final supabase = Supabase.instance.client;
      final inv = widget.invoice;

      _nomorInvoice = inv['nomor_invoice'] ?? '-';
      _totalTagihan = inv['total_tagihan'] != null 
          ? int.parse(inv['total_tagihan'].toString()) 
          : 0;
      _statusPembayaran = inv['status_pembayaran'] ?? 'Belum Bayar';
      _periodeSewa = inv['periode_sewa'] ?? '-';

      // 1. Ambil data Sewa untuk menghubungkan ke Kamar dan Penyewa
      final sewa = await supabase
          .from('sewa')
          .select()
          .eq('id_sewa', inv['id_sewa'])
          .maybeSingle();

      if (sewa != null) {
        // 2. Ambil data Kamar
        final kamar = await supabase
            .from('kamar')
            .select()
            .eq('id_kamar', sewa['id_kamar'])
            .maybeSingle();

        if (kamar != null) {
          _nomorKamar = 'Kamar ${kamar['nomor_kamar']}';
          
          // Ambil profil Admin pengelola kos
          final admin = await supabase
              .from('profil_admin')
              .select()
              .eq('id_admin', kamar['id_admin'])
              .maybeSingle();
          if (admin != null) {
            _namaKost = admin['nama_kost'] ?? 'KosKu';
          }
        }

        // 3. Ambil data Penyewa
        final penyewa = await supabase
            .from('penyewa')
            .select()
            .eq('id_penyewa', sewa['id_penyewa'])
            .maybeSingle();

        if (penyewa != null) {
          _namaPenyewa = penyewa['nama_lengkap'] ?? '-';
          _nomorWhatsapp = penyewa['nomor_whatsapp'] ?? '-';
        }
      }
    } catch (e) {
      debugPrint('Error loading invoice details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatRupiah(num number) {
    final strVal = number.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = strVal.length - 1; i >= 0; i--) {
      buffer.write(strVal[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return 'Rp ${buffer.toString().split('').reversed.join('')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        toolbarHeight: 54,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        titleSpacing: 0,
        title: const Text(
          'Detail Tagihan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invoice Pembayaran',
                        style: TextStyle(
                          color: Color(0xFF1F2933),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Berikut adalah detail tagihan sewa bulanan Anda.',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.apartment,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _namaKost,
                                  style: const TextStyle(
                                    color: _primaryColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _nomorInvoice,
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusBadge(status: _statusPembayaran),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _PartyInfo(
                              label: 'PENYEWA',
                              name: _namaPenyewa,
                              details: _nomorWhatsapp,
                              alignRight: false,
                            ),
                          ),
                          Expanded(
                            child: _PartyInfo(
                              label: 'UNIT & LANTAI',
                              name: _nomorKamar,
                              details: 'Lantai 1', // Default lantai 1
                              alignRight: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7F7),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: _primaryColor,
                              size: 18,
                            ),
                            const SizedBox(width: 9),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Periode Sewa',
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _periodeSewa,
                                  style: const TextStyle(
                                    color: Color(0xFF374151),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _InvoiceTable(
                        totalTagihan: _totalTagihan,
                        formatRupiah: _formatRupiah,
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: Color(0xFFE5E7EB), height: 1),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total Tagihan',
                              style: TextStyle(
                                color: Color(0xFF1F2933),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            _formatRupiah(_totalTagihan),
                            style: const TextStyle(
                              color: _primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          _getBottomMessage(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 10,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF9CA3AF),
                          ),
                          child: const Text(
                            'Tutup',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _getBottomMessage() {
    final status = _statusPembayaran.toUpperCase();
    if (status == 'LUNAS') {
      return 'Pembayaran telah lunas. Terima kasih telah melakukan pembayaran tepat waktu!';
    } else if (status == 'MENUNGGU VERIFIKASI') {
      return 'Bukti transfer telah dikirim dan sedang dalam proses verifikasi oleh Pemilik Kos.';
    } else {
      return 'Harap segera lakukan pembayaran via bank transfer sebelum tanggal jatuh tempo dan unggah bukti pembayaran.';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final statusUpper = status.toUpperCase();
    final isLunas = statusUpper == 'LUNAS';
    final isWaiting = statusUpper == 'MENUNGGU VERIFIKASI';

    final badgeColor = isLunas
        ? const Color(0xFF007461)
        : (isWaiting ? const Color(0xFFFFA834) : const Color(0xFFFF3B30));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLunas
                ? Icons.check_circle
                : (isWaiting ? Icons.hourglass_empty : Icons.error_outline),
            color: badgeColor,
            size: 10,
          ),
          const SizedBox(width: 4),
          Text(
            statusUpper,
            style: TextStyle(
              color: badgeColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyInfo extends StatelessWidget {
  const _PartyInfo({
    required this.label,
    required this.name,
    required this.details,
    required this.alignRight,
  });

  final String label;
  final String name;
  final String details;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          name,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF1F2933),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          details,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InvoiceTable extends StatelessWidget {
  final int totalTagihan;
  final String Function(num) formatRupiah;
  const _InvoiceTable({required this.totalTagihan, required this.formatRupiah});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'Deskripsi Item',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'Jumlah',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _InvoiceRow(
          title: 'Sewa Kamar',
          subtitle: 'Biaya sewa pokok bulanan',
          amount: formatRupiah(totalTagihan),
        ),
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1F2933),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          amount,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Color(0xFF1F2933),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
