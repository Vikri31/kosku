import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'edit_profile_screen.dart';
import '../../../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  String? _dbAdminName;
  String? _dbNamaKos;
  String? _fotoProfilUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileFromDatabase();
  }

  Future<void> _loadProfileFromDatabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profil_admin')
          .select()
          .eq('id_admin', user.id)
          .maybeSingle();

      if (data != null) {
        if (mounted) {
          setState(() {
            _dbAdminName = data['nama_lengkap'];
            _dbNamaKos = data['nama_kost'];
            _fotoProfilUrl = data['foto_profil_url'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile from DB: $e');
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

      // Upload ke Supabase Storage
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

  void _triggerTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'kosku_test_channel', // id
      'Test Notifikasi KosKu', // name
      channelDescription: 'Channel untuk testing notifikasi suara aplikasi KosKu',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      await flutterLocalNotificationsPlugin.show(
        id: 999,
        title: 'Uji Coba Notifikasi KosKu 🔊',
        body: 'Notifikasi sistem berhasil dikirim dengan suara dan getaran!',
        notificationDetails: platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('Gagal memicu test notifikasi: $e');
    }
  }

  // Handle Logout
  Future<void> _handleLogout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil keluar dari akun.'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigasi kembali ke GerbangUtamaScreen dan menghapus semua rute sebelumnya
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal keluar: $e'),
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

  // Show Info/About Dialog
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF004D40)),
            SizedBox(width: 10),
            Text(
              'Tentang Aplikasi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KosKu App',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text('Versi: 1.2.0'),
            SizedBox(height: 12),
            Text(
              'Aplikasi manajemen kos modern untuk mempermudah pemilik kos mengelola kamar, penyewa, transaksi, dan buku kas secara teratur dan real-time.',
              style: TextStyle(color: Colors.black87, fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Developer: Kelompok KosKu',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Tutup',
              style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Show Support Dialog
  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF004D40)),
            SizedBox(width: 10),
            Text(
              'Bantuan & Dukungan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hubungi Tim Kami',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Jika Anda mengalami kendala atau membutuhkan bantuan lebih lanjut, silakan hubungi tim customer service kami.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.email, color: Colors.grey, size: 20),
                SizedBox(width: 8),
                Text('support@kosku.example.com', style: TextStyle(fontSize: 13)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, color: Colors.grey, size: 20),
                SizedBox(width: 8),
                Text('+62 812-3456-7890', style: TextStyle(fontSize: 13)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Tutup',
              style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF004D40);
    const backgroundColor = Color(0xFFF5F7F8);

    // Get current user metadata
    final user = Supabase.instance.client.auth.currentUser;
    final adminName = _dbAdminName ?? user?.userMetadata?['nama_lengkap'] ?? 'Budi Santoso';
    final namaKos = _dbNamaKos ?? user?.userMetadata?['nama_kos'] ?? 'Kos Makmur Jaya';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'KosKu',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // --- PROFILE CARD CONTAINER ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Circular Avatar stack
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
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
                              ? (exception, stackTrace) {}
                              : null,
                          child: _isUploadingPhoto
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : (_fotoProfilUrl == null || _fotoProfilUrl!.isEmpty)
                                  ? Icon(Icons.person, size: 54, color: Colors.grey[400])
                                  : null,
                        ),
                      ),
                      GestureDetector(
                        onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Colors.white, width: 2),
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Admin Name
                  Text(
                    adminName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  // Property Subtitle
                  Text(
                    'Pemilik $namaKos',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Room Stats (Total & Terisi)
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client
                        .from('kamar')
                        .stream(primaryKey: ['id_kamar'])
                        .eq('id_admin', user?.id ?? ''),
                    builder: (context, snapshot) {
                      int totalKamar = 0;
                      int terisiKamar = 0;

                      if (snapshot.hasData) {
                        totalKamar = snapshot.data!.length;
                        terisiKamar = snapshot.data!
                            .where((k) => k['status_kamar'] == 'Terisi')
                            .length;
                      }

                      return Row(
                        children: [
                          // Total Kamar Card
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    snapshot.connectionState == ConnectionState.waiting
                                        ? '-'
                                        : '$totalKamar',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total Kamar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Terisi Card
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    snapshot.connectionState == ConnectionState.waiting
                                        ? '-'
                                        : '$terisiKamar',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Terisi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- OPTION LIST CARDS ---

            // Edit Profil Card
            _buildOptionCard(
              icon: Icons.manage_accounts_outlined,
              title: 'Edit Profil',
              subtitle: 'Ubah data diri dan informasi kos',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                ).then((_) {
                  _loadProfileFromDatabase();
                });
              },
            ),
            const SizedBox(height: 12),

            // Tentang Aplikasi Card
            _buildOptionCard(
              icon: Icons.info_outline,
              title: 'Tentang Aplikasi',
              subtitle: 'Versi 1.2.0, Syarat & Ketentuan',
              onTap: _showAboutDialog,
            ),
            const SizedBox(height: 12),

            // Coba Notifikasi Sistem Card
            _buildOptionCard(
              icon: Icons.volume_up_outlined,
              title: 'Coba Notifikasi Sistem',
              subtitle: 'Uji suara dan popup notifikasi HP',
              onTap: _triggerTestNotification,
            ),
            const SizedBox(height: 12),

            // Bantuan & Dukungan Card
            _buildOptionCard(
              icon: Icons.help_outline,
              title: 'Bantuan & Dukungan',
              subtitle: 'Hubungi tim customer service kami',
              onTap: _showSupportDialog,
            ),
            const SizedBox(height: 28),

            // --- LOGOUT BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828), // Red Logout color
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _handleLogout,
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
                          Icon(Icons.logout, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Logout',
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
    );
  }

  // Option Card Builder helper
  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon in circle container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7F8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.grey[700],
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                // Chevron right
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
