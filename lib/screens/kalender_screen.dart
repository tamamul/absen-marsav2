import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import '../helpers/hari_besar.dart';
import '../helpers/hari_besar_custom.dart';

class KalenderScreen extends StatefulWidget {
  const KalenderScreen({super.key});

  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends State<KalenderScreen> {
  DateTime _bulanAktif  = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _hariDipilih = DateTime.now();
  List<HariBesar>       _hariBesarNasional = [];
  List<HariBesarCustom> _hariBesarCustom   = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final custom = await HariBesarCustomDb.getAll();
    setState(() {
      _hariBesarNasional = HariBesarHelper.getAll(_bulanAktif.year);
      _hariBesarCustom   = custom;
    });
  }

  void _bulanSebelum() {
    setState(() {
      _bulanAktif = DateTime(_bulanAktif.year, _bulanAktif.month - 1);
      _hariBesarNasional = HariBesarHelper.getAll(_bulanAktif.year);
    });
  }

  void _bulanBerikut() {
    setState(() {
      _bulanAktif = DateTime(_bulanAktif.year, _bulanAktif.month + 1);
      _hariBesarNasional = HariBesarHelper.getAll(_bulanAktif.year);
    });
  }

  List<HariBesar> _getNasionalTanggal(DateTime dt) {
    return _hariBesarNasional.where((h) =>
        h.tanggal.day   == dt.day &&
        h.tanggal.month == dt.month &&
        h.tanggal.year  == dt.year).toList();
  }

  List<HariBesarCustom> _getCustomTanggal(DateTime dt) {
    return _hariBesarCustom.where((h) => h.cocokDengan(dt)).toList();
  }

  bool _isHariIni(DateTime dt) {
    final now = DateTime.now();
    return dt.day == now.day &&
        dt.month == now.month &&
        dt.year  == now.year;
  }

  bool _isDipilih(DateTime dt) =>
      dt.day == _hariDipilih.day &&
      dt.month == _hariDipilih.month &&
      dt.year  == _hariDipilih.year;

  List<DateTime?> _buildGrid() {
    final firstDay    = DateTime(_bulanAktif.year, _bulanAktif.month, 1);
    final daysInMonth =
        DateTime(_bulanAktif.year, _bulanAktif.month + 1, 0).day;
    final offset = firstDay.weekday - 1;
    final grid   = <DateTime?>[];
    for (int i = 0; i < offset; i++) grid.add(null);
    for (int i = 1; i <= daysInMonth; i++) {
      grid.add(DateTime(_bulanAktif.year, _bulanAktif.month, i));
    }
    while (grid.length % 7 != 0) grid.add(null);
    return grid;
  }

