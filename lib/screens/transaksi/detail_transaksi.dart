import 'package:flutter/material.dart';

import 'preview_invoice.dart';
import 'tambah_transaksi.dart';
import 'transaksi_models.dart';

class DetailTransaksiScreen extends StatelessWidget {
  final TransactionItem item;

  const DetailTransaksiScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: transaksiBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Detail Transaksi',
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
          padding: const EdgeInsets.fromLTRB(17, 27, 17, 20),
          child: Column(
            children: [
              _PaidPill(isPaid: item.isPaid),
              const SizedBox(height: 17),
              Text(
                formatRupiah(item.amount),
                style: const TextStyle(
                  color: transaksiTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Pembayaran Sewa Kamar',
                style: TextStyle(color: Color(0xFF6D747A), fontSize: 12),
              ),
              const SizedBox(height: 39),
              _DetailCard(item: item),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 49,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PreviewInvoiceScreen(item: item)),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Generate Invoice'),
                  style: ElevatedButton.styleFrom(
                    elevation: 2,
                    backgroundColor: transaksiPrimaryColor,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => TambahTransaksiScreen(item: item)),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(38),
                        foregroundColor: transaksiTextColor,
                        side: const BorderSide(color: Color(0xFFB8C0C7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Hapus'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(38),
                        foregroundColor: const Color(0xFFE33B3B),
                        side: const BorderSide(color: Color(0xFFE33B3B)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaidPill extends StatelessWidget {
  final bool isPaid;

  const _PaidPill({required this.isPaid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFF9DEBDC) : const Color(0xFFFFD6D6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle : Icons.schedule_rounded,
            color: isPaid ? transaksiPrimaryColor : const Color(0xFFD93D3D),
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            isPaid ? 'Lunas' : 'Belum',
            style: TextStyle(
              color: isPaid ? transaksiPrimaryColor : const Color(0xFFD93D3D),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final TransactionItem item;

  const _DetailCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Nama Penyewa', value: item.tenantName),
          _DetailRow(label: 'Kamar', value: '${item.roomFloor} / ${item.room}'),
          _DetailRow(label: 'Tanggal Bayar', value: formatDetailDate(item.paymentDate)),
          _DetailRow(label: 'Metode Pembayaran', value: item.method),
          _DetailRow(label: 'ID Transaksi', value: item.id, compactValue: true, showDivider: false),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool compactValue;
  final bool showDivider;

  const _DetailRow({
    required this.label,
    required this.value,
    this.compactValue = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Color(0xFF6D747A), fontSize: 12),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: compactValue ? const Color(0xFF9AA2AA) : transaksiTextColor,
                  fontSize: compactValue ? 9 : 13,
                  fontWeight: compactValue ? FontWeight.w700 : FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, color: Color(0xFFE8ECEF)),
      ],
    );
  }
}
