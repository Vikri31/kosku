import 'package:flutter/material.dart';

import '../dashboard/dashboard_penghuni_screen.dart';
import 'detail_tagihan_screen.dart';

class TagihanScreen extends StatelessWidget {
  const TagihanScreen({super.key});

  static const Color _primaryColor = Color(0xFF007461);
  static const Color _backgroundColor = Color(0xFFF4F6F7);
  static const Color _dangerColor = Color(0xFFFF3B30);

  static const List<_BillItem> _bills = [
    _BillItem(
      title: 'Sewa Oktober 2024',
      date: '10 Okt 2024',
      amount: 'Rp 2.500.000',
      status: 'LUNAS',
      isPaid: true,
    ),
    _BillItem(
      title: 'Sewa November 2024',
      date: '10 Nov 2024',
      amount: 'Rp 2.500.000',
      status: 'BELUM LUNAS',
      isPaid: false,
    ),
    _BillItem(
      title: 'Sewa September 2024',
      date: '10 Sep 2024',
      amount: 'Rp 2.500.000',
      status: 'LUNAS',
      isPaid: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _primaryColor,
        elevation: 0,
        toolbarHeight: 54,
        centerTitle: true,
        title: const Text(
          'KosKu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tagihan Saya',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Riwayat pembayaran sewa kamar Anda',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SummaryCard(
                      label: 'Dibayar',
                      amount: 'Rp 12M',
                      color: _primaryColor,
                      icon: Icons.check_circle,
                    ),
                    const SizedBox(height: 12),
                    const _SummaryCard(
                      label: 'Belum Bayar',
                      amount: 'Rp 1.5M',
                      color: _dangerColor,
                      icon: Icons.cancel,
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        _FilterChip(label: 'Semua', selected: true),
                        SizedBox(width: 10),
                        _FilterChip(label: 'Lunas'),
                        SizedBox(width: 10),
                        _FilterChip(label: 'Belum Lunas'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    for (final bill in _bills) ...[
                      _BillTile(
                        bill: bill,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DetailTagihanScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            const PenghuniBottomNav(currentIndex: 1),
          ],
        ),
      ),
    );
  }
}

class _BillItem {
  const _BillItem({
    required this.title,
    required this.date,
    required this.amount,
    required this.status,
    required this.isPaid,
  });

  final String title;
  final String date;
  final String amount;
  final String status;
  final bool isPaid;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  amount,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? TagihanScreen._primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? TagihanScreen._primaryColor
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.bill, required this.onTap});

  final _BillItem bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = bill.isPaid
        ? TagihanScreen._primaryColor
        : const Color(0xFFF1B64C);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 13, 10, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  bill.isPaid
                      ? Icons.calendar_month_outlined
                      : Icons.error_outline,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            bill.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1F2933),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StatusBadge(label: bill.status, isPaid: bill.isPaid),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bill.date,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bill.amount,
                      style: const TextStyle(
                        color: TagihanScreen._primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFCAD2D7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.isPaid});

  final String label;
  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final color = isPaid
        ? TagihanScreen._primaryColor
        : TagihanScreen._dangerColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

