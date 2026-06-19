import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/presensi_model.dart';
import '../helpers/riwayat_cache.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  List<PresensiModel> _allData = [];
  List<PresensiModel> _filtered = [];
  bool _loading    = false;
  bool _modeTable  = false;
  String _filter   = 'bulan'; // minggu, bulan, custom
  DateTime? _dateFrom;
  DateTime? _dateTo;
  DateTime? _lastCached;
  String _jamMasukLokasi = '07:00:00'; // default, nanti dari profil

  @override
  void initState() {
    super.initState();
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
  setState(() => _loading = true);

  final hasCache = await RiwayatCache.hasCache();

  if (hasCache) {
    final cached = await RiwayatCache.getAll();
    _lastCached = await RiwayatCache.lastCached();

    setState(() {
      _allData = cached.map((e) => PresensiModel.fromJson(e)).toList();
      _loading = false;
    });

    _applyFilter();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchFromServer();
      }
    });
  } else {
    await _fetchFromServer();
  }
}

  Future<void> _fetchFromServer() async {
    setState(() => _loading = true);
    final res = await ApiService.getRiwayat();
    if (res['status'] == true) {
      final list = List<Map<String, dynamic>>.from(res['data']);
      await RiwayatCache.saveAll(list);
      _lastCached = DateTime.now();
      setState(() {
        _allData = list.map((e) => PresensiModel.fromJson(e)).toList();
        _loading = false;
      });
      _applyFilter();
    } else {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    List<PresensiModel> result;

    if (_filter == 'minggu') {
      final start = now.subtract(Duration(days: now.weekday - 1));
      final startDate = DateTime(start.year, start.month, start.day);
      result = _allData.where((e) {
        final d = DateTime.tryParse(e.tanggalMasuk);
        return d != null && !d.isBefore(startDate);
      }).toList();
    } else if (_filter == 'bulan') {
      result = _allData.where((e) {
        final d = DateTime.tryParse(e.tanggalMasuk);
        return d != null &&
            d.month == now.month &&
            d.year == now.year;
      }).toList();
    } else if (_filter == 'custom' &&
        _dateFrom != null &&
        _dateTo != null) {
      result = _allData.where((e) {
        final d = DateTime.tryParse(e.tanggalMasuk);
        return d != null &&
            !d.isBefore(_dateFrom!) &&
            !d.isAfter(_dateTo!.add(const Duration(days: 1)));
      }).toList();
    } else {
      result = List.from(_allData);
    }

    result.sort((a, b) => b.tanggalMasuk.compareTo(a.tanggalMasuk));
    setState(() => _filtered = result);
  }

  Future<void> _pilihCustomRange() async {
    final from = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 7)),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Dari Tanggal',
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B5E20)),
        ),
        child: child!,
      ),
    );
    if (from == null) return;

    final to = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: from,
      lastDate: DateTime.now(),
      helpText: 'Sampai Tanggal',
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B5E20)),
        ),
        child: child!,
      ),
    );
    if (to == null) return;

    setState(() {
      _dateFrom = from;
      _dateTo   = to;
      _filter   = 'custom';
    });
    _applyFilter();
  }

  Future<void> _clearCache() async {
    await RiwayatCache.clearAll();
    setState(() {
      _allData    = [];
      _filtered   = [];
      _lastCached = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache dihapus')),
    );
  }

  // Hitung menit terlambat
  int _hitungTerlambat(String jamMasuk) {
    try {
      final parts   = jamMasuk.split(':');
      final masuk   = Duration(
          hours: int.parse(parts[0]), minutes: int.parse(parts[1]));
      final batas   = _parseDuration(_jamMasukLokasi);
      final selisih = masuk - batas;
      return selisih.inMinutes > 0 ? selisih.inMinutes : 0;
    } catch (_) {
      return 0;
    }
  }

  Duration _parseDuration(String time) {
    final p = time.split(':');
    return Duration(hours: int.parse(p[0]), minutes: int.parse(p[1]));
  }

  // Hitung durasi kerja
  String _hitungDurasi(String jamMasuk, String jamKeluar) {
    try {
      if (jamKeluar == '00:00:00') return '-';
      final masuk  = _parseDuration(jamMasuk);
      final keluar = _parseDuration(jamKeluar);
      final dur    = keluar - masuk;
      final h      = dur.inHours;
      final m      = dur.inMinutes % 60;
      return '${h}j ${m}m';
    } catch (_) {
      return '-';
    }
  }

  // Rekap statistik
  Map<String, dynamic> get _rekap {
    int totalHadir    = _filtered.length;
    int totalTerlambat = 0;
    int totalMenitKerja = 0;
    int totalMenitTerlambat = 0;

    for (final item in _filtered) {
      if (!item.sudahMasuk) continue;
      final terlambat = _hitungTerlambat(item.jamMasuk);
      if (terlambat > 0) totalTerlambat++;
      totalMenitTerlambat += terlambat;

      if (item.sudahKeluar) {
        try {
          final masuk  = _parseDuration(item.jamMasuk);
          final keluar = _parseDuration(item.jamKeluar);
          totalMenitKerja += (keluar - masuk).inMinutes;
        } catch (_) {}
      }
    }

    final jamKerja  = totalMenitKerja ~/ 60;
    final menitKerja = totalMenitKerja % 60;
    final jamTerlambat = totalMenitTerlambat ~/ 60;
    final menitTerlambat = totalMenitTerlambat % 60;

    return {
      'hadir':      totalHadir,
      'terlambat':  totalTerlambat,
      'tepat':      totalHadir - totalTerlambat,
      'jam_kerja':  '${jamKerja}j ${menitKerja}m',
      'total_terlambat': '${jamTerlambat}j ${menitTerlambat}m',
    };
  }

  String _filterLabel() {
    if (_filter == 'minggu') return 'Minggu Ini';
    if (_filter == 'bulan')  return 'Bulan Ini';
    if (_filter == 'custom' && _dateFrom != null && _dateTo != null) {
      return '${_dateFrom!.day}/${_dateFrom!.month} - ${_dateTo!.day}/${_dateTo!.month}';
    }
    return 'Custom';
  }

  @override
  Widget build(BuildContext context) {
    final rekap = _rekap;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Riwayat Absensi'),
        actions: [
          // Toggle mode
          IconButton(
            icon: Icon(_modeTable
                ? Icons.grid_view
                : Icons.table_rows),
            onPressed: () =>
                setState(() => _modeTable = !_modeTable),
            tooltip: _modeTable ? 'Mode Kartu' : 'Mode Tabel',
          ),
          // Update dari server
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: _loading ? null : _fetchFromServer,
            tooltip: 'Ambil data terbaru',
          ),
          // Menu
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'cache',
                child: Row(children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Hapus Cache'),
                ]),
              ),
            ],
            onSelected: (v) {
              if (v == 'cache') _clearCache();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color: const Color(0xFF1B5E20),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                _filterChip('Minggu Ini', 'minggu'),
                const SizedBox(width: 8),
                _filterChip('Bulan Ini', 'bulan'),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pilihCustomRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _filter == 'custom'
                          ? Colors.white
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.date_range,
                            size: 14,
                            color: _filter == 'custom'
                                ? const Color(0xFF1B5E20)
                                : Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _filter == 'custom'
                              ? _filterLabel()
                              : 'Custom',
                          style: TextStyle(
                              fontSize: 12,
                              color: _filter == 'custom'
                                  ? const Color(0xFF1B5E20)
                                  : Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rekap card
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Rekap ${_filterLabel()}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    if (_lastCached != null)
                      Text(
                        'Cache: ${_lastCached!.day}/${_lastCached!.month} ${_lastCached!.hour}:${_lastCached!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _rekapItem('Hadir', '${rekap['hadir']}',
                        Colors.green, Icons.check_circle),
                    _rekapItem('Tepat', '${rekap['tepat']}',
                        Colors.blue, Icons.timer),
                    _rekapItem('Terlambat', '${rekap['terlambat']}',
                        Colors.orange, Icons.warning),
                    _rekapItem('Jam Kerja', rekap['jam_kerja'],
                        Colors.purple, Icons.work),
                  ],
                ),
                if ((rekap['terlambat'] as int) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 13, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          'Total keterlambatan: ${rekap['total_terlambat']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Tidak ada data',
                                style:
                                    TextStyle(color: Colors.grey[500])),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _fetchFromServer,
                              icon: const Icon(Icons.cloud_download),
                              label: const Text('Ambil dari server'),
                            ),
                          ],
                        ),
                      )
                    : _modeTable
                        ? _buildTable()
                        : _buildKartu(),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _applyFilter();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              color:
                  active ? const Color(0xFF1B5E20) : Colors.white,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _rekapItem(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  // Mode kartu
  Widget _buildKartu() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final item      = _filtered[i];
        final terlambat = _hitungTerlambat(item.jamMasuk);
        final durasi    = _hitungDurasi(item.jamMasuk, item.jamKeluar);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 14, color: Color(0xFF1B5E20)),
                    const SizedBox(width: 6),
                    Text(item.tanggalMasuk,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (terlambat > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Text(
                          'Terlambat ${terlambat}m',
                          style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Text(
                          'Tepat Waktu',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _jamItem(Icons.login, 'Masuk',
                          item.jamMasuk, Colors.green),
                    ),
                    Expanded(
                      child: _jamItem(
                          Icons.logout,
                          'Keluar',
                          item.sudahKeluar ? item.jamKeluar : '-',
                          Colors.blue),
                    ),
                    Expanded(
                      child: _jamItem(Icons.timer, 'Durasi',
                          durasi, Colors.purple),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _jamItem(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13)),
      ],
    );
  }

  // Mode tabel
  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
              const Color(0xFF1B5E20).withOpacity(0.1)),
          columnSpacing: 16,
          columns: const [
            DataColumn(
                label: Text('Tanggal',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Masuk',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Keluar',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Durasi',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Status',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filtered.map((item) {
            final terlambat = _hitungTerlambat(item.jamMasuk);
            final durasi =
                _hitungDurasi(item.jamMasuk, item.jamKeluar);
            return DataRow(cells: [
              DataCell(Text(item.tanggalMasuk,
                  style: const TextStyle(fontSize: 12))),
              DataCell(Text(item.jamMasuk,
                  style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12))),
              DataCell(Text(
                  item.sudahKeluar ? item.jamKeluar : '-',
                  style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12))),
              DataCell(Text(durasi,
                  style: const TextStyle(
                      color: Colors.purple, fontSize: 12))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: terlambat > 0
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    terlambat > 0
                        ? '+${terlambat}m'
                        : 'Tepat',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: terlambat > 0
                            ? Colors.orange
                            : Colors.green),
                  ),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}