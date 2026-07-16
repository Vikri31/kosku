import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaLengkapController;
  late TextEditingController _namaKostController;
  late TextEditingController _nomorWaController;
  late TextEditingController _emailController;

  bool _isLoading = false;
  String? _fotoProfilUrl;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    // Fetch initial user data from Supabase session
    final user = Supabase.instance.client.auth.currentUser;
    final initialName = user?.userMetadata?['nama_lengkap'] ?? 'Budi Santoso';
    final initialKos = user?.userMetadata?['nama_kos'] ?? 'KosKu Harmoni';
    final initialWa = user?.userMetadata?['nomor_wa'] ?? '';
    final email = user?.email ?? 'budi.santoso@example.com';

    _namaLengkapController = TextEditingController(text: initialName);
    _namaKostController = TextEditingController(text: initialKos);
    _nomorWaController = TextEditingController(text: initialWa);
    _emailController = TextEditingController(text: email);

    _loadProfileFromDatabase();
  }

  Future<void> _loadProfileFromDatabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await Supabase.instance.client
          .from('profil_admin')
          .select()
          .eq('id_admin', user.id)
          .maybeSingle();

      if (data != null) {
        if (mounted) {
          setState(() {
            if (data['nama_lengkap'] != null) {
              _namaLengkapController.text = data['nama_lengkap'];
            }
            if (data['nama_kost'] != null) {
              _namaKostController.text = data['nama_kost'];
            }
            if (data['nomor_wa'] != null) {
              _nomorWaController.text = data['nomor_wa'];
            }
            if (data['foto_profil_url'] != null) {
              _fotoProfilUrl = data['foto_profil_url'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile from database: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image == null) return;

      if (mounted) setState(() => _isUploadingPhoto = true);

      final bytes = await image.readAsBytes();
      final String fileName = 'admin_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String storagePath = 'profil_admin/$fileName';

      // Upload ke Supabase Storage (menggunakan bucket 'foto_kamar' yang sudah ada)
      await Supabase.instance.client.storage
          .from('foto_kamar')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Dapatkan public URL
      final String publicUrl = Supabase.instance.client.storage
          .from('foto_kamar')
          .getPublicUrl(storagePath);

      // Update ke tabel profil_admin
      await Supabase.instance.client
          .from('profil_admin')
          .update({
            'foto_profil_url': publicUrl,
          })
          .eq('id_admin', user.id);

      if (mounted) {
        setState(() {
          _fotoProfilUrl = publicUrl;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload foto: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _namaLengkapController.dispose();
    _namaKostController.dispose();
    _nomorWaController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Handle Save Profile Changes
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _namaLengkapController.text.trim();
      final kos = _namaKostController.text.trim();
      final wa = _nomorWaController.text.trim();

      // Update user metadata in Supabase Auth
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'nama_lengkap': name,
            'nama_kos': kos,
            'nomor_wa': wa,
          },
        ),
      );

      // Attempt to upsert/update profil_admin table
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('profil_admin').upsert({
          'id_admin': userId,
          'nama_lengkap': name,
          'nama_kost': kos,
          'nomor_wa': wa,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perubahan profil berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
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
    const backgroundColor = Color(0xFFF5F7F8);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- AVATAR CHOOSE CONTAINER ---
              GestureDetector(
                onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: (_fotoProfilUrl != null && _fotoProfilUrl!.isNotEmpty)
                            ? NetworkImage(_fotoProfilUrl!) as ImageProvider
                            : null,
                        onBackgroundImageError: (_fotoProfilUrl != null && _fotoProfilUrl!.isNotEmpty)
                            ? (exception, stackTrace) {
                                // Fallback if load fails
                              }
                            : null,
                        child: _isUploadingPhoto
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : (_fotoProfilUrl == null || _fotoProfilUrl!.isEmpty)
                                ? Icon(Icons.person, size: 54, color: Colors.grey[400])
                                : null,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ketuk untuk mengubah foto',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),

              // --- FORM CONTAINER ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field 1: Nama Lengkap Label
                    const Text(
                      'Nama Lengkap',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Field 1: Nama Lengkap Input
                    TextFormField(
                      controller: _namaLengkapController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          return 'Nama lengkap tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Field 2: Nama Properti Kos Label
                    const Text(
                      'Nama Properti Kos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Field 2: Nama Properti Kos Input
                    TextFormField(
                      controller: _namaKostController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.home_work_outlined, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          return 'Nama properti kos tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Field WhatsApp Label
                    const Text(
                      'Nomor WhatsApp',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Field WhatsApp Input
                    TextFormField(
                      controller: _nomorWaController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
                        hintText: 'Contoh: 6281234567890',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          return 'Nomor WhatsApp tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Field 3: Email Label Row
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'TIDAK DAPAT DIUBAH',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Field 3: Email Input (Disabled style)
                    TextFormField(
                      controller: _emailController,
                      enabled: false,
                      style: TextStyle(color: Colors.grey[600]),
                      decoration: InputDecoration(
                        fillColor: const Color(0xFFF2F4F5),
                        filled: true,
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                        suffixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Email Helper Subtext
                    Text(
                      'Hubungi admin untuk mengubah alamat email.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // --- SAVE CHANGES BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_outlined, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Simpan Perubahan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
