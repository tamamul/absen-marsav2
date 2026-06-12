import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import '../helpers/hari_besar.dart';

class KalenderScreen extends StatefulWidget {
  const KalenderScreen({super.key});

  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends State<KalenderScreen> {
  DateTime _bulanAktif = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _hariDipilih = DateTime.now();
  late List<HariBesar> _hariBesarBulanIni;

  @override
  void initState() {
    super.initState();
    _loadHariBesar();
  }

  void _loadHariBesar() {
    _hariBesarBulanIni = HariBesarHelper.getAll(_bulanAktif.year);
  }

  void _bulanSebelum() {
    setState(() {
      _bulanAktif = DateTime(_bulanAktif.year, _bulanAktif.month - 1);
      _loadHariBesar();
    });
  }

  void _bulanBerikut() {
    setState(() {
      _bulanAktif = DateTime(_bulanAktif.year, _bulanAktif.month + 1);
      _loadHariBesar();
    });
  }

  List<HariBesar> _getHariBesarTanggal(DateTime dt) {
    return _hariBesarBulanIni.where((h) =>
        h.tanggal.day   == dt.day &&
        h.tanggal.month == dt.month &&
        h.tanggal.year  == dt.year).toList();
  }

  bool _isHariIni(DateTime dt) {
    final now = DateTime.now();
    return dt.day == now.day &&
        dt.month == now.month &&
        dt.year == now.year;
  }

  bool _isDipilih(DateTime dt) {
    return dt.day   == _hariDipilih.day &&
        dt.month == _hariDipilih.month &&
        dt.year  == _hariDipilih.year;
  }

  // Bangun grid tanggal
  List<DateTime?> _buildGrid() {
    final firstDay = DateTime(_bulanAktif.year, _bulanAktif.month, 1);
    final daysInMonth =
        DateTime(_bulanAktif.year, _bulanAktif.month + 1, 0).day;
    // Senin = 1, jadi offset = weekday - 1
    final offset = firstDay.weekday - 1;
    final grid = <DateTime?>[];
    for (int i = 0; i < offset; i++) grid.add(null);
    for (int i = 1; i <= daysInMonth; i++) {
      grid.add(DateTime(_bulanAktif.year, _bulanAktif.month, i));
    }
    // Pad sampai kelipatan 7
    while (grid.length % 7 != 0) grid.add(null);
    return grid;
  }

  @override
  Widget build(BuildContext context) {
    final hijriBulan = HijriCalendar.fromDate(
        DateTime(_bulanAktif.year, _bulanAktif.month, 15));
    final hariDipilihBesar = _getHariBesarTanggal(_hariDipilih);
    final hijriDipilih = HijriCalendar.fromDate(_hariDipilih);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Kalender'),
      ),
      body: Column(
        children: [
          // Header bulan
          Container(
            color: const Color(0xFF1B5E20),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left,
                          color: Colors.white),
                      onPressed: _bulanSebelum,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${HariBesarHelper.namaBulan(_bulanAktif.month)} ${_bulanAktif.year}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${HariBesarHelper.namaBulanHijri(hijriBulan.hMonth)} ${hijriBulan.hYear} H',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right,
                          color: Colors.white),
                      onPressed: _bulanBerikut,
                    ),
                  ],
                ),
                // Header hari
                Row(
                  children: ['Sen','Sel','Rab','Kam','Jum','Sab','Min']
                      .map((h) => Expanded(
                            child: Center(
                              child: Text(h,
                                  style: TextStyle(
                                      color: h == 'Min'
                                          ? Colors.red[200]
                                          : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),

          // Grid kalender
          Container(
            color: Colors.white,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: _buildGrid().length,
              itemBuilder: (_, i) {
                final dt = _buildGrid()[i];
                if (dt == null) return const SizedBox();
                return _buildTanggal(dt);
              },
            ),
          ),

          const Divider(height: 1),

          // Detail hari dipilih
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info tanggal dipilih
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B5E20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${_hariDipilih.day}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${HariBesarHelper.namaHari(_hariDipilih)}, ${_hariDipilih.day} ${HariBesarHelper.namaBulan(_hariDipilih.month)} ${_hariDipilih.year}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              Text(
                                '${hijriDipilih.hDay} ${HariBesarHelper.namaBulanHijri(hijriDipilih.hMonth)} ${hijriDipilih.hYear} H',
                                style: const TextStyle(
                                    color: Color(0xFF1B5E20),
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Hari besar pada tanggal dipilih
                  if (hariDipilihBesar.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Hari Besar',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1B5E20))),
                    const SizedBox(height: 8),
                    ...hariDipilihBesar.map((h) => _buildHariBesarItem(h)),
                  ],

                  // Hari besar mendatang
                  const SizedBox(height: 16),
                  const Text('Hari Besar Mendatang',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1B5E20))),
                  const SizedBox(height: 8),
                  ..._buildMendatang(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTanggal(DateTime dt) {
    final hariBesar = _getHariBesarTanggal(dt);
    final isHariIni = _isHariIni(dt);
    final isDipilih = _isDipilih(dt);
    final isMinggu  = dt.weekday == 7;
    final isLibur   = hariBesar.isNotEmpty;

    return GestureDetector(
      onTap: () => setState(() => _hariDipilih = dt),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isDipilih
              ? const Color(0xFF1B5E20)
              : isHariIni
                  ? const Color(0xFF1B5E20).withOpacity(0.15)
                  : null,
          shape: BoxShape.circle,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${dt.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isHariIni || isDipilih
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: isDipilih
                      ? Colors.white
                      : isMinggu || isLibur
                          ? Colors.red
                          : Colors.black87,
                ),
              ),
            ),
            // Dot hari besar
            if (isLibur && !isDipilih)
              Positioned(
                bottom: 4, left: 0, right: 0,
                child: Center(
                  child: Container(
                    width: 4, height: 4,
                    decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHariBesarItem(HariBesar h) {
    final color = h.tipe == 'islam'
        ? const Color(0xFF1B5E20)
        : Colors.red[700]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(h.emoji ?? '📅',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.nama,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(
                  h.tipe == 'islam' ? 'Hari Besar Islam' : 'Hari Nasional',
                  style: TextStyle(
                      fontSize: 11,
                      color: color.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMendatang() {
    final mendatang = HariBesarHelper.getMendatang(
        DateTime.now(), hari: 60);
    if (mendatang.isEmpty) {
      return [
        const Text('Tidak ada hari besar dalam 60 hari ke depan',
            style: TextStyle(color: Colors.grey))
      ];
    }
    return mendatang.take(10).map((h) {
      final selisih = h.tanggal
          .difference(DateTime.now())
          .inDays;
      final color = h.tipe == 'islam'
          ? const Color(0xFF1B5E20)
          : Colors.red[700]!;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Text(h.emoji ?? '📅',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.nama,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Text(
                    '${HariBesarHelper.namaHari(h.tanggal)}, ${h.tanggal.day} ${HariBesarHelper.namaBulan(h.tanggal.month)}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: selisih <= 7
                    ? Colors.red.withOpacity(0.1)
                    : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                selisih == 0
                    ? 'Hari ini'
                    : '$selisih hari lagi',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selisih <= 7 ? Colors.red : color),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}