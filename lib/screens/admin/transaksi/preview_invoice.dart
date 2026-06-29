import 'package:flutter/material.dart';

import 'transaksi_models.dart';

class PreviewInvoiceScreen extends StatelessWidget {
  final TransactionItem item;

  const PreviewInvoiceScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: transaksiBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Invoice',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF004D40),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview Invoice',
                        style: TextStyle(
                          color: transaksiTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pastikan data sudah benar sebelum dikirim.',
                        style: TextStyle(color: Color(0xFF7B858E), fontSize: 10),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.download_rounded, size: 18, color: transaksiTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _InvoicePaper(item: item),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 43,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_outlined, size: 17),
                  label: const Text('Kirim via WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: transaksiPrimaryColor,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                height: 39,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: transaksiTextColor,
                    side: const BorderSide(color: Color(0xFF9EADB5)),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoicePaper extends StatelessWidget {
  final TransactionItem item;

  const _InvoicePaper({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment_rounded, color: transaksiPrimaryColor, size: 24),
              const SizedBox(width: 5),
              Text(
                'KosKu',
                style: TextStyle(
                  color: Colors.teal.shade800,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Jl. Mawar Merah\nNo. 12,\nKecamatan\nSukamaju,\nJakarta',
            style: TextStyle(color: transaksiTextColor, fontSize: 10, height: 1.45),
          ),
          const SizedBox(height: 21),
          const Text(
            'INVOICE',
            style: TextStyle(
              color: transaksiTextColor,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.invoiceNumber,
            style: const TextStyle(color: Color(0xFF6E777F), fontSize: 10),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF9DEBDC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: transaksiPrimaryColor, size: 13),
                SizedBox(width: 5),
                Text(
                  'Status Lunas',
                  style: TextStyle(
                    color: transaksiPrimaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Divider(height: 1, color: Color(0xFFE3E7EB)),
          const SizedBox(height: 20),
          _InfoBox(
            title: 'Ditagihkan Kepada',
            lines: [
              _InfoLine.primary(item.tenantName),
              _InfoLine.secondary(item.phone),
            ],
          ),
          const SizedBox(height: 10),
          _InfoBox(
            lines: [
              _InfoLine.pair('Kamar', item.room, highlightValue: true),
              _InfoLine.pair('Periode Sewa', 'Okt 2023'),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Rincian Tagihan',
            style: TextStyle(color: transaksiTextColor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 13),
          _BillRow(label: 'Sewa Kamar (1 Bulan)', value: formatRupiah(item.amount)),
          const SizedBox(height: 10),
          _BillRow(label: 'Biaya Listrik Tambahan', value: formatRupiah(item.electricityFee)),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFD8DEE3)),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Nominal Tagihan',
                  style: TextStyle(
                    color: transaksiTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                formatRupiah(item.totalAmount),
                style: const TextStyle(
                  color: transaksiPrimaryColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Terima kasih atas pembayaran Anda.',
              style: TextStyle(color: Color(0xFF8C949C), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine {
  final String? label;
  final String value;
  final bool primary;
  final bool highlightValue;

  const _InfoLine({
    this.label,
    required this.value,
    this.primary = false,
    this.highlightValue = false,
  });

  factory _InfoLine.primary(String value) => _InfoLine(value: value, primary: true);

  factory _InfoLine.secondary(String value) => _InfoLine(value: value);

  factory _InfoLine.pair(String label, String value, {bool highlightValue = false}) {
    return _InfoLine(label: label, value: value, highlightValue: highlightValue);
  }
}

class _InfoBox extends StatelessWidget {
  final String? title;
  final List<_InfoLine> lines;

  const _InfoBox({this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE3E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(color: Color(0xFF6E777F), fontSize: 10),
            ),
            const SizedBox(height: 5),
          ],
          for (final line in lines) ...[
            Row(
              children: [
                if (line.label != null)
                  Expanded(
                    child: Text(
                      line.label!,
                      style: const TextStyle(color: transaksiTextColor, fontSize: 10),
                    ),
                  ),
                Text(
                  line.value,
                  style: TextStyle(
                    color: line.highlightValue ? transaksiPrimaryColor : transaksiTextColor,
                    fontSize: line.primary || line.highlightValue ? 12 : 10,
                    fontWeight: line.primary || line.highlightValue ? FontWeight.w900 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (line != lines.last) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;

  const _BillRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: transaksiTextColor, fontSize: 11),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: transaksiTextColor, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
