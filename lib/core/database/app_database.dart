import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pilach.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE chats ADD COLUMN other_user_id TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE messages ADD COLUMN reactions_json TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE chats ADD COLUMN is_online INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE chats ADD COLUMN last_active_at TEXT');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE messages ADD COLUMN reply_to_json TEXT');
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT,
        avatar_url TEXT,
        avatar_local_path TEXT,
        other_user_id TEXT,
        unread_count INTEGER DEFAULT 0,
        last_message_seq INTEGER DEFAULT 0,
        last_message_preview TEXT,
        last_message_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_pinned INTEGER DEFAULT 0,
        is_muted INTEGER DEFAULT 0,
        is_online INTEGER DEFAULT 0,
        last_active_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        client_msg_id TEXT UNIQUE,
        conversation_id TEXT NOT NULL,
        seq INTEGER,
        sender_id TEXT NOT NULL,
        type TEXT NOT NULL,
        text TEXT,
        attachments_json TEXT,
        reactions_json TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        edited_at TEXT,
        deleted INTEGER DEFAULT 0,
        reply_to_id TEXT,
        reply_to_json TEXT
      )
    ''');
    
    await db.execute('CREATE INDEX idx_messages_conv_seq ON messages(conversation_id, seq)');

    await db.execute('''
      CREATE TABLE outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_msg_id TEXT NOT NULL,
        conversation_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        attempt_count INTEGER DEFAULT 0,
        next_retry_at TEXT,
        last_error TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE media_cache (
        url TEXT PRIMARY KEY,
        local_path TEXT NOT NULL,
        mime_type TEXT,
        size_bytes INTEGER,
        downloaded_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_state (
        conversation_id TEXT PRIMARY KEY,
        oldest_synced_seq INTEGER,
        newest_synced_seq INTEGER,
        last_synced_at TEXT
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
