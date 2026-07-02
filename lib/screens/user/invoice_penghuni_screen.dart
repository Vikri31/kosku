import 'package:flutter/material.dart';

class InvoicePenghuniScreen extends StatelessWidget {
  const InvoicePenghuniScreen({super.key});

  static const Color _primaryColor = Color(0xFF007461);
  static const Color _backgroundColor = Color(0xFFF4F6F7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        toolbarHeight: 54,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        titleSpacing: 0,
        title: const Text(
          'Detail Tagihan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invoice Pembayaran',
                  style: TextStyle(
                    color: Color(0xFF1F2933),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Berikut adalah detail tagihan sewa bulanan Anda.',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.apartment,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KosKu',
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '#INV-202310 - 0892',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _StatusBadge(),
                  ],
                ),
                const SizedBox(height: 22),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PartyInfo(
                        label: 'PENYEWA',
                        name: 'Ananda Pratama',
                        details: '+62 812-3456-7890',
                        alignRight: false,
                      ),
                    ),
                    Expanded(
                      child: _PartyInfo(
                        label: 'UNIT & LANTAI',
                        name: 'Kamar A-12',
                        details: 'Lantai 2, Sayap Timur',
                        alignRight: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7F7),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        color: _primaryColor,
                        size: 18,
                      ),
                      SizedBox(width: 9),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Periode Sewa',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '01 Oktober 2023 - 31 Oktober 2023',
                            style: TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const _InvoiceTable(),
                const SizedBox(height: 18),
                const Divider(color: Color(0xFFE5E7EB), height: 1),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total Tagihan',
                        style: TextStyle(
                          color: Color(0xFF1F2933),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      'Rp 2.000.000',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text(
                    'Pembayaran telah diterima via Bank Transfer pada\n05 Okt 2023. Terima kasih telah melakukan\npembayaran tepat waktu!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.download_outlined, size: 17),
                    label: const Text(
                      'Simpan ke Galeri',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF9CA3AF),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: InvoicePenghuniScreen._primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: InvoicePenghuniScreen._primaryColor,
            size: 10,
          ),
          SizedBox(width: 4),
          Text(
            'LUNAS',
            style: TextStyle(
              color: InvoicePenghuniScreen._primaryColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyInfo extends StatelessWidget {
  const _PartyInfo({
    required this.label,
    required this.name,
    required this.details,
    required this.alignRight,
  });

  final String label;
  final String name;
  final String details;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          name,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF1F2933),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          details,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InvoiceTable extends StatelessWidget {
  const _InvoiceTable();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Deskripsi Item',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'Jumlah',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        _InvoiceRow(
          title: 'Sewa Kamar Reguler',
          subtitle: 'Biaya sewa pokok bulanan',
          amount: 'Rp1.800.000',
        ),
        SizedBox(height: 13),
        _InvoiceRow(
          title: 'Biaya Listrik & Air',
          subtitle: 'Pemakaian Flat',
          amount: 'Rp 150.000',
        ),
        SizedBox(height: 13),
        _InvoiceRow(
          title: 'Iuran Kebersihan',
          subtitle: 'Layanan kebersihan lingkungan',
          amount: 'Rp 50.000',
        ),
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1F2933),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          amount,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Color(0xFF1F2933),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
