import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'form_pengeluaran_screen.dart';
import 'detail_pengeluaran_screen.dart';

class BukuKasScreen extends StatefulWidget {
  const BukuKasScreen({super.key});

  @override
  State<BukuKasScreen> createState() => _BukuKasScreenState();
}

class _BukuKasScreenState extends State<BukuKasScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _kamar = [];
  List<Map<String, dynamic>> _sewa = [];
  List<Map<String, dynamic>> _invoice = [];
  List<Map<String, dynamic>> _pemasukan = [];
  List<Map<String, dynamic>> _pengeluaran = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final client = Supabase.instance.client;
      final adminId = client.auth.currentUser?.id ?? '';

      // Standard HTTP select queries (RLS compliant, no Realtime server dependency)
      final results = await Future.wait([
        client.from('kamar').select().eq('id_admin', adminId),
        client.from('sewa').select(),
        client.from('invoice').select(),
        client.from('pemasukan').select(),
        client.from('pengeluaran').select().eq('id_admin', adminId),
      ]);

      if (mounted) {
        setState(() {
          _kamar = List<Map<String, dynamic>>.from(results[0]);
          _sewa = List<Map<String, dynamic>>.from(results[1]);
          _invoice = List<Map<String, dynamic>>.from(results[2]);
          _pemasukan = List<Map<String, dynamic>>.from(results[3]);
          _pengeluaran = List<Map<String, dynamic>>.from(results[4]);
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

  // Custom Rupiah Formatter
  String _formatRupiah(num number) {
    final isNegative = number < 0;
    final absNumber = number.abs();
    final str = absNumber.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    final formatted = 'Rp ${buffer.toString().split('').reversed.join('')}';
    return isNegative ? '- $formatted' : formatted;
  }

  // Indonesian Date Formatter
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dateTime = DateTime.parse(dateStr);
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    } catch (_) {
      return dateStr;
    }
  }

  // Icon selector based on category
  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('listrik')) {
      return Icons.flash_on_rounded;
    } else if (cat.contains('air')) {
      return Icons.water_drop_rounded;
    } else if (cat.contains('kebersihan')) {
      return Icons.cleaning_services_rounded;
    } else if (cat.contains('keamanan')) {
      return Icons.security_rounded;
    } else if (cat.contains('perbaikan') || cat.contains('perawat')) {
      return Icons.build_rounded;
    } else if (cat.contains('internet') || cat.contains('wifi')) {
      return Icons.wifi_rounded;
    } else {
      return Icons.payments_rounded;
    }
  }

  // Color selector based on category
  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('listrik')) {
      return const Color(0xFFFFB300);
    } else if (cat.contains('air')) {
      return const Color(0xFF1E88E5);
    } else if (cat.contains('kebersihan')) {
      return const Color(0xFF43A047);
    } else if (cat.contains('keamanan')) {
      return const Color(0xFFE53935);
    } else if (cat.contains('perbaikan') || cat.contains('perawat')) {
      return const Color(0xFF8E24AA);
    } else {
      return const Color(0xFF004D40);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF004D40);
    const accentColor = Color(0xFFF2A32B);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text(
          'Buku Kas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Gagal memuat Buku Kas:\n$_errorMessage',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                          onPressed: _fetchData,
                          child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildMainContent(primaryColor, accentColor),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FormPengeluaranScreen(),
            ),
          );
          _fetchData(); // reload!
        },
        backgroundColor: accentColor,
        foregroundColor: const Color(0xFF5D3600),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildMainContent(Color primaryColor, Color accentColor) {
    try {
      // 1. Get room IDs owned by admin
      final adminRoomIds = _kamar
          .map((r) => (r['id_kamar'] as num?)?.toInt())
          .whereType<int>()
          .toSet();

      // 2. Get sewa IDs for admin's rooms
      final adminSewas = _sewa.where((s) {
        final idKamar = (s['id_kamar'] as num?)?.toInt();
        return idKamar != null && adminRoomIds.contains(idKamar);
      }).toList();
      final adminSewaIds = adminSewas
          .map((s) => (s['id_sewa'] as num?)?.toInt())
          .whereType<int>()
          .toSet();

      // 3. Get invoices for admin's sewas
      final adminInvoices = _invoice.where((i) {
        final idSewa = (i['id_sewa'] as num?)?.toInt();
        return idSewa != null && adminSewaIds.contains(idSewa);
      }).toList();
      final adminInvoiceIds = adminInvoices
          .map((i) => (i['id_invoice'] as num?)?.toInt())
          .whereType<int>()
          .toSet();

      // 4. Get pemasukan for admin's invoices
      final adminPemasukans = _pemasukan.where((p) {
        final idInvoice = (p['id_invoice'] as num?)?.toInt();
        return idInvoice != null && adminInvoiceIds.contains(idInvoice);
      }).toList();

      // Kalkulasi Pemasukan
      int totalPemasukan = 0;
      for (final row in adminPemasukans) {
        totalPemasukan += (row['nominal_masuk'] as num?)?.toInt() ?? 0;
      }

      // Kalkulasi Pengeluaran
      int totalPengeluaran = 0;
      for (final row in _pengeluaran) {
        totalPengeluaran += (row['nominal_keluar'] as num?)?.toInt() ?? 0;
      }

      // Kalkulasi Saldo Bersih
      final saldoBersih = totalPemasukan - totalPengeluaran;

      // Sorting data pengeluaran berdasarkan tanggal_keluar terbaru secara kronologis
      final listPengeluaran = List<Map<String, dynamic>>.from(_pengeluaran);
      listPengeluaran.sort((a, b) {
        final dateA = DateTime.tryParse(a['tanggal_keluar'] ?? '') ?? DateTime(0);
        final dateB = DateTime.tryParse(b['tanggal_keluar'] ?? '') ?? DateTime(0);
        return dateB.compareTo(dateA);
      });

      return RefreshIndicator(
        onRefresh: _fetchData,
        color: primaryColor,
        child: Column(
          children: [
            // --- AREA RINGKASAN FINANSIAL (ATAS) ---
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Saldo Bersih
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SALDO BERSIH',
                          style: TextStyle(
                            color: Color(0xFF5D3600),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatRupiah(saldoBersih),
                          style: TextStyle(
                            color: saldoBersih >= 0
                                ? const Color(0xFF004D40)
                                : const Color(0xFFB71C1C),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Row Ringkasan Pemasukan & Pengeluaran
                  Row(
                    children: [
                      // Card Pemasukan
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    color: Colors.greenAccent,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Pemasukan',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatRupiah(totalPemasukan),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Card Pengeluaran
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.arrow_upward_rounded,
                                    color: Colors.redAccent,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Pengeluaran',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatRupiah(totalPengeluaran),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- DAFTAR HISTORI PENGELUARAN (BAWAH) ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Histori Pengeluaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: listPengeluaran.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 100),
                                Center(
                                  child: Text(
                                    'Belum ada catatan pengeluaran.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: listPengeluaran.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = listPengeluaran[index];
                                final idPengeluaran =
                                    (item['id_pengeluaran'] as num?)?.toInt() ?? 0;
                                final kategori =
                                    item['kategori'] ?? 'Lainnya';
                                final deskripsi = item['deskripsi'] ?? '';
                                final tgl = item['tanggal_keluar'];
                                final nominal =
                                    (item['nominal_keluar'] as num?)?.toInt() ?? 0;

                                return GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DetailPengeluaranScreen(
                                          idPengeluaran: idPengeluaran,
                                        ),
                                        settings: RouteSettings(
                                          arguments: idPengeluaran,
                                        ),
                                      ),
                                    );
                                    _fetchData(); // reload!
                                  },
                                  child: Card(
                                    margin: EdgeInsets.zero,
                                    color: Colors.white,
                                    elevation: 2,
                                    shadowColor:
                                        Colors.black.withValues(alpha: 0.04),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          // Category Icon Box
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: _getCategoryColor(
                                                      kategori)
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              _getCategoryIcon(kategori),
                                              color: _getCategoryColor(
                                                  kategori),
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          // Content Text
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  kategori,
                                                  style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 15,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  deskripsi.isNotEmpty
                                                      ? deskripsi
                                                      : 'Tanpa deskripsi',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatDate(tgl),
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Nominal (Negative style)
                                          Text(
                                            '- ${_formatRupiah(nominal)}',
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Crash in BukuKasScreen build: $e\n$stackTrace');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Terjadi kesalahan render: $e', style: const TextStyle(color: Colors.red)),
        ),
      );
    }
  }
}
