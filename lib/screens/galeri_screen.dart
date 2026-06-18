import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';



// ── Cache helper ──────────────────────────────────────────────
class _GaleriCache {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = p.join(await getDatabasesPath(), 'galeri_cache.db');
    return openDatabase(path, version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE galeri (
            id           TEXT PRIMARY KEY,
            tanggal      TEXT,
            nama         TEXT,
            jabatan      TEXT,
            jam_masuk    TEXT,
            jam_keluar   TEXT,
            foto_masuk   TEXT,
            foto_keluar  TEXT,
            cached_at    INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        // Tidak ada perubahan struktur, tetap kompatibel
      },
    );
  }

  // Simpan hanya data yang belum ada
  static Future<int> saveNew(
      String tanggal, List<Map<String, dynamic>> list) async {
    final database = await db;
    int newCount   = 0;
    final batch    = database.batch();
    final now      = DateTime.now().millisecondsSinceEpoch;

    for (final item in list) {
      final id = item['id']?.toString() ?? '';
      // Cek apakah sudah ada
      final existing = await database.query('galeri',
          where: 'id = ?', whereArgs: [id]);
      if (existing.isEmpty) {
        batch.insert('galeri', {
          'id':         id,
          'tanggal':    tanggal,
          'nama':       item['nama']        ?? '',
          'jabatan':    item['jabatan']     ?? '',
          'jam_masuk':  item['jam_masuk']   ?? '',
          'jam_keluar': item['jam_keluar']  ?? '',
          'foto_masuk': item['foto_masuk']  ?? '',
          'foto_keluar':item['foto_keluar'] ?? '',
          'cached_at':  now,
        });
        newCount++;
      }
    }
    await batch.commit(noResult: true);
    return newCount;
  }

  static Future<List<Map<String, dynamic>>> get(String tanggal) async {
    final database = await db;
    return database.query('galeri',
        where: 'tanggal = ?', whereArgs: [tanggal]);
  }

  static Future<bool> hasCache(String tanggal) async {
    final database = await db;
    final r = await database.rawQuery(
        'SELECT COUNT(*) as c FROM galeri WHERE tanggal = ?', [tanggal]);
    return (r.first['c'] as int) > 0;
  }

  static Future<DateTime?> lastCached(String tanggal) async {
    final database = await db;
    final r = await database.rawQuery(
        'SELECT MAX(cached_at) as last FROM galeri WHERE tanggal = ?',
        [tanggal]);
    final last = r.first['last'];
    if (last == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(last as int);
  }

  static Future<void> clearDate(String tanggal) async {
    final database = await db;
    await database.delete('galeri',
        where: 'tanggal = ?', whereArgs: [tanggal]);
  }

  static Future<void> clearAll() async {
    final database = await db;
    await database.delete('galeri');
  }

  static Future<int> totalRows() async {
    final database = await db;
    final r = await database
        .rawQuery('SELECT COUNT(*) as c FROM galeri');
    return r.first['c'] as int;
  }

  static Future<int> totalDates() async {
    final database = await db;
    final r = await database.rawQuery(
        'SELECT COUNT(DISTINCT tanggal) as c FROM galeri');
    return r.first['c'] as int;
  }
}

// ── Screen ────────────────────────────────────────────────────
class GaleriScreen extends StatefulWidget {
  const GaleriScreen({super.key});

  @override
  State<GaleriScreen> createState() => _GaleriScreenState();
}

