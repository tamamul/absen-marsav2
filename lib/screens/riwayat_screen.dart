import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/presensi_model.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  List<PresensiModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRiwayat();
  }

  Future<void> _loadRiwayat() async {
    setState(() => _loading = true);
    final res = await ApiService.getRiwayat();
    if (res['status'] == true) {
      final data = res['data'] as List;
      setState(() {
        _list = data.map((e) => PresensiModel.fromJson(e)).toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Riwayat Absensi'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadRiwayat),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text('Belum ada riwayat absensi'))
              : RefreshIndicator(
                  onRefresh: _loadRiwayat,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _list.length,
                    itemBuilder: (context, index) {
                      final item = _list[index];
                      return _buildItem(item);
                    },
                  ),
                ),
    );
  }

  Widget _buildItem(PresensiModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tanggal
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 16, color: Color(0xFF1B5E20)),
                const SizedBox(width: 6),
                Text(
                  item.tanggalMasuk,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                _buildBadge(item),
              ],
            ),
            const Divider(height: 16),
            // Jam masuk & keluar
            Row(
              children: [
                Expanded(
                  child: _buildJamItem(
                    icon: Icons.login,
                    label: 'Masuk',
                    jam: item.sudahMasuk ? item.jamMasuk : '-',
                    color: item.sudahMasuk
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildJamItem(
                    icon: Icons.logout,
                    label: 'Keluar',
                    jam: item.sudahKeluar ? item.jamKeluar : '-',
                    color: item.sudahKeluar
                        ? Colors.blue
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJamItem({
    required IconData icon,
    required String label,
    required String jam,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11)),
              Text(jam,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(PresensiModel item) {
    String label;
    Color color;

    if (item.sudahMasuk && item.sudahKeluar) {
      label = 'Lengkap';
      color = Colors.green;
    } else if (item.sudahMasuk) {
      label = 'Belum Keluar';
      color = Colors.orange;
    } else {
      label = 'Tidak Hadir';
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}