  // ── Form tambah/edit ─────────────────────────────────────────
  void _showForm({HariBesarCustom? existing}) {
    final namaCtrl    = TextEditingController(text: existing?.nama    ?? '');
    final catatanCtrl = TextEditingController(text: existing?.catatan ?? '');
    String emoji      = existing?.emoji ?? '📅';
    DateTime tanggal  = existing != null
        ? DateTime(
            existing.tahunan ? DateTime.now().year : existing.tanggalYear,
            existing.tanggalMonth,
            existing.tanggalDay)
        : _hariDipilih;
    bool tahunan = existing?.tahunan ?? false;

    final emojis = ['📅','🎉','🎂','🌙','⭐','🏆','📚','❤️',
                    '🎊','🕌','🇮🇩','👨‍👩‍👧','🏥','✈️','💼','🎓'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16, left: 16, right: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  existing == null
                      ? 'Tambah Pengingat'
                      : 'Edit Pengingat',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Pilih emoji
                const Text('Ikon',
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: emojis.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => setModal(() => emoji = emojis[i]),
                      child: Container(
                        width: 44, height: 44,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: emoji == emojis[i]
                              ? const Color(0xFF1B5E20).withOpacity(0.15)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: emoji == emojis[i]
                                ? const Color(0xFF1B5E20)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(emojis[i],
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Nama
                TextField(
                  controller: namaCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Pengingat *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Text(emoji,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),

                const SizedBox(height: 12),

                // Tanggal
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: tanggal,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(
                              primary: Color(0xFF1B5E20)),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setModal(() => tanggal = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: Color(0xFF1B5E20), size: 20),
                        const SizedBox(width: 10),
                        Text(
                          '${HariBesarHelper.namaHari(tanggal)}, ${tanggal.day} ${HariBesarHelper.namaBulan(tanggal.month)} ${tanggal.year}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Toggle tahunan
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.repeat,
                          color: Color(0xFF1B5E20), size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ulangi Setiap Tahun',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500)),
                            Text('Cocok untuk ulang tahun, dll',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Switch(
                        value: tahunan,
                        activeColor: const Color(0xFF1B5E20),
                        onChanged: (v) => setModal(() => tahunan = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Catatan
                TextField(
                  controller: catatanCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Catatan (opsional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.notes),
                  ),
                ),

                const SizedBox(height: 20),

                // Tombol simpan
                Row(
                  children: [
                    if (existing != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await HariBesarCustomDb.delete(existing.id!);
                            await _load();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pengingat dihapus'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete,
                              color: Colors.red),
                          label: const Text('Hapus',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    if (existing != null) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (namaCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Nama tidak boleh kosong')),
                            );
                            return;
                          }
                          final h = HariBesarCustom(
                            id:           existing?.id,
                            nama:         namaCtrl.text.trim(),
                            emoji:        emoji,
                            tanggalDay:   tanggal.day,
                            tanggalMonth: tanggal.month,
                            tanggalYear:  tahunan ? 0 : tanggal.year,
                            catatan:      catatanCtrl.text.trim(),
                            tahunan:      tahunan,
                          );
                          await HariBesarCustomDb.save(h);
                          Navigator.pop(ctx);
                          await _load();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(existing == null
                                  ? 'Pengingat ditambahkan'
                                  : 'Pengingat diperbarui'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: Text(existing == null ? 'Simpan' : 'Update'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hijriBulan   = HijriCalendar.fromDate(
        DateTime(_bulanAktif.year, _bulanAktif.month, 15));
    final nasionalDipilih = _getNasionalTanggal(_hariDipilih);
    final customDipilih   = _getCustomTanggal(_hariDipilih);
    final hijriDipilih    = HijriCalendar.fromDate(_hariDipilih);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Kalender'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Pengingat',
            onPressed: () => _showForm(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header bulan
          Container(
            color: const Color(0xFF1B5E20),
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
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
                                color: Colors.white70, fontSize: 12),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children:
                        ['Sen','Sel','Rab','Kam','Jum','Sab','Min']
                            .map((h) => Expanded(
                                  child: Center(
                                    child: Text(h,
                                        style: TextStyle(
                                            color: h == 'Min'
                                                ? Colors.red[200]
                                                : Colors.white70,
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.bold)),
                                  ),
                                ))
                            .toList(),
                  ),
                ),
              ],
            ),
          ),

          // Grid kalender
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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

          // Detail
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
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B5E20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${_hariDipilih.day}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${HariBesarHelper.namaHari(_hariDipilih)}, ${_hariDipilih.day} ${HariBesarHelper.namaBulan(_hariDipilih.month)} ${_hariDipilih.year}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${hijriDipilih.hDay} ${HariBesarHelper.namaBulanHijri(hijriDipilih.hMonth)} ${hijriDipilih.hYear} H',
                                  style: const TextStyle(
                                      color: Color(0xFF1B5E20),
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          // Tombol tambah di tanggal ini
                          IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Color(0xFF1B5E20)),
                            tooltip: 'Tambah pengingat',
                            onPressed: () => _showForm(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Hari besar nasional/islam
                  if (nasionalDipilih.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionLabel('Hari Besar'),
                    ...nasionalDipilih.map(_buildNasionalItem),
                  ],

                  // Pengingat custom
                  if (customDipilih.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionLabel('Pengingat'),
                    ...customDipilih.map(_buildCustomItem),
                  ],

                  // Semua pengingat custom
                  if (_hariBesarCustom.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _sectionLabel('Semua Pengingat'),
                        const Spacer(),
                        Text(
                          '${_hariBesarCustom.length} item',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._hariBesarCustom.map(_buildCustomItem),
                  ],

                  // Mendatang
                  const SizedBox(height: 16),
                  _sectionLabel('Hari Besar Mendatang'),
                  const SizedBox(height: 8),
                  ..._buildMendatang(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      // FAB tambah
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Pengingat'),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF1B5E20)));
  }

  Widget _buildTanggal(DateTime dt) {
    final nasional = _getNasionalTanggal(dt);
    final custom   = _getCustomTanggal(dt);
    final isHariIni = _isHariIni(dt);
    final isDipilih = _isDipilih(dt);
    final isMinggu  = dt.weekday == 7;
    final isLibur   = nasional.isNotEmpty;
    final hasCustom = custom.isNotEmpty;

    return GestureDetector(
      onTap: () => setState(() => _hariDipilih = dt),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isDipilih
              ? const Color(0xFF1B5E20)
              : isHariIni
                  ? const Color(0xFF1B5E20).withOpacity(0.12)
                  : null,
          shape: BoxShape.circle,
        ),
        child: Stack(
          children: [
            Center(
              child: Text('${dt.day}',
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
                  )),
            ),
            // Dot bawah
            if ((isLibur || hasCustom) && !isDipilih)
              Positioned(
                bottom: 3, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLibur)
                      Container(
                        width: 4, height: 4,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 1),
                        decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle),
                      ),
                    if (hasCustom)
                      Container(
                        width: 4, height: 4,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 1),
                        decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNasionalItem(HariBesar h) {
    final color = h.tipe == 'islam'
        ? const Color(0xFF1B5E20)
        : Colors.red[700]!;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
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
                        fontWeight: FontWeight.bold, color: color)),
                Text(
                  h.tipe == 'islam'
                      ? 'Hari Besar Islam'
                      : 'Hari Nasional',
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

  Widget _buildCustomItem(HariBesarCustom h) {
    return GestureDetector(
      onTap: () => _showForm(existing: h),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Text(h.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.nama,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                  Text(
                    h.tahunan
                        ? 'Setiap ${h.tanggalDay} ${HariBesarHelper.namaBulan(h.tanggalMonth)}'
                        : '${h.tanggalDay} ${HariBesarHelper.namaBulan(h.tanggalMonth)} ${h.tanggalYear}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.blue),
                  ),
                  if (h.catatan.isNotEmpty)
                    Text(h.catatan,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.edit, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMendatang() {
    final now       = DateTime.now();
    final nasional  = HariBesarHelper.getMendatang(now, hari: 60);
    final customAll = _hariBesarCustom.where((h) {
      final dt = DateTime(
          h.tahunan ? now.year : h.tanggalYear,
          h.tanggalMonth,
          h.tanggalDay);
      return dt.isAfter(now) &&
          dt.isBefore(now.add(const Duration(days: 60)));
    }).toList();

    // Gabung dan sort
    final semua = <Map<String, dynamic>>[];
    for (final h in nasional) {
      semua.add({'tanggal': h.tanggal, 'nama': h.nama,
                 'emoji': h.emoji ?? '📅', 'tipe': h.tipe});
    }
    for (final h in customAll) {
      final dt = DateTime(
          h.tahunan ? now.year : h.tanggalYear,
          h.tanggalMonth, h.tanggalDay);
      semua.add({'tanggal': dt, 'nama': h.nama,
                 'emoji': h.emoji, 'tipe': 'custom'});
    }
    semua.sort((a, b) =>
        (a['tanggal'] as DateTime).compareTo(b['tanggal'] as DateTime));

    if (semua.isEmpty) {
      return [
        const Text('Tidak ada hari besar dalam 60 hari ke depan',
            style: TextStyle(color: Colors.grey))
      ];
    }

    return semua.take(10).map((h) {
      final dt      = h['tanggal'] as DateTime;
      final selisih = dt.difference(now).inDays;
      final isCustom = h['tipe'] == 'custom';
      final color   = isCustom
          ? Colors.blue
          : h['tipe'] == 'islam'
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
            Text(h['emoji'] as String,
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h['nama'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Text(
                    '${HariBesarHelper.namaHari(dt)}, ${dt.day} ${HariBesarHelper.namaBulan(dt.month)}',
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