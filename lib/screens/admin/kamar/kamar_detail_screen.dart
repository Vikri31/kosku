import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'kamar_form_screen.dart';
import 'penyewa_form_screen.dart';
import 'konfirmasi_penghuni_screen.dart';
import '../transaksi/tambah_transaksi_screen.dart';
import '../../../services/notification_service.dart';

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
  Map<String, dynamic>? _detailPenyewaData;
  List<Map<String, dynamic>> _historiPembayaran = [];
  bool _isLoading = true;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
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

        if (penyewa != null && penyewa['nik'] != null) {
          final detail = await client
              .from('detail_penyewa')
              .select()
              .eq('nik', penyewa['nik'])
              .maybeSingle();
          _detailPenyewaData = detail;
        } else {
          _detailPenyewaData = null;
        }

        // Load histori pembayaran (invoices for this sewa)
        final invoices = await client
            .from('invoice')
            .select()
            .eq('id_sewa', sewa['id_sewa'])
            .order('tanggal_dibuat', ascending: false)
            .limit(10);
        _historiPembayaran = List<Map<String, dynamic>>.from(invoices);
      } else {
        _penyewaData = null;
        _detailPenyewaData = null;
        _historiPembayaran = [];
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
        title: const Text(
          'Hapus Kamar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  String _generateKodeKamar() {
    final random = math.Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final code = List.generate(
      4,
      (i) => chars[random.nextInt(chars.length)],
    ).join();
    return 'KOS-$code';
  }

  Future<void> _generateUlangKodeKamar() async {
    final newCode = _generateKodeKamar();
    try {
      await Supabase.instance.client
          .from('kamar')
          .update({'kode_kamar': newCode})
          .eq('id_kamar', widget.idKamar);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode kamar baru berhasil dibuat!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui kode: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }



  Future<void> _keluarkanPenyewa(int idSewa, String nomorKamar) async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;

      // 1. Cek apakah ada tagihan yang belum lunas
      final unpaidInvoices = await client
          .from('invoice')
          .select()
          .eq('id_sewa', idSewa)
          .neq('status_pembayaran', 'Lunas');

      if (!mounted) return;

      if (unpaidInvoices.isNotEmpty) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Gagal Mengeluarkan Penyewa',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            content: const Text(
              'Penyewa tidak dapat dikeluarkan karena masih memiliki tagihan yang belum dilunasi. Harap konfirmasi pelunasan semua tagihan terlebih dahulu.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengecek status tagihan: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluarkan Penyewa',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: Text(
          'Apakah Anda yakin ingin menyelesaikan masa sewa kamar $nomorKamar? Status kamar akan kembali menjadi Kosong.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Keluarkan'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final client = Supabase.instance.client;
        // End lease
        await client
            .from('sewa')
            .update({'status_sewa': 'Selesai'})
            .eq('id_sewa', idSewa);

        // Make room empty
        await client
            .from('kamar')
            .update({'status_kamar': 'Kosong'})
            .eq('id_kamar', widget.idKamar);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Penyewa berhasil dikeluarkan dan status kamar diubah.',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memproses: $e'),
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
  }

  Future<void> _konfirmasiLunas(Map<String, dynamic> inv) async {
    setState(() => _isLoading = true);
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

      // Kirim Notifikasi Skenario C (Admin -> User)
      try {
        final String? userPenyewaId = await NotificationService.getPenyewaUserId(inv['id_sewa']);
        if (userPenyewaId != null) {
          final total = inv['total_tagihan'] ?? inv['biaya_sewa_pokok'] ?? 0;
          final buffer = StringBuffer();
          final strVal = total.toString();
          int count = 0;
          for (int i = strVal.length - 1; i >= 0; i--) {
            buffer.write(strVal[i]);
            count++;
            if (count % 3 == 0 && i != 0) {
              buffer.write('.');
            }
          }
          final formattedNominal = "Rp ${buffer.toString().split('').reversed.join('')}";

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
            content: Text('Pembayaran berhasil dikonfirmasi Lunas!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal konfirmasi lunas: $e'),
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

  void _lihatBuktiLengkap(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text(
                'Bukti Transfer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: primaryColor,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Container(
              color: const Color(0xFFF5F7F8),
              padding: const EdgeInsets.all(16),
              height: 400,
              width: double.infinity,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Gagal memuat bukti transfer',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = _kamarData?['status_kamar'] ?? widget.status;
    final isTerisi = (currentStatus == 'Terisi');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      body: CustomScrollView(
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
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        ((_kamarData?['foto_kamar'] as List?)?.isEmpty ?? true)
                            ? Container(
                                color: primaryColor.withValues(
                                  alpha: 0.3,
                                ),
                                child: const Icon(
                                  Icons.bed_outlined,
                                  size: 60,
                                  color: Colors.white54,
                                ),
                              )
                            : PageView.builder(
                                controller: _pageController,
                                itemCount:
                                    (_kamarData!['foto_kamar'] as List).length,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentImageIndex = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final url =
                                      (_kamarData!['foto_kamar'] as List)[index]
                                          as String;
                                  return Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              color: primaryColor.withValues(
                                                alpha: 0.3,
                                              ),
                                              child: const Icon(
                                                Icons.broken_image_outlined,
                                                size: 60,
                                                color: Colors.white54,
                                              ),
                                            ),
                                  );
                                },
                              ),
                        // Gradient overlay
                        IgnorePointer(
                          child: Container(
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
                        ),
                        // Left Arrow Button
                        if (_kamarData != null &&
                            _kamarData!['foto_kamar'] != null &&
                            (_kamarData!['foto_kamar'] as List).length > 1 &&
                            _currentImageIndex > 0)
                          Positioned(
                            left: 12,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: const CircleBorder(),
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        // Right Arrow Button
                        if (_kamarData != null &&
                            _kamarData!['foto_kamar'] != null &&
                            (_kamarData!['foto_kamar'] as List).length > 1 &&
                            _currentImageIndex < (_kamarData!['foto_kamar'] as List).length - 1)
                          Positioned(
                            right: 12,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: const CircleBorder(),
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
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
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _currentImageIndex == i
                                        ? primaryColor
                                        : Colors.white.withValues(alpha: 0.6),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isTerisi
                                    ? const Color(0xFFE0F2F1)
                                    : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isTerisi
                                          ? const Color(0xFF00796B)
                                          : const Color(0xFFC62828),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    currentStatus,
                                    style: TextStyle(
                                      color: isTerisi
                                          ? const Color(0xFF00796B)
                                          : const Color(0xFFC62828),
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
                            if (_isLoading) {
                              return const SizedBox(
                                height: 24,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: primaryColor,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Memuat fasilitas...',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final List<dynamic> fasilitas =
                                _kamarData?['fasilitas'] as List<dynamic>? ??
                                [];
                            if (fasilitas.isEmpty) {
                              return Text(
                                'Tidak ada fasilitas khusus',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
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
                                return _buildFasilitasChip(
                                  getFacilityIcon(name),
                                  name,
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // --- CONDITIONAL CONTENT SECTION ---
                        if (isTerisi) ...[
                          _buildKamarTerisiSection(),
                        ] else ...[
                          _buildKamarKosongSection(),
                        ],

                        // --- BASE CHAMBER ACTIONS (Edit Kamar, Hapus Kamar) ---
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          label: 'Edit Properti Kamar',
                          icon: Icons.edit_outlined,
                          color: Colors.transparent,
                          textColor: _isLoading ? Colors.grey : primaryColor,
                          borderColor: _isLoading ? Colors.grey : primaryColor,
                          onPressed: _isLoading
                              ? () {}
                              : () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          KamarFormScreen(roomData: _kamarData),
                                    ),
                                  );
                                  _loadData();
                                },
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          label: 'Hapus Kamar',
                          icon: Icons.delete_outline,
                          color: _isLoading ? Colors.grey : const Color(0xFFC62828),
                          onPressed: _isLoading ? () {} : _hapusKamar,
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

  void _showKtpDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text(
                'Foto KTP Penyewa',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text('Gagal memuat foto KTP'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== KAMAR KOSONG UI LAYOUT ====================
  Widget _buildKamarKosongSection() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }
    final tokenKamar = _kamarData?['kode_kamar'] ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Bagian "Pilih Cara Tambah Penyewa"
        const Text(
          'Pilih Cara Tambah Penyewa',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Card 1: Input Manual (Tanpa Aplikasi)
            Expanded(
              child: GestureDetector(
                onTap: () async {
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
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.all(14),
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
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(0xFFE0F2F1),
                        radius: 20,
                        child: Icon(
                          Icons.edit_note,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Input Manual',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '(Tanpa Aplikasi)',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Card 2: Via Aplikasi (Dengan Aplikasi) - Kosmetik/Panduan
            Expanded(
              child: Container(
                height: 140,
                padding: const EdgeInsets.all(14),
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
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFFFFF3E0),
                      radius: 20,
                      child: Icon(
                        Icons.phone_android,
                        color: accentOrange,
                        size: 20,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Via Aplikasi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '(Dengan Aplikasi)',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 2. Realtime Stream Card Notifikasi Calon Penghuni
        FutureBuilder<List<Map<String, dynamic>>>(
          future: Supabase.instance.client
              .from('request_join')
              .select()
              .eq('id_kamar', widget.idKamar),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: primaryColor),
                ),
              );
            }
            if (snapshot.hasError) {
              debugPrint('Error loading request_join: ${snapshot.error}');
              return const SizedBox.shrink();
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final pendingRequests = snapshot.data!
                .where((req) => req['status_request'] == 'Menunggu Konfirmasi')
                .toList();

            if (pendingRequests.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengajuan Bergabung',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingRequests.length,
                  itemBuilder: (context, index) {
                    final req = pendingRequests[index];
                    final idRequest = req['id_request'];
                    final timeAgo = _getRelativeTime(req['tanggal_pengajuan']);

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: Supabase.instance.client
                          .from('detail_penyewa')
                          .select()
                          .eq('id_user', req['id_user'])
                          .maybeSingle(),
                      builder: (context, detailSnapshot) {
                        final detail = detailSnapshot.data;
                        final name =
                            detail?['nama_lengkap'] ?? 'Calon Penghuni';
                        final avatarUrl =
                            detail?['foto_profil_url'] ??
                            detail?['foto_ktp_url'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                                radius: 24,
                                backgroundColor: const Color(0xFFE0F2F1),
                                backgroundImage:
                                    (avatarUrl != null &&
                                        avatarUrl.toString().isNotEmpty)
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child:
                                    (avatarUrl == null ||
                                        avatarUrl.toString().isEmpty)
                                    ? const Icon(
                                        Icons.person,
                                        color: primaryColor,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timeAgo,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => KonfirmasiPenghuniScreen(
                                        idRequest: idRequest as int,
                                      ),
                                    ),
                                  ).then((_) => _loadData());
                                },
                                child: const Text(
                                  'Lihat & Konfirmasi',
                                  style: TextStyle(
                                    fontSize: 11,
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
                const SizedBox(height: 12),
              ],
            );
          },
        ),

        // 3. Bagian "Kode Kamar" (Container Token)
        const Text(
          'Kode Kamar',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!, width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                tokenKamar,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F7F8),
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text(
                      'Salin Kode',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tokenKamar));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kode kamar disalin ke clipboard!'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.refresh_outlined, size: 16),
                    label: const Text(
                      'Generate Ulang',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: _generateUlangKodeKamar,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== KAMAR TERISI UI LAYOUT ====================
  Widget _buildKamarTerisiSection() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }
    final nama = _penyewaData?['nama_lengkap'] ?? '-';
    final wa = _penyewaData?['nomor_whatsapp'] ?? '-';
    final nik = _penyewaData?['nik'] ?? '-';
    final initial = nama.isNotEmpty ? nama[0].toUpperCase() : 'P';

    final tglMasuk = _sewaData?['tanggal_masuk'];
    final jatuhTempo = _getJatuhTempo();
    final jatuhTempoStr = jatuhTempo != null
        ? '${jatuhTempo.year}-${jatuhTempo.month.toString().padLeft(2, '0')}-${jatuhTempo.day.toString().padLeft(2, '0')}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Card "Penyewa Aktif"
        const Text(
          'Penyewa Aktif',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFE0F2F1),
                    backgroundImage: (_detailPenyewaData?['foto_profil_url'] != null &&
                            _detailPenyewaData!['foto_profil_url'].toString().isNotEmpty)
                        ? NetworkImage(_detailPenyewaData!['foto_profil_url'])
                        : null,
                    child: (_detailPenyewaData?['foto_profil_url'] == null ||
                            _detailPenyewaData!['foto_profil_url'].toString().isEmpty)
                        ? Text(
                            initial,
                            style: const TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nama,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'DATA DARI APLIKASI',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_android_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              wa,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tanggal Masuk',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(tglMasuk),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey[300]),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jatuh Tempo',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(jatuhTempoStr),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Card "Informasi Pribadi"
        Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informasi Pribadi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Nama Lengkap', nama, canCopy: true),
              const Divider(height: 24),
              _buildInfoRow('No. WhatsApp', wa, canCopy: true),
              const Divider(height: 24),
              _buildInfoRow('No. KTP (NIK)', nik, canCopy: true),
              if (_detailPenyewaData?['foto_ktp_url'] != null &&
                  _detailPenyewaData!['foto_ktp_url'].toString().isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Foto KTP',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.credit_card_outlined, size: 18),
                      label: const Text(
                        'Lihat KTP',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () => _showKtpDialog(
                        context,
                        _detailPenyewaData!['foto_ktp_url'].toString(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. Tombol Aksi Utama (Vertikal Lebar)
        if (_sewaData != null) ...[
          if (_detailPenyewaData?['id_user'] == null) ...[
            _buildActionButton(
              label: 'Tambah Pembayaran',
              icon: Icons.add_card_outlined,
              color: primaryColor,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TambahTransaksiScreen(
                      initialSewaId: _sewaData!['id_sewa'],
                    ),
                  ),
                ).then((value) {
                  if (value == true) {
                    _loadData();
                  }
                });
              },
            ),
            const SizedBox(height: 12),
          ],
          _buildActionButton(
            label: 'Keluarkan Penyewa',
            icon: Icons.exit_to_app_outlined,
            color: Colors.transparent,
            textColor: const Color(0xFFC62828),
            borderColor: const Color(0xFFC62828),
            onPressed: () =>
                _keluarkanPenyewa(_sewaData!['id_sewa'], widget.nomorKamar),
          ),
        ],
        const SizedBox(height: 24),

        // 4. Seksi "Bukti Pembayaran Masuk" (Realtime Validation Card)
        if (_sewaData != null)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client
                .from('invoice')
                .select()
                .eq('id_sewa', _sewaData!['id_sewa']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                );
              }
              if (snapshot.hasError) {
                debugPrint('Error loading invoices: ${snapshot.error}');
                return const SizedBox.shrink();
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }

              final pendingInvoices = snapshot.data!
                  .where(
                    (inv) =>
                        inv['status_pembayaran'] == 'Menunggu Verifikasi' &&
                        inv['bukti_transfer_url'] != null &&
                        inv['bukti_transfer_url'].toString().isNotEmpty,
                  )
                  .toList();

              if (pendingInvoices.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verifikasi Pembayaran Masuk',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...pendingInvoices.map((inv) {
                    final nominal = inv['total_tagihan'] ?? 0;
                    final String buktiUrl = inv['bukti_transfer_url'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accentOrange, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: accentOrange,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Bukti Transfer Masuk',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatRupiah(nominal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black87,
                                    side: BorderSide(color: Colors.grey[400]!),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  onPressed: () => _lihatBuktiLengkap(buktiUrl),
                                  child: const Text(
                                    'Lihat Bukti Lengkap',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () => _konfirmasiLunas(inv),
                                  child: const Text(
                                    'Konfirmasi Lunas',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),

        // 5. Seksi "Histori Pembayaran"
        _buildHistoriPembayaranSection(),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool canCopy = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        if (canCopy)
          IconButton(
            icon: Icon(Icons.copy_outlined, size: 16, color: Colors.grey[400]),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label disalin'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildHistoriPembayaranSection() {
    final lunasInvoices = _historiPembayaran
        .where((inv) => inv['status_pembayaran'] == 'Lunas')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Histori Pembayaran',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (lunasInvoices.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Belum ada histori pembayaran lunas.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          Container(
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
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lunasInvoices.length,
              separatorBuilder: (context, _) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, i) {
                final inv = lunasInvoices[i];
                final nominal = inv['total_tagihan'] as num? ?? 0;
                final tanggal = _formatDate(inv['tanggal_dibuat']);
                final periode = inv['periode_sewa'] ?? '-';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_downward_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Sewa Kamar ${widget.nomorKamar}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    '$tanggal • Periode $periode',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatRupiah(nominal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LUNAS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00796B),
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
          side: borderColor != null
              ? BorderSide(color: borderColor, width: 1.5)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
