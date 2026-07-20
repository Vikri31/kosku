import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tambah_transaksi_screen.dart';
import 'transaksi_detail_screen.dart';

class DaftarTransaksiScreen extends StatefulWidget {
  const DaftarTransaksiScreen({super.key});

  @override
  State<DaftarTransaksiScreen> createState() => _DaftarTransaksiScreenState();
}

class _DaftarTransaksiScreenState extends State<DaftarTransaksiScreen> {
  // Theme colors
  static const Color primaryColor = Color(0xFF004D40); // Teal
  static const Color accentColor = Color(0xFFFFA834);  // Orange
  static const Color backgroundColor = Color(0xFFF5F7F8);

  bool _isLoading = true;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final adminId = client.auth.currentUser?.id;
      if (adminId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 1. Ambil id_kamar milik admin ini
      final kamarData = await client
          .from('kamar')
          .select('id_kamar')
          .eq('id_admin', adminId);

      if (kamarData.isEmpty) {
        if (mounted) {
          setState(() {
            _invoices = [];
            _isLoading = false;
          });
        }
        return;
      }

      final List<int> kamarIds = (kamarData as List)
          .map((k) => k['id_kamar'] as int)
          .toList();

      // 2. Ambil id_sewa dari kamar-kamar tersebut
      final sewaData = await client
          .from('sewa')
          .select('id_sewa')
          .inFilter('id_kamar', kamarIds);

      if (sewaData.isEmpty) {
        if (mounted) {
          setState(() {
            _invoices = [];
            _isLoading = false;
          });
        }
        return;
      }

      final List<int> sewaIds = (sewaData as List)
          .map((s) => s['id_sewa'] as int)
          .toList();

      // 3. Ambil invoice berdasarkan sewa milik admin ini
      final data = await client
          .from('invoice')
          .select('*, sewa(*, penyewa(*), kamar(*))')
          .inFilter('id_sewa', sewaIds)
          .order('tanggal_dibuat', ascending: false);

      if (mounted) {
        setState(() {
          _invoices = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat daftar transaksi: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'KosKu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: primaryColor,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daftar Transaksi',
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Kelola pembayaran dan tagihan penyewa',
                        style: TextStyle(color: Color(0xFF707070), fontSize: 12),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _loadInvoices,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadInvoices,
                  color: primaryColor,
                  child: _isLoading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            const Center(child: CircularProgressIndicator(color: primaryColor)),
                          ],
                        )
                      : _invoices.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Belum ada data transaksi',
                                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              itemCount: _invoices.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = _invoices[index];
                                return _TransactionCard(
                                  item: item,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DetailTransaksiScreen(
                                          idInvoice: item['id_invoice'] as int,
                                        ),
                                      ),
                                    ).then((val) {
                                      if (val == true) {
                                        _loadInvoices();
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TambahTransaksiScreen()),
          ).then((val) {
            if (val == true) {
              _loadInvoices();
            }
          });
        },
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _TransactionCard({required this.item, required this.onTap});

  // Helper to format currency
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

  // Helper to format date
  String _formatShortDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sewa = item['sewa'];
    final penyewa = sewa?['penyewa'];
    final kamar = sewa?['kamar'];

    final String tenantName = penyewa?['nama_lengkap'] ?? 'Penyewa';
    final String roomNum = kamar?['nomor_kamar'] ?? '-';
    final String status = item['status_pembayaran'] ?? 'Belum Bayar';
    final num amount = item['total_tagihan'] ?? 0;
    final String dateStr = item['tanggal_dibuat'] ?? '';
    final String dueDateStr = item['tanggal_jatuh_tempo'] ?? '';

    bool isOverdue = false;
    if (status.toLowerCase() != 'lunas' && dueDateStr.isNotEmpty) {
      try {
        final dueDate = DateTime.parse(dueDateStr).toLocal();
        final today = DateTime.now();
        final todayDateOnly = DateTime(today.year, today.month, today.day);
        final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
        if (dueDateOnly.isBefore(todayDateOnly)) {
          isOverdue = true;
        }
      } catch (_) {}
    }

    final String displayStatus = isOverdue ? 'Lewat Jatuh Tempo' : status;

    // Color logic according to status
    Color paidColor;
    Color paidBackground;

    if (displayStatus == 'Lewat Jatuh Tempo') {
      paidColor = const Color(0xFFD32F2F); // Dark Red
      paidBackground = const Color(0xFFFFCDD2);
    } else if (status.toLowerCase() == 'lunas') {
      paidColor = const Color(0xFF2E7D32); // Green
      paidBackground = const Color(0xFFE8F5E9);
    } else if (status.toLowerCase() == 'belum' || status.toLowerCase() == 'belum bayar') {
      paidColor = const Color(0xFFC62828); // Red
      paidBackground = const Color(0xFFFFEBEE);
    } else {
      paidColor = const Color(0xFFEF6C00); // Orange
      paidBackground = const Color(0xFFFFF3E0);
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF004D40).withValues(alpha: 0.1), width: 1),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF004D40),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenantName,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.meeting_room_outlined,
                              color: Colors.grey,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Kamar $roomNum',
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: paidBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      displayStatus.toUpperCase(),
                      style: TextStyle(
                        color: paidColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatShortDate(dateStr),
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      if (item['bukti_transfer_url'] != null &&
                          item['bukti_transfer_url'].toString().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2F1), // Light teal background
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.image_outlined, size: 10, color: Color(0xFF00796B)),
                              SizedBox(width: 3),
                              Text(
                                'BUKTI',
                                style: TextStyle(
                                  color: Color(0xFF00796B),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _formatRupiah(amount),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
