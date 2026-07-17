import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../dashboard/dashboard_penghuni_screen.dart';
import '../../../main.dart';

const Color _kPrimary = Color(0xFF004D40);
const Color _kBg = Color(0xFFF4F6F7);

class ProfilPenghuniScreen extends StatefulWidget {
  const ProfilPenghuniScreen({super.key});

  @override
  State<ProfilPenghuniScreen> createState() => _ProfilPenghuniScreenState();
}

class _ProfilPenghuniScreenState extends State<ProfilPenghuniScreen> {
  // ── Static Cache Data (Persist between route replacements) ────────────────
  static String? _cachedNamaPenghuni;
  static String? _cachedNamaKos;
  static String? _cachedNomorKamar;
  static String? _cachedStatusTagihan;
  static bool? _cachedStatusLunas;
  static String? _cachedAvatarUrl;
  static bool? _cachedIsDataLengkap;
  static int? _cachedIdSewa;
  static int? _cachedIdKamar;
  static bool _hasLoadedOnce = false;

  // ── State Data ──────────────────────────────────────────────────────────
  late String _namaPenghuni;
  late String _namaKos;
  late String _nomorKamar;
  late String _statusTagihan;
  late bool _statusLunas;
  String? _avatarUrl;
  late bool _isDataLengkap;
  int? _idSewa;
  int? _idKamar;
  late bool _isLoading;

  static const String _appVersion = '1.0.0 (Stable)';

