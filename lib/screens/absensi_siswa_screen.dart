import 'package:flutter/material.dart';
import '../helpers/absensi_siswa_db.dart';
import '../helpers/hari_besar.dart';

class AbsensiSiswaScreen extends StatefulWidget {
  const AbsensiSiswaScreen({super.key});

  @override
  State<AbsensiSiswaScreen> createState() => _AbsensiSiswaScreenState();
}

class _AbsensiSiswaScreenState extends State<AbsensiSiswaScreen> {
  List<Kelas>  _kelasList = [];
  Kelas?       _kelasDipilih;
  List<Siswa>  _siswaList = [];
  DateTime     _tanggal   = DateTime.now();
  bool         _loading   = false;
  bool         _simpan    = false;

  // Status absen tiap siswa: id_siswa → status
  final Map<int, String> _statusMap = {};

  static const Map<String, Map<String, dynamic>> _statusInfo = {
    'hadir': {'label': 'Hadir',  'color': Colors.green,  'icon': Icons.check_circle},
    'sakit': {'label': 'Sakit',  'color': Colors.orange, 'icon': Icons.medical_services},
    'izin':  {'label': 'Izin',   'color': Colors.blue,   'icon': Icons.assignment},
    'alpha': {'label': 'Alpha',  'color': Colors.red,    'icon': Icons.cancel},
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
    if (_kelasDipilih != null) _loadSiswa();
  }

  Future<void> _loadSiswa() async {
    if (_kelasDipilih == null) return;
    setState(() => _loading = true);

    final siswa   = await AbsensiSiswaDb.getSiswaByKelas(_kelasDipilih!.id!);
    final tanggal = _fmtTanggal(_tanggal);
    final absensi = await AbsensiSiswaDb.getAbsensi(
        _kelasDipilih!.id!, tanggal);

    // Default semua hadir
    final map = <int, String>{};
    for (final s in siswa) {
      map[s.id!] = 'hadir';
    }
    // Override dari data tersimpan
    for (final a in absensi) {
      map[a.idSiswa] = a.status;
    }

    setState(() {
      _siswaList = siswa;
      _statusMap
        ..clear()
        ..addAll(map);
      _loading = false;
    });
  }

