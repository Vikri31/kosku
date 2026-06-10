import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FormPengeluaranScreen extends StatefulWidget {
  const FormPengeluaranScreen({super.key});

  @override
  State<FormPengeluaranScreen> createState() => _FormPengeluaranScreenState();
}

class _FormPengeluaranScreenState extends State<FormPengeluaranScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customKategoriController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _nominalController = TextEditingController();

  String _selectedKategori = 'Listrik';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<String> _kategoriOptions = [
    'Listrik',
    'Air',
    'Kebersihan',
    'Keamanan',
    'Perbaikan',
    'Operasional',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _updateDateText();
  }

  @override
  void dispose() {
    _customKategoriController.dispose();
    _deskripsiController.dispose();
    _tanggalController.dispose();
    _nominalController.dispose();
    super.dispose();
  }

  void _updateDateText() {
    // Format YYYY-MM-DD
    final year = _selectedDate.year;
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final day = _selectedDate.day.toString().padLeft(2, '0');
    _tanggalController.text = '$year-$month-$day';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF004D40), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Color(0xFF004D40), // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF004D40), // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _updateDateText();
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final finalKategori = _selectedKategori == 'Lainnya'
          ? _customKategoriController.text.trim()
          : _selectedKategori;
      final finalDeskripsi = _deskripsiController.text.trim();
      final finalNominal = int.parse(_nominalController.text.trim());
      final finalTanggal = _tanggalController.text.trim();

      await Supabase.instance.client.from('pengeluaran').insert({
        'kategori': finalKategori,
        'deskripsi': finalDeskripsi,
        'tanggal_keluar': finalTanggal,
        'nominal_keluar': finalNominal,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data pengeluaran berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pengeluaran: $e'),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text(
          'Tambah Pengeluaran',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              Card(
                color: Colors.white,
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, color: primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Formulir Pengeluaran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Kategori Dropdown
                      const Text(
                        'Kategori Pengeluaran',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedKategori,
                        items: _kategoriOptions.map((kategori) {
                          return DropdownMenuItem<String>(
                            value: kategori,
                            child: Text(kategori),
                          );
                        }).toList(),
                        decoration: InputDecoration(
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: primaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedKategori = value;
                            });
                          }
                        },
                      ),

                      // Custom Kategori (apabila memilih Lainnya)
                      if (_selectedKategori == 'Lainnya') ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Nama Kategori Kustom',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _customKategoriController,
                          decoration: InputDecoration(
                            hintText: 'Misal: Pajak, Konsumsi Rapat',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
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
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: primaryColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (_selectedKategori == 'Lainnya' &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Nama kategori kustom tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Tanggal Pengeluaran
                      const Text(
                        'Tanggal Pengeluaran',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _tanggalController,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        decoration: InputDecoration(
                          hintText: 'Pilih Tanggal',
                          suffixIcon: const Icon(
                            Icons.calendar_today_rounded,
                            color: primaryColor,
                          ),
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: primaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Tanggal pengeluaran wajib dipilih';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Nominal Pengeluaran
                      const Text(
                        'Nominal Pengeluaran',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nominalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          prefixStyle: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: primaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nominal pengeluaran tidak boleh kosong';
                          }
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null) {
                            return 'Nominal harus berupa angka bulat';
                          }
                          if (parsed <= 0) {
                            return 'Nominal harus lebih dari 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Keterangan / Deskripsi
                      const Text(
                        'Keterangan / Deskripsi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _deskripsiController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Tulis keterangan tambahan pengeluaran...',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: primaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Tombol Simpan
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
                          'Simpan Pengeluaran',
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
