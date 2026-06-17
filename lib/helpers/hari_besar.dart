import 'package:hijri/hijri_calendar.dart';

class HariBesar {
  final String nama;
  final DateTime tanggal;
  final String tipe; // 'nasional', 'islam', 'custom'
  final String? emoji;

  HariBesar({
    required this.nama,
    required this.tanggal,
    required this.tipe,
    this.emoji,
  });
}

class HariBesarHelper {
  // ── Hari Nasional tetap ──────────────────────────────────────
  static List<HariBesar> getNasional(int tahun) {
    return [
      HariBesar(nama: 'Tahun Baru',           tanggal: DateTime(tahun, 1, 1),   tipe: 'nasional', emoji: '🎉'),
      HariBesar(nama: 'Hari Buruh',           tanggal: DateTime(tahun, 5, 1),   tipe: 'nasional', emoji: '👷'),
      HariBesar(nama: 'Hari Kebangkitan',     tanggal: DateTime(tahun, 5, 20),  tipe: 'nasional', emoji: '🇮🇩'),
      HariBesar(nama: 'Hari Pancasila',       tanggal: DateTime(tahun, 6, 1),   tipe: 'nasional', emoji: '🦅'),
      HariBesar(nama: 'Hari Kemerdekaan',     tanggal: DateTime(tahun, 8, 17),  tipe: 'nasional', emoji: '🇮🇩'),
      HariBesar(nama: 'Hari Pahlawan',        tanggal: DateTime(tahun, 11, 10), tipe: 'nasional', emoji: '⚔️'),
      HariBesar(nama: 'Hari Ibu',             tanggal: DateTime(tahun, 12, 22), tipe: 'nasional', emoji: '👩'),
      HariBesar(nama: 'Natal',                tanggal: DateTime(tahun, 12, 25), tipe: 'nasional', emoji: '🎄'),
      HariBesar(nama: 'Tahun Baru Masehi',    tanggal: DateTime(tahun, 12, 31), tipe: 'nasional', emoji: '🎆'),
      // Tambah sesuai kebutuhan
      HariBesar(nama: 'Hari Guru',            tanggal: DateTime(tahun, 11, 25), tipe: 'nasional', emoji: '👨‍🏫'),
      HariBesar(nama: 'Hari Pendidikan',      tanggal: DateTime(tahun, 5, 2),   tipe: 'nasional', emoji: '📚'),
      HariBesar(nama: 'Hari Kartini',         tanggal: DateTime(tahun, 4, 21),  tipe: 'nasional', emoji: '👩‍🎓'),
      HariBesar(nama: 'Hari Batik',           tanggal: DateTime(tahun, 10, 2),  tipe: 'nasional', emoji: '🎨'),
      HariBesar(nama: 'Hari Sumpah Pemuda',   tanggal: DateTime(tahun, 10, 28), tipe: 'nasional', emoji: '✊'),


HariBesar(nama: 'Hari Gizi Nasional', tanggal: DateTime(tahun, 1, 25), tipe: 'nasional', emoji: '🥗'),
HariBesar(nama: 'Hari Pers Nasional', tanggal: DateTime(tahun, 2, 9), tipe: 'nasional', emoji: '📰'),
HariBesar(nama: 'Hari Sampah Nasional', tanggal: DateTime(tahun, 2, 21), tipe: 'nasional', emoji: '♻️'),
HariBesar(nama: 'Hari Perempuan Internasional', tanggal: DateTime(tahun, 3, 8), tipe: 'nasional', emoji: '👩'),
HariBesar(nama: 'Hari Air Sedunia', tanggal: DateTime(tahun, 3, 22), tipe: 'nasional', emoji: '💧'),
HariBesar(nama: 'Hari Kesehatan Sedunia', tanggal: DateTime(tahun, 4, 7), tipe: 'nasional', emoji: '🏥'),
HariBesar(nama: 'Hari Bumi', tanggal: DateTime(tahun, 4, 22), tipe: 'nasional', emoji: '🌍'),
HariBesar(nama: 'Hari Buku Nasional', tanggal: DateTime(tahun, 5, 17), tipe: 'nasional', emoji: '📚'),
HariBesar(nama: 'Hari Anak Nasional', tanggal: DateTime(tahun, 7, 23), tipe: 'nasional', emoji: '🧒'),
HariBesar(nama: 'Hari Pramuka', tanggal: DateTime(tahun, 8, 14), tipe: 'nasional', emoji: '⛺'),
HariBesar(nama: 'Hari Olahraga Nasional', tanggal: DateTime(tahun, 9, 9), tipe: 'nasional', emoji: '🏆'),
HariBesar(nama: 'Hari TNI', tanggal: DateTime(tahun, 10, 5), tipe: 'nasional', emoji: '🪖'),
HariBesar(nama: 'Hari Santri Nasional', tanggal: DateTime(tahun, 10, 22), tipe: 'nasional', emoji: '🕌'),
HariBesar(nama: 'Hari Kesehatan Nasional', tanggal: DateTime(tahun, 11, 12), tipe: 'nasional', emoji: '⚕️'),
HariBesar(nama: 'Hari Korpri', tanggal: DateTime(tahun, 11, 29), tipe: 'nasional', emoji: '🏢'),

    ];
  }

