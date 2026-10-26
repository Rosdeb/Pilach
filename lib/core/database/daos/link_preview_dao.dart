import 'package:sqflite/sqflite.dart';

import '../app_database.dart';

class LinkPreviewDao {
  Future<Database> get db => AppDatabase.instance.database;

  Future<Map<String, dynamic>?> getByUrl(String url) async {
    final database = await db;
    final rows = await database.query(
      'link_previews',
      where: 'url = ?',
      whereArgs: [url],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> save(Map<String, dynamic> row) async {
    final database = await db;
    await database.insert(
      'link_previews',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
