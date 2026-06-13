import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class HariBesarCustom {
  final int?   id;
  final String nama;
  final String emoji;
  final int    tanggalDay;
  final int    tanggalMonth;
  final int    tanggalYear; // 0 = tahunan
  final String catatan;
  final bool   tahunan; // ulang tahun tiap tahun

  HariBesarCustom({
    this.id,
    required this.nama,
    required this.emoji,
    required this.tanggalDay,
    required this.tanggalMonth,
    required this.tanggalYear,
    this.catatan = '',
    this.tahunan = false,
  });

  Map<String, dynamic> toMap() => {
    'id':            id,
    'nama':          nama,
    'emoji':         emoji,
    'tanggal_day':   tanggalDay,
    'tanggal_month': tanggalMonth,
    'tanggal_year':  tanggalYear,
    'catatan':       catatan,
    'tahunan':       tahunan ? 1 : 0,
  };

  factory HariBesarCustom.fromMap(Map<String, dynamic> m) =>
      HariBesarCustom(
        id:           m['id'],
        nama:         m['nama'],
        emoji:        m['emoji'] ?? '📅',
        tanggalDay:   m['tanggal_day'],
        tanggalMonth: m['tanggal_month'],
        tanggalYear:  m['tanggal_year'],
        catatan:      m['catatan'] ?? '',
        tahunan:      m['tahunan'] == 1,
      );

  // Cocok dengan tanggal tertentu?
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
    return openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE hari_besar (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          nama          TEXT NOT NULL,
          emoji         TEXT DEFAULT "📅",
          tanggal_day   INTEGER NOT NULL,
          tanggal_month INTEGER NOT NULL,
          tanggal_year  INTEGER NOT NULL,
          catatan       TEXT DEFAULT "",
          tahunan       INTEGER DEFAULT 0
        )
      ''');
    });
  }

  static Future<List<HariBesarCustom>> getAll() async {
    final database = await db;
    final rows = await database.query('hari_besar',
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

  static Future<void> delete(int id) async {
    final database = await db;
    await database.delete('hari_besar',
        where: 'id = ?', whereArgs: [id]);
  }
}