  // ── Hari Islam (Hijriah → Masehi) ───────────────────────────
  static List<HariBesar> getIslam(int tahun) {
    final List<HariBesar> hasil = [];

    // Daftar hari Islam dalam kalender Hijriah
    // Format: [bulanHijri, tanggalHijri, nama, emoji]
    final islamDates = [
      [1,  1,  'Tahun Baru Hijriah',      '🌙'],
      [1,  10, 'Hari Asyura',             '🕌'],
      [3,  12, 'Maulid Nabi',             '🌟'],
      [7,  27, 'Isra Miraj',              '✨'],
      [8,  15, 'Nisfu Syaban',            '🌕'],
      [9,  1,  'Awal Ramadan',            '🌙'],
      [9,  17, 'Nuzulul Quran',           '📖'],
      [9,  21, 'Lailatul Qadar (21)',     '⭐'],
      [9,  23, 'Lailatul Qadar (23)',     '⭐'],
      [9,  25, 'Lailatul Qadar (25)',     '⭐'],
      [9,  27, 'Lailatul Qadar (27)',     '⭐'],
      [9,  29, 'Lailatul Qadar (29)',     '⭐'],
      [10, 1,  'Idul Fitri',              '🎊'],
      [10, 2,  'Idul Fitri Hari 2',       '🎊'],
      [12, 9,  'Wukuf Arafah',           '🕋'],
      [12, 10, 'Idul Adha',              '🐄'],
      [12, 11, 'Idul Adha Hari 2',       '🐄'],
      [12, 12, 'Idul Adha Hari 3',       '🐄'],

[7, 1,  'Awal Rajab',          '🌙'],
[8, 1,  'Awal Syaban',         '🌙'],
[9, 10, '10 Ramadan',          '📖'],
[9, 20, 'Malam Iktikaf',       '🕌'],
[10, 8, 'Puasa Syawal',        '🌙'],
[12, 8, 'Tarwiyah',            '🕋'],
[12, 13, 'Hari Tasyrik 3',     '🐄'],

    ];

    // Coba konversi untuk tahun ini dan tahun depan
    for (final tahunH in [
      _getMungkinTahunHijri(tahun),
      _getMungkinTahunHijri(tahun) + 1,
    ]) {
      for (final d in islamDates) {
        try {
          final hijri = HijriCalendar()
            ..hYear  = tahunH
            ..hMonth = d[0] as int
            ..hDay   = d[1] as int;
          final masehi = hijri.hijriToGregorian(
              tahunH, d[0] as int, d[1] as int);
          if (masehi.year == tahun) {
            hasil.add(HariBesar(
              nama:    d[2] as String,
              tanggal: masehi,
              tipe:    'islam',
              emoji:   d[3] as String,
            ));
          }
        } catch (_) {}
      }
    }

    return hasil;
  }

  static int _getMungkinTahunHijri(int tahunMasehi) {
    // Perkiraan kasar tahun hijriah
    return ((tahunMasehi - 622) * 1.030684).round();
  }

  // ── Semua hari besar ─────────────────────────────────────────
  static List<HariBesar> getAll(int tahun) {
    final all = [
      ...getNasional(tahun),
      ...getIslam(tahun),
    ];
    all.sort((a, b) => a.tanggal.compareTo(b.tanggal));
    return all;
  }

  // ── Hari besar pada tanggal tertentu ─────────────────────────
  static List<HariBesar> getHariIni(DateTime tanggal) {
    return getAll(tanggal.year).where((h) =>
        h.tanggal.day   == tanggal.day &&
        h.tanggal.month == tanggal.month &&
        h.tanggal.year  == tanggal.year).toList();
  }

  // ── Hari besar mendatang (N hari ke depan) ───────────────────
  static List<HariBesar> getMendatang(DateTime dari, {int hari = 30}) {
    final batas = dari.add(Duration(days: hari));
    return getAll(dari.year).where((h) =>
        h.tanggal.isAfter(dari) &&
        h.tanggal.isBefore(batas)).toList()
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
  }

  // ── Format nama hari ─────────────────────────────────────────
  static String namaHari(DateTime dt) {
    const hari = ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
    return hari[dt.weekday - 1];
  }

  static String namaBulan(int bulan) {
    const bulan0 = ['','Januari','Februari','Maret','April','Mei','Juni',
                    'Juli','Agustus','September','Oktober','November','Desember'];
    return bulan0[bulan];
  }

  static String namaBulanHijri(int bulan) {
    const bulan0 = ['','Muharrom','Safar','Robiul Awal','Robiul Akhir',
                    'Jumadil Awal','Jumadil Akhir','Rojab','Syaban',
                    'Ramadan','Syawal','Dzulqodah','Dzulhijjah'];
    return bulan0[bulan];
  }

// ── Hari Pasaran Jawa ────────────────────────────────────────
static const List<String> _pasaran = [
  'Manis', 'Pahing', 'Pon', 'Wage', 'Kliwon', 
];

static String hariPasaran(DateTime dt) {
  // Epoch 1 Januari 1970 = Wage (index 3)
  // Siklus 5 hari
  final epoch    = DateTime(1970, 1, 1);
  final selisih  = dt.difference(epoch).inDays;
  final index    = (selisih + 3) % 5; // +3 karena 1 Jan 1970 = Wage
  return _pasaran[index];
}

static String hariLengkap(DateTime dt) {
  return '${namaHari(dt)} ${hariPasaran(dt)}';
}


  // ── Konversi ke Hijriah ──────────────────────────────────────
  static String toHijriah(DateTime dt) {
    try {
      final h = HijriCalendar.fromDate(dt);
      return '${h.hDay} ${namaBulanHijri(h.hMonth)} ${h.hYear} H';
    } catch (_) {
      return '-';
    }
  }

  static HijriCalendar toHijriCalendar(DateTime dt) {
    return HijriCalendar.fromDate(dt);
  }
}