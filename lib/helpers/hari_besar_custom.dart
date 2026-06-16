import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class HariBesarCustom {
  final int?   id;
  final String nama;
  final String emoji;
  final int    tanggalDay;
  final int    tanggalMonth;
  final int    tanggalYear;
  final String catatan;
  final bool   tahunan;
  final bool   isPublik;
  final int?   serverId; // id di tabel pengumuman server

  HariBesarCustom({
    this.id,
    required this.nama,
    required this.emoji,
    required this.tanggalDay,
    required this.tanggalMonth,
    required this.tanggalYear,
    this.catatan   = '',
    this.tahunan   = false,
    this.isPublik  = false,
    this.serverId,
  });

  Map<String, dynamic> toMap() => {
    'id':            id,
    'nama':          nama,
    'emoji':         emoji,
    'tanggal_day':   tanggalDay,
    'tanggal_month': tanggalMonth,
    'tanggal_year':  tanggalYear,
    'catatan':       catatan,
    'tahunan':       tahunan   ? 1 : 0,
    'is_publik':     isPublik  ? 1 : 0,
    'server_id':     serverId,
  };

  factory HariBesarCustom.fromMap(Map<String, dynamic> m) =>
      HariBesarCustom(
        id:           m['id'],
        nama:         m['nama'],
        emoji:        m['emoji'] ?? '📅',
        tanggalDay:   m['tanggal_day'],
        tanggalMonth: m['tanggal_month'],
        tanggalYear:  m['tanggal_year'],
        catatan:      m['catatan']   ?? '',
        tahunan:      m['tahunan']   == 1,
        isPublik:     m['is_publik'] == 1,
        serverId:     m['server_id'],
      );

  // Dari data pengumuman server
  factory HariBesarCustom.fromServer(Map<String, dynamic> j) {
    final tgl = j['tanggal_event'] != null
        ? DateTime.tryParse(j['tanggal_event'])
        : null;
    return HariBesarCustom(
      nama:         j['judul']        ?? '',
      emoji:        j['emoji']        ?? '📅',
      tanggalDay:   tgl?.day          ?? 1,
      tanggalMonth: tgl?.month        ?? 1,
      tanggalYear:  tgl?.year         ?? DateTime.now().year,
      catatan:      j['isi']          ?? '',
      tahunan:      false,
      isPublik:     true,
      serverId:     int.tryParse(j['id'].toString()),
    );
  }

  bool cocokDengan(DateTime dt) {
    if (tahunan) {
      return tanggalDay == dt.day && tanggalMonth == dt.month;
    }
    return tanggalDay   == dt.day   &&
           tanggalMonth == dt.month &&
           tanggalYear  == dt.year;
  }
}

class HariBesarCustomDb {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = p.join(await getDatabasesPath(), 'hari_besar_custom.db');
    return openDatabase(
      path,
      version: 2, // naik versi
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE hari_besar (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            nama          TEXT NOT NULL,
            emoji         TEXT DEFAULT "📅",
            tanggal_day   INTEGER NOT NULL,
            tanggal_month INTEGER NOT NULL,
            tanggal_year  INTEGER NOT NULL,
            catatan       TEXT DEFAULT "",
            tahunan       INTEGER DEFAULT 0,
            is_publik     INTEGER DEFAULT 0,
            server_id     INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE hari_besar ADD COLUMN is_publik INTEGER DEFAULT 0');
          await db.execute(
              'ALTER TABLE hari_besar ADD COLUMN server_id INTEGER');
        }
      },
    );
  }

  static Future<List<HariBesarCustom>> getAll() async {
    final database = await db;
    final rows = await database.query('hari_besar',
        orderBy: 'tanggal_month, tanggal_day');
    return rows.map(HariBesarCustom.fromMap).toList();
  }

  static Future<List<HariBesarCustom>> getPrivat() async {
    final database = await db;
    final rows = await database.query('hari_besar',
        where: 'is_publik = 0',
        orderBy: 'tanggal_month, tanggal_day');
    return rows.map(HariBesarCustom.fromMap).toList();
  }

  static Future<List<HariBesarCustom>> getByTanggal(DateTime dt) async {
    final all = await getAll();
    return all.where((h) => h.cocokDengan(dt)).toList();
  }

  static Future<void> save(HariBesarCustom h) async {
    final database = await db;
    if (h.id == null) {
      await database.insert('hari_besar', h.toMap()..remove('id'));
    } else {
      await database.update('hari_besar', h.toMap(),
          where: 'id = ?', whereArgs: [h.id]);
    }
  }

  // Simpan list publik dari server (replace semua)
  static Future<void> savePublikFromServer(
      List<HariBesarCustom> list) async {
    final database = await db;
    await database.delete('hari_besar', where: 'is_publik = 1');
    final batch = database.batch();
    for (final h in list) {
      batch.insert('hari_besar', h.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  static Future<void> delete(int id) async {
    final database = await db;
    final row = await database.query('hari_besar',
        where: 'id = ?', whereArgs: [id]);
    if (row.isNotEmpty) {
      final h = HariBesarCustom.fromMap(row.first);
      // Kalau publik, hapus juga dari server
      if (h.isPublik && h.serverId != null) {
        // handle di caller
      }
    }
    await database.delete('hari_besar',
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> clearAll() async {
    final database = await db;
    await database.delete('hari_besar');
  }
}