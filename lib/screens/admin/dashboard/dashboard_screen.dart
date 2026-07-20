import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../kamar/kamar_list_screen.dart';
import '../buku_kas/buku_kas_screen.dart';
import '../profile/profile_screen.dart';
import '../transaksi/transaksi_list_screen.dart';
import '../../../services/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const primaryColor = Color(0xFF004D40);
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _profilAdmin = [];
  List<Map<String, dynamic>> _kamar = [];
  List<Map<String, dynamic>> _sewa = [];
  List<Map<String, dynamic>> _pemasukan = [];
  List<Map<String, dynamic>> _invoice = [];

  RealtimeChannel? _invoiceChannel;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final client = Supabase.instance.client;
    _invoiceChannel = client.channel('public:invoice').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'invoice',
      callback: (payload) {
        debugPrint('Realtime change detected in invoice table, refetching...');
        _fetchDashboardData();
      },
    ).subscribe();
  }

  @override
  void dispose() {
    if (_invoiceChannel != null) {
      Supabase.instance.client.removeChannel(_invoiceChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final client = Supabase.instance.client;
      final adminId = client.auth.currentUser?.id ?? '';

      // Standard HTTP select queries (no Realtime dependency)
      final results = await Future.wait([
        client.from('profil_admin').select().eq('id_admin', adminId),
        client.from('kamar').select().eq('id_admin', adminId),
        client.from('sewa').select(),
        client.from('pemasukan').select(),
        client.from('invoice').select(),
      ]);

      if (mounted) {
        setState(() {
          _profilAdmin = List<Map<String, dynamic>>.from(results[0]);
          _kamar = List<Map<String, dynamic>>.from(results[1]);
          _sewa = List<Map<String, dynamic>>.from(results[2]);
          _pemasukan = List<Map<String, dynamic>>.from(results[3]);
          _invoice = List<Map<String, dynamic>>.from(results[4]);
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
    final str = number.toString();
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

  // Helper to fetch details for invoices
  Future<Map<String, dynamic>> _getInvoiceDetails(int idSewa) async {
    try {
      final client = Supabase.instance.client;
      final sewaData = await client
          .from('sewa')
          .select('id_kamar, id_penyewa')
          .eq('id_sewa', idSewa)
          .maybeSingle();

      if (sewaData == null) return {};

      final kamarData = await client
          .from('kamar')
          .select('nomor_kamar')
          .eq('id_kamar', sewaData['id_kamar'])
          .maybeSingle();

      final penyewaData = await client
          .from('penyewa')
          .select('nama_lengkap, nik')
          .eq('id_penyewa', sewaData['id_penyewa'])
          .maybeSingle();

      String? fotoProfilUrl;
      if (penyewaData != null && penyewaData['nik'] != null) {
        final detailPenyewa = await client
            .from('detail_penyewa')
            .select('foto_profil_url')
            .eq('nik', penyewaData['nik'])
            .maybeSingle();
        fotoProfilUrl = detailPenyewa?['foto_profil_url'];
      }

      return {
        'nomor_kamar': kamarData?['nomor_kamar'] ?? '-',
        'nama_lengkap': penyewaData?['nama_lengkap'] ?? 'Penyewa',
        'foto_profil_url': fotoProfilUrl,
      };
    } catch (e) {
      return {};
    }
  }

  // Calculate remaining days for due date
  String _getRemainingDaysText(String? dateStr) {
    if (dateStr == null) return '';
    final dueDate = DateTime.tryParse(dateStr);
    if (dueDate == null) return '';
    final today = DateTime.now();
    final todayZero = DateTime(today.year, today.month, today.day);
    final dueZero = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final difference = dueZero.difference(todayZero).inDays;

    if (difference == 0) {
      return 'Jatuh tempo hari ini';
    } else if (difference > 0) {
      return '$difference hari lagi';
    } else {
      return 'Telat ${difference.abs()} hari';
    }
  }

  @override
  Widget build(BuildContext context) {
    // List of screens for BottomNavigationBar
    final List<Widget> screens = [
      _buildBeranda(context, primaryColor),
      const KamarListScreen(),
      const DaftarTransaksiScreen(),
      const BukuKasScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 0) {
            _fetchDashboardData();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bed_outlined),
            activeIcon: Icon(Icons.bed),
            label: 'Kamar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Transaksi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Buku',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // --- BERANDA PAGE ---
  Widget _buildBeranda(BuildContext context, Color primaryColor) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                'Gagal memuat Beranda:\n$_errorMessage',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: _fetchDashboardData,
                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    String adminName = user?.userMetadata?['nama_lengkap'] ?? 'Admin';
    String namaKos = user?.userMetadata?['nama_kos'] ?? 'KosKu';

    if (_profilAdmin.isNotEmpty) {
      final adminData = _profilAdmin.first;
      adminName = adminData['nama_lengkap'] ?? adminName;
      namaKos = adminData['nama_kost'] ?? namaKos;
    }

    try {
      // 1. Get room IDs owned by admin
      final adminRooms = _kamar;
      final adminRoomIds = adminRooms
          .map((r) => (r['id_kamar'] as num?)?.toInt())
          .whereType<int>()
          .toSet();

      // 2. Get sewa IDs for admin's rooms
      final allSewas = _sewa;
      final adminSewas = allSewas.where((s) {
        final idKamar = (s['id_kamar'] as num?)?.toInt();
        return idKamar != null && adminRoomIds.contains(idKamar);
      }).toList();
      final adminSewaIds = adminSewas
          .map((s) => (s['id_sewa'] as num?)?.toInt())
          .whereType<int>()
          .toSet();

      // 3. Get invoices for admin's sewas
      final allInvoices = _invoice;
      final adminInvoices = allInvoices.where((i) {
        final idSewa = (i['id_sewa'] as num?)?.toInt();
        return idSewa != null && adminSewaIds.contains(idSewa);
      }).toList();
      final adminInvoiceIds = adminInvoices
          .map((i) => (i['id_invoice'] as num?)?.toInt())
          .whereType<int>()
          .toSet();

      // 4. Get pemasukan for admin's invoices
      final allPemasukan = _pemasukan;
      final adminPemasukans = allPemasukan.where((p) {
        final idInvoice = (p['id_invoice'] as num?)?.toInt();
        return idInvoice != null && adminInvoiceIds.contains(idInvoice);
      }).toList();

      // Calculate Room Stats
      int terisiCount = 0;
      int kosongCount = 0;
      for (final kamar in adminRooms) {
        if (kamar['status_kamar'] == 'Terisi') {
          terisiCount++;
        } else if (kamar['status_kamar'] == 'Kosong') {
          kosongCount++;
        }
      }

      // Calculate Pemasukan Bulan Ini
      int totalPemasukan = 0;
      final now = DateTime.now();
      for (final pem in adminPemasukans) {
        final dateStr = pem['tanggal_bayar'];
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null && date.month == now.month && date.year == now.year) {
            totalPemasukan += (pem['nominal_masuk'] as num?)?.toInt() ?? 0;
          }
        }
      }

      // Calculate paid invoices count
      int paidRoomsCount = 0;
      for (final inv in adminInvoices) {
        final dateStr = inv['tanggal_dibuat'];
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null &&
              date.month == now.month &&
              date.year == now.year &&
              inv['status_pembayaran'] == 'Lunas') {
            paidRoomsCount++;
          }
        }
      }

      // Filter & Sort unpaid invoices for "Hampir Jatuh Tempo"
      List<Map<String, dynamic>> unpaidInvoices = adminInvoices
          .where((inv) => inv['status_pembayaran'] != 'Lunas')
          .toList();
      unpaidInvoices.sort((a, b) {
        final dateA = DateTime.tryParse(a['tanggal_jatuh_tempo'] ?? '') ?? DateTime(9999);
        final dateB = DateTime.tryParse(b['tanggal_jatuh_tempo'] ?? '') ?? DateTime(9999);
        return dateA.compareTo(dateB);
      });

      // Filter invoices for "Bukti Bayar Masuk" queue (status = 'Menunggu Verifikasi')
      List<Map<String, dynamic>> pendingInvoices = adminInvoices
          .where((inv) =>
              inv['status_pembayaran'] == 'Menunggu Verifikasi' &&
              inv['bukti_transfer_url'] != null &&
              inv['bukti_transfer_url'].toString().isNotEmpty)
          .toList();

      final totalRooms = terisiCount + kosongCount;

      return RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER & INCOME CARD STACK ---
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Header Dark Green Background
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 50, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hai, $adminName 👋',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    namaKos,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Notification Button
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/notifications');
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Income Card Box (Overlaying)
                  Positioned(
                    top: 170,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2A32B), // Accent Amber
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'PEMASUKAN BULAN INI',
                                style: TextStyle(
                                  color: Color(0xFF5D3600), // Dark Amber text
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Bulan Ini',
                                  style: TextStyle(
                                    color: Color(0xFF5D3600),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatRupiah(totalPemasukan),
                            style: const TextStyle(
                              color: Color(0xFF004D40), // Dark Green text
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 100), // Space for Positioned Card

              // --- STATISTIK KAMAR & PENDAPATAN ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Statistik Properti',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Card Terisi
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.meeting_room, color: Colors.green, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Terisi', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$terisiCount',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Card Kosong
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.meeting_room_outlined, color: Colors.orange, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Kosong', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$kosongCount',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Card Pembayaran Lunas (Full Width)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.task_alt_rounded, color: Color(0xFF00796B), size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Kamar Lunas Iuran Bulan Ini', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: totalRooms > 0 ? (paidRoomsCount / totalRooms) : 0,
                                    backgroundColor: Colors.grey[200],
                                    color: const Color(0xFF004D40),
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$paidRoomsCount dari $totalRooms Kamar',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- HAMPIR JATUH TEMPO SECTION ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Menunggu Pembayaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (unpaidInvoices.length > 5)
                      TextButton(
                        onPressed: () {
                          // Pindah ke tab transaksi
                          setState(() {
                            _currentIndex = 2;
                          });
                        },
                        child: const Text(
                          'Lihat Semua',
                          style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              if (unpaidInvoices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          'Tidak ada tagihan yang belum lunas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade100),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: unpaidInvoices.length > 5 ? 5 : unpaidInvoices.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final invoice = unpaidInvoices[index];
                        final idSewa = (invoice['id_sewa'] as num?)?.toInt() ?? 0;
                        final totalTagihan = invoice['total_tagihan'] as num? ?? 0;
                        final remainingText = _getRemainingDaysText(invoice['tanggal_jatuh_tempo']);
                        final isTelat = remainingText.contains('Telat');

                        return FutureBuilder<Map<String, dynamic>>(
                          future: _getInvoiceDetails(idSewa),
                          builder: (context, detailSnapshot) {
                            final data = detailSnapshot.data ?? {};
                            final namaLengkap = data['nama_lengkap'] ?? 'Loading...';
                            final nomorKamar = data['nomor_kamar'] ?? '-';
                            final initial = namaLengkap.isNotEmpty ? namaLengkap[0].toUpperCase() : 'P';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.grey[200],
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                namaLengkap,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                'Kamar $nomorKamar • $remainingText',
                                style: TextStyle(
                                  color: isTelat ? Colors.redAccent : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatRupiah(totalTagihan),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Builder(
                                    builder: (context) {
                                      final String statusPembayaran = invoice['status_pembayaran'] ?? 'Belum Bayar';
                                      final bool isMenungguVerifikasi = statusPembayaran == 'Menunggu Verifikasi';

                                      Color badgeBgColor;
                                      Color badgeTextColor;
                                      String badgeLabel;

                                      if (isMenungguVerifikasi) {
                                        badgeBgColor = const Color(0xFFFFF3E0);
                                        badgeTextColor = const Color(0xFFE65100);
                                        badgeLabel = 'Menunggu';
                                      } else if (isTelat) {
                                        badgeBgColor = const Color(0xFFFFEBEE);
                                        badgeTextColor = const Color(0xFFC62828);
                                        badgeLabel = 'Telat';
                                      } else {
                                        badgeBgColor = const Color(0xFFFFEBEE);
                                        badgeTextColor = const Color(0xFFC62828);
                                        badgeLabel = 'Belum Bayar';
                                      }

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeBgColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          badgeLabel,
                                          style: TextStyle(
                                            color: badgeTextColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // --- BUKTI BAYAR MASUK SECTION ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bukti Bayar Masuk',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (pendingInvoices.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA834),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${pendingInvoices.length} PERLU DICEK',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              if (pendingInvoices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          'Tidak ada bukti bayar masuk yang perlu diverifikasi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: pendingInvoices.length,
                    itemBuilder: (context, index) {
                      final invoice = pendingInvoices[index];
                      final idSewa = invoice['id_sewa'] as int;
                      final totalTagihan = invoice['total_tagihan'] as num;

                      return FutureBuilder<Map<String, dynamic>>(
                        future: _getInvoiceDetails(idSewa),
                        builder: (context, detailSnapshot) {
                          final data = detailSnapshot.data ?? {};
                          final namaLengkap = data['nama_lengkap'] ?? 'Loading...';
                          final nomorKamar = data['nomor_kamar'] ?? '-';
                          final fotoProfilUrl = data['foto_profil_url'];

                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade100),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  // Tenant Avatar
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.grey[200],
                                      image: fotoProfilUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(fotoProfilUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: fotoProfilUrl == null
                                        ? Icon(Icons.person, color: Colors.grey[400])
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          namaLengkap,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Kamar $nomorKamar • ${_formatRupiah(totalTagihan)}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Button "Lihat Bukti"
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFA834),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                                    label: const Text(
                                      'Lihat Bukti',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      _showBuktiTransferDialog(context, invoice, namaLengkap, nomorKamar);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Crash in DashboardScreen build: $e\n$stackTrace');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Terjadi kesalahan render: $e', style: const TextStyle(color: Colors.red)),
        ),
      );
    }
  }

  void _showBuktiTransferDialog(
    BuildContext context,
    Map<String, dynamic> invoice,
    String namaLengkap,
    String nomorKamar,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        bool isDialogProcessing = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final String? buktiUrl = invoice['bukti_transfer_url'];
            final num totalTagihan = invoice['total_tagihan'] as num? ?? 0;
            final String nomorInvoice = invoice['nomor_invoice'] ?? '-';

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Verifikasi Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tenant and Room Info
                    Text(
                      'Nama Penyewa: $namaLengkap',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nomor Kamar: Kamar $nomorKamar',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nomor Invoice: $nomorInvoice',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Tagihan: ${_formatRupiah(totalTagihan)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor),
                    ),
                    const SizedBox(height: 16),

                    // Proof of Transfer Image Card
                    const Text(
                      'Gambar Bukti Transfer:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: buktiUrl != null && buktiUrl.isNotEmpty
                            ? InteractiveViewer(
                                child: Image.network(
                                  buktiUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Center(
                                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                  ),
                                ),
                              )
                            : const Center(
                                child: Text('Bukti transfer tidak tersedia', style: TextStyle(color: Colors.grey)),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              actions: isDialogProcessing
                  ? [
                      Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      )
                    ]
                  : [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                setDialogState(() => isDialogProcessing = true);
                                await _tolakPembayaran(invoice);
                                if (context.mounted) Navigator.pop(context);
                              },
                              child: const Text(
                                'TOLAK',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                setDialogState(() => isDialogProcessing = true);
                                await _konfirmasiLunas(invoice);
                                if (context.mounted) Navigator.pop(context);
                              },
                              child: const Text(
                                'SETUJUI',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  Future<void> _konfirmasiLunas(Map<String, dynamic> inv) async {
    try {
      final client = Supabase.instance.client;
      final today = DateTime.now().toIso8601String().split('T').first;

      // 1. Update invoice status to 'Lunas'
      await client
          .from('invoice')
          .update({'status_pembayaran': 'Lunas'})
          .eq('id_invoice', inv['id_invoice']);

      // 2. Insert to public.pemasukan
      await client.from('pemasukan').insert({
        'id_invoice': inv['id_invoice'],
        'tanggal_bayar': today,
        'nominal_masuk': inv['total_tagihan'] ?? inv['biaya_sewa_pokok'] ?? 0,
        'metode_bayar': 'Transfer Bank',
        'catatan': 'Pembayaran Invoice ${inv['nomor_invoice']}',
      });

      // 3. Kirim Notifikasi (Admin -> User)
      try {
        final String? userPenyewaId = await NotificationService.getPenyewaUserId(inv['id_sewa']);
        if (userPenyewaId != null) {
          final total = inv['total_tagihan'] ?? inv['biaya_sewa_pokok'] ?? 0;
          final formattedNominal = _formatRupiah(total);

          await NotificationService.sendNotification(
            idUser: userPenyewaId,
            judul: 'Pembayaran Terkonfirmasi 🎉',
            pesan: 'Pembayaran tagihan sebesar $formattedNominal Anda telah dikonfirmasi dan dinyatakan LUNAS. Terima kasih!',
            kategori: 'penyewa',
          );
        }
      } catch (e) {
        debugPrint('Gagal mengirim notifikasi konfirmasi lunas: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil disetujui!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _fetchDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal konfirmasi pembayaran: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _tolakPembayaran(Map<String, dynamic> inv) async {
    try {
      final client = Supabase.instance.client;

      // 1. Update invoice status to 'Belum Bayar' and clear bukti_transfer_url
      await client
          .from('invoice')
          .update({
            'status_pembayaran': 'Belum Bayar',
            'bukti_transfer_url': null,
          })
          .eq('id_invoice', inv['id_invoice']);

      // 2. Kirim Notifikasi Penolakan (Admin -> User)
      try {
        final String? userPenyewaId = await NotificationService.getPenyewaUserId(inv['id_sewa']);
        if (userPenyewaId != null) {
          final total = inv['total_tagihan'] ?? inv['biaya_sewa_pokok'] ?? 0;
          final formattedNominal = _formatRupiah(total);

          await NotificationService.sendNotification(
            idUser: userPenyewaId,
            judul: 'Pembayaran Ditolak ❌',
            pesan: 'Pembayaran tagihan sebesar $formattedNominal ditolak oleh Admin. Silakan periksa kembali bukti transfer Anda dan unggah ulang.',
            kategori: 'penyewa',
          );
        }
      } catch (e) {
        debugPrint('Gagal mengirim notifikasi penolakan: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil ditolak.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _fetchDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menolak pembayaran: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
