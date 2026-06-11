import 'package:flutter/material.dart';

import 'transaksi_models.dart';

class TambahTransaksiScreen extends StatelessWidget {
  final TransactionItem? item;

  const TambahTransaksiScreen({super.key, this.item});

  @override
  Widget build(BuildContext context) {
    final selectedItem = item ?? sampleTransactions.first;

    return Scaffold(
      backgroundColor: transaksiBackgroundColor,
      appBar: AppBar(
        title: Text(
          item == null ? 'Tambah Transaksi' : 'Edit Transaksi',
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: transaksiPrimaryColor,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(17, 31, 17, 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(15, 18, 15, 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _InputBlock(
                      label: 'Pilih Penyewa',
                      child: DropdownButtonFormField<String>(
                        value: selectedItem.tenantName,
                        decoration: _inputDecoration(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                        items: sampleTransactions
                            .map(
                              (transaction) => DropdownMenuItem(
                                value: transaction.tenantName,
                                child: Text(transaction.tenantName),
                              ),
                            )
                            .toList(),
                        onChanged: (_) {},
                      ),
                    ),
                    _InputBlock(
                      label: 'Nominal',
                      helperText: 'Nominal otomatis terisi sesuai harga kamar, namun dapat diubah.',
                      child: TextFormField(
                        initialValue: formatRupiah(selectedItem.amount).replaceFirst('Rp ', 'Rp   '),
                        decoration: _inputDecoration(),
                      ),
                    ),
                    _InputBlock(
                      label: 'Tanggal Pembayaran',
                      child: TextFormField(
                        initialValue: formatInputDate(DateTime(2023, 10, 25)),
                        decoration: _inputDecoration(),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status Pembayaran',
                            style: TextStyle(
                              color: transaksiTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _RadioLabel(label: 'Lunas', selected: selectedItem.isPaid),
                              const SizedBox(width: 16),
                              _RadioLabel(label: 'Belum', selected: !selectedItem.isPaid),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InputBlock(
                      label: 'Catatan (Opsional)',
                      bottomMargin: 0,
                      child: TextFormField(
                        minLines: 3,
                        maxLines: 3,
                        decoration: _inputDecoration(hint: 'Tambahkan keterangan jika perlu...'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 38),
              SizedBox(
                width: double.infinity,
                height: 49,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Simpan Transaksi'),
                  style: ElevatedButton.styleFrom(
                    elevation: 4,
                    shadowColor: transaksiPrimaryColor.withValues(alpha: 0.28),
                    backgroundColor: transaksiPrimaryColor,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA2AA), fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xFFC9D1D6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: transaksiPrimaryColor, width: 1.4),
      ),
    );
  }
}

class _InputBlock extends StatelessWidget {
  final String label;
  final Widget child;
  final String? helperText;
  final double bottomMargin;

  const _InputBlock({
    required this.label,
    required this.child,
    this.helperText,
    this.bottomMargin = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: transaksiTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
          if (helperText != null) ...[
            const SizedBox(height: 7),
            Text(
              helperText!,
              style: const TextStyle(color: Color(0xFF7B858E), fontSize: 10, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

class _RadioLabel extends StatelessWidget {
  final String label;
  final bool selected;

  const _RadioLabel({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? transaksiPrimaryColor : const Color(0xFFB9C2C9),
              width: selected ? 5 : 2,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontSize: 12, color: transaksiTextColor)),
      ],
    );
  }
}
