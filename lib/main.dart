import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase menggunakan URL project kelompok
  await Supabase.initialize(
    url: 'https://lscrtjygvlamygonwihn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxzY3J0anlndmxhbXlnb253aWhuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAwMDM5NjMsImV4cCI6MjA5NTU3OTk2M30.03NJ5aSG3sC9oGJUVMQBkJFhJmcQXxMJmvHgGY-pm9A', // <-- Ganti dengan Anon Key asli dari WhatsApp
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tes Koneksi KosKu',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CekKoneksiScreen(),
    );
  }
}

class CekKoneksiScreen extends StatelessWidget {
  const CekKoneksiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // <-- Sudah diperbaiki dari app_appbar ke appBar
        title: const Text('🔌 Tes Koneksi Supabase'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('kamar')
            .stream(primaryKey: ['id_kamar']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 15),
                  Text('Sedang menghubungkan ke server Supabase...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(
                  20.0,
                ), // <-- Parameter align yang salah sudah dihapus
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gpp_bad, color: Colors.red, size: 60),
                    const SizedBox(height: 10),
                    const Text(
                      'KONEKSI GAGAL!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(color: Colors.grey),
                      textAlign:
                          TextAlign.center, // Perataan tengah ditaruh di sini
                    ),
                  ],
                ),
              ),
            );
          }

          final dataKamar = snapshot.data ?? [];
          if (dataKamar.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_done, color: Colors.green, size: 60),
                  SizedBox(height: 10),
                  Text(
                    'KONEKSI SUKSES!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text('Tabel "kamar" terbaca, tapi isinya masih kosong.'),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.green.shade100,
                padding: const EdgeInsets.all(12),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Koneksi Berhasil & Data Sinkron!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: dataKamar.length,
                  itemBuilder: (context, index) {
                    final kamar = dataKamar[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.bed, color: Colors.blue),
                        title: Text(
                          'Kamar No: ${kamar['nomor_kamar']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Harga: Rp ${kamar['harga_sewa_dasar']}',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: kamar['status_kamar'] == 'Kosong'
                                ? Colors.green.shade400
                                : Colors.orange.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${kamar['status_kamar']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
