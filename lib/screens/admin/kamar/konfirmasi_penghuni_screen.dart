import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/notification_service.dart';

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
  // Theme colors
  static const Color primaryColor = Color(0xFF004D40); // Teal
  static const Color accentColor = Color(0xFFFFA834);  // Orange

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

  // Formatting datetime to Indonesian format with time (e.g. Minggu, 5 Juli 2026 pukul 14:30)
  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dateUtc = DateTime.parse(dateStr);
      final date = dateUtc.toLocal();
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final days = [
        'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
      ];
      final dayName = days[date.weekday - 1];
      final monthName = months[date.month - 1];
      
      // Jika data tanggal tidak memiliki komponen waktu (jam, menit, detik = 0 dalam UTC), cukup tampilkan tanggal saja
      if (dateUtc.hour == 0 && dateUtc.minute == 0 && dateUtc.second == 0) {
        return '$dayName, ${date.day} $monthName ${date.year}';
      }
      
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$dayName, ${date.day} $monthName ${date.year} pukul $hour:$minute';
    } catch (e) {
      return dateStr;
    }
  }

  // Calculated estimated move-in date (+3 days from request)
  String _getPerkiraanTanggalMasuk(String? tanggalPengajuanStr) {
    if (tanggalPengajuanStr == null || tanggalPengajuanStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(tanggalPengajuanStr).toLocal();
      final estimatedDate = date.add(const Duration(days: 3));
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${estimatedDate.day} ${months[estimatedDate.month - 1]} ${estimatedDate.year}';
    } catch (e) {
      return '-';
    }
  }

  // Formatting currency to Rupiah format
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

  // Extract file name from Supabase storage URL
  String _getFileName(String? urlStr) {
    if (urlStr == null || urlStr.isEmpty) return 'KTP_Belum_Diunggah.jpg';
    try {
      final uri = Uri.parse(urlStr);
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
    } catch (_) {}
    return 'KTP_Calon_Penghuni.jpg';
  }

  Future<void> _loadData() async {
    if (!mounted) return;
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
            content: Text('Gagal memuat data: $e'),
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

      // Fallbacks if profile details do not exist
      final String nik = _detailPenyewaData?['nik'] ?? 'NIK-AUTO-${DateTime.now().millisecondsSinceEpoch}';
      final String tempatLahir = _detailPenyewaData?['tempat_lahir'] ?? '-';
      final String tanggalLahir = _detailPenyewaData?['tanggal_lahir'] ?? '2000-01-01';
      final String jenisKelamin = _detailPenyewaData?['jenis_kelamin'] ?? '-';
      final String alamatKtp = _detailPenyewaData?['alamat_ktp'] ?? '-';
      final String pekerjaan = _detailPenyewaData?['pekerjaan'] ?? '-';
      final String? fotoKtpUrl = _detailPenyewaData?['foto_ktp_url'];
      final String? fotoProfilUrl = _detailPenyewaData?['foto_profil_url'];

      final String nama = _detailPenyewaData?['nama_lengkap'] ?? 'Penghuni Baru';
      final String noWa = _detailPenyewaData?['nomor_whatsapp'] ?? '-';

      // 1. Ensure detail_penyewa exists
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
          'foto_profil_url': fotoProfilUrl,
          'nama_lengkap': nama,
          'nomor_whatsapp': noWa,
        });
      }

      // 2. Ensure penyewa exists
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

      // 3. Insert new sewa record
      final today = DateTime.now().toIso8601String().split('T').first;
      await client.from('sewa').insert({
        'id_kamar': idKamar,
        'id_penyewa': idPenyewa,
        'tanggal_masuk': today,
        'durasi_bulan': 1,
        'status_sewa': 'Aktif',
      });

      // 4. Update status_kamar in kamar to 'Terisi'
      await client
          .from('kamar')
          .update({'status_kamar': 'Terisi'})
          .eq('id_kamar', idKamar);

      // 5. Update status_request in request_join to 'Disetujui'
      await client
          .from('request_join')
          .update({'status_request': 'Disetujui'})
          .eq('id_request', widget.idRequest);

      // 6. Send notification to tenant and owner
      try {
        final roomNo = _kamarData?['nomor_kamar'] ?? '-';
        await NotificationService.sendNotification(
          idUser: idUser,
          judul: 'Pengajuan Bergabung Disetujui! 🎉',
          pesan: 'Selamat! Pengajuan Anda ke Kamar $roomNo telah disetujui.',
          kategori: 'penyewa',
        );

        // Kirim notifikasi ke Pemilik Kost (admin)
        final idAdmin = _kamarData?['id_admin'] ?? client.auth.currentUser?.id;
        if (idAdmin != null) {
          await NotificationService.sendNotification(
            idUser: idAdmin,
            judul: 'Penghuni Baru Bergabung! 🏠',
            pesan: '$nama telah berhasil bergabung ke Kamar $roomNo.',
            kategori: 'penyewa_join',
          );
        }
      } catch (e) {
        debugPrint('Gagal mengirim notifikasi persetujuan/bergabung: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan berhasil disetujui! Kamar terisi.'),
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
            content: Text('Gagal menyetujui pengajuan: $e'),
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

      // Update status_request to 'Ditolak'
      await client
          .from('request_join')
          .update({'status_request': 'Ditolak'})
          .eq('id_request', widget.idRequest);

      // Send notification to tenant
      try {
        final idUser = _requestData?['id_user'];
        final roomNo = _kamarData?['nomor_kamar'] ?? '-';
        if (idUser != null) {
          await NotificationService.sendNotification(
            idUser: idUser,
            judul: 'Pengajuan Bergabung Ditolak ❌',
            pesan: 'Maaf, pengajuan Anda ke Kamar $roomNo telah ditolak.',
            kategori: 'penyewa',
          );
        }
      } catch (e) {
        debugPrint('Gagal mengirim notifikasi penolakan: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan berhasil ditolak.'),
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

  void _lihatFotoKtp() {
    final String? url = _detailPenyewaData?['foto_ktp_url'];
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calon penghuni belum mengunggah berkas KTP'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Photo view area
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.transparent,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Bar of the modal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 12.0),
                          child: Text(
                            'Berkas KTP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    // Image network
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.6,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(
                              height: 200,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 48, color: Colors.redAccent),
                                    SizedBox(height: 8),
                                    Text('Gagal memuat gambar KTP', style: TextStyle(color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? profilePhoto = _detailPenyewaData?['foto_profil_url'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text(
          'Konfirmasi Penghuni',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- BADGE STATUS ---
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentColor, width: 1.5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, color: accentColor, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Menunggu Konfirmasi',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- CARD PROFIL CALON PENGHUNI ---
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          // Profile Circle Avatar
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFE8F5F2),
                              border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 3),
                            ),
                            child: ClipOval(
                              child: (profilePhoto != null && profilePhoto.isNotEmpty)
                                  ? Image.network(
                                      profilePhoto,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.person,
                                        size: 45,
                                        color: primaryColor,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 45,
                                      color: primaryColor,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Tenant Details Title
                          const Text(
                            'Data Diri Calon Penghuni',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // Data rows
                          _buildProfileRow(
                            Icons.person_outline,
                            'Nama',
                            _detailPenyewaData?['nama_lengkap'] ?? 'Penghuni Baru',
                          ),
                          const SizedBox(height: 14),
                          _buildProfileRow(
                            Icons.email_outlined,
                            'Email',
                            _detailPenyewaData?['email'] ?? '-',
                          ),
                          const SizedBox(height: 14),
                          _buildProfileRow(
                            Icons.phone_iphone_outlined,
                            'No. Telepon',
                            _detailPenyewaData?['nomor_whatsapp'] ?? '-',
                          ),
                          const SizedBox(height: 14),
                          _buildProfileRow(
                            Icons.badge_outlined,
                            'NIK',
                            _detailPenyewaData?['nik'] ?? '-',
                          ),
                          const SizedBox(height: 14),
                          _buildProfileRow(
                            Icons.meeting_room_outlined,
                            'Nama Kamar',
                            _kamarData != null ? 'Kamar ${_kamarData!['nomor_kamar']}' : '-',
                          ),
                          const SizedBox(height: 14),
                          _buildProfileRow(
                            Icons.monetization_on_outlined,
                            'Harga Sewa',
                            _kamarData != null ? '${_formatRupiah(_kamarData!['harga_sewa_dasar'])} / Bulan' : '-',
                          ),
                          const SizedBox(height: 14),
                          _buildProfileRow(
                            Icons.calendar_month_outlined,
                            'Perkiraan Tanggal Masuk',
                            _getPerkiraanTanggalMasuk(_requestData?['tanggal_pengajuan']),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- CARD DOKUMEN IDENTITAS ---
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.credit_card_outlined,
                              color: primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dokumen Identitas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getFileName(_detailPenyewaData?['foto_ktp_url']),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              elevation: 0,
                            ),
                            onPressed: _lihatFotoKtp,
                            child: const Text(
                              'Lihat Foto',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- CATATAN INFORMASI WAKTU ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.15), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: primaryColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Penyewa mengajukan permintaan pada ${_formatDateTime(_requestData?['tanggal_pengajuan'])}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // --- ACTION BUTTONS ---
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _tolakPengajuan,
                            child: const Text(
                              'TOLAK',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32), // Green
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _setujuiPengajuan,
                            child: const Text(
                              'SETUJUI',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primaryColor.withValues(alpha: 0.7), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
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
        ),
      ],
    );
  }
}
