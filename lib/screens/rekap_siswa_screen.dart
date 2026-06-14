import 'package:flutter/material.dart';
import '../helpers/absensi_siswa_db.dart';
import '../helpers/hari_besar.dart';

class RekapSiswaScreen extends StatefulWidget {
  const RekapSiswaScreen({super.key});

  @override
  State<RekapSiswaScreen> createState() => _RekapSiswaScreenState();
}

class _RekapSiswaScreenState extends State<RekapSiswaScreen> {
  List<Kelas> _kelasList     = [];
  Kelas?      _kelasDipilih;
  List<Siswa> _siswaList     = [];
  DateTime    _bulan         = DateTime.now();
  bool        _loading       = false;
  bool        _modeDetail    = false; // false=tabel, true=per siswa
  Siswa?      _siswaDipilih;

  // Data rekap: id_siswa → {hadir, sakit, izin, alpha}
  Map<int, Map<String, int>> _rekapMap = {};

  // Riwayat harian siswa dipilih
  List<AbsensiSiswa> _riwayat = [];

  static const Map<String, Map<String, dynamic>> _statusInfo = {
    'hadir': {'label': 'H', 'color': Colors.green,  'full': 'Hadir'},
    'sakit': {'label': 'S', 'color': Colors.orange, 'full': 'Sakit'},
    'izin':  {'label': 'I', 'color': Colors.blue,   'full': 'Izin'},
    'alpha': {'label': 'A', 'color': Colors.red,    'full': 'Alpha'},
  };

  @override
  void initState() {
    super.initState();
    _loadKelas();
  }

  Future<void> _loadKelas() async {
    final list = await AbsensiSiswaDb.getAllKelas();
    setState(() {
      _kelasList    = list;
      _kelasDipilih = list.isNotEmpty ? list.first : null;
    });
    if (_kelasDipilih != null) _loadRekap();
  }

  Future<void> _loadRekap() async {
    if (_kelasDipilih == null) return;
    setState(() => _loading = true);

    final siswa  = await AbsensiSiswaDb.getSiswaByKelas(_kelasDipilih!.id!);
    final bulanStr = '${_bulan.year}-${_bulan.month.toString().padLeft(2, '0')}';

    final Map<int, Map<String, int>> rekap = {};
    for (final s in siswa) {
      rekap[s.id!] = await AbsensiSiswaDb.getRekapSiswa(s.id!, bulanStr);
    }

    setState(() {
      _siswaList  = siswa;
      _rekapMap   = rekap;
      _loading    = false;
    });
  }

  Future<void> _loadRiwayatSiswa(Siswa siswa) async {
    final bulanStr = '${_bulan.year}-${_bulan.month.toString().padLeft(2, '0')}';
    final db = await AbsensiSiswaDb.db;
    final rows = await db.query('absensi',
        where: 'id_siswa = ? AND tanggal LIKE ?',
        whereArgs: [siswa.id, '$bulanStr%'],
        orderBy: 'tanggal ASC');
    setState(() {
      _riwayat = rows.map(AbsensiSiswa.fromMap).toList();
    });
  }

  String _fmtBulan(DateTime dt) =>
      '${HariBesarHelper.namaBulan(dt.month)} ${dt.year}';

  void _bulanSebelum() {
    setState(() => _bulan = DateTime(_bulan.year, _bulan.month - 1));
    _loadRekap();
  }

  void _bulanBerikut() {
    if (_bulan.year == DateTime.now().year &&
        _bulan.month == DateTime.now().month) return;
    setState(() => _bulan = DateTime(_bulan.year, _bulan.month + 1));
    _loadRekap();
  }

  // Total kehadiran kelas
  Map<String, int> get _totalKelas {
    final r = {'hadir': 0, 'sakit': 0, 'izin': 0, 'alpha': 0};
    for (final v in _rekapMap.values) {
      r['hadir'] = r['hadir']! + (v['hadir'] ?? 0);
      r['sakit'] = r['sakit']! + (v['sakit'] ?? 0);
      r['izin']  = r['izin']!  + (v['izin']  ?? 0);
      r['alpha'] = r['alpha']! + (v['alpha']  ?? 0);
    }
    return r;
  }

