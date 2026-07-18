import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'preview_invoice_screen.dart';
import 'transaksi_models.dart';

class DetailTransaksiScreen extends StatefulWidget {
  final int idInvoice;

  const DetailTransaksiScreen({super.key, required this.idInvoice});

  @override
  State<DetailTransaksiScreen> createState() => _DetailTransaksiScreenState();
}

class _DetailTransaksiScreenState extends State<DetailTransaksiScreen> {
  // Theme colors
  static const Color primaryColor = Color(0xFF004D40); // Teal
  static const Color backgroundColor = Color(0xFFF5F7F8);

  bool _isLoading = true;
  bool _isDeleting = false;
  Map<String, dynamic>? _invoiceData;
  Map<String, dynamic>? _pemasukanData;
  bool _isManualTenant = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;

      // 1. Fetch invoice data with joins
      final invoice = await client
          .from('invoice')
          .select('*, sewa(*, penyewa(*), kamar(*))')
          .eq('id_invoice', widget.idInvoice)
          .single();

      _invoiceData = invoice;

      // 2. Fetch payment method details from pemasukan table if exists
      final pemasukan = await client
          .from('pemasukan')
          .select()
          .eq('id_invoice', widget.idInvoice)
          .maybeSingle();

      _pemasukanData = pemasukan;

      // 3. Check if tenant is manual (no auth user account)
      final sewa = invoice['sewa'];
      final penyewa = sewa?['penyewa'];
      final nik = penyewa?['nik'];
      if (nik != null) {
        final detailPenyewa = await client
            .from('detail_penyewa')
            .select('id_user')
            .eq('nik', nik)
            .maybeSingle();
        if (detailPenyewa != null && detailPenyewa['id_user'] != null) {
          _isManualTenant = false;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat detail transaksi: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
  String _formatDetailDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      const months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute';
    } catch (_) {
      return dateStr;
    }
  }

  // Delete transaction function
  Future<void> _hapusTransaksi() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Hapus Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Apakah Anda yakin ingin menghapus transaksi ini dari sistem?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      final client = Supabase.instance.client;

      // 1. Delete payment record from pemasukan table first due to FK constraints
      await client.from('pemasukan').delete().eq('id_invoice', widget.idInvoice);

