import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _client = Supabase.instance.client;

  /// Mengirimkan notifikasi baru ke database Supabase
  static Future<void> sendNotification({
    required String idUser,
    required String judul,
    required String pesan,
    required String kategori,
  }) async {
    try {
      await _client.from('notifikasi').insert({
        'id_user': idUser,
        'judul': judul,
        'pesan': pesan,
        'kategori': kategori,
        'status_dibaca': false,
      });
    } catch (e) {
      // Supress and print for debugging
      debugPrint('Gagal mengirim notifikasi: $e');
    }
  }

  /// Mendapatkan Stream realtime dari tabel notifikasi milik user aktif
  static Stream<List<Map<String, dynamic>>> streamNotifications(String userId) {
    return _client
        .from('notifikasi')
        .stream(primaryKey: ['id_notifikasi'])
        .eq('id_user', userId)
        .order('created_at', ascending: false);
  }

  /// Menandai notifikasi tertentu sebagai sudah dibaca
  static Future<void> markAsRead(String idNotifikasi) async {
    try {
      await _client
          .from('notifikasi')
          .update({'status_dibaca': true})
          .eq('id_notifikasi', idNotifikasi);
    } catch (e) {
      debugPrint('Gagal menandai notifikasi telah dibaca: $e');
    }
  }

  /// Menghapus notifikasi tertentu
  static Future<void> deleteNotification(String idNotifikasi) async {
    try {
      await _client.from('notifikasi').delete().eq('id_notifikasi', idNotifikasi);
    } catch (e) {
      debugPrint('Gagal menghapus notifikasi: $e');
    }
  }

  /// Mencari User ID penyewa dari id_sewa
  static Future<String?> getPenyewaUserId(int idSewa) async {
    try {
      final sewa = await _client
          .from('sewa')
          .select('id_penyewa')
          .eq('id_sewa', idSewa)
          .maybeSingle();
      if (sewa == null) return null;
      final idPenyewa = sewa['id_penyewa'];

      final penyewa = await _client
          .from('penyewa')
          .select('nik')
          .eq('id_penyewa', idPenyewa)
          .maybeSingle();
      if (penyewa == null) return null;
      final nik = penyewa['nik'];

      final detail = await _client
          .from('detail_penyewa')
          .select('id_user')
          .eq('nik', nik)
          .maybeSingle();
      if (detail == null) return null;
      return detail['id_user']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Mencari Admin/Pemilik User ID dari id_sewa
  static Future<String?> getAdminUserId(int idSewa) async {
    try {
      final sewa = await _client
          .from('sewa')
          .select('id_kamar')
          .eq('id_sewa', idSewa)
          .maybeSingle();
      if (sewa == null) return null;
      final idKamar = sewa['id_kamar'];

      final kamar = await _client
          .from('kamar')
          .select('id_admin')
          .eq('id_kamar', idKamar)
          .maybeSingle();
      if (kamar == null) return null;
      return kamar['id_admin']?.toString();
    } catch (_) {
      return null;
    }
  }
}
