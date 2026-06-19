import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PenyewaFormScreen extends StatefulWidget {
  /// If editing: pass penyewa and sewa data
  final Map<String, dynamic>? penyewaData;
  final Map<String, dynamic>? sewaData;

  /// Optionally pre-select a room
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
  final _phoneController = TextEditingController();
  final _ktpController = TextEditingController();

  DateTime? _tanggalMasuk;
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
      _phoneController.text = widget.penyewaData?['no_hp'] ?? '';
      _ktpController.text = widget.penyewaData?['no_ktp'] ?? '';

      final tanggalStr = widget.sewaData?['tanggal_masuk'];
      if (tanggalStr != null) {
        _tanggalMasuk = DateTime.tryParse(tanggalStr);
      }
    }

    if (widget.preselectedKamarId != null) {
      _selectedKamarId = widget.preselectedKamarId;
    }

    _loadAvailableKamars();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _phoneController.dispose();
    _ktpController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableKamars() async {
    setState(() => _isLoadingKamars = true);
    try {
      final client = Supabase.instance.client;
      // Load kosong rooms + the current room if editing
      final query = client.from('kamar').select('id_kamar, nomor_kamar');
      final List<dynamic> result;
      if (_isEditMode && _selectedKamarId != null) {
        // show all including current
        result = await query.or('status_kamar.eq.Kosong,id_kamar.eq.$_selectedKamarId');
      } else {
        result = await query.eq('status_kamar', 'Kosong');
      }
      _availableKamars = List<Map<String, dynamic>>.from(result);
    } catch (_) {
      _availableKamars = [];
    } finally {
      if (mounted) setState(() => _isLoadingKamars = false);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _tanggalMasuk = picked);
    }
  }

  Future<void> _handleSimpan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tanggalMasuk == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal masuk wajib diisi'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_selectedKamarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kamar terlebih dahulu'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final nama = _namaController.text.trim();
      final phone = _phoneController.text.trim();
      final ktp = _ktpController.text.trim();
      final tanggalMasukStr = _tanggalMasuk!.toIso8601String().split('T').first;

      // Calculate jatuh tempo: 1 month from tanggal masuk
      final jatuhTempo = DateTime(
        _tanggalMasuk!.year,
        _tanggalMasuk!.month + 1,
        _tanggalMasuk!.day,
      );
      final jatuhTempoStr = jatuhTempo.toIso8601String().split('T').first;

      int penyewaId;

      if (_isEditMode) {
        // Update penyewa
        penyewaId = widget.penyewaData!['id_penyewa'] as int;
        await client.from('penyewa').update({
          'nama_lengkap': nama,
          'no_hp': phone,
          'no_ktp': ktp,
        }).eq('id_penyewa', penyewaId);

        // Update sewa
        final sewaId = widget.sewaData!['id_sewa'] as int;
        await client.from('sewa').update({
          'id_kamar': _selectedKamarId,
          'tanggal_masuk': tanggalMasukStr,
          'tanggal_jatuh_tempo': jatuhTempoStr,
        }).eq('id_sewa', sewaId);
      } else {
        // Insert new penyewa
        final penyewaResult = await client.from('penyewa').insert({
          'nama_lengkap': nama,
          'no_hp': phone,
          'no_ktp': ktp,
        }).select().single();
        penyewaId = penyewaResult['id_penyewa'] as int;

        // Insert new sewa
        await client.from('sewa').insert({
          'id_penyewa': penyewaId,
          'id_kamar': _selectedKamarId,
          'tanggal_masuk': tanggalMasukStr,
          'tanggal_jatuh_tempo': jatuhTempoStr,
          'status_sewa': 'Aktif',
        });

        // Update kamar status to Terisi
        await client.from('kamar').update({'status_kamar': 'Terisi'}).eq('id_kamar', _selectedKamarId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Data penyewa berhasil diperbarui!' : 'Penyewa berhasil ditambahkan!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Penyewa' : 'Tambah Penyewa',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              // --- MAIN FORM CARD ---
              Card(
                color: Colors.white,
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama Lengkap
                      _buildFieldLabel('Nama Lengkap'),
                      _buildTextField(
                        controller: _namaController,
                        hint: 'Masukkan nama lengkap penyewa',
                        keyboardType: TextInputType.name,
                        inputFormatters: [],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Nama tidak boleh kosong';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // No. Handphone
                      _buildFieldLabel('No. Handphone'),
                      _buildTextField(
                        controller: _phoneController,
                        hint: 'Contoh: 081234567890',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'No. HP tidak boleh kosong';
                          if (v.length < 10) return 'No. HP tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // No. KTP
                      _buildFieldLabel('No. KTP (NIK)'),
                      _buildTextField(
                        controller: _ktpController,
                        hint: 'Masukkan 16 digit NIK',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'No. KTP tidak boleh kosong';
                          if (v.length != 16) return 'NIK harus 16 digit';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Tanggal Masuk
                      _buildFieldLabel('Tanggal Masuk'),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                                      : 'mm/dd/yyyy',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _tanggalMasuk != null ? Colors.black87 : Colors.grey[400],
                                  ),
                                ),
                              ),
                              Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey[500]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Pilih Kamar
                      _buildFieldLabel('Pilih Kamar'),
                      _isLoadingKamars
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
                              ),
                            )
                          : _availableKamars.isEmpty && !_isEditMode
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Tidak ada kamar kosong tersedia.',
                                          style: TextStyle(color: Colors.orange, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : DropdownButtonFormField<int>(
                                  initialValue: _selectedKamarId,
                                  hint: Text(
                                    'Pilih kamar kosong',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                  ),
                                  items: _availableKamars.map((kamar) {
                                    final id = kamar['id_kamar'] as int;
                                    final nomor = kamar['nomor_kamar'] as String;
                                    return DropdownMenuItem<int>(
                                      value: id,
                                      child: Text('Kamar $nomor'),
                                    );
                                  }).toList(),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: primaryColor, width: 1.5),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedKamarId = value;
                                    });
                                  },
                                  validator: (v) => v == null ? 'Pilih kamar terlebih dahulu' : null,
                                ),
                      const SizedBox(height: 28),

                      // --- SUBMIT BUTTON ---
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _handleSimpan,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  _isEditMode ? 'Simpan Perubahan' : 'Tambah Penyewa',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter> inputFormatters = const [],
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
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