class _GaleriScreenState extends State<GaleriScreen> {
  List<Map<String, dynamic>> _data     = [];
  bool   _loading    = false;
  bool   _newerFirst = true;
  bool   _fromCache  = false;
  DateTime _tanggal  = DateTime.now();
  DateTime? _lastCached;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _fmtLabel(DateTime dt) {
    const hari  = ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
    const bulan = ['Jan','Feb','Mar','Apr','Mei','Jun',
                   'Jul','Agu','Sep','Okt','Nov','Des'];
    final isToday = dt.day == DateTime.now().day &&
        dt.month == DateTime.now().month &&
        dt.year == DateTime.now().year;
    if (isToday) return 'Hari Ini';
    return '${hari[dt.weekday - 1]}, ${dt.day} ${bulan[dt.month - 1]} ${dt.year}';
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
  setState(() { _loading = true; _fromCache = false; });
  final tanggal = _fmt(_tanggal);

  // 1. Tampil dari cache dulu (cepat)
  if (await _GaleriCache.hasCache(tanggal)) {
    final cached = await _GaleriCache.get(tanggal);
    _lastCached  = await _GaleriCache.lastCached(tanggal);
    setState(() {
      _data      = List<Map<String, dynamic>>.from(cached);
      _loading   = false;
      _fromCache = true;
    });
    // 2. Background: cek server untuk data baru
    if (!forceRefresh) {
      _syncBackground(tanggal);
      return;
    }
  }

  // 3. Fetch dari server (pertama kali atau force refresh)
  await _fetchServer(tanggal, clear: forceRefresh);
}

Future<void> _syncBackground(String tanggal) async {
  try {
    final res = await ApiService.getGaleriHadir(tanggal: tanggal);
    if (res['status'] == true) {
      final list     = List<Map<String, dynamic>>.from(
          res['data'] ?? []);
      final newCount = await _GaleriCache.saveNew(tanggal, list);
      if (newCount > 0) {
        // Ada data baru → update tampilan
        final cached = await _GaleriCache.get(tanggal);
        _lastCached  = DateTime.now();
        if (mounted) {
          setState(() {
            _data      = List<Map<String, dynamic>>.from(cached);
            _fromCache = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$newCount data baru ditemukan'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ));
        }
      }
    }
  } catch (_) {}
}

Future<void> _fetchServer(String tanggal,
    {bool clear = false}) async {
  setState(() => _loading = true);
  try {
    if (clear) await _GaleriCache.clearDate(tanggal);
    final res = await ApiService.getGaleriHadir(tanggal: tanggal);
    if (res['status'] == true) {
      final list = List<Map<String, dynamic>>.from(
          res['data'] ?? []);
      await _GaleriCache.saveNew(tanggal, list);
      _lastCached = DateTime.now();
      final cached = await _GaleriCache.get(tanggal);
      setState(() {
        _data      = List<Map<String, dynamic>>.from(cached);
        _loading   = false;
        _fromCache = false;
      });
    } else {
      setState(() { _data = []; _loading = false; });
    }
  } catch (_) {
    setState(() => _loading = false);
  }
}

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
      _loadData();
    }
  }

