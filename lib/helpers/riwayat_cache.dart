import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class RiwayatCache {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'riwayat_cache.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE riwayat (
            id TEXT PRIMARY KEY,
            id_pegawai TEXT,
            tanggal_masuk TEXT,
            jam_masuk TEXT,
            foto_masuk TEXT,
            tanggal_keluar TEXT,
            jam_keluar TEXT,
            foto_keluar TEXT,
            created_at TEXT,
            updated_at TEXT,
            cached_at INTEGER
          )
        ''');
      },
    );
  }

  // Simpan list ke cache
  static Future<void> saveAll(List<Map<String, dynamic>> list) async {
    final database = await db;
    final batch = database.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final item in list) {
      batch.insert(
        'riwayat',
        {
          'id':              item['id']?.toString() ?? '',
          'id_pegawai':      item['id_pegawai']?.toString() ?? '',
          'tanggal_masuk':   item['tanggal_masuk'] ?? '',
          'jam_masuk':       item['jam_masuk'] ?? '',
          'foto_masuk':      item['foto_masuk'] ?? '',
          'tanggal_keluar':  item['tanggal_keluar'] ?? '',
          'jam_keluar':      item['jam_keluar'] ?? '',
          'foto_keluar':     item['foto_keluar'] ?? '',
          'created_at':      item['created_at'] ?? '',
          'updated_at':      item['updated_at'] ?? '',
          'cached_at':       now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Ambil semua dari cache
  static Future<List<Map<String, dynamic>>> getAll() async {
    final database = await db;
    return database.query('riwayat', orderBy: 'tanggal_masuk DESC');
  }

  // Cek apakah cache ada
  static Future<bool> hasCache() async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM riwayat');
    return (result.first['cnt'] as int) > 0;
  }

  // Hapus semua cache
  static Future<void> clearAll() async {
    final database = await db;
    await database.delete('riwayat');
  }

  // Waktu cache terakhir
  static Future<DateTime?> lastCached() async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT MAX(cached_at) as last FROM riwayat');
    final last = result.first['last'];
    if (last == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(last as int);
  }
}