import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Skema Supabase (aktif):
// penyewa   : id_penyewa (int8 PK), nik (text), nomor_whatsapp (text), nama_lengkap (text)
// sewa      : id_sewa (int8 PK), id_kamar (int8 FK), id_penyewa (int8 FK),
//             tanggal_masuk (date), durasi_bulan (int4), status_sewa (text)

class PenyewaFormScreen extends StatefulWidget {
  /// Jika edit: kirim penyewaData dan sewaData
  final Map<String, dynamic>? penyewaData;
  final Map<String, dynamic>? sewaData;

  /// Opsional — preselect kamar tertentu
  final int? preselectedKamarId;
  final String? preselectedKamarNomor;

  const PenyewaFormScreen({
    super.key,
    this.penyewaData,
    this.sewaData,
    this.preselectedKamarId,
    this.preselectedKamarNomor,
  });

  @override
  State<PenyewaFormScreen> createState() => _PenyewaFormScreenState();
}

class _PenyewaFormScreenState extends State<PenyewaFormScreen> {
  static const primaryColor = Color(0xFF004D40);

  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _waController = TextEditingController(); // nomor_whatsapp
  final _nikController = TextEditingController(); // nik

  DateTime? _tanggalMasuk;
  int _durasibulan = 1;
  int? _selectedKamarId;

  List<Map<String, dynamic>> _availableKamars = [];
  bool _isLoading = false;
  bool _isLoadingKamars = true;

  bool get _isEditMode => widget.penyewaData != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _namaController.text = widget.penyewaData?['nama_lengkap'] ?? '';
      _waController.text = widget.penyewaData?['nomor_whatsapp'] ?? '';
      _nikController.text = widget.penyewaData?['nik'] ?? '';

