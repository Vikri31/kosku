import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/notification_service.dart';
import 'transaksi_detail_screen.dart';

class TambahTransaksiScreen extends StatefulWidget {
  final int? initialSewaId;
  const TambahTransaksiScreen({super.key, this.initialSewaId});

  @override
  State<TambahTransaksiScreen> createState() => _TambahTransaksiScreenState();
}

class _TambahTransaksiScreenState extends State<TambahTransaksiScreen> {
  // Theme colors
  static const Color primaryColor = Color(0xFF004D40); // Teal
  static const Color accentColor = Color(0xFFFFA834);  // Orange
  static const Color backgroundColor = Color(0xFFF5F7F8);

  final _formKey = GlobalKey<FormState>();
  final _nominalController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _catatanController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _activeLeases = [];
  Map<String, dynamic>? _selectedLease;
  DateTime _selectedDate = DateTime.now();
  bool _isPaid = true;

  @override
  void initState() {
    super.initState();
    _tanggalController.text = _formatInputDate(_selectedDate);
    _loadActiveLeases();
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _tanggalController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  // Formatting date helper for text field display
  String _formatInputDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Load active leases from Supabase (filtered by current admin)
  Future<void> _loadActiveLeases() async {
    try {
      final client = Supabase.instance.client;
      final adminId = client.auth.currentUser?.id;

      if (adminId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 1. Ambil id_kamar milik admin ini
      final kamarData = await client
          .from('kamar')
          .select('id_kamar')
          .eq('id_admin', adminId);

      if (kamarData.isEmpty) {
        if (mounted) {
          setState(() {
            _activeLeases = [];
            _isLoading = false;
          });
        }
        return;
      }

      final List<int> kamarIds = (kamarData as List)
          .map((k) => k['id_kamar'] as int)
          .toList();

      // 2. Ambil sewa aktif hanya dari kamar milik admin
      final data = await client
          .from('sewa')
          .select('*, penyewa(*), kamar(*)')
          .eq('status_sewa', 'Aktif')
          .inFilter('id_kamar', kamarIds);

      if (mounted) {
        setState(() {
          _activeLeases = List<Map<String, dynamic>>.from(data);
          if (widget.initialSewaId != null) {
            final found = _activeLeases.firstWhere(
              (lease) => lease['id_sewa'] == widget.initialSewaId,
              orElse: () => <String, dynamic>{},
            );
            if (found.isNotEmpty) {
              _selectedLease = found;
              if (found['kamar'] != null) {
                final harga = found['kamar']['harga_sewa_dasar'] ?? 0;
                _nominalController.text = harga.toString();
              }
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat penyewa: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Date picker dialog
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _tanggalController.text = _formatInputDate(picked);
      });
    }
  }

  // Save transaction to Supabase
  Future<void> _simpanTransaksi() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLease == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih penyewa terlebih dahulu'),
          backgroundColor: accentColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final client = Supabase.instance.client;
      final idSewa = _selectedLease!['id_sewa'];
      final nominal = int.parse(_nominalController.text.replaceAll(RegExp(r'[^0-9]'), ''));

      // Generate invoice number
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final invoiceNumber = 'INV-${_selectedDate.year}${_selectedDate.month.toString().padLeft(2, '0')}-$timestamp';

      final tanggalDibuatStr = _selectedDate.toIso8601String().split('T').first;
      final tanggalJatuhTempoStr = _selectedDate.add(const Duration(days: 7)).toIso8601String().split('T').first;
      final statusPembayaran = _isPaid ? 'Lunas' : 'Belum Bayar';

      // 1. Insert to invoice table
      final insertedInvoice = await client
          .from('invoice')
          .insert({
            'id_sewa': idSewa,
            'nomor_invoice': invoiceNumber,
            'tanggal_dibuat': tanggalDibuatStr,
            'tanggal_jatuh_tempo': tanggalJatuhTempoStr,
            'total_tagihan': nominal,
            'status_pembayaran': statusPembayaran,
          })
          .select()
          .single();

      final int idInvoice = insertedInvoice['id_invoice'];

      // Kirim Notifikasi Skenario A (Admin -> User)
      try {
        final String? userPenyewaId = await NotificationService.getPenyewaUserId(idSewa);
        if (userPenyewaId != null) {
          final buffer = StringBuffer();
          final strVal = nominal.toString();
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
            judul: 'Tagihan Baru Tersedia 🧾',
            pesan: 'Tagihan baru sebesar $formattedNominal telah dibuat. Harap lakukan pembayaran sebelum jatuh tempo.',
            kategori: 'penyewa',
          );
        }
      } catch (e) {
        debugPrint('Gagal mengirim notifikasi pembuatan invoice: $e');
      }

      // 2. If status is Lunas, insert to pemasukan table
      if (_isPaid) {
        await client.from('pemasukan').insert({
          'id_invoice': idInvoice,
          'tanggal_bayar': tanggalDibuatStr,
          'nominal_masuk': nominal,
          'metode_bayar': 'Transfer', // Default payment method
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil disimpan!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        if (widget.initialSewaId == null) {
          // Skenario 2: Navigasi ke Detail Transaksi (lalu ke generate & share invoice)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DetailTransaksiScreen(idInvoice: idInvoice),
            ),
          );
        } else {
          // Skenario 1: Langsung kembali ke halaman Detail Kamar
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan transaksi: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Tambah Transaksi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dropdown Penyewa
                            _InputBlock(
                              label: 'Pilih Penyewa',
                              child: DropdownButtonFormField<Map<String, dynamic>>(
                                initialValue: _selectedLease,
                                decoration: _inputDecoration(),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                                hint: const Text('Pilih Penyewa (Kamar)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                items: _activeLeases.map((lease) {
                                  final penyewaName = lease['penyewa']?['nama_lengkap'] ?? 'Penyewa';
                                  final roomNum = lease['kamar']?['nomor_kamar'] ?? '-';
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: lease,
                                    child: Text('$penyewaName (Kamar $roomNum)', style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedLease = value;
                                    if (value != null && value['kamar'] != null) {
                                      final harga = value['kamar']['harga_sewa_dasar'] ?? 0;
                                      _nominalController.text = harga.toString();
                                    }
                                  });
                                },
                                validator: (val) => val == null ? 'Harap pilih penyewa' : null,
                              ),
                            ),

                            // Nominal
                            _InputBlock(
                              label: 'Nominal',
                              helperText: 'Nominal otomatis terisi sesuai harga kamar, namun dapat diubah.',
                              child: TextFormField(
                                controller: _nominalController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration(hint: 'Masukkan nominal pembayaran'),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Harap isi nominal';
                                  if (int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) == null) {
                                    return 'Harap isi dengan format angka valid';
                                  }
                                  return null;
                                },
                              ),
                            ),

                            // Tanggal Pembayaran
                            _InputBlock(
                              label: 'Tanggal Pembayaran',
                              child: TextFormField(
                                controller: _tanggalController,
                                readOnly: true,
                                onTap: _selectDate,
                                decoration: _inputDecoration().copyWith(
                                  suffixIcon: const Icon(Icons.calendar_month_outlined, size: 20, color: primaryColor),
                                ),
                              ),
                            ),

                            // Status Pembayaran
                            const Text(
                              'Status Pembayaran',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _RadioLabel(
                                  label: 'Lunas',
                                  selected: _isPaid,
                                  onTap: () => setState(() => _isPaid = true),
                                ),
                                const SizedBox(width: 24),
                                _RadioLabel(
                                  label: 'Belum',
                                  selected: !_isPaid,
                                  onTap: () => setState(() => _isPaid = false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Catatan
                            _InputBlock(
                              label: 'Catatan (Opsional)',
                              bottomMargin: 0,
                              child: TextFormField(
                                controller: _catatanController,
                                minLines: 3,
                                maxLines: 3,
                                decoration: _inputDecoration(hint: 'Tambahkan keterangan jika perlu...'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Button Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: _isSaving
                            ? const Center(child: CircularProgressIndicator(color: primaryColor))
                            : ElevatedButton.icon(
                                onPressed: _simpanTransaksi,
                                icon: const Icon(Icons.save_outlined, size: 20),
                                label: Text(
                                  widget.initialSewaId == null
                                      ? 'Simpan & Detail Transaksi'
                                      : 'Simpan Transaksi',
                                  style: const TextStyle(letterSpacing: 0.5),
                                ),
                                style: ElevatedButton.styleFrom(
                                  elevation: 2,
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

class _InputBlock extends StatelessWidget {
  final String label;
  final Widget child;
  final String? helperText;
  final double bottomMargin;

  const _InputBlock({
    required this.label,
    required this.child,
    this.helperText,
    this.bottomMargin = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          child,
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText!,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

class _RadioLabel extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadioLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? const Color(0xFF004D40) : Colors.grey.shade400,
                width: selected ? 6 : 2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
