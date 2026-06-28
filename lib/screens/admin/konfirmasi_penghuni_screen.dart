import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KonfirmasiPenghuniScreen extends StatefulWidget {
  final int idRequest;

  const KonfirmasiPenghuniScreen({
    super.key,
    required this.idRequest,
  });

  @override
  State<KonfirmasiPenghuniScreen> createState() => _KonfirmasiPenghuniScreenState();
}

class _KonfirmasiPenghuniScreenState extends State<KonfirmasiPenghuniScreen> {
  static const primaryColor = Color(0xFF004D40);

  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, dynamic>? _requestData;
  Map<String, dynamic>? _detailPenyewaData;
  Map<String, dynamic>? _kamarData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;

      // 1. Fetch request_join
      final request = await client
          .from('request_join')
          .select()
          .eq('id_request', widget.idRequest)
          .single();
      _requestData = request;

      final idKamar = request['id_kamar'];
      final idUser = request['id_user'];

      // 2. Fetch kamar info
      final kamar = await client
          .from('kamar')
          .select()
          .eq('id_kamar', idKamar)
          .single();
      _kamarData = kamar;

      // 3. Fetch detail_penyewa info by id_user
      final detailPenyewa = await client
          .from('detail_penyewa')
          .select()
          .eq('id_user', idUser)
          .maybeSingle();
      _detailPenyewaData = detailPenyewa;

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data pengajuan: $e'),
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

  Future<void> _setujuiPengajuan() async {
    if (_requestData == null) return;

    setState(() => _isProcessing = true);
    try {
      final client = Supabase.instance.client;
      final idUser = _requestData!['id_user'];
      final idKamar = _requestData!['id_kamar'];

      // Fallbacks if data is missing from detail_penyewa
      final String nik = _detailPenyewaData?['nik'] ?? 'NIK-AUTO-${DateTime.now().millisecondsSinceEpoch}';
      final String tempatLahir = _detailPenyewaData?['tempat_lahir'] ?? '-';
      final String tanggalLahir = _detailPenyewaData?['tanggal_lahir'] ?? '2000-01-01';
      final String jenisKelamin = _detailPenyewaData?['jenis_kelamin'] ?? '-';
      final String alamatKtp = _detailPenyewaData?['alamat_ktp'] ?? '-';
      final String pekerjaan = _detailPenyewaData?['pekerjaan'] ?? '-';
      final String? fotoKtpUrl = _detailPenyewaData?['foto_ktp_url'];

      // Attempt to retrieve metadata for name and WhatsApp from user_metadata / fallbacks
      final String nama = _detailPenyewaData?['nama_lengkap'] ?? 'Penghuni Baru';
      final String noWa = _detailPenyewaData?['nomor_whatsapp'] ?? '-';

      // 1. Insert to detail_penyewa if not exists
      final existingDetail = await client
          .from('detail_penyewa')
          .select()
          .eq('nik', nik)
          .maybeSingle();

      if (existingDetail == null) {
        await client.from('detail_penyewa').insert({
          'nik': nik,
          'id_user': idUser,
          'tempat_lahir': tempatLahir,
          'tanggal_lahir': tanggalLahir,
          'jenis_kelamin': jenisKelamin,
          'alamat_ktp': alamatKtp,
          'pekerjaan': pekerjaan,
          'foto_ktp_url': fotoKtpUrl,
        });
      }

      // 1b. Insert to penyewa if not exists
      final existingPenyewa = await client
          .from('penyewa')
          .select()
          .eq('nik', nik)
          .maybeSingle();

      int idPenyewa;
      if (existingPenyewa == null) {
        final newPenyewa = await client
            .from('penyewa')
            .insert({
              'nik': nik,
              'nomor_whatsapp': noWa,
              'nama_lengkap': nama,
            })
            .select()
            .single();
        idPenyewa = newPenyewa['id_penyewa'];
      } else {
        idPenyewa = existingPenyewa['id_penyewa'];
      }

      // 2. Insert to sewa
      final today = DateTime.now().toIso8601String().split('T').first;
      await client.from('sewa').insert({
        'id_kamar': idKamar,
        'id_penyewa': idPenyewa,
        'tanggal_masuk': today,
        'durasi_bulan': 1,
        'status_sewa': 'Aktif',
      });

      // 3. Update status_kamar in kamar
      await client
          .from('kamar')
          .update({'status_kamar': 'Terisi'})
          .eq('id_kamar', idKamar);

      // 4. Update status_request in request_join
      await client
          .from('request_join')
          .update({'status_request': 'Disetujui'})
          .eq('id_request', widget.idRequest);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan disetujui! Kamar sekarang Terisi.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses persetujuan: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _tolakPengajuan() async {
    setState(() => _isProcessing = true);
    try {
      final client = Supabase.instance.client;

      // Update status_request to Ditolak
      await client
          .from('request_join')
          .update({'status_request': 'Ditolak'})
          .eq('id_request', widget.idRequest);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan calon penghuni telah ditolak.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menolak pengajuan: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text(
          'Konfirmasi Calon Penghuni',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- KAMAR INFO HEADER ---
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.meeting_room, color: primaryColor, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kamar ${_kamarData?['nomor_kamar'] ?? '-'}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Token: ${_kamarData?['kode_kamar'] ?? '-'}',
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- DATA CALON PENGHUNI ---
                  const Text(
                    'Detail Calon Penghuni',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),

                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.person_outline,
                            'Nama Lengkap',
                            _detailPenyewaData?['nama_lengkap'] ?? 'Penghuni Baru',
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            Icons.contact_mail_outlined,
                            'Email',
                            _detailPenyewaData?['email'] ?? '-',
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            Icons.badge_outlined,
                            'NIK KTP',
                            _detailPenyewaData?['nik'] ?? '-',
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            Icons.phone_iphone_outlined,
                            'No Telepon / WhatsApp',
                            _detailPenyewaData?['nomor_whatsapp'] ?? '-',
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            Icons.work_outline,
                            'Pekerjaan',
                            _detailPenyewaData?['pekerjaan'] ?? '-',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- PRATINJAU KTP ---
                  const Text(
                    'Pratinjau Berkas KTP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),

                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 1,
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: const BoxDecoration(color: Color(0xFFECEFF1)),
                      child: (_detailPenyewaData?['foto_ktp_url'] != null &&
                              _detailPenyewaData!['foto_ktp_url'].toString().isNotEmpty)
                          ? Image.network(
                              _detailPenyewaData!['foto_ktp_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Gagal memuat foto KTP', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.credit_card, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Tidak ada lampiran KTP', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // --- BUTTONS ACTION ---
                  if (_isProcessing)
                    const Center(child: CircularProgressIndicator(color: primaryColor))
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _tolakPengajuan,
                            child: const Text(
                              'TOLAK',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _setujuiPengajuan,
                            child: const Text(
                              'SETUJUI',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primaryColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
