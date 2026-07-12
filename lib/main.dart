import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/pilih_role_screen.dart';
import 'screens/auth/register_penghuni_screen.dart';
import 'screens/admin/dashboard/dashboard_screen.dart';
import 'screens/user/dashboard/dashboard_penghuni_screen.dart';
import 'screens/user/tagihan/tagihan_screen.dart';
import 'screens/user/profil/lengkapi_data_diri_screen.dart';
import 'screens/user/join/input_kode_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/notification/notification_list_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  try {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  } catch (e) {
    debugPrint('Gagal inisialisasi local notification: $e');
  }

  try {
    await Supabase.initialize(
      url: 'https://lscrtjygvlamygonwihn.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxzY3J0anlndmxhbXlnb253aWhuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAwMDM5NjMsImV4cCI6MjA5NTU3OTk2M30.03NJ5aSG3sC9oGJUVMQBkJFhJmcQXxMJmvHgGY-pm9A',
    );

    runApp(const MyApp());
  } catch (e) {
    runApp(const StartupErrorApp());
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Gagal menghubungkan aplikasi ke Supabase.')),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KosKu Gateway',
      theme: ThemeData(
        primaryColor: const Color(
          0xFF004D40,
        ), // Diselaraskan dengan warna dasar gelap kehijauan
        scaffoldBackgroundColor: Colors.white,
      ),
      // Rute awal diarahkan ke '/' yang mengaktifkan pengecekan session di AuthGate
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/pilih-role': (context) => const PilihRoleScreen(),
        '/register-penghuni': (context) => const RegisterPenghuniScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/dashboard-penghuni': (context) => const DashboardPenghuniScreen(),
        '/tagihan': (context) => const TagihanScreen(),
        '/lengkapi-data': (context) => const LengkapiDataDiriScreen(),
        '/input-kode': (context) => const InputKodeScreen(),
        '/gerbang': (context) => const GerbangUtamaScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/notifications': (context) => const NotificationListScreen(),
      },
    );
  }
}

