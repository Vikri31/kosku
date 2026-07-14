import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../kamar/kamar_list_screen.dart';
import '../buku_kas/buku_kas_screen.dart';
import '../profile/profile_screen.dart';
import '../transaksi/transaksi_list_screen.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

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
      final sewaData = await Supabase.instance.client
          .from('sewa')
          .select('id_kamar, id_penyewa')
          .eq('id_sewa', idSewa)
          .maybeSingle();

      if (sewaData == null) return {};

      final kamarData = await Supabase.instance.client
          .from('kamar')
          .select('nomor_kamar')
          .eq('id_kamar', sewaData['id_kamar'])
          .maybeSingle();

      final penyewaData = await Supabase.instance.client
          .from('penyewa')
          .select('nama_lengkap')
          .eq('id_penyewa', sewaData['id_penyewa'])
          .maybeSingle();

      return {
        'nomor_kamar': kamarData?['nomor_kamar'] ?? '-',
        'nama_lengkap': penyewaData?['nama_lengkap'] ?? 'Penyewa',
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
    const primaryColor = Color(0xFF004D40);

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
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final adminId = user?.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: client
          .from('profil_admin')
          .stream(primaryKey: ['id_admin'])
          .eq('id_admin', adminId ?? ''),
      builder: (context, adminSnapshot) {
        String adminName = user?.userMetadata?['nama_lengkap'] ?? 'Admin';
        String namaKos = user?.userMetadata?['nama_kos'] ?? 'KosKu';

        if (adminSnapshot.hasData && adminSnapshot.data!.isNotEmpty) {
          final adminData = adminSnapshot.data!.first;
          adminName = adminData['nama_lengkap'] ?? adminName;
          namaKos = adminData['nama_kost'] ?? namaKos;
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: client
              .from('kamar')
              .stream(primaryKey: ['id_kamar'])
              .eq('id_admin', adminId ?? ''),
      builder: (context, kamarSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: client.from('sewa').stream(primaryKey: ['id_sewa']),
          builder: (context, sewaSnapshot) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: client.from('pemasukan').stream(primaryKey: ['id_pemasukan']),
              builder: (context, pemasukanSnapshot) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: client.from('invoice').stream(primaryKey: ['id_invoice']),
                  builder: (context, invoiceSnapshot) {
                    // Check loading
                    if (kamarSnapshot.connectionState == ConnectionState.waiting ||
                        sewaSnapshot.connectionState == ConnectionState.waiting ||
                        pemasukanSnapshot.connectionState == ConnectionState.waiting ||
                        invoiceSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: primaryColor));
                    }

                    // 1. Get room IDs owned by admin
                    final adminRooms = kamarSnapshot.data ?? [];
                    final adminRoomIds = adminRooms.map((r) => r['id_kamar'] as int).toSet();

                    // 2. Get sewa IDs for admin's rooms
                    final allSewas = sewaSnapshot.data ?? [];
                    final adminSewas = allSewas.where((s) => adminRoomIds.contains(s['id_kamar'] as int)).toList();
                    final adminSewaIds = adminSewas.map((s) => s['id_sewa'] as int).toSet();

                    // 3. Get invoices for admin's sewas
                    final allInvoices = invoiceSnapshot.data ?? [];
                    final adminInvoices = allInvoices.where((i) => adminSewaIds.contains(i['id_sewa'] as int)).toList();
                    final adminInvoiceIds = adminInvoices.map((i) => i['id_invoice'] as int).toSet();

                    // 4. Get pemasukan for admin's invoices
                    final allPemasukan = pemasukanSnapshot.data ?? [];
                    final adminPemasukans = allPemasukan.where((p) => adminInvoiceIds.contains(p['id_invoice'] as int)).toList();

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
                          totalPemasukan += (pem['nominal_masuk'] as num).toInt();
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

                    final totalRooms = terisiCount + kosongCount;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
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
                                        const Text(
                                          'KosKu',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                Navigator.pushNamed(context, '/notifications');
                                              },
                                              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Halo, $adminName 👋',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      namaKos,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Income Card (Overlapping)
                              Positioned(
                                top: 170,
                                left: 20,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFA834),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'PEMASUKAN BULAN INI',
                                              style: TextStyle(
                                                color: Color(0xFF8D5300),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _formatRupiah(totalPemasukan),
                                              style: const TextStyle(
                                                color: Color(0xFF5D3600),
                                                fontSize: 26,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.check_circle_outline,
                                                  size: 14,
                                                  color: Color(0xFF8D5300),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$paidRoomsCount dari $totalRooms kamar telah bayar',
                                                  style: const TextStyle(
                                                    color: Color(0xFF8D5300),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0x26000000),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(
                                          Icons.trending_up_rounded,
                                          color: Color(0xFF5D3600),
                                          size: 30,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 100),

                          // --- ROOM SUMMARY CARDS ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Row(
                              children: [
                                // Terisi Card
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE0F2F1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.king_bed_outlined,
                                                color: Color(0xFF00796B),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE0F2F1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'TERISI',
                                                style: TextStyle(
                                                  color: Color(0xFF00796B),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          '$terisiCount',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const Text(
                                          'Kamar',
                                          style: TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Kosong Card
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFEBEE),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.meeting_room_outlined,
                                                color: Color(0xFFC62828),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFEBEE),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'KOSONG',
                                                style: TextStyle(
                                                  color: Color(0xFFC62828),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          '$kosongCount',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const Text(
                                          'Kamar',
                                          style: TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ],
                                    ),
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
                                  'Hampir Jatuh Tempo',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {},
                                  child: const Text(
                                    'Lihat Semua',
                                    style: TextStyle(color: Color(0xFF00796B), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // List Items of Due Invoices
                          if (unpaidInvoices.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24.0),
                                child: Text(
                                  'Tidak ada tagihan yang belum lunas.',
                                  style: TextStyle(color: Colors.grey),
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
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: unpaidInvoices.length > 5 ? 5 : unpaidInvoices.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final invoice = unpaidInvoices[index];
                                    final idSewa = invoice['id_sewa'] as int;
                                    final totalTagihan = invoice['total_tagihan'] as num;
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
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isTelat ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isTelat ? 'Telat' : 'Menunggu',
                                                  style: TextStyle(
                                                    color: isTelat ? const Color(0xFFC62828) : const Color(0xFFE65100),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
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
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
      },
    );
  }

}
