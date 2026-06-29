import 'package:flutter/material.dart';

const transaksiPrimaryColor = Color(0xFF007965);
const transaksiAccentColor = Color(0xFFFFA726);
const transaksiBackgroundColor = Color(0xFFF4F7FA);
const transaksiTextColor = Color(0xFF202427);

class TransactionItem {
  final String id;
  final String tenantName;
  final String room;
  final String roomFloor;
  final DateTime paymentDate;
  final int amount;
  final bool isPaid;
  final String method;
  final String phone;
  final String invoiceNumber;
  final int electricityFee;

  const TransactionItem({
    required this.id,
    required this.tenantName,
    required this.room,
    required this.roomFloor,
    required this.paymentDate,
    required this.amount,
    required this.isPaid,
    required this.method,
    required this.phone,
    required this.invoiceNumber,
    this.electricityFee = 150000,
  });

  int get totalAmount => amount + electricityFee;
}

final sampleTransactions = [
  TransactionItem(
    id: 'TRX-20231024-001',
    tenantName: 'Budi Santoso',
    room: 'A-01',
    roomFloor: 'Lantai 1',
    paymentDate: DateTime(2023, 10, 24, 14, 30),
    amount: 1500000,
    isPaid: true,
    method: 'Transfer Bank (BCA)',
    phone: '+62 812-3456-7890',
    invoiceNumber: 'INV-202310-042',
  ),
  TransactionItem(
    id: 'TRX-20231012-002',
    tenantName: 'Siti Aminah',
    room: 'B2',
    roomFloor: 'Lantai 2',
    paymentDate: DateTime(2023, 10, 12, 9, 10),
    amount: 1200000,
    isPaid: false,
    method: 'Tunai',
    phone: '+62 813-2222-4567',
    invoiceNumber: 'INV-202310-041',
  ),
  TransactionItem(
    id: 'TRX-20231001-003',
    tenantName: 'Andi Wijaya',
    room: 'C3',
    roomFloor: 'Lantai 3',
    paymentDate: DateTime(2023, 10, 1, 11, 45),
    amount: 1500000,
    isPaid: true,
    method: 'Transfer Bank (Mandiri)',
    phone: '+62 856-7788-9012',
    invoiceNumber: 'INV-202310-040',
  ),
];

String formatRupiah(num value) {
  final text = value.toInt().toString();
  final buffer = StringBuffer();
  var count = 0;

  for (var i = text.length - 1; i >= 0; i--) {
    buffer.write(text[i]);
    count++;
    if (count % 3 == 0 && i != 0) {
      buffer.write('.');
    }
  }

  return 'Rp ${buffer.toString().split('').reversed.join()}';
}

String formatShortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

String formatDetailDate(DateTime date) {
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]}, $hour:$minute';
}

String formatInputDate(DateTime date) {
  return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
}
