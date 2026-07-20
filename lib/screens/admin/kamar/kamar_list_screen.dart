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
  String _searchQuery = '';
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Terisi':
        return const Color(0xFFE0F2F1);
      case 'Kosong':
        return const Color(0xFFE8F5E9);
      case 'Jatuh Tempo':
        return const Color(0xFFFFEBEE);
      default:
        return Colors.grey[200]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Terisi':
        return const Color(0xFF00796B);
      case 'Kosong':
        return const Color(0xFF2E7D32);
      case 'Jatuh Tempo':
        return const Color(0xFFC62828);
      default:
        return Colors.grey[700]!;
    }
  }

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
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final stream = Supabase.instance.client
        .from('kamar')
        .stream(primaryKey: ['id_kamar'])
        .eq('id_admin', currentUserId ?? '');

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
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER & SEARCH TOGGLE ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                IconButton(
                  icon: Icon(
                    _isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
                    color: Colors.black54,
                  ),
                  onPressed: () {
                    setState(() {
                      _isSearchVisible = !_isSearchVisible;
                      if (!_isSearchVisible) {
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          // --- SEARCH BAR (Animated) ---
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isSearchVisible
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(height: 12),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Cari nomor atau nama kamar...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: primaryColor, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              ),
            ),
          ),

          // --- HORIZONTAL FILTER CHIPS ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, top: 12, bottom: 16),
            child: Row(
              children: ['Semua', 'Terisi', 'Kosong', 'Jatuh Tempo'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    checkmarkColor: Colors.white,
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
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              color: primaryColor,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: primaryColor));
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Text(
                            'Gagal memuat data: ${snapshot.error}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    );
                  }

                  final rooms = snapshot.data ?? [];

                  // Filter berdasarkan status chip
                  var filteredRooms = rooms.where((room) {
                    if (_selectedFilter == 'Semua') return true;
                    return room['status_kamar'] == _selectedFilter;
                  }).toList();

                  // Filter berdasarkan search query (nomor atau nama kamar)
                  if (_searchQuery.isNotEmpty) {
                    filteredRooms = filteredRooms.where((room) {
                      final nomorKamar = (room['nomor_kamar'] ?? '').toString().toLowerCase();
                      final namaKamar = (room['nama_kamar'] ?? '').toString().toLowerCase();
                      return nomorKamar.contains(_searchQuery) || namaKamar.contains(_searchQuery);
                    }).toList();
                  }

                  if (filteredRooms.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Kamar "$_searchQuery" tidak ditemukan.'
                                    : 'Tidak ada kamar dalam kategori ini.',
                                style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                                  child: ((room['foto_kamar'] as List?)?.isNotEmpty ?? false)
                                      ? Image.network(
                                          (room['foto_kamar'] as List).first as String,
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
                                        )
                                      : Container(
                                          height: 110,
                                          width: double.infinity,
                                          color: Colors.grey[200],
                                          child: Icon(
                                            Icons.bed_outlined,
                                            size: 40,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusBgColor(status),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusTextColor(status),
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
