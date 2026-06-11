import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/presensi_model.dart';

class GaleriScreen extends StatefulWidget {
  const GaleriScreen({super.key});

  @override
  State<GaleriScreen> createState() => _GaleriScreenState();
}

class _GaleriScreenState extends State<GaleriScreen> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;
  bool _newerFirst = true;
  DateTime _tanggal = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final res = await ApiService.getGaleriHadir(
      tanggal: _formatTanggal(_tanggal),
    );
    if (res['status'] == true) {
      List data = res['data'] ?? [];
      setState(() {
        _data = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } else {
      setState(() { _data = []; _loading = false; });
    }
  }

  String _formatTanggal(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _formatTanggalLabel(DateTime dt) {
    const hari  = ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
    const bulan = ['Jan','Feb','Mar','Apr','Mei','Jun',
                   'Jul','Agu','Sep','Okt','Nov','Des'];
    return '${hari[dt.weekday - 1]}, ${dt.day} ${bulan[dt.month - 1]} ${dt.year}';
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1B5E20),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _tanggal = picked);
      _loadData();
    }
  }

  Future<void> _clearCache() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
            'Hapus cache gambar yang tersimpan di perangkat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Clear image cache Flutter
              imageCache.clear();
              imageCache.clearLiveImages();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache berhasil dihapus'),
                  backgroundColor: Colors.green,
                ),
              );
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _sortedData {
    final list = List<Map<String, dynamic>>.from(_data);
    list.sort((a, b) {
      final jamA = a['jam_masuk'] ?? '';
      final jamB = b['jam_masuk'] ?? '';
      return _newerFirst
          ? jamB.compareTo(jamA)
          : jamA.compareTo(jamB);
    });
    return list;
  }

  String _fotoUrl(String? nama, String tipe) {
    if (nama == null || nama.isEmpty) return '';
    return 'https://chat.marsa9.com/present/public/assets/img/foto_presensi/$tipe/$nama';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Galeri Kehadiran'),
        actions: [
          // Sort button
          IconButton(
            icon: Icon(_newerFirst
                ? Icons.arrow_downward
                : Icons.arrow_upward),
            tooltip: _newerFirst ? 'Terbaru' : 'Terlama',
            onPressed: () =>
                setState(() => _newerFirst = !_newerFirst),
          ),
          // Clear cache
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: 'Clear Cache',
            onPressed: _clearCache,
          ),
        ],
      ),
      body: Column(
        children: [
          // Pilih tanggal
          Container(
            color: const Color(0xFF1B5E20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                onTap: _pilihTanggal,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        _formatTanggalLabel(_tanggal),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down,
                          color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Summary bar
          if (!_loading)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _buildChip(Icons.people, '${_data.length} Hadir',
                      Colors.green),
                  const SizedBox(width: 8),
                  _buildChip(
                    Icons.check_circle,
                    '${_data.where((d) => (d['jam_keluar'] ?? '00:00:00') != '00:00:00').length} Lengkap',
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildChip(
                    Icons.pending,
                    '${_data.where((d) => (d['jam_keluar'] ?? '00:00:00') == '00:00:00').length} Belum Keluar',
                    Colors.orange,
                  ),
                ],
              ),
            ),

          // Grid foto
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _data.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada kehadiran\npada tanggal ini',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _sortedData.length,
                          itemBuilder: (context, i) =>
                              _buildCard(_sortedData[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final namaFotoMasuk = item['foto_masuk'] ?? '';
    final fotoUrl = _fotoUrl(namaFotoMasuk, 'masuk');
    final sudahKeluar =
        (item['jam_keluar'] ?? '00:00:00') != '00:00:00';
    final nama = item['nama'] ?? '-';

    return GestureDetector(
      onTap: () => _showDetail(item),
      child: Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Foto masuk
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  fotoUrl.isNotEmpty
                      ? Image.network(
                          fotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _placeholderFoto(nama),
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2)),
                                    ),
                        )
                      : _placeholderFoto(nama),
                  // Badge status
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: sudahKeluar
                            ? Colors.green
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        sudahKeluar ? 'Lengkap' : 'Masuk',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info bawah
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.login,
                          size: 11, color: Colors.green),
                      const SizedBox(width: 3),
                      Text(item['jam_masuk'] ?? '-',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.green)),
                      if (sudahKeluar) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.logout,
                            size: 11, color: Colors.blue),
                        const SizedBox(width: 3),
                        Text(item['jam_keluar'],
                            style: const TextStyle(
                                fontSize: 11, color: Colors.blue)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderFoto(String nama) {
    return Container(
      color: const Color(0xFF1B5E20).withOpacity(0.1),
      child: Center(
        child: Text(
          nama.isNotEmpty ? nama[0].toUpperCase() : '?',
          style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20)),
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> item) {
    final namaFotoMasuk  = item['foto_masuk'] ?? '';
    final namaFotoKeluar = item['foto_keluar'] ?? '';
    final fotoMasukUrl   = _fotoUrl(namaFotoMasuk, 'masuk');
    final fotoKeluarUrl  = _fotoUrl(namaFotoKeluar, 'keluar');
    final sudahKeluar    =
        (item['jam_keluar'] ?? '00:00:00') != '00:00:00';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(item['nama'] ?? '-',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(item['jabatan'] ?? '-',
                    style: const TextStyle(color: Colors.grey)),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailFoto(
                        label: 'Foto Masuk',
                        jam: item['jam_masuk'] ?? '-',
                        fotoUrl: fotoMasukUrl,
                        color: Colors.green,
                        icon: Icons.login,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailFoto(
                        label: 'Foto Keluar',
                        jam: sudahKeluar
                            ? item['jam_keluar']
                            : '-',
                        fotoUrl: sudahKeluar
                            ? fotoKeluarUrl
                            : '',
                        color: Colors.blue,
                        icon: Icons.logout,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailFoto({
    required String label,
    required String jam,
    required String fotoUrl,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        Text(jam,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: fotoUrl.isNotEmpty
              ? Image.network(fotoUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 160,
                  errorBuilder: (_, __, ___) =>
                      _placeholderFoto('?'))
              : Container(
                  height: 160,
                  color: Colors.grey[200],
                  child: const Center(
                      child: Icon(Icons.image_not_supported,
                          color: Colors.grey)),
                ),
        ),
      ],
    );
  }
}