      // 2. Delete invoice
      await client.from('invoice').delete().eq('id_invoice', widget.idInvoice);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil dihapus!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Pop back with refresh parameter
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus transaksi: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Generate TransactionItem for PreviewInvoiceScreen
  void _generateInvoice() {
    if (_invoiceData == null) return;

    final sewa = _invoiceData!['sewa'];
    final penyewa = sewa?['penyewa'];
    final kamar = sewa?['kamar'];

    final item = TransactionItem(
      id: _invoiceData!['id_invoice'].toString(),
      tenantName: penyewa?['nama_lengkap'] ?? 'Penyewa',
      room: kamar?['nomor_kamar'] ?? '-',
      roomFloor: 'Lantai 1',
      paymentDate: DateTime.tryParse(_invoiceData!['tanggal_dibuat']) ?? DateTime.now(),
      amount: _invoiceData!['total_tagihan'] as int,
      isPaid: _invoiceData!['status_pembayaran']?.toString().toLowerCase() == 'lunas',
      method: _pemasukanData?['metode_bayar'] ?? '-',
      phone: penyewa?['nomor_whatsapp'] ?? '-',
      invoiceNumber: _invoiceData!['nomor_invoice'] ?? '-',
      electricityFee: 0,
      isManual: _isManualTenant,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewInvoiceScreen(item: item),
      ),
    ).then((val) {
      if (val == true) {
        _loadDetail();
      }
    });
  }

  Future<void> _tandaiLunas() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Konfirmasi Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Apakah Anda yakin ingin menandai transaksi ini sebagai Lunas?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Ya, Lunas', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;

      // 1. Update invoice status to 'Lunas'
      await client
          .from('invoice')
          .update({
            'status_pembayaran': 'Lunas',
          })
          .eq('id_invoice', widget.idInvoice);

      // 2. Insert into pemasukan table if not exists
      if (_pemasukanData == null) {
        final amount = _invoiceData!['total_tagihan'] as num;
        final nowStr = DateTime.now().toIso8601String().split('T').first;
        await client.from('pemasukan').insert({
          'id_invoice': widget.idInvoice,
          'tanggal_bayar': nowStr,
          'nominal_masuk': amount,
          'metode_bayar': 'Transfer', // Default payment method
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil ditandai sebagai Lunas!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadDetail(); // Reload detail to reflect updated status
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menandai lunas: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_invoiceData == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Detail Transaksi', style: TextStyle(color: Colors.white)),
          backgroundColor: primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: Text('Data transaksi tidak ditemukan')),
      );
    }

    final sewa = _invoiceData!['sewa'];
    final penyewa = sewa?['penyewa'];
    final kamar = sewa?['kamar'];

    final String tenantName = penyewa?['nama_lengkap'] ?? 'Penyewa';
    final String roomNum = kamar?['nomor_kamar'] ?? '-';
    final String status = _invoiceData!['status_pembayaran'] ?? 'Belum Bayar';
    final num amount = _invoiceData!['total_tagihan'] ?? 0;
    final String dateStr = _invoiceData!['tanggal_dibuat'] ?? '';
    final String methodStr = _pemasukanData?['metode_bayar'] ?? '-';
    final String invoiceNum = _invoiceData!['nomor_invoice'] ?? '-';

    final bool isPaid = status.toLowerCase() == 'lunas';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Detail Transaksi',
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
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: Column(
            children: [
              // Paid status pill
              _PaidPill(isPaid: isPaid, status: status),
              const SizedBox(height: 20),

              // Total Tagihan Amount
              Text(
                _formatRupiah(amount),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pembayaran Sewa Kamar',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 36),

              // Detail card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _DetailRow(label: 'Nama Penyewa', value: tenantName),
                    _DetailRow(label: 'Kamar', value: 'Kamar $roomNum'),
                    _DetailRow(label: 'Tanggal Bayar', value: _formatDetailDate(dateStr)),
                    _DetailRow(label: 'Metode Pembayaran', value: methodStr),
                    _DetailRow(
                      label: 'Nomor Invoice',
                      value: invoiceNum,
                      compactValue: true,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Generate Invoice Button & Sudah Dibayarkan Button
              if (status.toUpperCase() != 'LUNAS') ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _generateInvoice,
                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                    label: const Text('Generate Invoice'),
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _tandaiLunas,
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Sudah Dibayarkan (Konfirmasi Lunas)'),
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      backgroundColor: const Color(0xFF2E7D32), // Green color
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Delete button (Hapus)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: _isDeleting
                    ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                    : OutlinedButton.icon(
                        onPressed: _hapusTransaksi,
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        label: const Text('Hapus Transaksi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD32F2F),
                          side: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaidPill extends StatelessWidget {
  final bool isPaid;
  final String status;

  const _PaidPill({required this.isPaid, required this.status});

  @override
  Widget build(BuildContext context) {
    Color paidColor;
    Color paidBackground;

    if (isPaid) {
      paidColor = const Color(0xFF2E7D32); // Green
      paidBackground = const Color(0xFFE8F5E9);
    } else if (status.toLowerCase() == 'belum' || status.toLowerCase() == 'belum bayar') {
      paidColor = const Color(0xFFC62828); // Red
      paidBackground = const Color(0xFFFFEBEE);
    } else {
      paidColor = const Color(0xFFEF6C00); // Orange
      paidBackground = const Color(0xFFFFF3E0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: paidBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle : Icons.schedule_rounded,
            color: paidColor,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: paidColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool compactValue;
  final bool showDivider;

  const _DetailRow({
    required this.label,
    required this.value,
    this.compactValue = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: compactValue ? Colors.grey.shade500 : Colors.black87,
                  fontSize: compactValue ? 11 : 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}