  int _totalSiswa(int idSiswa) {
    final r = _rekapMap[idSiswa] ?? {};
    return (r['hadir'] ?? 0) + (r['sakit'] ?? 0) +
           (r['izin']  ?? 0) + (r['alpha'] ?? 0);
  }

  double _persen(int idSiswa) {
    final total = _totalSiswa(idSiswa);
    if (total == 0) return 0;
    return (_rekapMap[idSiswa]?['hadir'] ?? 0) / total * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Rekap Absensi Siswa'),
        actions: [
          IconButton(
            icon: Icon(_modeDetail
                ? Icons.table_rows
                : Icons.person_search),
            tooltip: _modeDetail ? 'Mode Tabel' : 'Mode Per Siswa',
            onPressed: () => setState(() => _modeDetail = !_modeDetail),
          ),
        ],
      ),
      body: _kelasList.isEmpty
          ? const Center(child: Text('Belum ada kelas'))
          : Column(
              children: [
                // Header
                Container(
                  color: const Color(0xFF1B5E20),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      // Pilih kelas + bulan
                      Row(
                        children: [
                          // Dropdown kelas
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Kelas>(
                                  value: _kelasDipilih,
                                  dropdownColor: const Color(0xFF1B5E20),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                  icon: const Icon(Icons.arrow_drop_down,
                                      color: Colors.white),
                                  items: _kelasList.map((k) =>
                                      DropdownMenuItem(
                                        value: k,
                                        child: Text(k.namaKelas,
                                            style: const TextStyle(
                                                color: Colors.white)),
                                      )).toList(),
                                  onChanged: (k) {
                                    setState(() => _kelasDipilih = k);
                                    _loadRekap();
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Navigasi bulan
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _bulanSebelum,
                                child: const Icon(Icons.chevron_left,
                                    color: Colors.white),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _fmtBulan(_bulan),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                              GestureDetector(
                                onTap: _bulanBerikut,
                                child: const Icon(Icons.chevron_right,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Summary kelas
                      _buildSummaryKelas(),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _siswaList.isEmpty
                          ? const Center(
                              child: Text('Belum ada siswa di kelas ini'))
                          : _modeDetail
                              ? _buildModePerSiswa()
                              : _buildModeTabel(),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryKelas() {
    final total = _totalKelas;
    final semua = (total['hadir']! + total['sakit']! +
                   total['izin']!  + total['alpha']!);
    return Row(
      children: [
        _summaryItem('Hadir',  total['hadir']!,  Colors.green),
        _summaryItem('Sakit',  total['sakit']!,  Colors.orange),
        _summaryItem('Izin',   total['izin']!,   Colors.blue),
        _summaryItem('Alpha',  total['alpha']!,  Colors.red),
        _summaryItem('Total',  semua,            Colors.white70,
            isTotal: true),
      ],
    );
  }

  Widget _summaryItem(String label, int value, Color color,
      {bool isTotal = false}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isTotal
              ? Colors.white.withOpacity(0.1)
              : color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: isTotal
              ? Border.all(color: Colors.white30)
              : null,
        ),
        child: Column(
          children: [
            Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ── Mode Tabel ───────────────────────────────────────────────
  Widget _buildModeTabel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Tabel rekap
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                    const Color(0xFF1B5E20).withOpacity(0.1)),
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('No',
                      style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Nama Siswa',
                      style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('H',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: Colors.green))),
                  DataColumn(label: Text('S',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: Colors.orange))),
                  DataColumn(label: Text('I',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: Colors.blue))),
                  DataColumn(label: Text('A',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: Colors.red))),
                  DataColumn(label: Text('%',
                      style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _siswaList.asMap().entries.map((e) {
                  final idx    = e.key;
                  final siswa  = e.value;
                  final rekap  = _rekapMap[siswa.id!] ?? {};
                  final persen = _persen(siswa.id!);
                  final color  = persen >= 80
                      ? Colors.green
                      : persen >= 60
                          ? Colors.orange
                          : Colors.red;

                  return DataRow(
                    onSelectChanged: (_) {
                      setState(() {
                        _modeDetail    = true;
                        _siswaDipilih  = siswa;
                      });
                      _loadRiwayatSiswa(siswa);
                    },
                    cells: [
                      DataCell(Text('${idx + 1}',
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(siswa.nama,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500))),
                      DataCell(Text('${rekap['hadir'] ?? 0}',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold))),
                      DataCell(Text('${rekap['sakit'] ?? 0}',
                          style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold))),
                      DataCell(Text('${rekap['izin'] ?? 0}',
                          style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold))),
                      DataCell(Text('${rekap['alpha'] ?? 0}',
                          style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${persen.toStringAsFixed(0)}%',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Grafik bar sederhana
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tingkat Kehadiran per Siswa',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 16),
                  ..._siswaList.map((s) {
                    final persen = _persen(s.id!);
                    final color  = persen >= 80
                        ? Colors.green
                        : persen >= 60
                            ? Colors.orange
                            : Colors.red;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.nama,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${persen.toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: color),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: persen / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(color),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode Per Siswa ───────────────────────────────────────────
  Widget _buildModePerSiswa() {
    return Column(
      children: [
        // Pilih siswa
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _siswaList.map((s) {
                final active = _siswaDipilih?.id == s.id;
                return GestureDetector(
                  onTap: () {
                    setState(() => _siswaDipilih = s);
                    _loadRiwayatSiswa(s);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF1B5E20)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.nama.split(' ').first,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: active
                              ? Colors.white
                              : Colors.black87),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        Expanded(
          child: _siswaDipilih == null
              ? const Center(
                  child: Text('Pilih siswa di atas',
                      style: TextStyle(color: Colors.grey)))
              : _buildDetailSiswa(_siswaDipilih!),
        ),
      ],
    );
  }

  Widget _buildDetailSiswa(Siswa siswa) {
    final rekap  = _rekapMap[siswa.id!] ?? {};
    final persen = _persen(siswa.id!);
    final total  = _totalSiswa(siswa.id!);
    final color  = persen >= 80
        ? Colors.green
        : persen >= 60
            ? Colors.orange
            : Colors.red;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Info siswa
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF1B5E20),
                        child: Text(
                          siswa.nama[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(siswa.nama,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            if (siswa.nis.isNotEmpty)
                              Text('NIS: ${siswa.nis}',
                                  style: const TextStyle(
                                      color: Colors.grey)),
                            Text(_kelasDipilih?.namaKelas ?? '',
                                style: const TextStyle(
                                    color: Color(0xFF1B5E20),
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      // Persen besar
                      Column(
                        children: [
                          Text(
                            '${persen.toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: color),
                          ),
                          Text('Kehadiran',
                              style: TextStyle(
                                  fontSize: 11, color: color)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: persen / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Rekap box
                  Row(
                    children: [
                      _rekapBox('Hadir',
                          rekap['hadir'] ?? 0, Colors.green),
                      _rekapBox('Sakit',
                          rekap['sakit'] ?? 0, Colors.orange),
                      _rekapBox('Izin',
                          rekap['izin']  ?? 0, Colors.blue),
                      _rekapBox('Alpha',
                          rekap['alpha'] ?? 0, Colors.red),
                      _rekapBox('Total', total, Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Riwayat harian
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Riwayat ${_fmtBulan(_bulan)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  _riwayat.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Belum ada data',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _riwayat.map((a) {
                            final info =
                                _statusInfo[a.status] ??
                                _statusInfo['hadir']!;
                            final color =
                                info['color'] as Color;
                            final tgl = DateTime.parse(a.tanggal);
                            return Container(
                              width: 44, height: 54,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(8),
                                border: Border.all(
                                    color: color.withOpacity(0.4)),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text('${tgl.day}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey)),
                                  Text(
                                    info['label'] as String,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.bold,
                                        color: color),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rekapBox(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}