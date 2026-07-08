import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen for entering room code to request access/join a room.
class InputKodeScreen extends StatefulWidget {
  const InputKodeScreen({super.key});

  @override
  State<InputKodeScreen> createState() => _InputKodeScreenState();
}

class _InputKodeScreenState extends State<InputKodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Theme colors consistent with the KosKu design system
  static const Color _kPrimary = Color(0xFF1A7C6A);
  static const Color _kBg = Color(0xFFF4F6F7);
  static const Color _kTextDark = Color(0xFF1F2933);
  static const Color _kTextMuted = Color(0xFF6B7280);

  // Default fallback whatsapp link if no admin contact is configured
  static const String _fallbackAdminWa = '6281234567890';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // --- Helper to convert all inputs to uppercase ---
  List<TextInputFormatter> get _codeFormatters => [
    TextInputFormatter.withFunction((oldValue, newValue) {
      return newValue.copyWith(text: newValue.text.toUpperCase());
    }),
    LengthLimitingTextInputFormatter(20), // Sensible code length limit
  ];

  // --- Submit Code Flow ---
  Future<void> _submitCode() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'Pengguna tidak terautentikasi. Silakan login kembali.',
        );
      }

      // 1. Check if room exists with this code
      final room = await supabase
          .from('kamar')
          .select()
          .eq('kode_kamar', code)
          .maybeSingle();

      if (room == null) {
        if (mounted) {
          _showSnackBar(
            'Kode kamar tidak valid atau tidak terdaftar!',
            isError: true,
          );
        }
        return;
      }

      final int idKamar = room['id_kamar'];
      final String nomorKamar = room['nomor_kamar']?.toString() ?? '-';

      // 2. Check if user already has an active lease (pindah kos/kamar)
      String? activeSewaId;
      String? activeKamarId;
      String? activeKamarNomor;

      // Find user details by id_user
      final detail = await supabase
          .from('detail_penyewa')
          .select()
          .eq('id_user', user.id)
          .maybeSingle();

      if (detail != null && detail['nik'] != null) {
        final String nik = detail['nik'];
        // Find penyewa by NIK
        final penyewa = await supabase
            .from('penyewa')
            .select()
            .eq('nik', nik)
            .maybeSingle();

        if (penyewa != null) {
          final int idPenyewa = penyewa['id_penyewa'];
          // Find active sewa
          final activeSewa = await supabase
              .from('sewa')
              .select('*, kamar(*)')
              .eq('id_penyewa', idPenyewa)
              .eq('status_sewa', 'Aktif')
              .maybeSingle();

          if (activeSewa != null) {
            activeSewaId = activeSewa['id_sewa']?.toString();
            activeKamarId = activeSewa['id_kamar']?.toString();
            if (activeSewa['kamar'] != null) {
              activeKamarNomor = activeSewa['kamar']['nomor_kamar']?.toString();
            }
          }
        }
      }

      // 3. Handle confirmation if they already have an active lease
      if (activeSewaId != null) {
        if (mounted) {
          final confirm = await _showConfirmDialog(
            currentRoom: activeKamarNomor ?? 'sebelumnya',
            newRoom: nomorKamar,
          );
          if (confirm != true) {
            return; // User cancelled
          }
        }
      }

      // 4. Send request to join
      await _processJoinRequest(
        idKamar: idKamar,
        userId: user.id,
        oldSewaId: activeSewaId,
        oldKamarId: activeKamarId,
      );

      if (mounted) {
        _showSuccessDialog(nomorKamar);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Terjadi kesalahan: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Perform Database Update and Insert ---
  Future<void> _processJoinRequest({
    required int idKamar,
    required String userId,
    String? oldSewaId,
    String? oldKamarId,
  }) async {
    final supabase = Supabase.instance.client;

    // If migrating from an old room, set lease to 'Selesai' and old room to 'Kosong'
    if (oldSewaId != null && oldKamarId != null) {
      await supabase
          .from('sewa')
          .update({'status_sewa': 'Selesai'})
          .eq('id_sewa', int.parse(oldSewaId));

      await supabase
          .from('kamar')
          .update({'status_kamar': 'Kosong'})
          .eq('id_kamar', int.parse(oldKamarId));
    }

    // Insert request to join new room
    await supabase.from('request_join').insert({
      'id_kamar': idKamar,
      'id_user': userId,
      'status_request': 'Menunggu Konfirmasi',
      'tanggal_pengajuan': DateTime.now().toIso8601String(),
    });
  }

  // --- Show Confirmation Dialog for Changing Rooms ---
  Future<bool?> _showConfirmDialog({
    required String currentRoom,
    required String newRoom,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text(
                'Pindah Kamar?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _kTextDark,
                ),
              ),
            ],
          ),
          content: Text(
            'Anda saat ini masih terdaftar aktif di Kamar $currentRoom. '
            'Menghubungkan ke Kamar $newRoom akan menonaktifkan sewa aktif dan akses Anda di Kamar $currentRoom.\n\nApakah Anda yakin ingin melanjutkan?',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: _kTextDark,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Batal',
                style: TextStyle(
                  color: _kTextMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Ya, Pindah',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Show Beautiful Success Dialog ---
  void _showSuccessDialog(String nomorKamar) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _kPrimary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Permintaan Dikirim!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Pengajuan bergabung ke Kamar $nomorKamar berhasil dikirim. '
                'Silakan hubungi admin untuk menyetujui pengajuan Anda.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kTextMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // Navigate back or refresh dashboard
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to dashboard screen
                  },
                  child: const Text(
                    'Kembali ke Dashboard',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Helper WhatsApp launcher to contact Admin ---
  Future<void> _contactAdmin() async {
    final uri = Uri.parse('https://wa.me/$_fallbackAdminWa');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Tidak bisa membuka WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Gagal menghubungi Admin: WhatsApp tidak tersedia.',
          isError: true,
        );
      }
    }
  }

  // --- Show Snack Bar Helper ---
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFFF3B30) : _kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hubungkan Kamar',
          style: TextStyle(
            color: _kTextDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Upper Section: Visuals and Inputs ---
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          // 1. Circular Key Icon Container
                          Center(
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5F2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFB2EAD9),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.key_rounded,
                                color: _kPrimary,
                                size: 54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // 2. Heading Title
                          const Text(
                            'Masukkan Kode Kamar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _kTextDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 3. Subtitle Description
                          const Text(
                            'Masukkan kode unik kamar yang Anda terima dari Admin untuk menghubungkan data sewa Anda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: _kTextMuted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // 4. Custom Outlined Text Field
                          TextFormField(
                            controller: _codeController,
                            textAlign: TextAlign.center,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: _codeFormatters,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4.0,
                              color: _kTextDark,
                            ),
                            decoration: InputDecoration(
                              hintText: 'KODE-KAMAR',
                              hintStyle: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                                letterSpacing: 2.0,
                                color: _kTextMuted.withValues(alpha: 0.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFB2EAD9),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: _kPrimary,
                                  width: 2.0,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF3B30),
                                  width: 1.5,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF3B30),
                                  width: 2.0,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Kode kamar tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // 5. Orange Warning Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4EC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFD1B3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Menghubungkan kode baru akan menonaktifkan akses ke kamar sebelumnya',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade900,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // --- Bottom Section: Submit Button & Contact Admin ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 6. Connect/Submit Button
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kPrimary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              onPressed: _isLoading ? null : _submitCode,
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
                                      'Hubungkan',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 7. Clickable link to contact admin
                          Center(
                            child: GestureDetector(
                              onTap: _contactAdmin,
                              child: Text.rich(
                                TextSpan(
                                  text: 'Tidak punya kode? ',
                                  style: const TextStyle(
                                    color: _kTextMuted,
                                    fontSize: 13,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Hubungi Admin KosKu',
                                      style: TextStyle(
                                        color: _kPrimary.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