// ── WIDGET AUTH GATE (Pencegah & Penyeleksi Sesi) ────────────────────────────
// Widget Stateful ini bertindak sebagai penjaga gerbang masuk aplikasi.
// Ia mendeteksi status login pengguna secara instan dan real-time menggunakan Supabase Auth.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Session? _currentSession;
  bool _isLoading = true;
  Future<String?>? _roleFuture;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    // A. Periksa session saat pertama kali aplikasi dimuat (Sync Check)
    _checkInitialSession();
    // B. Dengarkan perubahan status login secara real-time (Login / Logout / Session Expired)
    _listenToAuthChanges();
  }

  void _requestNotificationPermission() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _showSystemNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'kosku_notifikasi_channel', // id
      'Notifikasi KosKu', // name
      channelDescription: 'Channel untuk notifikasi real-time aplikasi KosKu',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000), // unique id
        title,
        body,
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('Gagal memicu notifikasi sistem: $e');
    }
  }

  void _setupNotificationRealtimeListener(String userId) {
    _notificationSubscription?.cancel();
    _notificationSubscription = Supabase.instance.client
        .from('notifikasi')
        .stream(primaryKey: ['id_notifikasi'])
        .eq('id_user', userId)
        .listen((List<Map<String, dynamic>> notifs) {
          if (!mounted) return;
          if (notifs.isNotEmpty) {
            final latestNotif = notifs.first;
            final bool isRead = latestNotif['status_dibaca'] ?? false;
            final createdAtStr = latestNotif['created_at'];
            if (!isRead && createdAtStr != null) {
              final createdAt = DateTime.tryParse(createdAtStr);
              if (createdAt != null) {
                // Membandingkan dengan konversi UTC agar terhindar dari perbedaan zona waktu lokal device (WIB/WITA/WIT)
                final diffInSeconds = DateTime.now().toUtc().difference(createdAt.toUtc()).inSeconds.abs();
                if (diffInSeconds < 15) {
                  // Tampilkan snackbar in-app sebagai popup notifikasi
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF004D40), // Teal warna tema KosKu
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      content: Row(
                        children: [
                          const Icon(Icons.notifications_active, color: Color(0xFFFFA834)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  latestNotif['judul'] ?? 'Notifikasi Baru',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  latestNotif['pesan'] ?? '',
                                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      action: SnackBarAction(
                        label: 'LIHAT',
                        textColor: const Color(0xFFFFA834),
                        onPressed: () {
                          Navigator.pushNamed(context, '/notifications');
                        },
                      ),
                    ),
                  );

                  // Tampilkan notifikasi sistem bersuara di HP
                  _showSystemNotification(
                    latestNotif['judul'] ?? 'Notifikasi Baru',
                    latestNotif['pesan'] ?? '',
                  );
                }
              }
            }
          }
        });
  }

  void _cancelNotificationRealtimeListener() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  void _checkInitialSession() {
    final session = Supabase.instance.client.auth.currentSession;

    setState(() {
      _currentSession = session;
      _roleFuture = session == null ? null : _getUserRole(session.user);
      _isLoading = false;
    });

    if (session != null) {
      _setupNotificationRealtimeListener(session.user.id);
    }
  }

  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (!mounted) return;

      setState(() {
        _currentSession = data.session;
        _roleFuture = data.session == null
            ? null
            : _getUserRole(data.session!.user);
      });

      if (data.session != null) {
        _setupNotificationRealtimeListener(data.session!.user.id);
      } else {
        _cancelNotificationRealtimeListener();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cancelNotificationRealtimeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // KONDISI LOADING: Menampilkan indikator loading saat session sedang diperiksa
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF004D40),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // KONDISI BELUM LOGIN (session == null): Arahkan paksa ke LoginScreen()
    if (_currentSession == null) {
      return const LoginScreen();
    }

    // KONDISI SUDAH LOGIN (session != null):
    // Ambil data pengguna dan cari role untuk menentukan layar beranda yang cocok
    final user = _currentSession!.user;

    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF004D40),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Memverifikasi Akun...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const LoginScreen();
        }

        final role = snapshot.data;

        // Arahkan admin / pemilik ke Dashboard Admin
        if (role == 'admin' || role == 'pemilik') {
          return const DashboardScreen();
        }
        // Arahkan penyewa / penghuni ke Dashboard Penghuni (HomeScreen)
        else if (role == 'user' || role == 'penghuni') {
          return const DashboardPenghuniScreen();
        }
        // Jika role belum terdaftar/tidak diketahui, berikan akses untuk menginput kode kamar
        else {
          return const InputKodeScreen();
        }
      },
    );
  }

  // Fungsi pembantu (helper) untuk mengambil role pengguna secara aman
  Future<String?> _getUserRole(User user) async {
    final client = Supabase.instance.client;
    String? role;

    try {
      // Langkah 1: Cari role di tabel detail_penyewa
      final detail = await client
          .from('detail_penyewa')
          .select()
          .eq('id_user', user.id)
          .maybeSingle();

      if (detail != null && detail['role'] != null) {
        role = detail['role'].toString();
      }
    } catch (_) {
      // Abaikan error query
    }

    // Langkah 2: Fallback ke metadata akun user jika tidak ada di tabel detail_penyewa
    if (role == null) {
      final metadata = user.userMetadata;
      if (metadata != null && metadata['role'] != null) {
        role = metadata['role'].toString();
      } else {
        // Deteksi alternatif jika metadata memiliki nama_kos, berarti pemilik (admin)
        if (metadata != null && metadata.containsKey('nama_kos')) {
          role = 'pemilik';
        }
      }
    }

    return role;
  }
}

class GerbangUtamaScreen extends StatelessWidget {
  const GerbangUtamaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Menggunakan background gelap kehijauan khas splash screen kelompok kalian
      backgroundColor: const Color(0xFF004D40),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('kamar')
            .stream(primaryKey: ['id_kamar']),
        builder: (context, snapshot) {
          // 1. KONDISI LOADING: Saat mengecek koneksi awal
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Menghubungkan ke server KosKu...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          // 2. KONDISI ERROR: Koneksi internet putus / database bermasalah
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.gpp_bad,
                      color: Colors.redAccent,
                      size: 70,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'KONEKSI KE SERVER GAGAL',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Harap periksa koneksi internet kelompok kalian.\nError: ${snapshot.error}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ), // Sudah diperbaiki dari whiteAA ke white70
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // 3. KONDISI SUKSES: Terhubung dengan database cloud (Tabel isi ataupun kosong)
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- Bagian Atas: Status Indikator Validasi Jaringan ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(
                        alpha: 0.2,
                      ), // Sudah diperbaiki menggunakan dengan .withValues
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.greenAccent),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Supabase Cloud Connected & Realtime Active',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Bagian Tengah: Identitas & Logo Aplikasi (Sesuai Mockup) ---
                  Column(
                    children: [
                      // Tempat menaruh logo icon_kosku.jpeg nantinya
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.home_work,
                          size: 65,
                          color: Color(0xFF004D40),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'KosKu',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Kelola Kos Lebih Mudah',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  // --- Bagian Bawah: Tombol Gerbang Masuk Aplikasi ---
                  Column(
                    // <-- Properti width: double.infinity yang salah sudah dihapus dari sini
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.white, // Tombol kontras putih
                            foregroundColor: const Color(0xFF004D40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () {
                            Navigator.of(context).pushNamed('/login');
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Masuk ke Aplikasi',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tugas Pemrograman Mobile - Kelompok KosKu',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
