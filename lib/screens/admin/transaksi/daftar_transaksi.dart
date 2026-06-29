import 'package:flutter/material.dart';

import 'detail_transaksi.dart';
import 'tambah_transaksi.dart';
import 'transaksi_models.dart';

class DaftarTransaksiScreen extends StatelessWidget {
  const DaftarTransaksiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF004D40);

    return Scaffold(
      backgroundColor: transaksiBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'KosKu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: primaryColor,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daftar Transaksi',
                        style: TextStyle(
                          color: transaksiTextColor,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Kelola pembayaran dan tagihan penyewa',
                        style: TextStyle(color: Color(0xFF7B858E), fontSize: 11),
                      ),
                    ],
                  ),
                  Container(
                    width: 35,
                    height: 35,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6EBEF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      color: Color(0xFF596268),
                      size: 21,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: sampleTransactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = sampleTransactions[index];
                    return _TransactionCard(item: item);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TambahTransaksiScreen()),
          );
        },
        backgroundColor: transaksiAccentColor,
        foregroundColor: const Color(0xFF332000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.add_rounded, size: 29),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionItem item;

  const _TransactionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final paidColor = item.isPaid ? transaksiPrimaryColor : const Color(0xFFD93D3D);
    final paidBackground = item.isPaid ? const Color(0xFF9DEBDC) : const Color(0xFFFFD6D6);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailTransaksiScreen(item: item)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.isPaid ? const Color(0xFFD9F4EF) : const Color(0xFFE8ECEF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: item.isPaid ? transaksiPrimaryColor : const Color(0xFF737B82),
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.tenantName,
                          style: const TextStyle(
                            color: transaksiTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.meeting_room_outlined,
                              color: Color(0xFF6E777F),
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Kamar ${item.room}',
                              style: const TextStyle(color: Color(0xFF6E777F), fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: paidBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.isPaid ? 'LUNAS' : 'BELUM',
                      style: TextStyle(
                        color: paidColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              const Divider(height: 1, color: Color(0xFFE9EDF0)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatShortDate(item.paymentDate),
                    style: const TextStyle(color: Color(0xFF7B858E), fontSize: 11),
                  ),
                  Text(
                    formatRupiah(item.amount),
                    style: const TextStyle(
                      color: transaksiTextColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
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
