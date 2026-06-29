import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'kamar_form_screen.dart';
import 'penyewa_form_screen.dart';

class KamarDetailScreen extends StatefulWidget {
  final int idKamar;
  final String nomorKamar;
  final num harga;
  final String status;

  const KamarDetailScreen({
    super.key,
    required this.idKamar,
    required this.nomorKamar,
    required this.harga,
    required this.status,
  });

  @override
  State<KamarDetailScreen> createState() => _KamarDetailScreenState();
}

class _KamarDetailScreenState extends State<KamarDetailScreen> {
  static const primaryColor = Color(0xFF004D40);
  static const accentOrange = Color(0xFFFFA834);

  Map<String, dynamic>? _kamarData;
  Map<String, dynamic>? _sewaData;
  Map<String, dynamic>? _penyewaData;
  List<Map<String, dynamic>> _historiPembayaran = [];
  bool _isLoading = true;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '-';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  String _getRelativeTime(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff < 0) return 'Dalam ${diff.abs()} hari';
    final bulan = (diff / 30).round();
    if (bulan < 1) return '$diff hari lalu';
    return '$bulan bulan lalu';
  }

  /// Hitung tanggal jatuh tempo dari tanggal_masuk + durasi_bulan
  DateTime? _getJatuhTempo() {
    final tglMasukStr = _sewaData?['tanggal_masuk'];
    final durasi = _sewaData?['durasi_bulan'] as int? ?? 1;
    if (tglMasukStr == null) return null;
    final tglMasuk = DateTime.tryParse(tglMasukStr);
    if (tglMasuk == null) return null;
    return DateTime(tglMasuk.year, tglMasuk.month + durasi, tglMasuk.day);
  }

  String _getDueDateStatus(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final now = DateTime.now();
    final nowZero = DateTime(now.year, now.month, now.day);
    final dateZero = DateTime(date.year, date.month, date.day);
    final diff = dateZero.difference(nowZero).inDays;
    if (diff == 0) return 'Jatuh tempo hari ini';
    if (diff > 0) return 'Dalam $diff hari';
    return 'Telat ${diff.abs()} hari';
  }

  bool _isDueDateOverdue(DateTime? date) {
    if (date == null) return false;
    return date.isBefore(DateTime.now());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;

      // Load kamar details
      final kamar = await client
          .from('kamar')
          .select()
          .eq('id_kamar', widget.idKamar)
          .maybeSingle();
      _kamarData = kamar;

      // Load active sewa
      final sewa = await client
          .from('sewa')
          .select()
          .eq('id_kamar', widget.idKamar)
          .eq('status_sewa', 'Aktif')
          .maybeSingle();
      _sewaData = sewa;

      if (sewa != null) {
        // Load penyewa details
        final penyewa = await client
            .from('penyewa')
            .select()
            .eq('id_penyewa', sewa['id_penyewa'])
            .maybeSingle();
        _penyewaData = penyewa;

        // Load histori pembayaran (invoices for this sewa)
        final invoices = await client
            .from('invoice')
            .select()
            .eq('id_sewa', sewa['id_sewa'])
            .order('tanggal_dibuat', ascending: false)
            .limit(5);
        _historiPembayaran = List<Map<String, dynamic>>.from(invoices);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _hapusKamar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Kamar', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Apakah Anda yakin ingin menghapus Kamar ${widget.nomorKamar}? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Supabase.instance.client
            .from('kamar')
            .delete()
            .eq('id_kamar', widget.idKamar);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kamar berhasil dihapus.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTerisi = (widget.status == 'Terisi');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // --- SLIVER APP BAR WITH IMAGE ---
                SliverAppBar(
                  expandedHeight: 240,
                  pinned: true,
                  backgroundColor: primaryColor,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: const Text(
                    'Detail Kamar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        ((_kamarData?['foto_kamar'] as List?)?.isEmpty ?? true)
                            ? Image.network(
                                isTerisi
                                    ? 'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?w=600'
                                    : 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=600',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  child: const Icon(Icons.bed_outlined, size: 60, color: Colors.white54),
                                ),
                              )
                            : PageView.builder(
                                itemCount: (_kamarData!['foto_kamar'] as List).length,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentImageIndex = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final url = (_kamarData!['foto_kamar'] as List)[index] as String;
                                  return Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: primaryColor.withValues(alpha: 0.3),
                                      child: const Icon(Icons.broken_image_outlined, size: 60, color: Colors.white54),
                                    ),
                                  );
                                },
                              ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.black.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                        // Page indicator dots
                        if (_kamarData != null &&
                            _kamarData!['foto_kamar'] != null &&
                            (_kamarData!['foto_kamar'] as List).length > 1)
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                (_kamarData!['foto_kamar'] as List).length,
                                (i) => Container(
                                  width: _currentImageIndex == i ? 20 : 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    color: _currentImageIndex == i ? primaryColor : Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- KAMAR HEADER INFO ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TIPE PREMIUM',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[500],
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Kamar ${widget.nomorKamar}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatRupiah(widget.harga)} / bulan',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isTerisi ? const Color(0xFFE0F2F1) : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isTerisi ? const Color(0xFF00796B) : const Color(0xFFC62828),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.status,
                                    style: TextStyle(
                                      color: isTerisi ? const Color(0xFF00796B) : const Color(0xFFC62828),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // --- FASILITAS CHIPS ---
                        Builder(
                          builder: (context) {
                            final List<dynamic> fasilitas = _kamarData?['fasilitas'] as List<dynamic>? ?? [];
                            if (fasilitas.isEmpty) {
                              return Text(
                                'Tidak ada fasilitas khusus',
                                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                              );
                            }
                            
                            IconData getFacilityIcon(String name) {
                              switch (name) {
                                case 'Kasur':
                                  return Icons.king_bed_outlined;
                                case 'AC':
                                  return Icons.ac_unit_outlined;
                                case 'KM Dalam':
                                  return Icons.bathtub_outlined;
                                case 'WiFi':
                                  return Icons.wifi_rounded;
                                case 'Meja Belajar':
                                  return Icons.table_restaurant_outlined;
                                case 'Lemari':
                                  return Icons.checkroom_outlined;
                                default:
                                  return Icons.star_border;
                              }
                            }

                            return Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: fasilitas.map((f) {
                                final name = f.toString();
                                return _buildFasilitasChip(getFacilityIcon(name), name);
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // --- PENYEWA AKTIF SECTION ---
                        if (isTerisi && _penyewaData != null) ...[
                          const Text(
                            'Penyewa Aktif',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 12),
                          _buildPenyewaCard(),
                          const SizedBox(height: 16),
                          _buildInformasiPribadiCard(),
                          const SizedBox(height: 16),
                          _buildKamarInfoCard(),
                          const SizedBox(height: 16),
                          _buildTanggalMasukCard(),
                          const SizedBox(height: 16),
                          _buildJatuhTempoCard(),
                          const SizedBox(height: 24),
                          _buildHistoriPembayaranSection(),
                          const SizedBox(height: 24),
                        ] else if (!isTerisi) ...[
                          _buildKosongCard(),
                          const SizedBox(height: 24),
                        ],

                        // --- ACTION BUTTONS ---
                        if (isTerisi && _penyewaData != null)
                          _buildActionButton(
                            label: 'Edit Penyewa',
                            icon: Icons.edit_outlined,
                            color: primaryColor,
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PenyewaFormScreen(
                                    penyewaData: _penyewaData,
                                    sewaData: _sewaData,
                                    preselectedKamarId: _sewaData?['id_kamar'] as int? ?? widget.idKamar,
                                    preselectedKamarNomor: widget.nomorKamar,
                                  ),
                                ),
                              );
                              _loadData();
                            },
                          ),
                        if (isTerisi) const SizedBox(height: 12),
                        _buildActionButton(
                          label: 'Edit Kamar',
                          icon: Icons.edit_outlined,
                          color: Colors.transparent,
                          textColor: primaryColor,
                          borderColor: primaryColor,
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KamarFormScreen(roomData: _kamarData),
                              ),
                            );
                            _loadData();
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          label: 'Hapus Kamar',
                          icon: Icons.delete_outline,
                          color: const Color(0xFFC62828),
                          onPressed: _hapusKamar,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFasilitasChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildPenyewaCard() {
    final nama  = _penyewaData?['nama_lengkap'] ?? '-';
    final wa    = _penyewaData?['nomor_whatsapp'] ?? '-';
    final initial = nama.isNotEmpty ? nama[0].toUpperCase() : 'P';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFE0F2F1),
            child: Text(
              initial,
              style: const TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_android_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(wa, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformasiPribadiCard() {
    final nama = _penyewaData?['nama_lengkap'] ?? '-';
    final wa   = _penyewaData?['nomor_whatsapp'] ?? '-';
    final nik  = _penyewaData?['nik'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informasi Pribadi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          _buildInfoRow('Nama Lengkap', nama, canCopy: false),
          const Divider(height: 24),
          _buildInfoRow('No. WhatsApp', wa, canCopy: true),
          const Divider(height: 24),
          _buildInfoRow('No. KTP (NIK)', nik, canCopy: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool canCopy = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
            ),
            if (canCopy)
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label disalin'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Icon(Icons.copy_outlined, size: 18, color: Colors.grey[400]),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildKamarInfoCard() {
    final lantai = _kamarData?['lantai']?.toString() ?? '1';
    final tipe = _kamarData?['tipe_kamar'] ?? 'Standar';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.door_front_door_outlined, color: primaryColor, size: 18),
              ),
              const SizedBox(width: 8),
              const Text('Kamar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.nomorKamar,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          Text(
            'Lantai $lantai - $tipe',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTanggalMasukCard() {
    final tanggalMasuk = _sewaData?['tanggal_masuk'];
    final relative = _getRelativeTime(tanggalMasuk);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.login_outlined, color: accentOrange, size: 18),
              ),
              const SizedBox(width: 8),
              const Text('Tanggal Masuk', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accentOrange)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatDate(tanggalMasuk),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          Text(relative, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildJatuhTempoCard() {
    final jatuhTempo = _getJatuhTempo();
    final jatuhTempoStr = jatuhTempo != null
        ? '${jatuhTempo.year}-${jatuhTempo.month.toString().padLeft(2, '0')}-${jatuhTempo.day.toString().padLeft(2, '0')}'
        : null;
    final isOverdue = _isDueDateOverdue(jatuhTempo);
    final statusText = _getDueDateStatus(jatuhTempoStr);
    final cardColor = isOverdue ? const Color(0xFFFFEBEE) : const Color(0xFFF3E5F5);
    final iconColor = isOverdue ? const Color(0xFFC62828) : const Color(0xFF7B1FA2);
    final textColor = isOverdue ? const Color(0xFFC62828) : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.event_outlined, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Jatuh Tempo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            jatuhTempo != null ? _formatDate(jatuhTempoStr) : '-',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
          ),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 13,
              color: isOverdue ? const Color(0xFFC62828) : Colors.grey[500],
              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoriPembayaranSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Histori Pembayaran',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
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
        const SizedBox(height: 8),
        if (_historiPembayaran.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('Belum ada histori pembayaran.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _historiPembayaran.length,
              separatorBuilder: (context, _) => const Divider(height: 1, indent: 56, endIndent: 16),
              itemBuilder: (context, i) {
                final inv = _historiPembayaran[i];
                final nominal = inv['total_tagihan'] as num? ?? 0;
                final status = inv['status_pembayaran'] ?? '-';
                final tanggal = _formatDate(inv['tanggal_dibuat']);
                final metodeBayar = inv['metode_bayar'] ?? 'Transfer Bank';
                final isLunas = status == 'Lunas';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_downward_rounded, color: primaryColor, size: 20),
                  ),
                  title: Text(
                    'Sewa Kamar ${widget.nomorKamar}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  subtitle: Text(
                    '$tanggal • $metodeBayar',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatRupiah(nominal),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isLunas ? const Color(0xFFE0F2F1) : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isLunas ? const Color(0xFF00796B) : const Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildKosongCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.vpn_key_outlined, color: primaryColor, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Kamar Kosong',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Kamar ini belum memiliki penyewa aktif.\nTambahkan penyewa untuk mulai menyewakan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Tambah Penyewa', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PenyewaFormScreen(
                      preselectedKamarId: widget.idKamar,
                      preselectedKamarNomor: widget.nomorKamar,
                    ),
                  ),
                );
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    Color textColor = Colors.white,
    Color? borderColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          side: borderColor != null ? BorderSide(color: borderColor, width: 1.5) : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        onPressed: onPressed,
      ),
    );
  }
}
