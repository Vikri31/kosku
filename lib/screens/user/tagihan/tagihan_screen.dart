import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/dashboard_penghuni_screen.dart';
import 'detail_tagihan_screen.dart';

class TagihanScreen extends StatefulWidget {
  const TagihanScreen({super.key});

  static const Color _primaryColor = Color(0xFF007461);
  static const Color _backgroundColor = Color(0xFFF4F6F7);
  static const Color _dangerColor = Color(0xFFFF3B30);

  @override
  State<TagihanScreen> createState() => _TagihanScreenState();
}

class _TagihanScreenState extends State<TagihanScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _allInvoices = [];
  List<Map<String, dynamic>> _filteredInvoices = [];

  String _totalPaidStr = 'Rp 0';
  String _totalUnpaidStr = 'Rp 0';
  String _activeFilter = 'Semua';
  bool _isDataLengkap = true;
  bool _hasActiveSewa = true;

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("Pengguna tidak masuk.");
      }

      // 1. Dapatkan detail_penyewa
      final detailPenyewa = await supabase
          .from('detail_penyewa')
          .select()
          .eq('id_user', user.id)
          .maybeSingle();

      if (detailPenyewa == null) {
        setState(() {
          _isDataLengkap = false;
          _hasActiveSewa = false;
          _allInvoices = [];
          _filteredInvoices = [];
          _totalPaidStr = 'Rp 0';
          _totalUnpaidStr = 'Rp 0';
          _isLoading = false;
        });
        return;
      }

      final String nik = detailPenyewa['nik'];

      // 2. Dapatkan data penyewa
      final penyewa = await supabase
          .from('penyewa')
          .select()
          .eq('nik', nik)
          .maybeSingle();

      if (penyewa == null) {
        setState(() {
          _isDataLengkap = false;
          _hasActiveSewa = false;
          _allInvoices = [];
          _filteredInvoices = [];
          _totalPaidStr = 'Rp 0';
          _totalUnpaidStr = 'Rp 0';
          _isLoading = false;
        });
        return;
      }

      final int idPenyewa = penyewa['id_penyewa'];

      // 3. Dapatkan semua sewa (aktif, selesai, dll.)
      final List<dynamic> sewaResponse = await supabase
          .from('sewa')
          .select()
          .eq('id_penyewa', idPenyewa);

      if (sewaResponse.isEmpty) {
        setState(() {
          _isDataLengkap = true;
          _hasActiveSewa = false;
          _allInvoices = [];
          _filteredInvoices = [];
          _totalPaidStr = 'Rp 0';
          _totalUnpaidStr = 'Rp 0';
          _isLoading = false;
        });
        return;
      }

      final bool hasActiveSewa = sewaResponse.any((s) => s['status_sewa'] == 'Aktif');
      final List<int> idSewaList = sewaResponse.map<int>((s) => s['id_sewa'] as int).toList();

      // 4. Ambil semua invoice
      final List<dynamic> response = await supabase
          .from('invoice')
          .select()
          .inFilter('id_sewa', idSewaList)
          .order('tanggal_dibuat', ascending: false);

      final List<Map<String, dynamic>> invoices = List<Map<String, dynamic>>.from(response);

      int totalPaid = 0;
      int totalUnpaid = 0;

      for (var inv in invoices) {
        final int amount = inv['total_tagihan'] != null
            ? int.parse(inv['total_tagihan'].toString())
            : 0;
        if (inv['status_pembayaran']?.toString().toUpperCase() == 'LUNAS') {
          totalPaid += amount;
        } else {
          totalUnpaid += amount;
        }
      }

      if (mounted) {
        setState(() {
          _isDataLengkap = true;
          _hasActiveSewa = hasActiveSewa;
          _allInvoices = invoices;
          _totalPaidStr = _formatRupiah(totalPaid);
          _totalUnpaidStr = _formatRupiah(totalUnpaid);
          _applyFilter(_activeFilter);
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _activeFilter = filter;
      if (filter == 'Semua') {
        _filteredInvoices = _allInvoices;
      } else if (filter == 'Lunas') {
        _filteredInvoices = _allInvoices.where((inv) => inv['status_pembayaran']?.toString().toUpperCase() == 'LUNAS').toList();
      } else {
        _filteredInvoices = _allInvoices.where((inv) => inv['status_pembayaran']?.toString().toUpperCase() != 'LUNAS').toList();
      }
    });
  }

  String _formatRupiah(dynamic amount) {
    if (amount == null) return 'Rp 0';
    final int val = amount is int ? amount : int.parse(amount.toString());
    final str = val.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return "Rp ${buffer.toString().split('').reversed.join('')}";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: TagihanScreen._backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: TagihanScreen._primaryColor),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: TagihanScreen._backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: TagihanScreen._dangerColor, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchInvoices,
                  style: ElevatedButton.styleFrom(backgroundColor: TagihanScreen._primaryColor),
                  child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: TagihanScreen._backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: TagihanScreen._primaryColor,
        elevation: 0,
        toolbarHeight: 54,
        centerTitle: true,
        title: const Text(
          'KosKu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tagihan Saya',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Riwayat pembayaran sewa kamar Anda',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SummaryCard(
                      label: 'Dibayar',
                      amount: _totalPaidStr,
                      color: TagihanScreen._primaryColor,
                      icon: Icons.check_circle,
                    ),
                    const SizedBox(height: 12),
                    _SummaryCard(
                      label: 'Belum Bayar',
                      amount: _totalUnpaidStr,
                      color: TagihanScreen._dangerColor,
                      icon: Icons.cancel,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _FilterChip(
                          label: 'Semua',
                          selected: _activeFilter == 'Semua',
                          onTap: () => _applyFilter('Semua'),
                        ),
                        const SizedBox(width: 10),
                        _FilterChip(
                          label: 'Lunas',
                          selected: _activeFilter == 'Lunas',
                          onTap: () => _applyFilter('Lunas'),
                        ),
                        const SizedBox(width: 10),
                        _FilterChip(
                          label: 'Belum Lunas',
                          selected: _activeFilter == 'Belum Lunas',
                          onTap: () => _applyFilter('Belum Lunas'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_filteredInvoices.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            !_isDataLengkap
                                ? 'Data diri Anda belum lengkap.\nSilakan lengkapi data diri Anda di menu Profil.'
                                : !_hasActiveSewa
                                    ? 'Anda belum terdaftar di kamar aktif manapun.\nHubungi pemilik kos untuk menyewa kamar.'
                                    : 'Tidak ada tagihan.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
                          ),
                        ),
                      )
                    else
                      for (final invoice in _filteredInvoices) ...[
                        _BillTile(
                          invoice: invoice,
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DetailTagihanScreen(invoice: invoice),
                              ),
                            );
                            if (result == true) {
                              _fetchInvoices();
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
            const PenghuniBottomNav(currentIndex: 1),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  amount,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? TagihanScreen._primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? TagihanScreen._primaryColor
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF6B7280),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.invoice, required this.onTap});

  final Map<String, dynamic> invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isPaid = invoice['status_pembayaran']?.toString().toUpperCase() == 'LUNAS';
    final accentColor = isPaid
        ? TagihanScreen._primaryColor
        : const Color(0xFFF1B64C);

    final String title = _getBulanSewa(invoice['tanggal_dibuat']);
    final String dateStr = isPaid
        ? "Dibayar: ${_formatTanggal(invoice['tanggal_dibuat'])}"
        : "Jatuh tempo: ${_formatTanggal(invoice['tanggal_jatuh_tempo'])}";
    final String amountStr = _formatRupiah(invoice['total_tagihan']);
    final String statusLabel = invoice['status_pembayaran'] ?? 'BELUM';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 13, 10, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPaid
                      ? Icons.calendar_month_outlined
                      : Icons.error_outline,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1F2933),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StatusBadge(label: statusLabel, isPaid: isPaid),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amountStr,
                      style: const TextStyle(
                        color: TagihanScreen._primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFCAD2D7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRupiah(dynamic amount) {
    if (amount == null) return 'Rp 0';
    final int val = amount is int ? amount : int.parse(amount.toString());
    final str = val.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return "Rp ${buffer.toString().split('').reversed.join('')}";
  }

  String _getShortBulan(int month) {
    const listBulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    if (month >= 1 && month <= 12) {
      return listBulan[month - 1];
    }
    return '';
  }

  String _formatTanggal(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day} ${_getShortBulan(date.month)} ${date.year}";
    } catch (_) {
      return dateStr;
    }
  }

  String _getNamaBulan(int month) {
    const listBulan = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    if (month >= 1 && month <= 12) {
      return listBulan[month - 1];
    }
    return '';
  }

  String _getBulanSewa(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return "Sewa ${_getNamaBulan(date.month)} ${date.year}";
    } catch (_) {
      return '';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.isPaid});

  final String label;
  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final color = isPaid
        ? TagihanScreen._primaryColor
        : TagihanScreen._dangerColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

