import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'register_penghuni_screen.dart';

/// Warna utama KosKu â€” hijau tosca gelap
const Color _kPrimary = Color(0xFF1A7C6A);
const Color _kSelectedBorder = Color(0xFF2BAE8E);
const Color _kSelectedBg = Color(0xFFD6F2EC);
const Color _kIconBg = Color(0xFFB2EAD9);
const Color _kGrey = Color(0xFF6B7280);

class PilihRoleScreen extends StatefulWidget {
  const PilihRoleScreen({super.key});

  @override
  State<PilihRoleScreen> createState() => _PilihRoleScreenState();
}

class _PilihRoleScreenState extends State<PilihRoleScreen> {
  String? _selectedRole;

  void _onSelectRole(String role) {
    setState(() => _selectedRole = role);
  }

  void _onLanjutkan() {
    if (_selectedRole == null) return;
    if (_selectedRole == 'pemilik') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const RegisterScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const RegisterPenghuniScreen()),
      );
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildLogo(),
              const SizedBox(height: 36),
              const Text(
                'Daftar Sebagai?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih peran Anda untuk melanjutkan\npendaftaran',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _kGrey, height: 1.5),
              ),
              const SizedBox(height: 32),
              _RoleCard(
                label: 'Pemilik Kos',
                icon: Icons.home_outlined,
                isSelected: _selectedRole == 'pemilik',
                onTap: () => _onSelectRole('pemilik'),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                label: 'Penghuni Kos',
                icon: Icons.person_outline,
                isSelected: _selectedRole == 'penghuni',
                onTap: () => _onSelectRole('penghuni'),
              ),
              const SizedBox(height: 40),
              _buildLanjutkanButton(),
              const SizedBox(height: 20),
              _buildLoginLink(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/Logo_KosKu.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.home_work_rounded, size: 56, color: _kPrimary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'KosKu',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kPrimary, letterSpacing: 0.5),
        ),
        Text(
          'kelola Kos Lebih Mudah',
          style: TextStyle(fontSize: 11, color: _kGrey, letterSpacing: 0.3),
        ),
      ],
    );
  }

  Widget _buildLanjutkanButton() {
    final bool isEnabled = _selectedRole != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isEnabled ? _kPrimary : const Color(0xFFB0BEC5),
        boxShadow: isEnabled
            ? [BoxShadow(color: _kPrimary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isEnabled ? _onLanjutkan : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Lanjutkan',
                style: TextStyle(
                  color: isEnabled ? Colors.white : Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: isEnabled ? Colors.white : Colors.white70, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Sudah punya akun? ', style: TextStyle(fontSize: 13, color: _kGrey)),
        GestureDetector(
          onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
          child: const Text(
            'Masuk',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kPrimary),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? _kSelectedBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? _kSelectedBorder : const Color(0xFFE5E7EB),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? _kSelectedBorder.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? _kIconBg : const Color(0xFFF0FAF7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 26, color: isSelected ? _kPrimary : const Color(0xFF4CAF8A)),
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? _kPrimary : const Color(0xFF374151),
                  ),
                ),
                const Spacer(),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSelected ? 1 : 0,
                  child: const Icon(Icons.check_circle_rounded, color: _kSelectedBorder, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

