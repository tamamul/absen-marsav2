import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppCacheManager {
  // Auto cleanup: hapus cache foto lebih dari N hari
  static const int _maxCacheAgeDays = 7;

  // ── Hapus cache foto lama via CachedNetworkImage ────────────
  static Future<void> clearOldImageCache() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
  }

  // ── Hapus cache foto lebih dari 7 hari ───────────────────────
  static Future<Map<String, dynamic>> cleanOldCache() async {
    int hapusData  = 0;
    int hapusFoto  = 0;
    double sizeMb  = 0;

    try {
      // Hapus data DB galeri > 7 hari
      final database = await _getDb();
      final batas = DateTime.now()
          .subtract(Duration(days: _maxCacheAgeDays))
          .millisecondsSinceEpoch;

      final old = await database.query('galeri',
          where: 'cached_at < ?', whereArgs: [batas]);
      hapusData = old.length;

      await database.delete('galeri',
          where: 'cached_at < ?', whereArgs: [batas]);

      // Hapus cache foto (CachedNetworkImage store)
      final cacheDir = await getTemporaryDirectory();
      final cacheFolder = Directory(
          p.join(cacheDir.path, 'libCachedImageData'));
      if (await cacheFolder.exists()) {
        final files = cacheFolder.listSync();
        for (final f in files) {
          if (f is File) {
            final stat = await f.stat();
            final age  = DateTime.now().difference(stat.modified).inDays;
            if (age > _maxCacheAgeDays) {
              sizeMb += stat.size / 1024 / 1024;
              await f.delete();
              hapusFoto++;
            }
          }
        }
      }
    } catch (_) {}

    return {
      'hapus_data': hapusData,
      'hapus_foto': hapusFoto,
      'size_mb':    sizeMb,
    };
  }

  // ── Hitung ukuran cache foto ─────────────────────────────────
  static Future<double> getCacheSizeMb() async {
    double total = 0;
    try {
      final cacheDir    = await getTemporaryDirectory();
      final cacheFolder = Directory(
          p.join(cacheDir.path, 'libCachedImageData'));
      if (await cacheFolder.exists()) {
        final files = cacheFolder.listSync();
        for (final f in files) {
          if (f is File) {
            final stat = await f.stat();
            total += stat.size / 1024 / 1024;
          }
        }
      }
    } catch (_) {}
    return total;
  }

  // ── Hapus semua cache foto ───────────────────────────────────
  static Future<void> clearAllImageCache() async {
  try {
    await DefaultCacheManager().emptyCache();
  } catch (_) {}
}

  // ── Auto cleanup saat app dibuka ────────────────────────────
  // Panggil di main.dart atau initState dashboard
  static Future<void> autoCleanup() async {
    try {
      final prefs = await _getPrefs();
      final lastClean = prefs['last_cleanup'] as int? ?? 0;
      final now       = DateTime.now().millisecondsSinceEpoch;
      // Jalankan cleanup max 1x per hari
      if (now - lastClean > 86400000) {
        await cleanOldCache();
        await _saveLastClean(now);
      }
    } catch (_) {}
  }

  static Future<Database> _getDb() async {
    final path = p.join(await getDatabasesPath(), 'galeri_cache.db');
    return openDatabase(path);
  }

  static Future<Map<String, dynamic>> _getPrefs() async {
    final path = p.join(await getDatabasesPath(), 'app_prefs.db');
    final db   = await openDatabase(path, version: 1,
        onCreate: (db, _) async {
          await db.execute(
              'CREATE TABLE prefs (key TEXT PRIMARY KEY, value TEXT)');
        });
    final rows = await db.query('prefs',
        where: 'key = ?', whereArgs: ['last_cleanup']);
    if (rows.isEmpty) return {};
    return {'last_cleanup': int.tryParse(rows.first['value'] as String)};
  }

  static Future<void> _saveLastClean(int timestamp) async {
    final path = p.join(await getDatabasesPath(), 'app_prefs.db');
    final db   = await openDatabase(path);
    await db.insert(
      'prefs',
      {'key': 'last_cleanup', 'value': timestamp.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}