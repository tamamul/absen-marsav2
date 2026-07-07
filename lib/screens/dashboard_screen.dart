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

  // Waktu
  late DateTime _now;

  // Hari besar
  List<HariBesar>       _hariBesarHariIni = [];
  List<HariBesarCustom> _customHariIni    = [];
  List<HariBesarCustom> _customMendatang  = [];

  // Background dari galeri
  List<String> _bgUrls       = [];
  int          _bgIndex      = 0;
  final PageController _bgCtrl = PageController();

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

  // Ambil foto dari galeri hari ini untuk background
  Future<void> _loadBgGaleri() async {
    try {
      final tanggal = '${_now.year}-${_now.month.toString().padLeft(2,'0')}-${_now.day.toString().padLeft(2,'0')}';
      final res = await ApiService.getGaleriHadir(tanggal: tanggal);
      if (res['status'] == true) {
        final list = List<Map<String, dynamic>>.from(res['data'] ?? []);
        final urls = <String>[];
        for (final item in list) {
          final foto = item['foto_masuk'] ?? '';
          if (foto.isNotEmpty) {
            urls.add('https://chat.marsa9.com/present/public/assets/img/foto_presensi/masuk/$foto');
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
          _presensi = PresensiModel.fromJson(resPresensi['data']);
        }
        _hariBesarHariIni = HariBesarHelper.getHariIni(now);
        _customHariIni    = allCustom
            .where((h) => h.cocokDengan(now))
            .toList();
        _customMendatang  = allCustom;
        _loading          = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
    await _validasiLokasi();
  }

  Future<void> _validasiLokasi() async {
    setState(() { _cekLokasi = true; _didalam = null; });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() { _cekLokasi = false; _didalam = false;
          _pesanLokasi = 'Izin lokasi ditolak'; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _posisi = pos;
      final res = await ApiService.cekLokasi(
          pos.latitude, pos.longitude);
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
              backgroundColor: const Color(0xFF1B5E20),
              backgroundImage: _fotoProfil != null
                  ? FileImage(_fotoProfil!) : null,
              child: _fotoProfil == null
                  ? Text(
                      _pegawai?.nama.isNotEmpty == true
                          ? _pegawai!.nama[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 36,
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
                await Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ProfilScreen(pegawai: _pegawai)));
                _loadFotoProfil();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Keluar',
                  style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); _logout(); },
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
                    const Color(0xFF1B5E20), () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const KalenderScreen()));
                }),
                _toolItem(Icons.how_to_reg, 'Absensi\nSiswa',
                    Colors.teal, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const AbsensiSiswaScreen()));
                }),
                _toolItem(Icons.bar_chart, 'Rekap\nSiswa',
                    Colors.indigo, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const RekapSiswaScreen()));
                }),
                _toolItem(Icons.campaign, 'Pengumuman',
                    Colors.orange, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const PengumumanScreen()));
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
                  size: 20, color: Color(0xFF1B5E20)),
            ),
            const SizedBox(width: 10),
            const Text('Absen MARSA',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
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
                            ? _pegawai!.nama[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Color(0xFF1B5E20),
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
    return Stack(
      children: [
        // ── Background foto galeri ──────────────────────────
        _buildBackground(),

        // ── Konten ─────────────────────────────────────────
        SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                        16, 8, 16, 100),
                    child: Column(
                      children: [
                        _buildTanggalCard(),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                            sudahMasuk, sudahKeluar),
                        const SizedBox(height: 12),
                        _buildLokasiStatus(),
                        const SizedBox(height: 20),
                        _buildAbsenButtons(
                            sudahMasuk, sudahKeluar,
                            bolehAbsen),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Background foto random bisa slide ──────────────────────
  Widget _buildBackground() {
    if (_bgUrls.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF0A1628)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Foto slideshow
        PageView.builder(
          controller: _bgCtrl,
          itemCount: _bgUrls.length,
          onPageChanged: (i) => setState(() => _bgIndex = i),
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: _bgUrls[i],
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (_, __) => Container(
                color: const Color(0xFF1B5E20)),
            errorWidget: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF0A1628)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),

        // Blur + gelap overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.65),
                  Colors.black.withOpacity(0.55),
                  const Color(0xFF1B5E20).withOpacity(0.4),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // Dot indicator slideshow
        if (_bgUrls.length > 1)
          Positioned(
            bottom: 100, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_bgUrls.length, (i) =>
                Container(
                  width: i == _bgIndex ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 2),
                  decoration: BoxDecoration(
                    color: i == _bgIndex
                        ? Colors.white
                        : Colors.white38,
                    borderRadius: BorderRadius.circular(3),
                  ),
                )),
            ),
          ),
      ],
    );
  }

  // ── Card tanggal + agenda ───────────────────────────────────
  Widget _buildTanggalCard() {
    final hijri     = HijriCalendar.fromDate(_now);
    final mendatang = HariBesarHelper.getMendatang(_now, hari: 30);

    final eventHariIni = <Map<String, dynamic>>[];
    for (final h in _hariBesarHariIni) {
      eventHariIni.add({'nama': h.nama, 'emoji': h.emoji ?? '📅'});
    }
    for (final h in _customHariIni) {
      eventHariIni.add({'nama': h.nama, 'emoji': h.emoji});
    }

    final agendaMendatang = <Map<String, dynamic>>[];
    for (final h in mendatang) {
      agendaMendatang.add({
        'tanggal': h.tanggal, 'nama': h.nama,
        'emoji': h.emoji ?? '📅', 'tipe': h.tipe, 'obj': null,
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
          'tanggal': dt, 'nama': h.nama,
          'emoji': h.emoji,
          'tipe': h.isPublik ? 'publik' : 'privat',
          'obj': h,
        });
      }
    }
    agendaMendatang.sort((a, b) =>
        (a['tanggal'] as DateTime)
            .compareTo(b['tanggal'] as DateTime));

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withOpacity(0.2), width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              color: Colors.white70,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const KalenderScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_month,
                                  color: Colors.white, size: 12),
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

              // Event hari ini
              if (eventHariIni.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: eventHariIni.map((e) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e['emoji'] as String,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(e['nama'] as String,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
                ),
              ],

              // Agenda mendatang
              if (agendaMendatang.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(color: Colors.white24, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Text('Agenda Mendatang',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const KalenderScreen())),
                        child: const Text('Lihat kalender',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10)),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: agendaMendatang.length,
                    itemBuilder: (_, i) {
                      final e       = agendaMendatang[i];
                      final dt      = e['tanggal'] as DateTime;
                      final selisih = dt.difference(_now).inDays;
                      return Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white24, width: 1),
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
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1),
                                decoration: BoxDecoration(
                                  color: selisih <= 3
                                      ? Colors.red
                                          .withOpacity(0.4)
                                      : Colors.white12,
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Text('${selisih}h',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white70,
                                        fontWeight:
                                            FontWeight.bold)),
                              ),
                            ]),
                            Text(e['nama'] as String,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            Text(
                              '${dt.day} ${HariBesarHelper.namaBulan(dt.month).substring(0, 3)}',
                              style: const TextStyle(
                                  color: Colors.white38,
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
      ),
    );
  }

  // ── Info profil + status dalam satu row ────────────────────
  Widget _buildInfoRow(bool sudahMasuk, bool sudahKeluar) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withOpacity(0.2), width: 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                backgroundImage: _fotoProfil != null
                    ? FileImage(_fotoProfil!) : null,
                child: _fotoProfil == null
                    ? Text(
                        _pegawai?.nama.isNotEmpty == true
                            ? _pegawai!.nama[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),

              // Nama & jabatan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_pegawai?.nama ?? '-',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    Text(_pegawai?.jabatan ?? '-',
                        style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12)),
                  ],
                ),
              ),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (sudahMasuk && sudahKeluar)
                      ? Colors.green.withOpacity(0.3)
                      : sudahMasuk
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (sudahMasuk && sudahKeluar)
                        ? Colors.green
                        : sudahMasuk
                            ? Colors.orange
                            : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      (sudahMasuk && sudahKeluar)
                          ? '✅ Lengkap'
                          : sudahMasuk
                              ? '⏳ Masuk'
                              : '—',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                    if (sudahMasuk)
                      Text(
                        _presensi!.jamMasuk,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Status lokasi compact ───────────────────────────────────
  Widget _buildLokasiStatus() {
    Color color;
    IconData icon;
    if (_cekLokasi) {
      color = Colors.orange; icon = Icons.location_searching;
    } else if (_didalam == true) {
      color = Colors.green; icon = Icons.location_on;
    } else {
      color = Colors.red; icon = Icons.location_off;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: color.withOpacity(0.4), width: 1),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          child: Row(
            children: [
              _cekLokasi
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color))
                  : Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _cekLokasi
                      ? 'Mengecek lokasi...'
                      : _pesanLokasi,
                  style: TextStyle(
                      color: _didalam == true
                          ? Colors.white
                          : Colors.white70,
                      fontSize: 12),
                ),
              ),
              GestureDetector(
                onTap: _cekLokasi ? null : _validasiLokasi,
                child: Icon(Icons.refresh,
                    color: Colors.white38, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tombol absen ────────────────────────────────────────────
  Widget _buildAbsenButtons(
      bool sudahMasuk, bool sudahKeluar, bool bolehAbsen) {
    return Row(
      children: [
        Expanded(
          child: _absenButton(
            label: 'Absen Masuk',
            icon: Icons.login,
            color: const Color(0xFF1B5E20),
            enabled: !sudahMasuk && bolehAbsen,
            onTap: () async {
              final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AbsenScreen(
                          tipe: 'masuk', posisi: _posisi)));
              if (result == true) _loadData();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _absenButton(
            label: 'Absen Keluar',
            icon: Icons.logout,
            color: Colors.blue[700]!,
            enabled: sudahMasuk && !sudahKeluar && bolehAbsen,
            onTap: () async {
              final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AbsenScreen(
                          tipe: 'keluar', posisi: _posisi)));
              if (result == true) _loadData();
            },
          ),
        ),
      ],
    );
  }

  Widget _absenButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: enabled
                  ? color.withOpacity(0.5)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: enabled
                    ? color.withOpacity(0.7)
                    : Colors.white12,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: enabled
                        ? Colors.white
                        : Colors.white30,
                    size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: enabled
                            ? Colors.white
                            : Colors.white30,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withOpacity(0.95),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 8),
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
                          color: const Color(0xFF1B5E20)
                              .withOpacity(0.2),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.apps,
                            color: Color(0xFF1B5E20), size: 22),
                      ),
                      const SizedBox(height: 2),
                      const Text('Tools',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF1B5E20),
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
              color: active
                  ? const Color(0xFF1B5E20)
                  : Colors.white38,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: active
                        ? const Color(0xFF1B5E20)
                        : Colors.white38,
                    fontWeight: active
                        ? FontWeight.bold
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}