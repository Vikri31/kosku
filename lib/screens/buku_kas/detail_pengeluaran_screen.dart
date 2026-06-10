import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailPengeluaranScreen extends StatefulWidget {
  final int? idPengeluaran;

  const DetailPengeluaranScreen({super.key, this.idPengeluaran});

  @override
  State<DetailPengeluaranScreen> createState() => _DetailPengeluaranScreenState();
}

class _DetailPengeluaranScreenState extends State<DetailPengeluaranScreen> {
  bool _isDeleting = false;

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

  Future<void> _handleDelete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Hapus Data'),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin menghapus data pengeluaran ini secara permanen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await Supabase.instance.client
          .from('pengeluaran')
          .delete()
          .eq('id_pengeluaran', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catatan pengeluaran berhasil dihapus!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus pengeluaran: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF004D40);
    const accentColor = Color(0xFFF2A32B);

    // Dapatkan ID dari constructor atau dari argumen route
    final routeId = ModalRoute.of(context)?.settings.arguments as int?;
    final finalId = widget.idPengeluaran ?? routeId;

    if (finalId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pengeluaran'),
          backgroundColor: primaryColor,
        ),
        body: const Center(
          child: Text('Error: ID pengeluaran tidak ditemukan.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text(
          'Detail Pengeluaran',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('pengeluaran')
            .stream(primaryKey: ['id_pengeluaran'])
            .eq('id_pengeluaran', finalId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Terjadi kesalahan: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final dataList = snapshot.data ?? [];
          if (dataList.isEmpty) {
            return const Center(
              child: Text('Data pengeluaran tidak ditemukan / telah dihapus.'),
            );
          }

          final detail = dataList.first;
          final kategori = detail['kategori'] ?? 'Lainnya';
          final deskripsi = detail['deskripsi'] ?? '-';
          final tgl = detail['tanggal_keluar'];
          final nominal = detail['nominal_keluar'] as num? ?? 0;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // --- TAMPILAN NOTA PREMIUM ---
                Card(
                  color: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipPath(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Bagian Kepala Struk (Hijau Tua)
                        Container(
                          color: primaryColor,
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 20,
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'BUKTI PENGELUARAN',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatRupiah(nominal),
                                style: const TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        // Bagian Rincian Informasi
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow(
                                title: 'KATEGORI',
                                value: kategori,
                                icon: Icons.category_rounded,
                              ),
                              const Divider(height: 32),
                              _buildDetailRow(
                                title: 'TANGGAL KELUAR',
                                value: _formatDate(tgl),
                                icon: Icons.calendar_today_rounded,
                              ),
                              const Divider(height: 32),
                              _buildDetailRow(
                                title: 'KETERANGAN / DESKRIPSI',
                                value: deskripsi.isNotEmpty ? deskripsi : '-',
                                icon: Icons.description_rounded,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // --- TOMBOL HAPUS DATA ---
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isDeleting ? null : () => _handleDelete(finalId),
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.redAccent,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded, size: 22),
                    label: const Text(
                      'Hapus Catatan Pengeluaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF004D40), size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