  String _fmtTanggal(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B5E20)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _tanggal = picked);
      _loadSiswa();
    }
  }

  Future<void> _simpanAbsensi() async {
    if (_kelasDipilih == null || _siswaList.isEmpty) return;
    setState(() => _simpan = true);

    final tanggal = _fmtTanggal(_tanggal);
    final list    = _siswaList.map((s) => AbsensiSiswa(
      idSiswa:   s.id!,
      idKelas:   _kelasDipilih!.id!,
      tanggal:   tanggal,
      status:    _statusMap[s.id!] ?? 'hadir',
    )).toList();

    await AbsensiSiswaDb.saveAbsensiBatch(list);
    setState(() => _simpan = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Absensi tersimpan'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _setStatus(int idSiswa, String status) {
    setState(() => _statusMap[idSiswa] = status);
  }

  void _showStatusPicker(Siswa siswa) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(siswa.nama,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            if (siswa.nis.isNotEmpty)
              Text('NIS: ${siswa.nis}',
                  style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ..._statusInfo.entries.map((e) {
              final active = (_statusMap[siswa.id!] ?? 'hadir') == e.key;
              final color  = e.value['color'] as Color;
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(e.value['icon'] as IconData,
                      color: color, size: 22),
                ),
                title: Text(e.value['label'] as String,
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: active ? color : null)),
                trailing: active
                    ? Icon(Icons.check, color: color)
                    : null,
                onTap: () {
                  _setStatus(siswa.id!, e.key);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Rekap hari ini ──────────────────────────────────────────
  Map<String, int> get _rekap {
    final r = {'hadir': 0, 'sakit': 0, 'izin': 0, 'alpha': 0};
    for (final s in _statusMap.values) {
      r[s] = (r[s] ?? 0) + 1;
    }
    return r;
  }

  // ── Form kelas ─────────────────────────────────────────────
  void _showFormKelas({Kelas? existing}) {
    final ctrl = TextEditingController(text: existing?.namaKelas ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16, left: 16, right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(existing == null ? 'Tambah Kelas' : 'Edit Kelas',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nama Kelas',
                hintText: 'Contoh: X IPA 1',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.class_),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (existing != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await AbsensiSiswaDb.deleteKelas(existing.id!);
                        await _loadKelas();
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Hapus',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                if (existing != null) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (ctrl.text.trim().isEmpty) return;
                      await AbsensiSiswaDb.saveKelas(Kelas(
                        id:        existing?.id,
                        namaKelas: ctrl.text.trim(),
                        waliKelas: '',
                      ));
                      Navigator.pop(context);
                      await _loadKelas();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(existing == null ? 'Simpan' : 'Update'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Form siswa ─────────────────────────────────────────────
  void _showFormSiswa({Siswa? existing}) {
    final namaCtrl = TextEditingController(text: existing?.nama ?? '');
    final nisCtrl  = TextEditingController(text: existing?.nis  ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16, left: 16, right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(existing == null ? 'Tambah Siswa' : 'Edit Siswa',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: namaCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nama Siswa *',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nisCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'NIS (opsional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (existing != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await AbsensiSiswaDb.deleteSiswa(existing.id!);
                        _loadSiswa();
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Hapus',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                if (existing != null) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (namaCtrl.text.trim().isEmpty) return;
                      await AbsensiSiswaDb.saveSiswa(Siswa(
                        id:      existing?.id,
                        idKelas: _kelasDipilih!.id!,
                        nama:    namaCtrl.text.trim(),
                        nis:     nisCtrl.text.trim(),
                        urutan:  existing?.urutan ?? _siswaList.length,
                      ));
                      Navigator.pop(context);
                      _loadSiswa();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(existing == null ? 'Simpan' : 'Update'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rekap   = _rekap;
    final tanggal = _tanggal;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Absensi Siswa'),
        actions: [
          // Manajemen kelas
          IconButton(
            icon: const Icon(Icons.class_outlined),
            tooltip: 'Kelola Kelas',
            onPressed: () => _showManajemenKelas(),
          ),
          // Simpan
          IconButton(
            icon: _simpan
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
            tooltip: 'Simpan',
            onPressed: _simpan ? null : _simpanAbsensi,
          ),
        ],
      ),
      body: _kelasList.isEmpty
          ? _buildKosong()
          : Column(
              children: [
                // ── Header ──────────────────────────────────
                Container(
                  color: const Color(0xFF1B5E20),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      // Pilih kelas + tanggal
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
                                  dropdownColor:
                                      const Color(0xFF1B5E20),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                  icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.white),
                                  items: _kelasList
                                      .map((k) => DropdownMenuItem(
                                            value: k,
                                            child: Text(k.namaKelas,
                                                style: const TextStyle(
                                                    color: Colors.white)),
                                          ))
                                      .toList(),
                                  onChanged: (k) {
                                    setState(() => _kelasDipilih = k);
                                    _loadSiswa();
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Pilih tanggal
                          GestureDetector(
                            onTap: _pilihTanggal,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${tanggal.day}/${tanggal.month}/${tanggal.year}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Dashboard rekap
                      Row(
                        children: [
                          _rekapItem('Hadir',
                              rekap['hadir']!, Colors.green),
                          _rekapItem('Sakit',
                              rekap['sakit']!, Colors.orange),
                          _rekapItem('Izin',
                              rekap['izin']!, Colors.blue),
                          _rekapItem('Alpha',
                              rekap['alpha']!, Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Progress bar ────────────────────────────
                if (_siswaList.isNotEmpty)
                  _buildProgressBar(rekap),

                // ── List siswa ──────────────────────────────
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator())
                      : _siswaList.isEmpty
                          ? _buildSiswaKosong()
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _siswaList.length,
                              itemBuilder: (_, i) =>
                                  _buildSiswaItem(i, _siswaList[i]),
                            ),
                ),
              ],
            ),
      floatingActionButton: _kelasDipilih != null
          ? FloatingActionButton(
              onPressed: () => _showFormSiswa(),
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }

  Widget _rekapItem(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Map<String, int> rekap) {
    final total = _siswaList.length;
    if (total == 0) return const SizedBox();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${rekap['hadir']} dari $total siswa hadir',
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                _progressSegment(
                    rekap['hadir']!, total, Colors.green),
                _progressSegment(
                    rekap['sakit']!, total, Colors.orange),
                _progressSegment(
                    rekap['izin']!, total, Colors.blue),
                _progressSegment(
                    rekap['alpha']!, total, Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressSegment(int val, int total, Color color) {
    if (val == 0) return const SizedBox();
    return Flexible(
      flex: val,
      child: Container(height: 6, color: color),
    );
  }

  Widget _buildSiswaItem(int index, Siswa siswa) {
    final status     = _statusMap[siswa.id!] ?? 'hadir';
    final info       = _statusInfo[status]!;
    final color      = info['color'] as Color;
    final isHadir    = status == 'hadir';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Nomor urut
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
            ),
            const SizedBox(width: 12),

            // Nama & NIS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(siswa.nama,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14)),
                  if (siswa.nis.isNotEmpty)
                    Text('NIS: ${siswa.nis}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),

            // Toggle hadir/tidak + pilih status
            Row(
              children: [
                // Jika tidak hadir, tampil badge status
                if (!isHadir)
                  GestureDetector(
                    onTap: () => _showStatusPicker(siswa),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(info['icon'] as IconData,
                              size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(info['label'] as String,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),

                // Switch hadir/ghoib
                Switch(
                  value: isHadir,
                  activeColor: Colors.green,
                  onChanged: (v) {
                    if (v) {
                      _setStatus(siswa.id!, 'hadir');
                    } else {
                      _showStatusPicker(siswa);
                    }
                  },
                ),

                // Edit siswa
                GestureDetector(
                  onTap: () => _showFormSiswa(existing: siswa),
                  child: const Icon(Icons.more_vert,
                      color: Colors.grey, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKosong() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.class_outlined,
              size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Belum ada kelas',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tambahkan kelas terlebih dahulu',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showFormKelas(),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Kelas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiswaKosong() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('Belum ada siswa di kelas ini'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showFormSiswa(),
            icon: const Icon(Icons.person_add),
            label: const Text('Tambah Siswa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showManajemenKelas() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                children: [
                  const Text('Kelola Kelas',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showFormKelas();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Tambah'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._kelasList.map((k) => ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF1B5E20),
                      child: Icon(Icons.class_,
                          color: Colors.white, size: 18),
                    ),
                    title: Text(k.namaKelas),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.grey, size: 18),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showFormKelas(existing: k);
                      },
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}