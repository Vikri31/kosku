import 'dart:convert';
import 'dart:io';

void main() async {
  print('=====================================================================');
  print(' 📑               KOSKU NOTIFICATION TESTING SYSTEM                  ');
  print('=====================================================================');

  // 1. Membaca file .env
  final envFile = File('.env');
  if (!await envFile.exists()) {
    print('ERROR: File .env tidak ditemukan di root project.');
    print('Pastikan file .env ada dan berisi SUPABASE_URL dan SUPABASE_ANON_KEY.');
    return;
  }

  String? supabaseUrl;
  String? supabaseAnonKey;
  String? supabaseServiceKey;

  final lines = await envFile.readAsLines();
  for (var line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('SUPABASE_URL=')) {
      supabaseUrl = trimmed.split('SUPABASE_URL=')[1].trim().replaceAll('"', '').replaceAll("'", "");
    } else if (trimmed.startsWith('SUPABASE_ANON_KEY=')) {
      supabaseAnonKey = trimmed.split('SUPABASE_ANON_KEY=')[1].trim().replaceAll('"', '').replaceAll("'", "");
    } else if (trimmed.startsWith('SUPABASE_SERVICE_ROLE_KEY=')) {
      supabaseServiceKey = trimmed.split('SUPABASE_SERVICE_ROLE_KEY=')[1].trim().replaceAll('"', '').replaceAll("'", "");
    }
  }

  if (supabaseUrl == null || supabaseAnonKey == null) {
    print('ERROR: SUPABASE_URL atau SUPABASE_ANON_KEY tidak ditemukan di .env.');
    return;
  }

  // Jika service key tidak ada di .env, tanyakan ke user
  if (supabaseServiceKey == null || supabaseServiceKey.isEmpty) {
    print('\n⚠️  Supabase Row Level Security (RLS) terdeteksi.');
    print('Untuk melakukan testing tanpa login, Anda memerlukan "service_role" key.');
    print('Dapatkan key ini di: Supabase Dashboard -> Project Settings -> API -> service_role');
    stdout.write('\nMasukkan SUPABASE_SERVICE_ROLE_KEY (atau tekan ENTER untuk skip & menggunakan anon key): ');
    final inputKey = stdin.readLineSync()?.trim() ?? '';
    if (inputKey.isNotEmpty) {
      supabaseServiceKey = inputKey;
    }
  }

  final useServiceKey = supabaseServiceKey != null && supabaseServiceKey.isNotEmpty;
  final activeKey = useServiceKey ? supabaseServiceKey : supabaseAnonKey;

  print('\nMenggunakan Supabase URL: $supabaseUrl');
  print('Mode Autentikasi: ${useServiceKey ? "Bypass RLS (Service Role)" : "Anon Key (Terkena RLS)"}');

  final client = HttpClient();
  
  // Helper function to send HTTP requests to Supabase REST API
  Future<dynamic> requestSupabase(String path, String method, {dynamic body, Map<String, String>? extraHeaders}) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1$path');
      final request = await client.openUrl(method, uri);
      
      // Add standard Supabase headers
      request.headers.set('apikey', supabaseAnonKey!);
      request.headers.set('Authorization', 'Bearer $activeKey');
      request.headers.set('Content-Type', 'application/json');
      
      if (extraHeaders != null) {
        extraHeaders.forEach((key, val) {
          request.headers.set(key, val);
        });
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody.isEmpty) return null;
        return jsonDecode(responseBody);
      } else {
        throw HttpException('Request failed with status ${response.statusCode}: $responseBody');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 2. Mengambil daftar user untuk mempermudah pemilihan target
  print('\nMengambil data user dari database...');
  List<Map<String, dynamic>> userChoices = [];
  try {
    final tokensData = await requestSupabase('/user_tokens?select=id_user,fcm_token', 'GET') as List<dynamic>?;
    final detailPenyewaData = await requestSupabase('/detail_penyewa?select=id_user,nik', 'GET') as List<dynamic>?;
    final adminData = await requestSupabase('/profil_admin?select=id_admin,nama_lengkap,nama_kost', 'GET') as List<dynamic>?;
    
    // Simpan data nama admin
    Map<String, String> adminNames = {};
    if (adminData != null) {
      for (var a in adminData) {
        if (a['id_admin'] != null && a['nama_lengkap'] != null) {
          final kostName = a['nama_kost'] != null ? ' - Kost: ${a['nama_kost']}' : '';
          adminNames[a['id_admin'].toString()] = '[Admin] ${a['nama_lengkap']}$kostName';
        }
      }
    }

    // Simpan data NIK penyewa
    Map<String, String> userNiks = {};
    if (detailPenyewaData != null) {
      for (var d in detailPenyewaData) {
        if (d['id_user'] != null && d['nik'] != null) {
          userNiks[d['id_user'].toString()] = d['nik'].toString();
        }
      }
    }

    // Mengambil data nama penyewa
    Map<String, String> userNames = {};
    try {
      final penyewaData = await requestSupabase('/penyewa?select=nama_lengkap,nik', 'GET') as List<dynamic>?;
      if (penyewaData != null) {
        for (var p in penyewaData) {
          final nik = p['nik']?.toString();
          if (nik != null) {
            userNiks.forEach((idUser, uNik) {
              if (uNik == nik) {
                userNames[idUser] = '[Penyewa] ${p['nama_lengkap']}';
              }
            });
          }
        }
      }
    } catch (_) {}

    // Kumpulkan user unik
    Set<String> uniqueUserIds = {};
    
    // Masukkan data admin terlebih dahulu agar mudah dipilih
    if (adminData != null) {
      for (var a in adminData) {
        final idAdmin = a['id_admin']?.toString();
        if (idAdmin != null) {
          uniqueUserIds.add(idAdmin);
          
          // Cari token FCM jika ada
          String? fcmToken;
          if (tokensData != null) {
            for (var t in tokensData) {
              if (t['id_user']?.toString() == idAdmin) {
                fcmToken = t['fcm_token']?.toString();
                break;
              }
            }
          }

          userChoices.add({
            'id_user': idAdmin,
            'fcm_token': fcmToken,
            'nama': adminNames[idAdmin] ?? '[Admin] Unknown',
          });
        }
      }
    }

    if (tokensData != null) {
      for (var t in tokensData) {
        final idUser = t['id_user']?.toString();
        if (idUser != null && !uniqueUserIds.contains(idUser)) {
          uniqueUserIds.add(idUser);
          userChoices.add({
            'id_user': idUser,
            'fcm_token': t['fcm_token'],
            'nama': userNames[idUser] ?? 'User (NIK: ${userNiks[idUser] ?? 'Tidak Diketahui'})',
          });
        }
      }
    }

    if (detailPenyewaData != null) {
      for (var d in detailPenyewaData) {
        final idUser = d['id_user']?.toString();
        if (idUser != null && !uniqueUserIds.contains(idUser)) {
          uniqueUserIds.add(idUser);
          userChoices.add({
            'id_user': idUser,
            'fcm_token': null,
            'nama': userNames[idUser] ?? 'User (NIK: ${d['nik']})',
          });
        }
      }
    }
  } catch (e) {
    print('Catatan: Gagal mengambil daftar user ($e).');
  }

  // 3. Tampilkan list user
  print('\n=== DAFTAR USER YANG TERSEDIA DI DATABASE ===');
  if (userChoices.isEmpty) {
    print('Tidak ada user yang ditemukan di tabel detail_penyewa atau user_tokens.');
    print('Anda harus memasukkan UUID User secara manual.');
  } else {
    for (int i = 0; i < userChoices.length; i++) {
      final item = userChoices[i];
      final fcmToken = item['fcm_token'];
      final fcmDisplay = fcmToken != null ? fcmToken : 'Kosong';
      print('[${i + 1}] Nama: ${item['nama']}');
      print('    ID: ${item['id_user']}');
      print('    FCM: $fcmDisplay');
      print('    -----------------------------------------------------------------');
    }
  }
  print('\n[M] Masukkan UUID User Secara Manual');

  stdout.write('\nPilih User tujuan (1-${userChoices.length} atau M): ');
  final userChoiceInput = stdin.readLineSync()?.trim() ?? '';
  
  String targetUserId = '';

  if (userChoiceInput.toUpperCase() == 'M' || userChoices.isEmpty) {
    stdout.write('Masukkan UUID User tujuan: ');
    targetUserId = stdin.readLineSync()?.trim() ?? '';
  } else {
    final index = int.tryParse(userChoiceInput);
    if (index != null && index >= 1 && index <= userChoices.length) {
      targetUserId = userChoices[index - 1]['id_user'];
    } else {
      print('Pilihan tidak valid. Menggunakan input manual...');
      stdout.write('Masukkan UUID User tujuan: ');
      targetUserId = stdin.readLineSync()?.trim() ?? '';
    }
  }

  if (targetUserId.isEmpty) {
    print('ERROR: UUID User tidak boleh kosong.');
    client.close();
    return;
  }

  // 4. Konfigurasi FCM Token
  final defaultAdminFcm = 'c1tPH9UrRM-cg1xuUZO4rv:APA91bHLxNMcrbvs7ZGcY2oVZw-RjrZxgbFzbJn0Up7-R9wpWBV2x-_y8fQa8mYtmIjo7gDZ6CuKNZl4s2y46_pha7ljM4vj78U0FG8D-z8-PT5dwxbX2_k';
  
  print('\nFCM Token Admin default yang Anda berikan:');
  print('[$defaultAdminFcm]');
  
  stdout.write('\nMasukkan FCM Token tujuan (Tekan ENTER untuk menggunakan default Admin): ');
  String targetFcmToken = stdin.readLineSync()?.trim() ?? '';
  if (targetFcmToken.isEmpty) {
    targetFcmToken = defaultAdminFcm;
  }

  // 5. Update FCM Token di tabel user_tokens
  print('\nMemetakan FCM Token ke ID User di tabel "user_tokens"...');
  try {
    // Hapus pemetaan lama untuk token ini jika ada, agar tidak terkena unique constraint
    try {
      await requestSupabase(
        '/user_tokens?fcm_token=eq.$targetFcmToken', 
        'DELETE'
      );
    } catch (e) {
      // Abaikan jika gagal delete
    }

    await requestSupabase(
      '/user_tokens', 
      'POST',
      body: {
        'id_user': targetUserId,
        'fcm_token': targetFcmToken,
        'device_type': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      },
      extraHeaders: {
        'Prefer': 'resolution=merge'
      }
    );
    print('✅ SUKSES: Token FCM berhasil dipetakan ke User ID tersebut.');
  } catch (e) {
    print('⚠️ WARNING: Gagal upsert ke tabel user_tokens: $e');
    print('Tetap melanjutkan untuk mengirim data notifikasi...');
  }

  // 6. Menu Skenario Notifikasi
  print('\n=== PILIH SKENARIO NOTIFIKASI YANG AKAN DITEST ===');
  print('[1] User mendapat Invoice Baru (FCM ke User)');
  print('[2] Admin mendapat Invoice Masuk / Pembayaran Baru (FCM ke Admin)');
  print('[3] User mendapat update Pembayaran Disetujui (FCM ke User)');
  print('[4] User mendapat update Pembayaran Ditolak (FCM ke User)');
  print('[5] Admin mendapat notifikasi ketika ada yang join Kamar (FCM ke Admin)');
  print('[6] Kustom (Input Judul, Pesan, dan Kategori sendiri)');

  stdout.write('\nPilih nomor skenario (1-6): ');
  final scenarioInput = stdin.readLineSync()?.trim() ?? '';

  String title = '';
  String message = '';
  String category = '';

  switch (scenarioInput) {
    case '1':
      title = 'Tagihan Invoice Baru';
      message = 'Tagihan baru invoice #INV-2026-0089 telah diterbitkan sebesar Rp 450.000. Harap segera bayar sebelum jatuh tempo.';
      category = 'penyewa'; // Menggunakan kategori valid 'penyewa'
      break;
    case '2':
      title = 'Pembayaran Invoice Masuk';
      message = 'Ada konfirmasi pembayaran masuk dari Kamar 103 sebesar Rp 450.000. Silakan verifikasi bukti transfer.';
      category = 'admin'; // Menggunakan kategori valid 'admin'
      break;
    case '3':
      title = 'Pembayaran Disetujui';
      message = 'Pembayaran tagihan Anda untuk Invoice #INV-2026-0089 sebesar Rp 450.000 telah DISETUJUI oleh Admin. Status: Lunas.';
      category = 'penyewa'; // Menggunakan kategori valid 'penyewa'
      break;
    case '4':
      title = 'Pembayaran Ditolak';
      message = 'Pembayaran tagihan Anda untuk Invoice #INV-2026-0089 DITOLAK oleh Admin. Alasan: Nominal transfer kurang.';
      category = 'penyewa'; // Menggunakan kategori valid 'penyewa'
      break;
    case '5':
      title = 'Permohonan Kamar Baru';
      message = 'Pengguna baru (a.n. Akhmad Vikri) telah mengajukan permohonan join ke Kamar 103. Konfirmasi di Dashboard Admin.';
      category = 'admin'; // Menggunakan kategori valid 'admin' karena ditujukan ke admin
      break;
    case '6':
      stdout.write('Masukkan Judul Notifikasi: ');
      title = stdin.readLineSync()?.trim() ?? 'Test Judul';
      stdout.write('Masukkan Isi Pesan Notifikasi: ');
      message = stdin.readLineSync()?.trim() ?? 'Test Pesan';
      stdout.write('Masukkan Kategori (wajib: penyewa atau admin): ');
      category = stdin.readLineSync()?.trim() ?? 'penyewa';
      break;
    default:
      print('Pilihan tidak valid. Membatalkan testing.');
      client.close();
      return;
  }

  print('\n--- DETAIL NOTIFIKASI YANG AKAN DIKIRIM ---');
  print('Target User ID : $targetUserId');
  print('FCM Token      : $targetFcmToken');
  print('Judul          : $title');
  print('Pesan          : $message');
  print('Kategori       : $category');
  print('-------------------------------------------');
  
  stdout.write('\nKirim notifikasi sekarang? (Y/N): ');
  final confirm = stdin.readLineSync()?.trim() ?? '';
  if (confirm.toUpperCase() != 'Y') {
    print('Batal mengirim.');
    client.close();
    return;
  }

  print('\nMengirim notifikasi dengan memasukkan data ke tabel "notifikasi"...');
  try {
    final response = await requestSupabase(
      '/notifikasi', 
      'POST', 
      body: {
        'id_user': targetUserId,
        'judul': title,
        'pesan': message,
        'kategori': category,
        'status_dibaca': false,
        'created_at': DateTime.now().toUtc().toIso8601String(), // Mengatasi desinkronisasi jam HP & Server
      },
      extraHeaders: {
        'Prefer': 'return=representation'
      }
    );

    print('\n=====================================================================');
    print(' 🎉 NOTIFIKASI BERHASIL DISIMPAN KE DATABASE!');
    print('=====================================================================');
    print('Respon Database: ${jsonEncode(response)}');
    print('\n💡 TIPS PENTING UNTUK TESTING:');
    print('1. NOTIFIKASI IN-APP (Aplikasi Sedang Terbuka):');
    print('   Agar SnackBar/notifikasi bersuara berbunyi di HP Anda saat aplikasi terbuka,');
    print('   akun yang sedang login di HP harus sama dengan User ID tujuan yang Anda pilih.');
    print('   Jika Anda sedang login sebagai Admin di HP, pilih User Admin di menu script.');
    print('2. PUSH NOTIFICATION (Aplikasi Sedang Ditutup/Background):');
    print('   Dikirim via Firebase FCM. Jika tidak muncul, pastikan Firebase Credentials');
    print('   (Project ID, Client Email, Private Key) telah di-input ke Secrets Supabase.');
    print('   Anda bisa cek log pengirimannya di:');
    print('   Supabase Dashboard -> Edge Functions -> send-push-notification -> Logs');
    print('=====================================================================');
  } catch (e) {
    print('❌ ERROR: Gagal mengirim notifikasi: $e');
  }

  client.close();
  print('\nTekan ENTER untuk keluar.');
  stdin.readLineSync();
}