  Future<void> _showCacheInfo() async {
  final total      = await _GaleriCache.totalRows();
  final totalDates = await _GaleriCache.totalDates();
  if (!mounted) return;
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
          const Text('Manajemen Cache',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.storage, color: Colors.white)),
            title: const Text('Data ter-cache'),
            subtitle: Text(
                '$total entri dari $totalDates tanggal'),
          ),
          ListTile(
            leading: const CircleAvatar(
                backgroundColor: Colors.purple,
                child: Icon(Icons.image, color: Colors.white)),
            title: const Text('Cache foto'),
            subtitle: const Text(
                'Dikelola otomatis oleh sistem'),
          ),
          if (_lastCached != null)
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.update, color: Colors.white)),
              title: const Text('Terakhir sync'),
              subtitle: Text(
                  '${_lastCached!.day}/${_lastCached!.month}/${_lastCached!.year} '
                  '${_lastCached!.hour}:${_lastCached!.minute.toString().padLeft(2, '0')}'),
            ),
          const Divider(),
          ListTile(
            leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.refresh, color: Colors.white)),
            title: const Text('Sync ulang tanggal ini'),
            onTap: () {
              Navigator.pop(context);
              _loadData(forceRefresh: true);
            },
          ),
          ListTile(
            leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.delete, color: Colors.white)),
            title: const Text('Hapus semua cache data',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text(
                'Cache foto tetap tersimpan di sistem'),
            onTap: () async {
              Navigator.pop(context);
              await _GaleriCache.clearAll();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Cache data dihapus'),
                    backgroundColor: Colors.green),
              );
              _loadData(forceRefresh: true);
            },
          ),
        ],
      ),
    ),
  );
}

  List<Map<String, dynamic>> get _sorted {
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
    final hadir    = _data.length;
    final lengkap  = _data.where(
        (d) => (d['jam_keluar'] ?? '00:00:00') != '00:00:00').length;
    final belum    = hadir - lengkap;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Galeri Kehadiran'),
        actions: [
          IconButton(
            icon: Icon(_newerFirst
                ? Icons.arrow_downward
                : Icons.arrow_upward),
            tooltip: _newerFirst ? 'Terbaru dulu' : 'Terlama dulu',
            onPressed: () =>
                setState(() => _newerFirst = !_newerFirst),
          ),
          IconButton(
            icon: const Icon(Icons.storage_outlined),
            tooltip: 'Cache',
            onPressed: _showCacheInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Pilih tanggal
          Container(
            color: const Color(0xFF1B5E20),
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
                    Text(_fmtLabel(_tanggal),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    // Cache indicator
                    if (_fromCache)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2,
                                size: 10, color: Colors.white70),
                            SizedBox(width: 3),
                            Text('cache',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70)),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down,
                        color: Colors.white),
                  ],
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
                  _chip(Icons.people, '$hadir Hadir', Colors.green),
                  const SizedBox(width: 8),
                  _chip(Icons.check_circle,
                      '$lengkap Lengkap', Colors.blue),
                  const SizedBox(width: 8),
                  _chip(Icons.pending,
                      '$belum Belum Keluar', Colors.orange),
                ],
              ),
            ),

          const Divider(height: 1),

          // Grid
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _data.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64,
                                color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada kehadiran\npada tanggal ini',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _loadData(forceRefresh: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            _loadData(forceRefresh: true),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _sorted.length,
                          itemBuilder: (_, i) =>
                              _buildCard(_sorted[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
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
    final fotoUrl    = _fotoUrl(item['foto_masuk'], 'masuk');
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
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  fotoUrl.isNotEmpty
    ? CachedNetworkImage(
        imageUrl: fotoUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
            color: Colors.grey[100],
            child: const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2))),
        errorWidget: (_, __, ___) => _placeholder(nama),
      )
    : _placeholder(nama),
                          
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
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nama,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
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

  Widget _placeholder(String nama) {
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
    final fotoMasukUrl  = _fotoUrl(item['foto_masuk'], 'masuk');
    final fotoKeluarUrl = _fotoUrl(item['foto_keluar'], 'keluar');
    final sudahKeluar   =
        (item['jam_keluar'] ?? '00:00:00') != '00:00:00';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scroll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),

                // Header info
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF1B5E20),
                        child: Text(
                          (item['nama'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['nama'] ?? '-',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text(item['jabatan'] ?? '-',
                              style: const TextStyle(
                                  color: Colors.grey)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: sudahKeluar
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sudahKeluar
                                  ? Colors.green
                                  : Colors.orange),
                        ),
                        child: Text(
                          sudahKeluar ? 'Lengkap' : 'Belum Keluar',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: sudahKeluar
                                  ? Colors.green
                                  : Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Foto masuk & keluar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _fotoDetailCard(
                          label: 'Foto Masuk',
                          jam: item['jam_masuk'] ?? '-',
                          url: fotoMasukUrl,
                          color: Colors.green,
                          icon: Icons.login,
                          nama: item['nama'] ?? '?',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _fotoDetailCard(
                          label: 'Foto Keluar',
                          jam: sudahKeluar
                              ? item['jam_keluar']
                              : '-',
                          url: sudahKeluar
                              ? fotoKeluarUrl
                              : '',
                          color: Colors.blue,
                          icon: Icons.logout,
                          nama: item['nama'] ?? '?',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fotoDetailCard({
    required String label,
    required String jam,
    required String url,
    required Color color,
    required IconData icon,
    required String nama,
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
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13)),
          ],
        ),
        Text(jam,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 8),
        // Foto — tap untuk fullscreen
        GestureDetector(
          onTap: url.isNotEmpty
              ? () => _showFullscreen(url, label, nama)
              : null,
          child: ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: url.isNotEmpty
    ? Stack(
        children: [
          CachedNetworkImage(
            imageUrl: Url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 160,
            placeholder: (_, __) => SizedBox(
              height: 160,
              child: Container(
                color: Colors.grey[100],
                child: const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2)),
              ),
            ),
            errorWidget: (_, __, ___) =>
                SizedBox(height: 160,
                    child: _placeholder(nama)),
          ),
          Positioned(
            bottom: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.zoom_in,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      )
                : Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                        child: Icon(Icons.image_not_supported,
                            color: Colors.grey, size: 40)),
                  ),
          ),
        ),
      ],
    );
  }

  void _showFullscreen(String url, String label, String nama) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('$label - $nama'),
          ),
          body: Center(
  child: InteractiveViewer(
    child: CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (_, __) => const CircularProgressIndicator(
          color: Colors.white),
      errorWidget: (_, __, ___) => const Icon(
          Icons.broken_image,
          color: Colors.white, size: 64),
    ),
  ),
),
        ),
      ),
    );
  }
}