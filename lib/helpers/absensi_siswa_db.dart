import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

// ── Models ────────────────────────────────────────────────────

class Kelas {
  final int?   id;
  final String namaKelas;
  final String waliKelas;

  Kelas({this.id, required this.namaKelas, required this.waliKelas});

  Map<String, dynamic> toMap() => {
    'id':         id,
    'nama_kelas': namaKelas,
    'wali_kelas': waliKelas,
  };

  factory Kelas.fromMap(Map<String, dynamic> m) => Kelas(
    id:        m['id'],
    namaKelas: m['nama_kelas'],
    waliKelas: m['wali_kelas'] ?? '',
  );
}

class Siswa {
  final int?   id;
  final int    idKelas;
  final String nama;
  final String nis;
  final int    urutan;

  Siswa({
    this.id,
    required this.idKelas,
    required this.nama,
    required this.nis,
    this.urutan = 0,
  });

  Map<String, dynamic> toMap() => {
    'id':       id,
    'id_kelas': idKelas,
    'nama':     nama,
    'nis':      nis,
    'urutan':   urutan,
  };

  factory Siswa.fromMap(Map<String, dynamic> m) => Siswa(
    id:      m['id'],
    idKelas: m['id_kelas'],
    nama:    m['nama'],
    nis:     m['nis'] ?? '',
    urutan:  m['urutan'] ?? 0,
  );
}

class AbsensiSiswa {
  final int?   id;
  final int    idSiswa;
  final int    idKelas;
  final String tanggal;
  final String status; // hadir, sakit, izin, alpha
  final String keterangan;

  AbsensiSiswa({
    this.id,
    required this.idSiswa,
    required this.idKelas,
    required this.tanggal,
    required this.status,
    this.keterangan = '',
  });

  Map<String, dynamic> toMap() => {
    'id':          id,
    'id_siswa':    idSiswa,
    'id_kelas':    idKelas,
    'tanggal':     tanggal,
    'status':      status,
    'keterangan':  keterangan,
  };

  factory AbsensiSiswa.fromMap(Map<String, dynamic> m) => AbsensiSiswa(
    id:          m['id'],
    idSiswa:     m['id_siswa'],
    idKelas:     m['id_kelas'],
    tanggal:     m['tanggal'],
    status:      m['status'],
    keterangan:  m['keterangan'] ?? '',
  );
}

// ── Database ──────────────────────────────────────────────────

class AbsensiSiswaDb {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = p.join(await getDatabasesPath(), 'absensi_siswa.db');
    return openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE kelas (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          nama_kelas TEXT NOT NULL,
          wali_kelas TEXT DEFAULT ""
        )
      ''');
      await db.execute('''
        CREATE TABLE siswa (
          id       INTEGER PRIMARY KEY AUTOINCREMENT,
          id_kelas INTEGER NOT NULL,
          nama     TEXT NOT NULL,
          nis      TEXT DEFAULT "",
          urutan   INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE absensi (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          id_siswa    INTEGER NOT NULL,
          id_kelas    INTEGER NOT NULL,
          tanggal     TEXT NOT NULL,
          status      TEXT NOT NULL,
          keterangan  TEXT DEFAULT "",
          UNIQUE(id_siswa, tanggal)
        )
      ''');
    });
  }

  // ── Kelas ──────────────────────────────────────────────────
  static Future<List<Kelas>> getAllKelas() async {
    final database = await db;
    final rows = await database.query('kelas', orderBy: 'nama_kelas');
    return rows.map(Kelas.fromMap).toList();
  }

  static Future<void> saveKelas(Kelas k) async {
    final database = await db;
    if (k.id == null) {
      await database.insert('kelas', k.toMap()..remove('id'));
    } else {
      await database.update('kelas', k.toMap(),
          where: 'id = ?', whereArgs: [k.id]);
    }
  }

  static Future<void> deleteKelas(int id) async {
    final database = await db;
    await database.delete('kelas', where: 'id = ?', whereArgs: [id]);
    await database.delete('siswa', where: 'id_kelas = ?', whereArgs: [id]);
    await database.delete('absensi', where: 'id_kelas = ?', whereArgs: [id]);
  }

  // ── Siswa ──────────────────────────────────────────────────
  static Future<List<Siswa>> getSiswaByKelas(int idKelas) async {
    final database = await db;
    final rows = await database.query('siswa',
        where: 'id_kelas = ?',
        whereArgs: [idKelas],
        orderBy: 'urutan, nama');
    return rows.map(Siswa.fromMap).toList();
  }

  static Future<void> saveSiswa(Siswa s) async {
    final database = await db;
    if (s.id == null) {
      await database.insert('siswa', s.toMap()..remove('id'));
    } else {
      await database.update('siswa', s.toMap(),
          where: 'id = ?', whereArgs: [s.id]);
    }
  }

  static Future<void> deleteSiswa(int id) async {
    final database = await db;
    await database.delete('siswa', where: 'id = ?', whereArgs: [id]);
    await database.delete('absensi',
        where: 'id_siswa = ?', whereArgs: [id]);
  }

  // ── Absensi ────────────────────────────────────────────────
  static Future<List<AbsensiSiswa>> getAbsensi(
      int idKelas, String tanggal) async {
    final database = await db;
    final rows = await database.query('absensi',
        where: 'id_kelas = ? AND tanggal = ?',
        whereArgs: [idKelas, tanggal]);
    return rows.map(AbsensiSiswa.fromMap).toList();
  }

  static Future<void> saveAbsensi(AbsensiSiswa a) async {
    final database = await db;
    await database.insert(
      'absensi',
      a.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> saveAbsensiBatch(
      List<AbsensiSiswa> list) async {
    final database = await db;
    final batch = database.batch();
    for (final a in list) {
      batch.insert(
        'absensi',
        a.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Rekap per kelas per tanggal
  static Future<Map<String, int>> getRekap(
      int idKelas, String tanggal) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT status, COUNT(*) as jumlah
      FROM absensi
      WHERE id_kelas = ? AND tanggal = ?
      GROUP BY status
    ''', [idKelas, tanggal]);

    final Map<String, int> rekap = {
      'hadir': 0, 'sakit': 0, 'izin': 0, 'alpha': 0
    };
    for (final r in rows) {
      rekap[r['status'] as String] = r['jumlah'] as int;
    }
    return rekap;
  }

  // Rekap bulanan siswa
  static Future<Map<String, int>> getRekapSiswa(
      int idSiswa, String bulan) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT status, COUNT(*) as jumlah
      FROM absensi
      WHERE id_siswa = ? AND tanggal LIKE ?
      GROUP BY status
    ''', [idSiswa, '$bulan%']);

    final Map<String, int> rekap = {
      'hadir': 0, 'sakit': 0, 'izin': 0, 'alpha': 0
    };
    for (final r in rows) {
      rekap[r['status'] as String] = r['jumlah'] as int;
    }
    return rekap;
  }

  // Riwayat absensi siswa
  static Future<List<AbsensiSiswa>> getRiwayatSiswa(
      int idSiswa, {int limit = 30}) async {
    final database = await db;
    final rows = await database.query('absensi',
        where: 'id_siswa = ?',
        whereArgs: [idSiswa],
        orderBy: 'tanggal DESC',
        limit: limit);
    return rows.map(AbsensiSiswa.fromMap).toList();
  }
}