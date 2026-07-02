import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _kPrimary = Color(0xFF1A7C6A);

class RegisterPenghuniScreen extends StatefulWidget {
  const RegisterPenghuniScreen({super.key});

  @override
  State<RegisterPenghuniScreen> createState() => _RegisterPenghuniScreenState();
}

class _RegisterPenghuniScreenState extends State<RegisterPenghuniScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaLengkapController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _namaLengkapController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final namaLengkap = _namaLengkapController.text.trim();

      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'nama_lengkap': namaLengkap,
          'role': 'penghuni',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Pendaftaran berhasil! Silakan periksa email Anda untuk verifikasi.',
            ),
            backgroundColor: _kPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        // Kembali ke login setelah register sukses
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Daftar Akun',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: Colors.white,
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 36.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Logo KosKu ──────────────────────────────────
                      Image.asset(
                        'assets/images/icon_kosku.jpeg',
                        height: 90,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.home_work_rounded,
                            size: 45,
                            color: _kPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'KosKu',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _kPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Text(
                        'kelola Kos Lebih Mudah',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Header ──────────────────────────────────────
                      const Text(
                        'Buat Akun Baru',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _kPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Mulai nikmati hunian kos dengan mudah.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // ── Nama Lengkap ─────────────────────────────────
                      _buildLabel('Nama Lengkap'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _namaLengkapController,
                        hint: 'Cth: Budi Santoso',
                        icon: Icons.person_outline,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Nama lengkap tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Alamat Email ─────────────────────────────────
                      _buildLabel('Alamat Email'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _emailController,
                        hint: 'nama@email.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email tidak boleh kosong';
                          }
                          final emailRegExp = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                          );
                          if (!emailRegExp.hasMatch(v.trim())) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Kata Sandi ───────────────────────────────────
                      _buildLabel('Kata Sandi'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _passwordController,
                        hint: '••••••••',
                        icon: Icons.lock_outlined,
                        obscure: _isPasswordObscured,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordObscured
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                            () => _isPasswordObscured = !_isPasswordObscured,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password tidak boleh kosong';
                          }
                          if (v.length < 6) {
                            return 'Password minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Konfirmasi Kata Sandi ────────────────────────
                      _buildLabel('Konfirmasi Kata Sandi'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hint: '••••••••',
                        icon: Icons.security_outlined,
                        obscure: _isConfirmPasswordObscured,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordObscured
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                            () => _isConfirmPasswordObscured =
                                !_isConfirmPasswordObscured,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Konfirmasi password tidak boleh kosong';
                          }
                          if (v != _passwordController.text) {
                            return 'Konfirmasi password tidak cocok';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // ── Tombol Daftar ────────────────────────────────
                      SizedBox(
                        width: double.infinity,
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
                          onPressed: _isLoading ? null : _handleRegister,
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
                                  'Daftar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Link Sudah punya akun ────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sudah punya akun? ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context)
                                .pushNamedAndRemoveUntil(
                                  '/login',
                                  (r) => false,
                                ),
                            child: const Text(
                              'Masuk',
                              style: TextStyle(
                                color: _kPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: suffixIcon,
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
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
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
