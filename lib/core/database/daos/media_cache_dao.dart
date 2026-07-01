import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class MediaCacheDao {
  Future<Database> get db async => await AppDatabase.instance.database;

  Future<void> insertMedia(Map<String, dynamic> mediaRow) async {
    final database = await db;
    await database.insert(
      'media_cache',
      mediaRow,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getMediaByUrl(String url) async {
    final database = await db;
    final results = await database.query(
      'media_cache',
      where: 'url = ?',
      whereArgs: [url],
      limit: 1,
    );
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<void> deleteMedia(String url) async {
    final database = await db;
    await database.delete(
      'media_cache',
      where: 'url = ?',
      whereArgs: [url],
    );
  }
}
