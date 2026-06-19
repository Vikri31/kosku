import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'kamar_form_screen.dart';
import 'kamar_detail_screen.dart';

class KamarListScreen extends StatefulWidget {
  const KamarListScreen({super.key});

  @override
  State<KamarListScreen> createState() => _KamarListScreenState();
}

class _KamarListScreenState extends State<KamarListScreen> {
  String _selectedFilter = 'Semua'; // Semua, Terisi, Kosong

  // Helper to format currency
  String _formatRupiah(num number) {
    final str = number.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return 'Rp ${buffer.toString().split('').reversed.join('')}';
  }

  // Future helper to get tenant's name
  Future<String> _getActiveTenantName(int idKamar) async {
    try {
      final sewaData = await Supabase.instance.client
          .from('sewa')
          .select('id_penyewa')
          .eq('id_kamar', idKamar)
          .eq('status_sewa', 'Aktif')
          .maybeSingle();

      if (sewaData == null) return 'Belum ada penyewa';

      final penyewaData = await Supabase.instance.client
          .from('penyewa')
          .select('nama_lengkap')
          .eq('id_penyewa', sewaData['id_penyewa'])
          .maybeSingle();

      return penyewaData?['nama_lengkap'] ?? 'Penyewa';
    } catch (e) {
      return 'Belum ada penyewa';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF004D40);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text(
          'KosKu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER & FILTER ICON ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daftar Kamar',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list_rounded, color: Colors.black54),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.search_rounded, color: Colors.black54),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- HORIZONTAL FILTER CHIPS ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, bottom: 16),
            child: Row(
              children: ['Semua', 'Terisi', 'Kosong'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: primaryColor,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? primaryColor : Colors.grey[300]!,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // --- GRID LIST OF ROOMS ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('kamar')
                  .stream(primaryKey: ['id_kamar']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Gagal memuat data: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final rooms = snapshot.data ?? [];
                // Filter rooms locally based on choice
                final filteredRooms = rooms.where((room) {
                  if (_selectedFilter == 'Semua') return true;
                  return room['status_kamar'] == _selectedFilter;
                }).toList();

                if (filteredRooms.isEmpty) {
                  return const Center(
                    child: Text(
                      'Tidak ada kamar dalam kategori ini.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: filteredRooms.length,
                  itemBuilder: (context, index) {
                    final room = filteredRooms[index];
                    final idKamar = room['id_kamar'] as int;
                    final nomorKamar = room['nomor_kamar'] as String;
                    final harga = room['harga_sewa_dasar'] as num;
                    final status = room['status_kamar'] as String;
                    final isTerisi = status == 'Terisi';

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => KamarDetailScreen(
                              idKamar: idKamar,
                              nomorKamar: nomorKamar,
                              harga: harga,
                              status: status,
                            ),
                          ),
                        );
                      },
                      child: Card(
                        color: Colors.white,
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Image + Badge
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                  child: Image.network(
                                    isTerisi
                                        ? 'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?w=400'
                                        : 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400',
                                    height: 110,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 110,
                                      color: Colors.grey[200],
                                      child: Icon(
                                        Icons.bed_outlined,
                                        size: 40,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isTerisi ? const Color(0xFFE0F2F1) : const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: isTerisi ? const Color(0xFF00796B) : const Color(0xFFC62828),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Card Content
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kamar $nomorKamar',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatRupiah(harga)}/bln',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  FutureBuilder<String>(
                                    future: _getActiveTenantName(idKamar),
                                    builder: (context, tenantSnapshot) {
                                      final tenantName = tenantSnapshot.data ?? 'Loading...';
                                      final hasTenant = tenantName != 'Belum ada penyewa' &&
                                          tenantName != 'Loading...';

                                      return Row(
                                        children: [
                                          Icon(
                                            hasTenant ? Icons.person_outline : Icons.vpn_key_outlined,
                                            size: 14,
                                            color: Colors.grey[500],
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              tenantName,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 11,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const KamarFormScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFFFFA834),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

