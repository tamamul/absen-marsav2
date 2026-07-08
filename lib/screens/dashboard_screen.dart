import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import '../services/api_service.dart';
import '../models/pegawai_model.dart';
import '../models/presensi_model.dart';
import '../helpers/hari_besar.dart';
import '../helpers/hari_besar_custom.dart';
import '../helpers/cache_manager.dart';
import 'absen_screen.dart';
import 'login_screen.dart';
import 'riwayat_screen.dart';
import 'galeri_screen.dart';
import 'profil_screen.dart';
import 'kalender_screen.dart';
import 'pengumuman_screen.dart';
import 'absensi_siswa_screen.dart';
import 'rekap_siswa_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  PegawaiModel?  _pegawai;
  PresensiModel? _presensi;
  bool   _loading      = true;
  bool   _cekLokasi    = false;
  bool?  _didalam;
  String _pesanLokasi  = '';
  Position? _posisi;
  int    _navIndex     = 0;
  File?  _fotoProfil;
  int?   _myUserId;

  late DateTime _now;

  List<HariBesar>       _hariBesarHariIni = [];
  List<HariBesarCustom> _customHariIni    = [];
  List<HariBesarCustom> _customMendatang  = [];

  List<String> _bgUrls = [];
  int _bgIndex         = 0;
  final PageController _bgCtrl = PageController();

  static const Color _primary = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _loadFotoProfil();
    _loadUserId();
    _loadData();
    _loadBgGaleri();
    AppCacheManager.autoCleanup();
    Future.delayed(const Duration(minutes: 1), _tickWaktu);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  void _tickWaktu() {
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    Future.delayed(const Duration(minutes: 1), _tickWaktu);
  }

  Future<void> _loadFotoProfil() async {
    final prefs = await SharedPreferences.getInstance();
    final path  = prefs.getString('foto_profil_lokal');
    if (path != null && File(path).existsSync()) {
      setState(() => _fotoProfil = File(path));
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('user_data');
    if (raw != null) {
      final user = jsonDecode(raw);
      setState(() => _myUserId =
          int.tryParse(user['id'].toString()));
    }
  }

  Future<void> _loadBgGaleri() async {
    try {
      final tanggal =
          '${_now.year}-${_now.month.toString().padLeft(2,'0')}-${_now.day.toString().padLeft(2,'0')}';
      final res =
          await ApiService.getGaleriHadir(tanggal: tanggal);
      if (res['status'] == true) {
        final list =
            List<Map<String, dynamic>>.from(res['data'] ?? []);
        final urls = <String>[];
        for (final item in list) {
          final foto = item['foto_masuk'] ?? '';
          if (foto.isNotEmpty) {
            urls.add(
                'https://chat.marsa9.com/present/public/assets/img/foto_presensi/masuk/$foto');
          }
        }
        urls.shuffle();
        if (mounted && urls.isNotEmpty) {
          setState(() => _bgUrls = urls.take(10).toList());
        }
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final resPegawai  = await ApiService.getPegawaiProfil();
      final resPresensi = await ApiService.getAbsenHariIni();
      final now         = DateTime.now();
      final allCustom   = await HariBesarCustomDb.getAll();

      setState(() {
        if (resPegawai['status'] == true) {
          _pegawai = PegawaiModel.fromJson(resPegawai['data']);
        }
        if (resPresensi['status'] == true &&
            resPresensi['data'] != null) {
          _presensi =
              PresensiModel.fromJson(resPresensi['data']);
        }
        _hariBesarHariIni = HariBesarHelper.getHariIni(now);
        _customHariIni =
            allCustom.where((h) => h.cocokDengan(now)).toList();
        _customMendatang = allCustom;
        _loading         = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
    await _validasiLokasi();
  }

  Future<void> _validasiLokasi() async {
    setState(() { _cekLokasi = true; _didalam = null; });
    try {
      LocationPermission perm =
          await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _cekLokasi   = false;
          _didalam     = false;
          _pesanLokasi = 'Izin lokasi ditolak';
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _posisi = pos;
      final res =
          await ApiService.cekLokasi(pos.latitude, pos.longitude);
      setState(() {
        _cekLokasi   = false;
        _didalam     = res['didalam'] == true;
        _pesanLokasi = res['message'] ?? '';
      });
    } catch (_) {
      setState(() {
        _cekLokasi   = false;
        _pesanLokasi = 'Gagal cek lokasi';
        _didalam     = false;
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _showProfilMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(
            vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            CircleAvatar(
              radius: 42,
              backgroundColor: _primary,
              backgroundImage: _fotoProfil != null
                  ? FileImage(_fotoProfil!) : null,
              child: _fotoProfil == null
                  ? Text(
                      _pegawai?.nama.isNotEmpty == true
                          ? _pegawai!.nama[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 36,
                          color: Colors.white,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(_pegawai?.nama ?? '-',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(_pegawai?.jabatan ?? '-',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil Saya'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ProfilScreen(pegawai: _pegawai)));
                _loadFotoProfil();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.logout, color: Colors.red),
              title: const Text('Keluar',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showToolsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
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
            const Text('Tools',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _toolItem(Icons.calendar_month, 'Kalender',
                    _primary, () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const KalenderScreen()));
                }),
                _toolItem(Icons.how_to_reg, 'Absensi\nSiswa',
                    Colors.teal, () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AbsensiSiswaScreen()));
                }),
                _toolItem(Icons.bar_chart, 'Rekap\nSiswa',
                    Colors.indigo, () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const RekapSiswaScreen()));
                }),
                _toolItem(Icons.campaign, 'Pengumuman',
                    Colors.orange, () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const PengumumanScreen()));
                }),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _toolItem(IconData icon, String label, Color color,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sudahMasuk  = _presensi?.sudahMasuk  ?? false;
    final sudahKeluar = _presensi?.sudahKeluar ?? false;
    final bolehAbsen  = _didalam == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school,
                  size: 20, color: _primary),
            ),
            const SizedBox(width: 10),
            const Text('Absen MARSA',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _showProfilMenu,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: _fotoProfil != null
                    ? FileImage(_fotoProfil!) : null,
                child: _fotoProfil == null
                    ? Text(
                        _pegawai?.nama.isNotEmpty == true
                            ? _pegawai!.nama[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: _navIndex == 0
          ? _buildBeranda(sudahMasuk, sudahKeluar, bolehAbsen)
          : _navIndex == 1
              ? const RiwayatScreen()
              : const GaleriScreen(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBeranda(
      bool sudahMasuk, bool sudahKeluar, bool bolehAbsen) {
    return Column(
      children: [
        // ── Header hijau dengan bg foto ──────────────────────
        _buildHeader(),

        // ── Konten scrollable ─────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildStatusCard(
                            sudahMasuk, sudahKeluar),
                        const SizedBox(height: 12),
                        _buildAgendaCard(),
                      ],
                    ),
                  ),
                ),
        ),

        // ── Bottom: lokasi + tombol absen ────────────────────
        _buildBottomAbsen(
            sudahMasuk, sudahKeluar, bolehAbsen),
      ],
    );
  }

  // ── Header dengan foto background slideshow ────────────────
  Widget _buildHeader() {
    final hijri = HijriCalendar.fromDate(_now);

    return Container(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background foto / gradient
          _bgUrls.isEmpty
              ? Container(color: _primary)
              : PageView.builder(
                  controller: _bgCtrl,
                  itemCount: _bgUrls.length,
                  onPageChanged: (i) =>
                      setState(() => _bgIndex = i),
                  itemBuilder: (_, i) => CachedNetworkImage(
                    imageUrl: _bgUrls[i],
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: _primary),
                    errorWidget: (_, __, ___) =>
                        Container(color: _primary),
                  ),
                ),

          // Blur + overlay hijau
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primary.withOpacity(0.85),
                    _primary.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // Konten tanggal & jam
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Nama pegawai kecil di atas
                Row(
                  children: [
                    Text(
                      _pegawai?.nama ?? '',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13),
                    ),
                    const Spacer(),
                    // Dot slideshow
                    if (_bgUrls.length > 1)
                      Row(
                        children: List.generate(
                            _bgUrls.length > 5
                                ? 5
                                : _bgUrls.length, (i) =>
                          Container(
                            width: i == _bgIndex ? 12 : 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 2),
                            decoration: BoxDecoration(
                              color: i == _bgIndex
                                  ? Colors.white
                                  : Colors.white38,
                              borderRadius:
                                  BorderRadius.circular(3),
                            ),
                          )),
                      ),
                  ],
                ),

                // Tanggal & jam
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            HariBesarHelper.namaHari(_now),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13),
                          ),
                          Text(
                            '${_now.day} ${HariBesarHelper.namaBulan(_now.month)} ${_now.year}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${hijri.hDay} ${HariBesarHelper.namaBulanHijri(hijri.hMonth)} ${hijri.hYear} H',
                            style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_now.hour.toString().padLeft(2,'0')}:${_now.minute.toString().padLeft(2,'0')}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              height: 1),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const KalenderScreen())),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_month,
                                    color: Colors.white,
                                    size: 12),
                                SizedBox(width: 4),
                                Text('Kalender',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Card status absen ──────────────────────────────────────
  Widget _buildStatusCard(bool sudahMasuk, bool sudahKeluar) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Status Kehadiran Hari Ini',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (sudahMasuk && sudahKeluar)
                        ? Colors.green.withOpacity(0.1)
                        : sudahMasuk
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (sudahMasuk && sudahKeluar)
                        ? '✅ Lengkap'
                        : sudahMasuk
                            ? '⏳ Belum Keluar'
                            : '— Belum Absen',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: (sudahMasuk && sudahKeluar)
                            ? Colors.green
                            : sudahMasuk
                                ? Colors.orange
                                : Colors.grey),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: _statusItem(
                    icon: Icons.login,
                    label: 'Masuk',
                    value: sudahMasuk
                        ? _presensi!.jamMasuk : '-',
                    color: sudahMasuk
                        ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statusItem(
                    icon: Icons.logout,
                    label: 'Keluar',
                    value: sudahKeluar
                        ? _presensi!.jamKeluar : '-',
                    color: sudahKeluar
                        ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Card agenda mendatang ──────────────────────────────────
  Widget _buildAgendaCard() {
    final eventHariIni = <Map<String, dynamic>>[];
    for (final h in _hariBesarHariIni) {
      eventHariIni
          .add({'nama': h.nama, 'emoji': h.emoji ?? '📅'});
    }
    for (final h in _customHariIni) {
      eventHariIni.add({'nama': h.nama, 'emoji': h.emoji});
    }

    final mendatang =
        HariBesarHelper.getMendatang(_now, hari: 30);
    final agendaMendatang = <Map<String, dynamic>>[];
    for (final h in mendatang) {
      agendaMendatang.add({
        'tanggal': h.tanggal,
        'nama': h.nama,
        'emoji': h.emoji ?? '📅',
      });
    }
    for (final h in _customMendatang) {
      final dt = DateTime(
        h.tahunan ? _now.year : h.tanggalYear,
        h.tanggalMonth, h.tanggalDay,
      );
      if (dt.isAfter(_now) &&
          dt.isBefore(_now.add(const Duration(days: 30)))) {
        agendaMendatang.add({
          'tanggal': dt,
          'nama': h.nama,
          'emoji': h.emoji,
        });
      }
    }
    agendaMendatang.sort((a, b) =>
        (a['tanggal'] as DateTime)
            .compareTo(b['tanggal'] as DateTime));

    if (eventHariIni.isEmpty && agendaMendatang.isEmpty) {
      return const SizedBox();
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event hari ini
            if (eventHariIni.isNotEmpty) ...[
              const Text('Hari Ini',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _primary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: eventHariIni.map((e) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e['emoji'] as String,
                          style:
                              const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(e['nama'] as String,
                          style: const TextStyle(
                              color: _primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                )).toList(),
              ),
              if (agendaMendatang.isNotEmpty)
                const SizedBox(height: 14),
            ],

            // Agenda mendatang
            if (agendaMendatang.isNotEmpty) ...[
              Row(
                children: [
                  const Text('Agenda Mendatang',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _primary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const KalenderScreen())),
                    child: const Text('Lihat semua',
                        style: TextStyle(
                            color: _primary, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: agendaMendatang.length,
                  itemBuilder: (_, i) {
                    final e  = agendaMendatang[i];
                    final dt = e['tanggal'] as DateTime;
                    final selisih =
                        dt.difference(_now).inDays;
                    return Container(
                      width: 90,
                      margin:
                          const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selisih <= 3
                            ? Colors.red.withOpacity(0.08)
                            : _primary.withOpacity(0.06),
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                          color: selisih <= 3
                              ? Colors.red.withOpacity(0.3)
                              : _primary.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Text(e['emoji'] as String,
                                style: const TextStyle(
                                    fontSize: 14)),
                            const Spacer(),
                            Text('${selisih}h',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: selisih <= 3
                                        ? Colors.red
                                        : Colors.grey,
                                    fontWeight:
                                        FontWeight.bold)),
                          ]),
                          Text(e['nama'] as String,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: selisih <= 3
                                      ? Colors.red[700]
                                      : Colors.black87),
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis),
                          Text(
                            '${dt.day} ${HariBesarHelper.namaBulan(dt.month).substring(0, 3)}',
                            style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Bottom: lokasi inline + tombol absen ───────────────────
  Widget _buildBottomAbsen(
      bool sudahMasuk, bool sudahKeluar, bool bolehAbsen) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lokasi inline — tidak ada box
            Row(
              children: [
                _cekLokasi
                    ? SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange))
                    : Icon(
                        _didalam == true
                            ? Icons.location_on
                            : Icons.location_off,
                        size: 14,
                        color: _didalam == true
                            ? Colors.green
                            : Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _cekLokasi
                        ? 'Mengecek lokasi...'
                        : _pesanLokasi,
                    style: TextStyle(
                        fontSize: 11,
                        color: _didalam == true
                            ? Colors.green[700]
                            : Colors.red[700]),
                  ),
                ),
                GestureDetector(
                  onTap:
                      _cekLokasi ? null : _validasiLokasi,
                  child: const Icon(Icons.refresh,
                      size: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tombol absen
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (sudahMasuk || !bolehAbsen)
                        ? null
                        : () async {
                            final r = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AbsenScreen(
                                        tipe: 'masuk',
                                        posisi: _posisi)));
                            if (r == true) _loadData();
                          },
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Absen Masuk'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.grey[200],
                      disabledForegroundColor:
                          Colors.grey[400],
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (!sudahMasuk ||
                            sudahKeluar ||
                            !bolehAbsen)
                        ? null
                        : () async {
                            final r = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AbsenScreen(
                                        tipe: 'keluar',
                                        posisi: _posisi)));
                            if (r == true) _loadData();
                          },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Absen Keluar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.grey[200],
                      disabledForegroundColor:
                          Colors.grey[400],
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _navItem(0, Icons.home_outlined,
                  Icons.home, 'Beranda'),
              _navItem(1, Icons.history_outlined,
                  Icons.history, 'Riwayat'),
              _navItem(2, Icons.photo_library_outlined,
                  Icons.photo_library, 'Galeri'),
              Expanded(
                child: GestureDetector(
                  onTap: _showToolsMenu,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.apps,
                            color: _primary, size: 22),
                      ),
                      const SizedBox(height: 2),
                      const Text('Tools',
                          style: TextStyle(
                              fontSize: 10,
                              color: _primary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData iconOff,
      IconData iconOn, String label) {
    final active = _navIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _navIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? iconOn : iconOff,
              color: active ? _primary : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: active ? _primary : Colors.grey,
                    fontWeight: active
                        ? FontWeight.bold
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}