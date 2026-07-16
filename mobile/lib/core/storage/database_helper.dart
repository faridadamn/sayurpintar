import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sayurpintar.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE waypoints (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        type TEXT DEFAULT 'custom',
        notes TEXT,
        sequence INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE routes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        status TEXT DEFAULT 'planned',
        total_distance REAL,
        estimated_time INTEGER,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE offline_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        method TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        body TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE offline_actions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        failed INTEGER DEFAULT 0
      )
    ''');
  }

  // Waypoints CRUD
  Future<int> insertWaypoint(Map<String, dynamic> waypoint) async {
    final db = await database;
    return await db.insert('waypoints', waypoint);
  }

  Future<List<Map<String, dynamic>>> getWaypoints(String userId) async {
    final db = await database;
    return await db.query(
      'waypoints',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'sequence ASC',
    );
  }

  Future<int> updateWaypoint(Map<String, dynamic> waypoint) async {
    final db = await database;
    return await db.update(
      'waypoints',
      waypoint,
      where: 'id = ?',
      whereArgs: [waypoint['id']],
    );
  }

  Future<int> deleteWaypoint(String id) async {
    final db = await database;
    return await db.delete('waypoints', where: 'id = ?', whereArgs: [id]);
  }

  // Routes CRUD
  Future<int> insertRoute(Map<String, dynamic> route) async {
    final db = await database;
    return await db.insert('routes', route);
  }

  Future<List<Map<String, dynamic>>> getRoutes(String userId) async {
    final db = await database;
    return await db.query(
      'routes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  // Offline queue
  Future<int> enqueue(String method, String endpoint, String? body) async {
    final db = await database;
    return await db.insert('offline_queue', {
      'method': method,
      'endpoint': endpoint,
      'body': body,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    final db = await database;
    return await db.query(
      'offline_queue',
      where: 'synced = 0',
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markSynced(int id) async {
    final db = await database;
    await db.update(
      'offline_queue',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Offline actions (new sync system)
  Future<int> insertAction(Map<String, dynamic> action) async {
    final db = await database;
    return await db.insert('offline_actions', action);
  }

  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final db = await database;
    return await db.query(
      'offline_actions',
      where: 'failed = 0',
      orderBy: 'created_at ASC',
    );
  }

  Future<void> deleteAction(String id) async {
    final db = await database;
    await db.delete('offline_actions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateActionRetry(String id, int retryCount) async {
    final db = await database;
    await db.update(
      'offline_actions',
      {'retry_count': retryCount},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markActionFailed(String id) async {
    final db = await database;
    await db.update(
      'offline_actions',
      {'failed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
