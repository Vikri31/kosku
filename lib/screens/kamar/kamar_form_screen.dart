import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KamarFormScreen extends StatefulWidget {
  final Map<String, dynamic>? roomData;

  const KamarFormScreen({super.key, this.roomData});

  @override
  State<KamarFormScreen> createState() => _KamarFormScreenState();
}

class _KamarFormScreenState extends State<KamarFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomorKamarController = TextEditingController();
  final _hargaSewaController = TextEditingController();
  String _statusKamar = 'Kosong';
  bool _isLoading = false;

  // Mock states for Facilities
  final Map<String, bool> _facilities = {
    'Kasur': false,
    'AC': false,
    'KM Dalam': false,
    'WiFi': false,
    'Meja Belajar': false,
    'Lemari': false,
  };

  @override
  void initState() {
    super.initState();
    if (widget.roomData != null) {
      _nomorKamarController.text = widget.roomData!['nomor_kamar']?.toString() ?? '';
      _hargaSewaController.text = widget.roomData!['harga_sewa_dasar']?.toString() ?? '';
      _statusKamar = widget.roomData!['status_kamar'] ?? 'Kosong';
    }
  }

  @override
  void dispose() {
    _nomorKamarController.dispose();
    _hargaSewaController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nomorKamar = _nomorKamarController.text.trim();
      final hargaSewa = int.parse(_hargaSewaController.text.trim());

      final Map<String, dynamic> payload = {
        'nomor_kamar': nomorKamar,
        'harga_sewa_dasar': hargaSewa,
        'status_kamar': _statusKamar,
      };

      // If editing, include the Primary Key to perform an UPDATE upsert
      if (widget.roomData != null) {
        payload['id_kamar'] = widget.roomData!['id_kamar'];
      }

      await Supabase.instance.client.from('kamar').upsert(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data kamar berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF004D40);
    final isEditMode = widget.roomData != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Edit Kamar' : 'Tambah Kamar',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- CARD 1: INFORMASI DASAR ---
              Card(
                color: Colors.white,
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Informasi Dasar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Nomor Kamar
                      const Text(
                        'Nomor / Nama Kamar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nomorKamarController,
                        decoration: InputDecoration(
                          hintText: 'Misal: A1, B2, atau Mawar',
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
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nomor kamar tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Harga Sewa
                      const Text(
                        'Harga Sewa (Per Bulan)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _hargaSewaController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          prefixStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                          hintText: '0',
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
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Harga sewa tidak boleh kosong';
                          }
                          if (int.tryParse(value.trim()) == null) {
                            return 'Harga sewa harus berupa angka';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Status Kamar
                      const Text(
                        'Status Kamar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _statusKamar,
                        items: ['Kosong', 'Terisi'].map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
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
                          if (value != null) {
                            setState(() {
                              _statusKamar = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- CARD 2: FASILITAS KAMAR ---
              Card(
                color: Colors.white,
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      const SizedBox(height: 20),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.8,
                        ),
                        itemCount: _facilities.keys.length,
                        itemBuilder: (context, index) {
                          final facility = _facilities.keys.elementAt(index);
                          final isChecked = _facilities[facility]!;

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

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: CheckboxListTile(
                              value: isChecked,
                              dense: true,
                              title: Row(
                                children: [
                                  Icon(getFacilityIcon(facility), size: 18, color: primaryColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      facility,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              contentPadding: EdgeInsets.zero,
                              activeColor: primaryColor,
                              checkboxShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _facilities[facility] = value ?? false;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- CARD 3: FOTO KAMAR ---
              Card(
                color: Colors.white,
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.camera_alt_outlined, color: primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Foto Kamar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                            style: BorderStyle.solid, // Use a simple solid border
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            const Text(
                              'Ketuk untuk mengunggah foto',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Maksimal 5 foto (JPG, PNG)',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // --- SIMPAN BUTTON ---
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
                  onPressed: _isLoading ? null : _handleSave,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Simpan Data Kamar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
