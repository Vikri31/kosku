import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class LengkapiDataDiriScreen extends StatefulWidget {
  const LengkapiDataDiriScreen({super.key});

  @override
  State<LengkapiDataDiriScreen> createState() => _LengkapiDataDiriScreenState();
}

class _LengkapiDataDiriScreenState extends State<LengkapiDataDiriScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _namaController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nikController = TextEditingController();
  final _tglLahirController = TextEditingController();

  // State variables
  DateTime? _selectedDate;
  File? _profileImage;
  File? _ktpImage;
  String? _existingProfileUrl;
  String? _existingKtpUrl;
  
  bool _isLoading = false;
  bool _isDataLoaded = false;
  bool _isNikDisabled = false;
  Map<String, dynamic>? _existingDetailPenyewa;

  // Colors
  static const Color _kPrimary = Color(0xFF1A7C6A);
  static const Color _kBg = Color(0xFFF4F6F7);
  static const Color _kTextDark = Color(0xFF1F2933);
  static const Color _kTextMuted = Color(0xFF6B7280);

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchExistingData();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _phoneController.dispose();
    _nikController.dispose();
    _tglLahirController.dispose();
    super.dispose();
  }

  // --- Fetch Existing Data ---
  Future<void> _fetchExistingData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;

      if (currentUser != null) {
        // Pre-populate name and phone from Auth metadata if available
        final meta = currentUser.userMetadata;
        if (meta != null) {
          if (meta['nama_lengkap'] != null) {
            _namaController.text = meta['nama_lengkap'].toString();
          }
          if (meta['nomor_whatsapp'] != null) {
            _phoneController.text = meta['nomor_whatsapp'].toString();
          }
        }

        // Fetch detail_penyewa
        final detail = await client
            .from('detail_penyewa')
            .select()
            .eq('id_user', currentUser.id)
            .maybeSingle();

        if (detail != null) {
          _existingDetailPenyewa = detail;
          if (detail['nik'] != null && detail['nik'].toString().isNotEmpty) {
            _nikController.text = detail['nik'].toString();
            _isNikDisabled = true; // Lock NIK after it has been saved
          }
          if (detail['tanggal_lahir'] != null) {
            final tglStr = detail['tanggal_lahir'].toString();
            _tglLahirController.text = tglStr;
            _selectedDate = DateTime.tryParse(tglStr);
          }
          if (detail['foto_profil_url'] != null) {
            _existingProfileUrl = detail['foto_profil_url'].toString();
          }
          if (detail['foto_ktp_url'] != null) {
            _existingKtpUrl = detail['foto_ktp_url'].toString();
          }
        }

        // If detail is not found, check if penyewa has it
        if (_nikController.text.isEmpty && currentUser.email != null) {
          final penyewaData = await client
              .from('penyewa')
              .select()
              .eq('nama_lengkap', _namaController.text)
              .maybeSingle();

          if (penyewaData != null) {
            if (penyewaData['nik'] != null) {
              _nikController.text = penyewaData['nik'].toString();
              // Load the detail from penyewa's NIK
              final detailByNik = await client
                  .from('detail_penyewa')
                  .select()
                  .eq('nik', penyewaData['nik'])
                  .maybeSingle();

              if (detailByNik != null) {
                _existingDetailPenyewa = detailByNik;
                _isNikDisabled = true;
                if (detailByNik['tanggal_lahir'] != null) {
                  final tglStr = detailByNik['tanggal_lahir'].toString();
                  _tglLahirController.text = tglStr;
                  _selectedDate = DateTime.tryParse(tglStr);
                }
                if (detailByNik['foto_profil_url'] != null) {
                  _existingProfileUrl = detailByNik['foto_profil_url'].toString();
                }
                if (detailByNik['foto_ktp_url'] != null) {
                  _existingKtpUrl = detailByNik['foto_ktp_url'].toString();
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading existing profile data: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isDataLoaded = true;
      });
    }
  }

  // --- Image Pickers ---
  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
    }
  }

  Future<void> _pickKtpImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _ktpImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking KTP image: $e');
    }
  }

  // --- Date Picker ---
  Future<void> _selectDateOfBirth() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _selectedDate ?? DateTime(2000, 1, 1);
    final DateTime firstDate = DateTime(1940);
    final DateTime lastDate = DateTime(now.year - 15); // Must be at least 15 years old

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kPrimary,
              onPrimary: Colors.white,
              onSurface: _kTextDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _tglLahirController.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  // --- Supabase Upload Helper ---
  Future<String?> _uploadFileToSupabase(File file, String prefix) async {
    try {
      final client = Supabase.instance.client;
      final fileExt = path.extension(file.path);
      final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode}$fileExt';
      final uploadPath = 'uploads/$fileName';

      // Upload file to the 'foto_kamar' bucket (or fallback bucket)
      await client.storage.from('foto_kamar').upload(uploadPath, file);
      
      // Get public URL
      final publicUrl = client.storage.from('foto_kamar').getPublicUrl(uploadPath);
      return publicUrl;
    } catch (e) {
      debugPrint('Storage upload error (will fallback to empty or local): $e');
      return null;
    }
  }

  // --- Save Action ---
  Future<void> _saveDataDiri() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;

      if (currentUser == null) {
        throw Exception('User tidak terautentikasi.');
      }

      final namaLengkap = _namaController.text.trim();
      final nomorWhatsapp = _phoneController.text.trim();
      final nik = _nikController.text.trim();
      final tglLahirStr = _tglLahirController.text.trim();

      // 1. Upload Images if picked
      String? profileUrl = _existingProfileUrl;
      if (_profileImage != null) {
        final uploaded = await _uploadFileToSupabase(_profileImage!, 'profile');
        if (uploaded != null) profileUrl = uploaded;
      }

      String? ktpUrl = _existingKtpUrl;
      if (_ktpImage != null) {
        final uploaded = await _uploadFileToSupabase(_ktpImage!, 'ktp');
        if (uploaded != null) ktpUrl = uploaded;
      }

      // Fallbacks for detail_penyewa not-null fields
      final tempatLahir = _existingDetailPenyewa?['tempat_lahir'] ?? '-';
      final jenisKelamin = _existingDetailPenyewa?['jenis_kelamin'] ?? '-';
      final alamatKtp = _existingDetailPenyewa?['alamat_ktp'] ?? '-';
      final pekerjaan = _existingDetailPenyewa?['pekerjaan'] ?? '-';

      // 2. Upsert to detail_penyewa
      final payloadDetail = {
        'nik': nik,
        'id_user': currentUser.id,
        'tempat_lahir': tempatLahir,
        'tanggal_lahir': tglLahirStr,
        'jenis_kelamin': jenisKelamin,
        'alamat_ktp': alamatKtp,
        'pekerjaan': pekerjaan,
        'foto_ktp_url': ktpUrl,
        'foto_profil_url': profileUrl,
        'nama_lengkap': namaLengkap, // For safety / query compatibility
        'nomor_whatsapp': nomorWhatsapp,
      };

      await client.from('detail_penyewa').upsert(payloadDetail);

      // 3. Upsert to penyewa table if NIK is valid
      try {
        final existingPenyewa = await client
            .from('penyewa')
            .select()
            .eq('nik', nik)
            .maybeSingle();

        if (existingPenyewa != null) {
          await client.from('penyewa').update({
            'nama_lengkap': namaLengkap,
            'nomor_whatsapp': nomorWhatsapp,
          }).eq('nik', nik);
        } else {
          await client.from('penyewa').insert({
            'nik': nik,
            'nama_lengkap': namaLengkap,
            'nomor_whatsapp': nomorWhatsapp,
          });
        }
      } catch (e) {
        debugPrint('Upsert penyewa table error (suppressed): $e');
      }

      // 4. Update Supabase Auth User Metadata (data_lengkap = true)
      await client.auth.updateUser(
        UserAttributes(
          data: {
            'data_lengkap': true,
            'nama_lengkap': namaLengkap,
            'nomor_whatsapp': nomorWhatsapp,
            'nik': nik,
            'tanggal_lahir': tglLahirStr,
            'foto_profil_url': profileUrl,
          },
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data diri berhasil disimpan!'),
            backgroundColor: _kPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true); // Return success to reload
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan data: $e'),
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

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded && _isLoading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: CircularProgressIndicator(color: _kPrimary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Data Diri Kamu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Profil Avatar ---
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: _kPrimary.withValues(alpha: 0.3), width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.transparent,
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : (_existingProfileUrl != null && _existingProfileUrl!.isNotEmpty
                                    ? NetworkImage(_existingProfileUrl!)
                                    : null) as ImageProvider?,
                            child: _profileImage == null && (_existingProfileUrl == null || _existingProfileUrl!.isEmpty)
                                ? const Icon(Icons.person, size: 54, color: _kPrimary)
                                : null,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _pickProfileImage,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: _kPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // --- Form Fields ---
                Text(
                  'Lengkapi Informasi Akun',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 16),

                // Nama Lengkap
                _buildTextField(
                  controller: _namaController,
                  label: 'Nama Lengkap Sesuai KTP',
                  hint: 'Masukkan nama lengkap',
                  icon: Icons.person_outline,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama lengkap harus diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // No Handphone
                _buildTextField(
                  controller: _phoneController,
                  label: 'Nomor Handphone (WA)',
                  hint: 'Contoh: 0812xxxxxxxx',
                  icon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nomor HP harus diisi';
                    }
                    if (val.length < 9) {
                      return 'Nomor HP tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // NIK
                _buildTextField(
                  controller: _nikController,
                  label: 'NIK (Nomor Induk Kependudukan)',
                  hint: 'Masukkan 16 digit NIK',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  enabled: !_isNikDisabled,
                  maxLength: 16,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'NIK harus diisi';
                    }
                    if (val.trim().length != 16) {
                      return 'NIK harus terdiri dari 16 digit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Tanggal Lahir
                GestureDetector(
                  onTap: _selectDateOfBirth,
                  child: AbsorbPointer(
                    child: _buildTextField(
                      controller: _tglLahirController,
                      label: 'Tanggal Lahir',
                      hint: 'Pilih Tanggal Lahir',
                      icon: Icons.calendar_today_outlined,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Tanggal lahir harus diisi';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- Upload KTP Section ---
                Text(
                  'Foto KTP',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickKtpImage,
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      painter: DashedBorderPainter(color: _kPrimary.withValues(alpha: 0.5)),
                      child: _ktpImage != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _ktpImage!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.black.withValues(alpha: 0.3),
                                  ),
                                  child: const Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit, color: Colors.white, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Ubah Foto KTP',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : (_existingKtpUrl != null && _existingKtpUrl!.isNotEmpty
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        _existingKtpUrl!,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.black.withValues(alpha: 0.3),
                                      ),
                                      child: const Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit, color: Colors.white, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Ubah Foto KTP',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 40,
                                        color: _kPrimary,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Upload Foto KTP',
                                        style: TextStyle(
                                          color: _kPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Format JPG/PNG, ukuran maks 5MB',
                                        style: TextStyle(
                                          color: _kTextMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // --- Warning Box ---
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFE6A3), width: 1),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Data NIK tidak dapat diubah setelah disimpan',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // --- Simpan Button ---
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _saveDataDiri,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Simpan Data Diri',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _kTextDark.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          maxLength: maxLength,
          validator: validator,
          style: TextStyle(
            fontSize: 13,
            color: enabled ? _kTextDark : _kTextMuted,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(icon, color: enabled ? _kPrimary : _kTextMuted, size: 18),
            counterText: '',
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFEBEFF1),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimary, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
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
        ),
      ],
    );
  }
}

// --- Dashed Border Custom Painter ---
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
    this.borderRadius = 12.0,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashPath = Path();

    double distance = 0.0;
    for (final PathMetric metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final double len = dashWidth;
        if (distance + len > metric.length) {
          dashPath.addPath(
            metric.extractPath(distance, metric.length),
            Offset.zero,
          );
        } else {
          dashPath.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
