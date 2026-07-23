import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;

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
  List<String> _fotoKamarUrls = [];
  bool _isCompressingOrUploading = false;

  String _generateKodeKamar() {
    final random = Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excludes I, O, 1, 0
    final buffer = StringBuffer('KOS-');
    for (int i = 0; i < 4; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

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
      _nomorKamarController.text =
          widget.roomData!['nomor_kamar']?.toString() ?? '';
      _hargaSewaController.text =
          widget.roomData!['harga_sewa_dasar']?.toString() ?? '';
      _statusKamar = widget.roomData!['status_kamar'] ?? 'Kosong';

      // Load existing photo URLs if any
      final existingPhotos = widget.roomData!['foto_kamar'];
      if (existingPhotos != null) {
        _fotoKamarUrls = List<String>.from(existingPhotos);
      }

      // Load existing facilities if any
      final existingFacilities = widget.roomData!['fasilitas'];
      if (existingFacilities != null) {
        final List<String> list = List<String>.from(existingFacilities);
        for (var item in list) {
          if (_facilities.containsKey(item)) {
            _facilities[item] = true;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nomorKamarController.dispose();
    _hargaSewaController.dispose();
    super.dispose();
  }

  Future<File?> _compressImage(File file) async {
    try {
      final tempDir = await path_provider.getTemporaryDirectory();
      final String targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 75,
        minWidth: 1080,
        minHeight: 1080,
        format: CompressFormat.jpeg,
      );

      if (result == null) return null;
      return File(result.path);
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String?> _uploadImageWeb(Uint8List bytes, String fileName) async {
    try {
      final supabase = Supabase.instance.client;
      final fileExtension = path.extension(fileName);
      final String uniqueFileName =
          'room_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode}$fileExtension';
      final String uploadPath = 'uploads/$uniqueFileName';

      await supabase.storage
          .from('foto_kamar')
          .uploadBinary(
            uploadPath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getContentType(fileExtension),
            ),
          );

      final String publicUrl = supabase.storage
          .from('foto_kamar')
          .getPublicUrl(uploadPath);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image on Web: $e');
      rethrow;
    }
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final supabase = Supabase.instance.client;
      final fileExtension = path.extension(file.path);
      final String uniqueFileName =
          'room_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode}$fileExtension';
      final String uploadPath = 'uploads/$uniqueFileName';

      await supabase.storage.from('foto_kamar').upload(uploadPath, file);

      final String publicUrl = supabase.storage
          .from('foto_kamar')
          .getPublicUrl(uploadPath);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Pilih Sumber Foto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004D40),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFF004D40),
              ),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Color(0xFF004D40),
              ),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    // Validate file extension
    final extension = path.extension(pickedFile.name).toLowerCase();
    if (extension != '.jpg' && extension != '.jpeg' && extension != '.png') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hanya format JPG, JPEG, dan PNG yang diperbolehkan.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    setState(() {
      _isCompressingOrUploading = true;
    });

    try {
      String? publicUrl;

      if (kIsWeb) {
        final Uint8List bytes = await pickedFile.readAsBytes();
        publicUrl = await _uploadImageWeb(bytes, pickedFile.name);
      } else {
        final File rawFile = File(pickedFile.path);
        File uploadFile = rawFile;

        final File? compressedFile = await _compressImage(rawFile);
        if (compressedFile != null) {
          uploadFile = compressedFile;
        } else {
          debugPrint('Gagal mengompresi gambar, menggunakan file asli.');
        }

        publicUrl = await _uploadImage(uploadFile);
      }

      if (publicUrl != null) {
        setState(() {
          _fotoKamarUrls.add(publicUrl!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proses gagal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCompressingOrUploading = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nomorKamar = _nomorKamarController.text.trim();
      final hargaSewa = int.parse(_hargaSewaController.text.trim());

      final selectedFacilities = _facilities.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final currentUser = Supabase.instance.client.auth.currentUser;
      final currentUserId = currentUser?.id;

      // Pastikan profil_admin sudah ada agar foreign key terpenuhi
      if (currentUserId != null) {
        final existingProfile = await Supabase.instance.client
            .from('profil_admin')
            .select('id_admin')
            .eq('id_admin', currentUserId)
            .maybeSingle();

        if (existingProfile == null) {
          // Buat baris profil_admin dengan data minimal dari akun auth
          final namaDefault =
              currentUser?.userMetadata?['nama_lengkap'] ??
              currentUser?.email?.split('@').first ??
              'Admin';
          await Supabase.instance.client.from('profil_admin').insert({
            'id_admin': currentUserId,
            'nama_lengkap': namaDefault,
            'nama_kost':
                'Kos Saya', // nilai sementara, bisa diubah di halaman Profil
          });
        }
      }

      final Map<String, dynamic> payload = {
        'nomor_kamar': nomorKamar,
        'harga_sewa_dasar': hargaSewa,
        'status_kamar': _statusKamar,
        'fasilitas': selectedFacilities,
        'foto_kamar': _fotoKamarUrls,
        'id_admin': currentUserId,
      };

      // If editing, include the Primary Key to perform an UPDATE upsert
      if (widget.roomData != null) {
        payload['id_kamar'] = widget.roomData!['id_kamar'];
        payload['kode_kamar'] = widget.roomData!['kode_kamar'];
      } else {
        // Only generate code for a new room
        payload['kode_kamar'] = _generateKodeKamar();
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
                      if (widget.roomData != null) ...[
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
                          items: ['Kosong', 'Terisi', 'Perbaikan'].map((
                            status,
                          ) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
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
                                _statusKamar = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
                                  Icon(
                                    getFacilityIcon(facility),
                                    size: 18,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      facility,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
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
                      if (_fotoKamarUrls.isEmpty && !_isCompressingOrUploading)
                        GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            width: double.infinity,
                            height: 140,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Ketuk untuk mengunggah foto',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Maksimal 5 foto (JPG, PNG)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ..._fotoKamarUrls.map((url) {
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                      image: DecorationImage(
                                        image: NetworkImage(url),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _fotoKamarUrls.remove(url);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            if (_isCompressingOrUploading)
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            if (_fotoKamarUrls.length < 5 &&
                                !_isCompressingOrUploading)
                              GestureDetector(
                                onTap: _pickAndUploadImage,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 24,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tambah',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
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