      final tanggalStr = widget.sewaData?['tanggal_masuk'];
      if (tanggalStr != null) {
        _tanggalMasuk = DateTime.tryParse(tanggalStr);
      }
      _durasibulan = widget.sewaData?['durasi_bulan'] as int? ?? 1;
    }

    if (widget.preselectedKamarId != null) {
      _selectedKamarId = widget.preselectedKamarId;
    }

    _loadAvailableKamars();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _waController.dispose();
    _nikController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableKamars() async {
    setState(() => _isLoadingKamars = true);
    try {
      final client = Supabase.instance.client;
      final adminId = client.auth.currentUser?.id;
      if (adminId == null) {
        _availableKamars = [];
        return;
      }

      final List<dynamic> result;
      if (_isEditMode && _selectedKamarId != null) {
        result = await client
            .from('kamar')
            .select('id_kamar, nomor_kamar')
            .eq('id_admin', adminId)
            .or('status_kamar.eq.Kosong,id_kamar.eq.$_selectedKamarId');
      } else {
        result = await client
            .from('kamar')
            .select('id_kamar, nomor_kamar')
            .eq('id_admin', adminId)
            .eq('status_kamar', 'Kosong');
      }
      _availableKamars = List<Map<String, dynamic>>.from(result);
    } catch (e) {
      _availableKamars = [];
    } finally {
      if (mounted) setState(() => _isLoadingKamars = false);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      '',
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
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalMasuk ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: primaryColor,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _tanggalMasuk = picked);
  }

  Future<void> _handleSimpan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tanggalMasuk == null) {
      _showSnack('Tanggal masuk wajib diisi', isError: true);
      return;
    }
    if (_selectedKamarId == null) {
      _showSnack('Pilih kamar terlebih dahulu', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final nama = _namaController.text.trim();
      final wa = _waController.text.trim();
      final nik = _nikController.text.trim();
      final tglMasuk = _tanggalMasuk!.toIso8601String().split('T').first;

      if (_isEditMode) {
        // ── 1. UPDATE detail_penyewa terlebih dahulu ──
        await client
            .from('detail_penyewa')
            .update({
              'tempat_lahir': '-',
              'tanggal_lahir': '2000-01-01',
              'jenis_kelamin': '-',
              'alamat_ktp': '-',
              'pekerjaan': '-',
            })
            .eq('nik', widget.penyewaData!['nik']);

        // ── 2. UPDATE penyewa ──
        final penyewaId = widget.penyewaData!['id_penyewa'];
        await client
            .from('penyewa')
            .update({'nama_lengkap': nama, 'nomor_whatsapp': wa, 'nik': nik})
            .eq('id_penyewa', penyewaId);

        // ── 3. UPDATE sewa ──
        final sewaId = widget.sewaData!['id_sewa'];
        await client
            .from('sewa')
            .update({
              'id_kamar': _selectedKamarId,
              'tanggal_masuk': tglMasuk,
              'durasi_bulan': _durasibulan,
            })
            .eq('id_sewa', sewaId);
      } else {
        // ── 1. WAJIB INSERT KE detail_penyewa DULUAN AGAR NIK TERDAFTAR ──
        await client.from('detail_penyewa').insert({
          'nik': nik,
          'tempat_lahir':
              '-', // Mengisi fallback data dummy agar tidak kena error NOT NULL
          'tanggal_lahir': '2000-01-01',
          'jenis_kelamin': '-',
          'alamat_ktp': '-',
          'pekerjaan': '-',
        });

        // ── 2. BARU INSERT KE TABEL penyewa (Sudah aman karena NIK sudah lolos validasi FK) ──
        final penyewaRes = await client
            .from('penyewa')
            .insert({'nama_lengkap': nama, 'nomor_whatsapp': wa, 'nik': nik})
            .select()
            .single();

        final penyewaId = penyewaRes['id_penyewa'];

        // ── 3. INSERT ke tabel sewa ──
        await client.from('sewa').insert({
          'id_penyewa': penyewaId,
          'id_kamar': _selectedKamarId,
          'tanggal_masuk': tglMasuk,
          'durasi_bulan': _durasibulan,
          'status_sewa': 'Aktif',
        });

        // ── 4. Update status kamar → Terisi ──
        await client
            .from('kamar')
            .update({'status_kamar': 'Terisi'})
            .eq('id_kamar', _selectedKamarId!);
      }

      if (mounted) {
        _showSnack(
          _isEditMode
              ? 'Data penyewa berhasil diperbarui!'
              : 'Penyewa berhasil ditambahkan!',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Gagal menyimpan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Penyewa' : 'Tambah Penyewa',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                color: Colors.white,
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Nama Lengkap ──
                      _label('Nama Lengkap'),
                      _textField(
                        controller: _namaController,
                        hint: 'Masukkan nama lengkap penyewa',
                        keyboardType: TextInputType.name,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Nama tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── No. WhatsApp ──
                      _label('No. WhatsApp'),
                      _textField(
                        controller: _waController,
                        hint: 'Contoh: 081234567890',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'No. WhatsApp tidak boleh kosong';
                          }
                          if (v.length < 10) {
                            return 'No. WhatsApp tidak valid';
                          }
                          return null;
                        },
                        prefixIcon: const Icon(
                          Icons.phone_android_outlined,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── NIK ──
                      _label('No. KTP (NIK)'),
                      _textField(
                        controller: _nikController,
                        hint: 'Masukkan 16 digit NIK',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'NIK tidak boleh kosong';
                          }
                          if (v.length != 16) {
                            return 'NIK harus 16 digit';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Tanggal Masuk ──
                      _label('Tanggal Masuk'),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _tanggalMasuk != null
                                      ? _formatDate(_tanggalMasuk!)
                                      : 'Pilih tanggal masuk',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _tanggalMasuk != null
                                        ? Colors.black87
                                        : Colors.grey[400],
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 20,
                                color: Colors.grey[500],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Pilih Kamar ──
                      _label('Pilih Kamar'),
                      _isLoadingKamars
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: CircularProgressIndicator(
                                  color: primaryColor,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : _availableKamars.isEmpty && !_isEditMode
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange[700],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Tidak ada kamar kosong. Tambah kamar terlebih dahulu.',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<int>(
                              initialValue: _selectedKamarId,
                              hint: Text(
                                'Pilih kamar kosong',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                              items: _availableKamars.map((kamar) {
                                final id = kamar['id_kamar'] as int;
                                final nomor = kamar['nomor_kamar'] as String;
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text('Kamar $nomor'),
                                );
                              }).toList(),
                              decoration: _dropdownDecoration(),
                              onChanged: (v) =>
                                  setState(() => _selectedKamarId = v),
                              validator: (v) => v == null
                                  ? 'Pilih kamar terlebih dahulu'
                                  : null,
                            ),
                      const SizedBox(height: 28),

                      // ── Tombol Simpan ──
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _handleSimpan,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  _isEditMode
                                      ? 'Simpan Perubahan'
                                      : 'Tambah Penyewa',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    ),
  );

  InputDecoration _dropdownDecoration() => InputDecoration(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: primaryColor, width: 1.5),
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter> inputFormatters = const [],
    String? Function(String?)? validator,
    Widget? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: prefixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}
