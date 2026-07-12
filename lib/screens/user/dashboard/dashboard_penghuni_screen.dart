import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../tagihan/tagihan_screen.dart';
import '../profil/profil_penghuni_screen.dart';

// ── Warna tema KosKu ────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF1A7C6A);
const Color _kBg = Color(0xFFF4F6F7);
const Color _kDanger = Color(0xFFFF3B30);
const Color _kAmber = Color(0xFFF1B64C);

// ═══════════════════════════════════════════════════════════════════════════
// Dashboard Penghuni
// ═══════════════════════════════════════════════════════════════════════════
class DashboardPenghuniScreen extends StatefulWidget {
  const DashboardPenghuniScreen({super.key});

  @override
  State<DashboardPenghuniScreen> createState() =>
      _DashboardPenghuniScreenState();
}

class _DashboardPenghuniScreenState extends State<DashboardPenghuniScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  String _namaPenghuni = '-';
  String _namaKos = 'Memuat kos...';
  String _nomorKamar = '-';
  String _tanggalMasuk = '-';
  String _jatuhTempo = '-';
  String _sisaHari = '-';
  bool _dekatJatuhTempo = false;
  String _nominalTagihan = '-';
  String _statusTagihan = 'BELUM';
  String _namaPemilik = '-';
  String _noPemilik = '';
  List<Map<String, dynamic>> _tagihan = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
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

      // 1. Dapatkan detail_penyewa berdasarkan id_user
      final detailPenyewa = await supabase
          .from('detail_penyewa')
          .select()
          .eq('id_user', user.id)
          .maybeSingle();

      if (detailPenyewa == null) {
        setState(() {
          _namaPenghuni =
              user.userMetadata?['nama_lengkap'] ??
              user.email?.split('@').first ??
              'Penghuni';
          _namaKos = 'Belum terikat kamar';
          _nomorKamar = '-';
          _tanggalMasuk = '-';
          _jatuhTempo = '-';
          _sisaHari = '-';
          _dekatJatuhTempo = false;
          _nominalTagihan = '-';
          _statusTagihan = 'BELUM';
          _namaPemilik = '-';
          _noPemilik = '';
          _tagihan = [];
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
          _namaPenghuni =
              user.userMetadata?['nama_lengkap'] ??
              user.email?.split('@').first ??
              'Penghuni';
          _namaKos = 'Belum terikat kamar';
          _nomorKamar = '-';
          _tanggalMasuk = '-';
          _jatuhTempo = '-';
          _sisaHari = '-';
          _dekatJatuhTempo = false;
          _nominalTagihan = '-';
          _statusTagihan = 'BELUM';
          _namaPemilik = '-';
          _noPemilik = '';
          _tagihan = [];
          _isLoading = false;
        });
        return;
      }

      final String namaLengkap = penyewa['nama_lengkap'] ?? '-';
      final int idPenyewa = penyewa['id_penyewa'];

      // 3. Dapatkan data sewa aktif
      final sewa = await supabase
          .from('sewa')
          .select()
          .eq('id_penyewa', idPenyewa)
          .eq('status_sewa', 'Aktif')
          .maybeSingle();

      if (sewa == null) {
        setState(() {
          _namaPenghuni = namaLengkap;
          _namaKos = 'Belum terikat kamar';
          _nomorKamar = '-';
          _tanggalMasuk = '-';
          _jatuhTempo = '-';
          _sisaHari = '-';
          _dekatJatuhTempo = false;
          _nominalTagihan = '-';
          _statusTagihan = 'BELUM';
          _namaPemilik = '-';
          _noPemilik = '';
          _tagihan = [];
          _isLoading = false;
        });
        return;
      }

      final int idKamar = sewa['id_kamar'];
      final int idSewa = sewa['id_sewa'];
      final String tglMasukRaw = sewa['tanggal_masuk'] ?? '';

      String formattedTglMasuk = tglMasukRaw;
      try {
        final parsedDate = DateTime.parse(tglMasukRaw);
        formattedTglMasuk =
            "${parsedDate.day} ${_getNamaBulan(parsedDate.month)} ${parsedDate.year}";
      } catch (_) {}

      // 4. Dapatkan data kamar
      final kamar = await supabase
          .from('kamar')
          .select()
          .eq('id_kamar', idKamar)
          .maybeSingle();

      if (kamar == null) {
        setState(() {
          _namaPenghuni = namaLengkap;
          _namaKos = 'Kamar tidak ditemukan';
          _nomorKamar = '-';
          _tanggalMasuk = '-';
          _jatuhTempo = '-';
          _sisaHari = '-';
          _dekatJatuhTempo = false;
          _nominalTagihan = '-';
          _statusTagihan = 'BELUM';
          _namaPemilik = '-';
          _noPemilik = '';
          _tagihan = [];
          _isLoading = false;
        });
        return;
      }

      final String nomorKamar = kamar['nomor_kamar'] ?? '-';
      final String? idAdmin = kamar['id_admin'];

      // 5. Dapatkan data admin (pemilik kos) jika ada
      String namaPemilik = '-';
      String namaKos = 'Kosku';
      String noPemilik = '';
      if (idAdmin != null) {
        final admin = await supabase
            .from('profil_admin')
            .select()
            .eq('id_admin', idAdmin)
            .maybeSingle();

        if (admin != null) {
          namaPemilik = admin['nama_lengkap'] ?? '-';
          namaKos = admin['nama_kost'] ?? 'Kosku';
          noPemilik = admin['nomor_wa'] ?? '';
        }
      }

      // 6. Dapatkan tagihan/invoice penyewa
      final invoices = await supabase
          .from('invoice')
          .select()
          .eq('id_sewa', idSewa)
          .order('tanggal_dibuat', ascending: false);

      List<Map<String, dynamic>> mappedTagihan = [];
      String nominalTagihanActive = '-';
      String statusTagihanActive = 'LUNAS';
      String jatuhTempoActive = '-';
      String sisaHariActive = '-';
      bool dekatJatuhTempoActive = false;

      Map<String, dynamic>? unpaidInvoice;
      if (invoices.isNotEmpty) {
        try {
          unpaidInvoice = invoices.firstWhere(
            (inv) => inv['status_pembayaran']?.toString().toUpperCase() != 'LUNAS',
          );
        } catch (_) {
          unpaidInvoice = invoices.first;
        }
      }

      if (unpaidInvoice != null) {
        nominalTagihanActive = _formatRupiah(unpaidInvoice['total_tagihan']);
        statusTagihanActive = unpaidInvoice['status_pembayaran'] ?? 'BELUM';
        final String jtRaw = unpaidInvoice['tanggal_jatuh_tempo'] ?? '';
        try {
          final jtDate = DateTime.parse(jtRaw);
          jatuhTempoActive =
              "${jtDate.day} ${_getNamaBulan(jtDate.month)} ${jtDate.year}";
          final diff = jtDate.difference(DateTime.now()).inDays;
          sisaHariActive = "$diff Hari";
          if (diff <= 7 && diff >= 0) {
            dekatJatuhTempoActive = true;
          }
        } catch (_) {
          jatuhTempoActive = jtRaw;
        }
      }

      for (var inv in invoices) {
        final bool isLunas = inv['status_pembayaran']?.toString().toUpperCase() == 'LUNAS';
        String label =
            "Sewa ${_getNamaBulanDariTanggal(inv['tanggal_dibuat'])}";
        String tglStr = "";
        try {
          final date = DateTime.parse(inv['tanggal_dibuat']);
          tglStr = "${date.day} ${_getNamaBulan(date.month)} ${date.year}";
        } catch (_) {
          tglStr = inv['tanggal_dibuat'] ?? '';
        }

        mappedTagihan.add({
          'label': label,
          'tgl': tglStr,
          'nominal': _formatRupiah(inv['total_tagihan']),
          'lunas': isLunas,
          'invoice_data': inv,
        });
      }

      if (mounted) {
        setState(() {
          _namaPenghuni = namaLengkap;
          _namaKos = namaKos;
          _nomorKamar = nomorKamar;
          _tanggalMasuk = formattedTglMasuk;
          _jatuhTempo = jatuhTempoActive;
          _sisaHari = sisaHariActive;
          _dekatJatuhTempo = dekatJatuhTempoActive;
          _nominalTagihan = nominalTagihanActive;
          _statusTagihan = statusTagihanActive;
           _namaPemilik = namaPemilik;
          _noPemilik = noPemilik.isNotEmpty ? noPemilik : "6281234567890";
          _tagihan = mappedTagihan;
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

  String _getNamaBulan(int month) {
    const listBulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agt',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    if (month >= 1 && month <= 12) {
      return listBulan[month - 1];
    }
    return '';
  }

  String _getNamaBulanDariTanggal(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      const listBulanFull = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
      return listBulanFull[date.month - 1];
    } catch (_) {
      return '';
    }
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
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: _kDanger, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchDashboardData,
                  style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                  child: const Text(
                    'Coba Lagi',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── Header Hijau ───────────────────────────────────────────
                SliverToBoxAdapter(child: _buildHeader()),
                // ── Konten ────────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildKamarCard(),
                      const SizedBox(height: 14),
                      _buildTwoCards(),
                      const SizedBox(height: 20),
                      _buildTagihanTerakhir(context),
                      const SizedBox(height: 16),
                      _buildKontakPemilik(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const PenghuniBottomNav(currentIndex: 0),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 32),
      decoration: const BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KosKu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Halo, $_namaPenghuni',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('👋', style: TextStyle(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _namaKos,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white54, width: 1.5),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Card KAMAR SAYA ──────────────────────────────────────────────────────
  Widget _buildKamarCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label "KAMAR SAYA"
          Text(
            'KAMAR SAYA',
            style: TextStyle(
              color: _kAmber,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          // Nomor Kamar Besar
          Text(
            _nomorKamar,
            style: const TextStyle(
              color: _kPrimary,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          // Fasilitas chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              _FasilitasChip(icon: Icons.ac_unit, label: 'AC'),
              _FasilitasChip(icon: Icons.wifi, label: 'Wifi'),
              _FasilitasChip(icon: Icons.bathroom_outlined, label: 'KM Dalam'),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),
          // Alamat
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _namaKos,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                'Tanggal Masuk: $_tanggalMasuk',
                style: const TextStyle(color: Color(0xFF374151), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2 Card Kecil: Jatuh Tempo + Tagihan ──────────────────────────────────
  Widget _buildTwoCards() {
    return Row(
      children: [
        // Jatuh Tempo
        Expanded(
          child: _SmallCard(
            icon: Icons.calendar_month_outlined,
            iconColor: _kDanger,
            label: 'Jatuh Tempo',
            value: _jatuhTempo,
            badge: _dekatJatuhTempo
                ? Row(
                    children: [
                      Text(
                        'Sisa $_sisaHari',
                        style: const TextStyle(
                          color: _kDanger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        // Tagihan bulan ini
        Expanded(
          child: _SmallCard(
            icon: Icons.receipt_long_outlined,
            iconColor: _kAmber,
            label: 'Tagihan',
            value: _nominalTagihan,
            badge: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (_statusTagihan.toUpperCase() == 'LUNAS' ? _kPrimary : _kDanger).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _statusTagihan,
                style: TextStyle(
                  color: _statusTagihan.toUpperCase() == 'LUNAS' ? _kPrimary : _kDanger,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tagihan Terakhir ──────────────────────────────────────────────────────
  Widget _buildTagihanTerakhir(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tagihan Terakhir',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TagihanScreen())),
              child: const Text(
                'Lihat Semua',
                style: TextStyle(
                  color: _kPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...(_tagihan.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TagihanItem(
              label: item['label'] as String,
              tgl: item['tgl'] as String,
              nominal: item['nominal'] as String,
              lunas: item['lunas'] as bool,
            ),
          ),
        )),
      ],
    );
  }

  // ── Kontak Pemilik ────────────────────────────────────────────────────────
  Widget _buildKontakPemilik() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A7C6A), Color(0xFF2BAE8E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar pemilik
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white54, width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PEMILIK KOS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _namaPemilik,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Tombol Hubungi
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.white38),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                final uri = Uri.parse('https://wa.me/$_noPemilik');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.message_outlined, size: 18),
              label: const Text(
                'Hubungi Pemilik',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Widget Pendukung Dashboard
// ═══════════════════════════════════════════════════════════════════════════

class _FasilitasChip extends StatelessWidget {
  const _FasilitasChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB2EAD9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _kPrimary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _kPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  const _SmallCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.badge,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1F2933),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (badge != null) ...[const SizedBox(height: 6), badge!],
        ],
      ),
    );
  }
}

class _TagihanItem extends StatelessWidget {
  const _TagihanItem({
    required this.label,
    required this.tgl,
    required this.nominal,
    required this.lunas,
  });
  final String label;
  final String tgl;
  final String nominal;
  final bool lunas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 20,
              color: _kPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2933),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tgl,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                nominal,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2933),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lunas ? 'LUNAS' : 'BELUM',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: lunas ? _kPrimary : _kDanger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED Bottom Navigation — dipakai di semua tab penghuni
// ═══════════════════════════════════════════════════════════════════════════
class PenghuniBottomNav extends StatelessWidget {
  const PenghuniBottomNav({super.key, required this.currentIndex});

  /// 0 = Beranda, 1 = Tagihan, 2 = Profil
  final int currentIndex;

  static const Color _active = Color(0xFF1A7C6A);
  static const Color _inactive = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          _NavBtn(
            icon: Icons.home_rounded,
            label: 'Beranda',
            active: currentIndex == 0,
            onTap: () => _go(context, 0),
          ),
          _NavBtn(
            icon: Icons.receipt_long_rounded,
            label: 'Tagihan',
            active: currentIndex == 1,
            onTap: () => _go(context, 1),
          ),
          _NavBtn(
            icon: Icons.person_rounded,
            label: 'Profil',
            active: currentIndex == 2,
            onTap: () => _go(context, 2),
          ),
        ],
      ),
    );
  }

  void _go(BuildContext context, int index) {
    if (index == currentIndex) return;
    Widget screen;
    switch (index) {
      case 0:
        screen = const DashboardPenghuniScreen();
        break;
      case 1:
        screen = const TagihanScreen();
        break;
      default:
        screen = const ProfilPenghuniScreen();
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionDuration: Duration.zero,
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? PenghuniBottomNav._active
        : PenghuniBottomNav._inactive;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