  @override
  void initState() {
    super.initState();
    
    // Load from static cache if available, otherwise use initial defaults
    _namaPenghuni = _cachedNamaPenghuni ?? '-';
    _namaKos = _cachedNamaKos ?? 'Memuat...';
    _nomorKamar = _cachedNomorKamar ?? 'Memuat...';
    _statusTagihan = _cachedStatusTagihan ?? 'Memuat...';
    _statusLunas = _cachedStatusLunas ?? true;
    _avatarUrl = _cachedAvatarUrl;
    _isDataLengkap = _cachedIsDataLengkap ?? false;
    _idSewa = _cachedIdSewa;
    _idKamar = _cachedIdKamar;
    _isLoading = !_hasLoadedOnce;

    // Fallback sync load from Auth metadata if cache is empty
    if (_cachedNamaPenghuni == null) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _namaPenghuni = user.userMetadata?['nama_lengkap'] ??
            user.email?.split('@').first ??
            '-';
        _isDataLengkap = user.userMetadata?['data_lengkap'] == true;
      }
    }
    _loadProfileData();
  }

  // ── Fetch Profile Data from Supabase ──────────────────────────────────────
  Future<void> _loadProfileData() async {
    if (!mounted) return;
    if (!_hasLoadedOnce) {
      setState(() {
        _isLoading = true;
        _namaKos = 'Memuat...';
        _nomorKamar = 'Memuat...';
        _statusTagihan = 'Memuat...';
      });
    }

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user != null) {
        // Reset defaults (only if we don't have cache)
        if (!_hasLoadedOnce) {
          _namaPenghuni =
              user.userMetadata?['nama_lengkap'] ??
              user.email?.split('@').first ??
              '-';
          _isDataLengkap = user.userMetadata?['data_lengkap'] == true;
          _idSewa = null;
          _idKamar = null;
          _avatarUrl = null;
        }

        // 2. Fetch from detail_penyewa table
        final detail = await client
            .from('detail_penyewa')
            .select()
            .eq('id_user', user.id)
            .maybeSingle();

        if (detail != null) {
          _isDataLengkap = true;
          if (detail['foto_profil_url'] != null) {
            _avatarUrl = detail['foto_profil_url'];
          }
          final String? nik = detail['nik'];
          if (nik != null) {
            // Find active penyewa and room info
            final penyewa = await client
                .from('penyewa')
                .select()
                .eq('nik', nik)
                .maybeSingle();

            if (penyewa != null) {
              _namaPenghuni = penyewa['nama_lengkap'] ?? _namaPenghuni;
              final idPenyewa = penyewa['id_penyewa'];
              final sewa = await client
                  .from('sewa')
                  .select()
                  .eq('id_penyewa', idPenyewa)
                  .eq('status_sewa', 'Aktif')
                  .maybeSingle();

              if (sewa != null) {
                _idSewa = sewa['id_sewa'];
                _idKamar = sewa['id_kamar'];
                final int idKamar = _idKamar!;
                final int idSewa = _idSewa!;
                final kamar = await client
                    .from('kamar')
                    .select()
                    .eq('id_kamar', idKamar)
                    .maybeSingle();

                if (kamar != null) {
                  _nomorKamar = 'Kamar ${kamar['nomor_kamar']}';
                  final String? idAdmin = kamar['id_admin'];
                  if (idAdmin != null) {
                    final admin = await client
                        .from('profil_admin')
                        .select()
                        .eq('id_admin', idAdmin)
                        .maybeSingle();
                    if (admin != null) {
                      _namaKos = admin['nama_kost'] ?? 'Kosku';
                    } else {
                      _namaKos = 'Kosku';
                    }
                  } else {
                    _namaKos = 'Kosku';
                  }
                } else {
                  _namaKos = 'Belum terikat kos';
                  _nomorKamar = '-';
                }

                // Check invoice status
                final invoices = await client
                    .from('invoice')
                    .select()
                    .eq('id_sewa', idSewa);

                if (invoices.isNotEmpty) {
                  final hasUnpaid = invoices.any(
                    (inv) => inv['status_pembayaran']?.toString().toUpperCase() != 'LUNAS',
                  );
                  if (hasUnpaid) {
                    _statusLunas = false;
                    _statusTagihan = 'Belum Lunas';
                  } else {
                    _statusLunas = true;
                    _statusTagihan = 'Lunas';
                  }
                } else {
                  _statusLunas = true;
                  _statusTagihan = 'Tidak Ada Tagihan';
                }
              } else {
                _namaKos = 'Belum terikat kos';
                _nomorKamar = '-';
                _statusTagihan = '-';
                _statusLunas = true;
              }
            } else {
              _namaKos = 'Belum terikat kos';
              _nomorKamar = '-';
              _statusTagihan = '-';
              _statusLunas = true;
            }
          } else {
            _namaKos = 'Belum terikat kos';
            _nomorKamar = '-';
            _statusTagihan = '-';
            _statusLunas = true;
          }
        } else {
          _namaKos = 'Belum terikat kos';
          _nomorKamar = '-';
          _statusTagihan = '-';
          _statusLunas = true;
        }

        // Save to static cache
        _cachedNamaPenghuni = _namaPenghuni;
        _cachedNamaKos = _namaKos;
        _cachedNomorKamar = _nomorKamar;
        _cachedStatusTagihan = _statusTagihan;
        _cachedStatusLunas = _statusLunas;
        _cachedAvatarUrl = _avatarUrl;
        _cachedIsDataLengkap = _isDataLengkap;
        _cachedIdSewa = _idSewa;
        _cachedIdKamar = _idKamar;
        _hasLoadedOnce = true;
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
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
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── AppBar hijau ──────────────────────────────────────────
                const SliverAppBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: _kPrimary,
                  pinned: true,
                  toolbarHeight: 56,
                  centerTitle: true,
                  title: Text(
                    'KosKu',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 28),
                        // ── Kartu Avatar + Nama ───────────────────────────
                        _buildProfileCard(),
                        const SizedBox(height: 16),
                        // ── Banner Lengkapi Data (Hanya jika belum lengkap) ─
                        if (!_isDataLengkap) _buildCompleteBanner(context),
                        const SizedBox(height: 20),
                        // ── Menu List ────────────────────────────────────
                        _buildMenuSection(context),
                        const SizedBox(height: 16),
                        // ── Tombol Pindah & Logout ────────────────────────
                        if (_idSewa != null && _idKamar != null) ...[
                          _buildPindahButton(),
                          const SizedBox(height: 10),
                        ],
                        _buildLogoutButton(context),
                        const SizedBox(height: 18),
                        // ── Versi App ─────────────────────────────────────
                        const Text(
                          'Version $_appVersion',
                          style: TextStyle(
                            color: Color(0xFFADB5BD),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const PenghuniBottomNav(currentIndex: 2),
        ],
      ),
    );
  }

  // ── Kartu profil ──────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar dengan tombol edit
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE8F5F2),
                  border: Border.all(
                    color: _kPrimary.withValues(alpha: 0.3),
                    width: 2.5,
                  ),
                ),
                child: ClipOval(
                  child: _isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _kPrimary,
                            ),
                          ),
                        )
                      : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? Image.network(
                              _avatarUrl!,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: _kPrimary,
                                );
                              },
                            )
                          : const Icon(Icons.person, size: 50, color: _kPrimary)),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () async {
                    final result = await Navigator.of(
                      context,
                    ).pushNamed('/lengkapi-data');
                    if (result == true) {
                      _loadProfileData();
                    }
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: _kPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _namaPenghuni,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _namaKos,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          // Info kamar & status
          Row(
            children: [
              Expanded(
                child: _InfoBox(
                  label: 'Nomor Kamar',
                  value: _nomorKamar,
                  valueColor: _kPrimary,
                ),
              ),
              Container(width: 1, height: 48, color: const Color(0xFFE5E7EB)),
              Expanded(
                child: _InfoBox(
                  label: 'Status Tagihan',
                  value: _statusLunas
                      ? '● $_statusTagihan'
                      : '● $_statusTagihan',
                  valueColor: _statusLunas
                      ? _kPrimary
                      : const Color(0xFFFF3B30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Banner lengkapi data ──────────────────────────────────────────────────
  Widget _buildCompleteBanner(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).pushNamed('/lengkapi-data');
        if (result == true) {
          _loadProfileData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFF1B64C).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1B64C).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF1B64C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lengkapi data diri',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  Text(
                    'Data anda belum lengkap 80%',
                    style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1B64C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Lengkapi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Menu section ─────────────────────────────────────────────────────────
  Widget _buildMenuSection(BuildContext context) {
    final menus = [
      _MenuItem(
        icon: Icons.person_pin_outlined,
        label: 'Lengkap Data Diri',
        badge: _isDataLengkap ? null : '1',
        onTap: () async {
          final result = await Navigator.of(
            context,
          ).pushNamed('/lengkapi-data');
          if (result == true) {
            _loadProfileData();
          }
        },
      ),
      if (_nomorKamar == '-' || _nomorKamar == 'Belum terikat kos')
        _MenuItem(
          icon: Icons.vpn_key_outlined,
          label: 'Masukkan Kode Kamar',
          onTap: () async {
            final result = await Navigator.of(context).pushNamed('/input-kode');
            if (result == true) {
              _loadProfileData();
            }
          },
        ),
      _MenuItem(
        icon: Icons.info_outline,
        label: 'Info Kamar Saya',
        onTap: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.info_outline, color: _kPrimary),
                    SizedBox(width: 8),
                    Text(
                      'Info Kamar Saya',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                content: Text(
                  _nomorKamar == '-' || _nomorKamar == 'Belum terikat kos'
                      ? 'Anda belum terdaftar di kamar manapun.'
                      : 'Anda terdaftar di $_nomorKamar - $_namaKos.',
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        color: _kPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      _MenuItem(
        icon: Icons.phone_android_outlined,
        label: 'Tentang Aplikasi',
        onTap: () {
          showAboutDialog(
            context: context,
            applicationName: 'KosKu',
            applicationVersion: _appVersion,
            applicationIcon: const Icon(
              Icons.home_work,
              color: _kPrimary,
              size: 40,
            ),
            children: const [
              Text(
                'KosKu adalah aplikasi pengelolaan kos yang memudahkan Anda sebagai penghuni untuk melihat informasi kamar, memantau tagihan bulanan, mengunggah bukti pembayaran, dan menerima notifikasi penting secara praktis.',
              ),
            ],
          );
        },
      ),
      _MenuItem(
        icon: Icons.volume_up_outlined,
        label: 'Coba Notifikasi Sistem',
        onTap: () async {
          const AndroidNotificationDetails androidPlatformChannelSpecifics =
              AndroidNotificationDetails(
            'kosku_test_channel',
            'Test Notifikasi KosKu',
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
        },
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: menus.asMap().entries.map((entry) {
          final idx = entry.key;
          final menu = entry.value;
          return Column(
            children: [
              _MenuTile(menu: menu),
              if (idx < menus.length - 1)
                const Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                  color: Color(0xFFF0F0F0),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Tombol Pindah Kost ───────────────────────────────────────────────────
  Widget _buildPindahButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _handlePindahKost,
        icon: const Icon(Icons.exit_to_app, color: Color(0xFFFF3B30), size: 18),
        label: const Text(
          'Pindah Kost',
          style: TextStyle(
            color: Color(0xFFFF3B30),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _handlePindahKost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3B30)),
              SizedBox(width: 8),
              Text(
                'Konfirmasi Pindah',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin untuk pindah kos? Semua status sewa aktif Anda akan dinyatakan selesai.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Ya, Pindah',
                style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      if (_idSewa == null || _idKamar == null) return;

      // Tampilkan progress indicator dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: _kPrimary),
        ),
      );

      try {
        final client = Supabase.instance.client;

        // 1. Update status sewa to Selesai
        await client
            .from('sewa')
            .update({'status_sewa': 'Selesai'})
            .eq('id_sewa', _idSewa!);

        // 2. Update status kamar to Kosong
        await client
            .from('kamar')
            .update({'status_kamar': 'Kosong'})
            .eq('id_kamar', _idKamar!);

        if (mounted) {
          // Tutup progress indicator dialog
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Berhasil keluar dari kos. Status kamar diubah menjadi Kosong.'),
              backgroundColor: Colors.green,
            ),
          );

          // Muat ulang data profil
          _loadProfileData();
        }
      } catch (e) {
        if (mounted) {
          // Tutup progress indicator dialog
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal melakukan pindah kos: $e'),
              backgroundColor: const Color(0xFFFF3B30),
            ),
          );
        }
      }
    }
  }

  // ── Tombol Logout ────────────────────────────────────────────────────────
  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB91C1C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: () async {
          await Supabase.instance.client.auth.signOut();
          if (context.mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (r) => false);
          }
        },
        icon: const Icon(Icons.logout, size: 18),
        label: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget Pendukung Profil
// ─────────────────────────────────────────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.label,
    required this.value,
    required this.valueColor,
  });
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.badge,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback? onTap;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.menu});
  final _MenuItem menu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: menu.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(menu.icon, size: 18, color: _kPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  menu.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2933),
                  ),
                ),
              ),
              if (menu.badge != null) ...[
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      menu.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFD1D5DB),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
