import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'invoice_penghuni_screen.dart';
import '../../../services/notification_service.dart';

class DetailTagihanScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  const DetailTagihanScreen({super.key, required this.invoice});

  static const Color _primaryColor = Color(0xFF007461);
  static const Color _backgroundColor = Color(0xFFF4F6F7);
  static const Color _dangerColor = Color(0xFFFF3B30);

  @override
  State<DetailTagihanScreen> createState() => _DetailTagihanScreenState();
}

class _DetailTagihanScreenState extends State<DetailTagihanScreen> {
  XFile? _imageFile;
  bool _isUploading = false;
  late String _statusPembayaran;
  String? _buktiTransferUrl;

  String _nomorKamar = '-';
  String _namaKos = '-';

  @override
  void initState() {
    super.initState();
    _statusPembayaran = widget.invoice['status_pembayaran'] ?? 'BELUM';
    _buktiTransferUrl = widget.invoice['bukti_transfer_url'];
    _fetchSewaDetails();
  }

  Future<void> _fetchSewaDetails() async {
    try {
      final supabase = Supabase.instance.client;
      final sewa = await supabase
          .from('sewa')
          .select()
          .eq('id_sewa', widget.invoice['id_sewa'])
          .maybeSingle();

      if (sewa != null) {
        final idKamar = sewa['id_kamar'];
        final kamar = await supabase
            .from('kamar')
            .select()
            .eq('id_kamar', idKamar)
            .maybeSingle();

        if (kamar != null) {
          final String? idAdmin = kamar['id_admin'];
          if (mounted) {
            setState(() {
              _nomorKamar = "Kamar ${kamar['nomor_kamar']}";
            });
          }

          if (idAdmin != null) {
            final admin = await supabase
                .from('profil_admin')
                .select()
                .eq('id_admin', idAdmin)
                .maybeSingle();
            if (admin != null && mounted) {
              setState(() {
                _namaKos = admin['nama_kost'] ?? '-';
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    if (_statusPembayaran.toUpperCase() == 'LUNAS') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tagihan ini sudah lunas!'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih gambar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _uploadBuktiPembayaran() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih foto struk/bukti transfer terlebih dahulu!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Pengguna tidak masuk.');

      final String fileExtension = _imageFile!.name.split('.').last.isNotEmpty
          ? _imageFile!.name.split('.').last
          : 'jpg';
      final String fileName = 'bukti_invoice_${widget.invoice['id_invoice']}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final String filePath = 'bukti_transfer/$fileName';

      final bytes = await _imageFile!.readAsBytes();

      // Upload ke bucket 'bukti_transfer' menggunakan bytes (Uint8List)
      await supabase.storage.from('bukti_transfer').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      final String publicUrl = supabase.storage.from('bukti_transfer').getPublicUrl(filePath);

      // Update database invoice
      await supabase
          .from('invoice')
          .update({
            'bukti_transfer_url': publicUrl,
            'status_pembayaran': 'Menunggu Verifikasi',
          })
          .eq('id_invoice', widget.invoice['id_invoice']);

      // Kirim Notifikasi Skenario B (User -> Admin)
      try {
        final String? adminId = await NotificationService.getAdminUserId(widget.invoice['id_sewa']);
        if (adminId != null) {
          final String title = 'Bukti Pembayaran Baru 🔔';
          final String roomNo = _nomorKamar.replaceAll(RegExp(r'[^0-9]'), '');
          final String msg = 'Penyewa Kamar $roomNo telah mengunggah bukti transfer untuk diverifikasi.';
          await NotificationService.sendNotification(
            idUser: adminId,
            judul: title,
            pesan: msg,
            kategori: 'admin',
          );
        }
      } catch (e) {
        debugPrint('Gagal mengirim notifikasi upload bukti pembayaran: $e');
      }

      if (mounted) {
        setState(() {
          _statusPembayaran = 'Menunggu Verifikasi';
          _buktiTransferUrl = publicUrl;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bukti transfer berhasil diunggah! Menunggu verifikasi admin.'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah bukti: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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

  String _getNamaBulan(int month) {
    const listBulan = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    if (month >= 1 && month <= 12) {
      return listBulan[month - 1];
    }
    return '';
  }

  String _getBulanSewa(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return "${_getNamaBulan(date.month)} ${date.year}";
    } catch (_) {
      return '';
    }
  }

  String _getShortBulan(int month) {
    const listBulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    if (month >= 1 && month <= 12) {
      return listBulan[month - 1];
    }
    return '';
  }

  String _formatTanggal(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day} ${_getShortBulan(date.month)} ${date.year}";
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPaid = _statusPembayaran.toUpperCase() == 'LUNAS';
    final bool isPending = _statusPembayaran == 'Menunggu Verifikasi';

    String statusLabel = 'BELUM BAYAR';
    Color pillBg = const Color(0xFFFFE6E4);
    Color pillText = DetailTagihanScreen._dangerColor;

    if (isPaid) {
      statusLabel = 'LUNAS';
      pillBg = const Color(0xFFDEF7EC);
      pillText = DetailTagihanScreen._primaryColor;
    } else if (isPending) {
      statusLabel = 'MENUNGGU VERIFIKASI';
      pillBg = const Color(0xFFFEF3C7);
      pillText = const Color(0xFFD97706);
    }

    return Scaffold(
      backgroundColor: DetailTagihanScreen._backgroundColor,
      appBar: AppBar(
        backgroundColor: DetailTagihanScreen._primaryColor,
        elevation: 0,
        toolbarHeight: 54,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        titleSpacing: 0,
        title: const Text(
          'Detail Tagihan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _StatusPill(
                  label: statusLabel,
                  backgroundColor: pillBg,
                  textColor: pillText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _formatRupiah(widget.invoice['total_tagihan']),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1F2933),
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pembayaran Sewa Kamar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              _buildInfoCard(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InvoicePenghuniScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: DetailTagihanScreen._primaryColor,
                  side: const BorderSide(color: DetailTagihanScreen._primaryColor, width: 1.5),
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 17),
                label: const Text(
                  'Lihat Invoice',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Upload Bukti Pembayaran',
                style: TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFB9C2C8),
                      width: 1.2,
                    ),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: kIsWeb
                              ? Image.network(
                                  _imageFile!.path,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                              : Image.file(
                                  io.File(_imageFile!.path),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                        )
                      : _buktiTransferUrl != null && _buktiTransferUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.network(
                                _buktiTransferUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(child: Icon(Icons.image, size: 40, color: Colors.grey));
                                },
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  color: Color(0xFF8C9AA1),
                                  size: 28,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Ketuk untuk upload foto struk',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 24),
              if (!isPaid && !isPending)
                _isUploading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _uploadBuktiPembayaran,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DetailTagihanScreen._primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Kirim ke Pemilik',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      child: Column(
        children: [
          _InfoRow(label: 'Periode', value: _getBulanSewa(widget.invoice['tanggal_dibuat'])),
          _InfoRow(label: 'Tanggal', value: _formatTanggal(widget.invoice['tanggal_dibuat'])),
          _InfoRow(label: 'Kamar', value: _nomorKamar),
          _InfoRow(label: 'Kos', value: _namaKos),
          _InfoRow(label: 'ID Transaksi', value: widget.invoice['nomor_invoice'] ?? '-'),
        ],
      ),
    );
  }
}



class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2F3), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
