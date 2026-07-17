import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'konfirmasi_penghuni_screen.dart';
import '../transaksi/tambah_transaksi_screen.dart';

class DetailKamarScreen extends StatefulWidget {
  final int idKamar;

  const DetailKamarScreen({super.key, required this.idKamar});

  @override
  State<DetailKamarScreen> createState() => _DetailKamarScreenState();
}

class _DetailKamarScreenState extends State<DetailKamarScreen> {
  static const primaryColor = Color(0xFF004D40);
  static const accentOrange = Color(0xFFFFA834);

  bool _isLoadingSewa = false;
  Map<String, dynamic>? _sewaData;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadSewaAndInvoices();
  }

  // Generate random KOS-XXXX code excluding I, O, 1, 0
  String _generateKodeKamar() {
    final random = Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buffer = StringBuffer('KOS-');
    for (int i = 0; i < 4; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  Future<void> _loadSewaAndInvoices() async {
    if (!mounted) return;
    setState(() => _isLoadingSewa = true);
    try {
      final client = Supabase.instance.client;
      // Fetch active lease
      final sewa = await client
          .from('sewa')
          .select('*, penyewa(*, detail_penyewa(*))')
          .eq('id_kamar', widget.idKamar)
          .eq('status_sewa', 'Aktif')
          .maybeSingle();

      _sewaData = sewa;

      if (sewa != null) {
        // Fetch invoices
        final response = await client
            .from('invoice')
            .select()
            .eq('id_sewa', sewa['id_sewa'])
            .order('tanggal_dibuat', ascending: false);
        _invoices = List<Map<String, dynamic>>.from(response);
      } else {
        _invoices = [];
      }
    } catch (e) {
      debugPrint('Error loading sewa data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingSewa = false);
      }
    }
  }

  Future<void> _generateUlangKode(String currentCode) async {
    try {
      final client = Supabase.instance.client;
      final newCode = _generateKodeKamar();

      await client
          .from('kamar')
          .update({'kode_kamar': newCode})
          .eq('id_kamar', widget.idKamar);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kode kamar berhasil diubah menjadi: $newCode'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
      setState(() => _isLoadingSewa = true);
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

        await _loadSewaAndInvoices();

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
          setState(() => _isLoadingSewa = false);
        }
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text(
          'Detail Kamar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: client
            .from('kamar')
            .stream(primaryKey: ['id_kamar'])
            .eq('id_kamar', widget.idKamar),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (snapshot.hasError ||
              snapshot.data == null ||
              snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Data kamar tidak ditemukan atau gagal dimuat.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final kamar = snapshot.data!.first;
          final String nomorKamar = kamar['nomor_kamar'] ?? '-';
          final String statusKamar = kamar['status_kamar'] ?? 'Kosong';
          final String kodeKamar = kamar['kode_kamar'] ?? '-';
          final num harga = kamar['harga_sewa_dasar'] ?? 0;
          final List fasilitas = kamar['fasilitas'] ?? [];
          final isKosong = statusKamar == 'Kosong';

          return RefreshIndicator(
            color: primaryColor,
            onRefresh: _loadSewaAndInvoices,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- AREA HERO DETAIL KAMAR ---
                  Container(
                    width: double.infinity,
                    color: primaryColor,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kamar $nomorKamar',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isKosong
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusKamar.toUpperCase(),
                                style: TextStyle(
                                  color: isKosong
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFF00796B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_formatRupiah(harga)} / Bulan',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isKosong) ...[
                    // ============================================
                    // KONDISI: KAMAR KOSONG
                    // ============================================

                    // --- CARD TOKEN KODE KAMAR ---
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Token Akses Pendaftaran Kamar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F4F8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blueGrey.shade100,
                                  ),
                                ),
                                child: Text(
                                  kodeKamar,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentOrange,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: const Icon(Icons.copy, size: 18),
                                    label: const Text('Salin Kode'),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: kodeKamar),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Token kamar disalin ke clipboard!',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: primaryColor,
                                        ),
                                      );
                                    },
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: const BorderSide(
                                        color: primaryColor,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Generate Ulang'),
                                    onPressed: () =>
                                        _generateUlangKode(kodeKamar),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // --- SUB-STREAM UNTUK CALON PENGHUNI ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Text(
                        'Pengajuan Masuk',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: client
                          .from('request_join')
                          .select()
                          .eq('id_kamar', widget.idKamar),
                      builder: (context, requestSnapshot) {
                        if (requestSnapshot.hasError) {
                          debugPrint('Error loading request_join: ${requestSnapshot.error}');
                          return const SizedBox.shrink();
                        }
                        if (requestSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            ),
                          );
                        }

                        final allRequests = requestSnapshot.data ?? [];
                        final requests = allRequests
                            .where(
                              (req) =>
                                  req['status_request'] ==
                                  'Menunggu Konfirmasi',
                            )
                            .toList();

                        if (requests.isEmpty) {
                          return Container(
                            margin: const EdgeInsets.all(20),
                            padding: const EdgeInsets.symmetric(
                              vertical: 36,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.person_add_disabled_outlined,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Belum ada pengajuan masuk dari calon penghuni.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final req = requests[index];
                            final idRequest = req['id_request'];
                            final dateStr = req['tanggal_pengajuan'] ?? '';

                            return Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: const Icon(
                                    Icons.person_add_alt_1,
                                    color: primaryColor,
                                  ),
                                ),
                                title: const Text(
                                  'Calon Penghuni Baru',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Mengajukan pada: $dateStr',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            KonfirmasiPenghuniScreen(
                                              idRequest: idRequest,
                                            ),
                                      ),
                                    ).then((_) => _loadSewaAndInvoices());
                                  },
                                  child: const Text('Lihat & Konfirmasi'),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ] else ...[
                    // ============================================
                    // KONDISI: KAMAR TERISI
                    // ============================================
                    if (_isLoadingSewa)
                      const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        ),
                      )
                    else if (_sewaData == null)
                      Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Gagal mengambil data sewa aktif. Hubungkan ulang data penyewa.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else ...[
                      // --- CARD PROFIL PENYEWA ---
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        size: 30,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _sewaData!['penyewa']?['nama_lengkap'] ??
                                                'Penyewa',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'WhatsApp: ${_sewaData!['penyewa']?['nomor_whatsapp'] ?? '-'}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'NIK KTP:',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Text(
                                      _sewaData!['penyewa']?['nik'] ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Tanggal Masuk:',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Text(
                                      _sewaData!['tanggal_masuk'] ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),

                                // ACTION BUTTONS FOR OCCUPIED ROOM
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.add_card,
                                          size: 18,
                                        ),
                                        label: const Text('Tambah Pembayaran'),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  TambahTransaksiScreen(
                                                    initialSewaId:
                                                        _sewaData!['id_sewa'],
                                                  ),
                                            ),
                                          ).then((value) {
                                            if (value == true) {
                                              _loadSewaAndInvoices();
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                            color: Colors.red,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.exit_to_app,
                                          size: 18,
                                        ),
                                        label: const Text('Keluarkan Penyewa'),
                                        onPressed: () => _keluarkanPenyewa(
                                          _sewaData!['id_sewa'],
                                          nomorKamar,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // --- LIST RIWAYAT INVOICE ---
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Riwayat Tagihan / Invoice',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_invoices.isEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'Belum ada riwayat tagihan dibuat.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _invoices.length,
                          itemBuilder: (context, index) {
                            final inv = _invoices[index];
                            final noInv = inv['nomor_invoice'] ?? '-';
                            final total = inv['total_tagihan'] ?? 0;
                            final statusBayar =
                                inv['status_pembayaran'] ?? 'Belum Bayar';
                            final isLunas = statusBayar == 'Lunas';
                            final periode = inv['periode_sewa'] ?? '';

                            return Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                title: Text(
                                  noInv,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Periode: $periode • Jatuh Tempo: ${inv['tanggal_jatuh_tempo'] ?? '-'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatRupiah(total),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLunas
                                            ? const Color(0xFFE8F5E9)
                                            : const Color(0xFFFFEBEE),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        statusBayar.toUpperCase(),
                                        style: TextStyle(
                                          color: isLunas
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFFC62828),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 30),
                    ],
                  ],

                  // --- CARD 3: FASILITAS KAMAR ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.bed_outlined, color: primaryColor),
                                SizedBox(width: 8),
                                Text(
                                  'Fasilitas Kamar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (fasilitas.isEmpty)
                              const Text(
                                'Tidak ada info fasilitas.',
                                style: TextStyle(color: Colors.grey),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: fasilitas.map((item) {
                                  return Chip(
                                    label: Text(
                                      item.toString(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: const Color(0xFFF0F4F8),
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
