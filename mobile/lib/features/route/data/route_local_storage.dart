import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sayurpintar/core/storage/database_helper.dart';
import 'package:sayurpintar/features/route/data/route_repository.dart';

// ──────────────────────────────────────────────
// Offline Action model
// ──────────────────────────────────────────────

class OfflineAction {
  final String id;
  final String type; // 'add_waypoint', 'mark_visited', 'mark_completed'
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;

  OfflineAction({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  factory OfflineAction.fromMap(Map<String, dynamic> map) {
    return OfflineAction(
      id: map['id'] as String,
      type: map['type'] as String,
      data: jsonDecode(map['data'] as String) as Map<String, dynamic>,
      createdAt: DateTime.parse(map['created_at'] as String),
      retryCount: map['retry_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'data': jsonEncode(data),
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
    };
  }
}

// ──────────────────────────────────────────────
// Local Storage
// ──────────────────────────────────────────────

class RouteLocalStorage {
  final DatabaseHelper _db;
  final _uuid = const Uuid();

  RouteLocalStorage(this._db);

  // Ensure tables exist (for migration from older DB versions)
  Future<void> _ensureTables() async {
    final db = await _db.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_waypoints (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_routes (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_visits (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_actions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');
  }

  // ── Waypoints Cache ──────────────────────────

  Future<void> cacheWaypoints(List<Waypoint> waypoints) async {
    await _ensureTables();
    final db = await _db.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    // Clear old cache
    batch.delete('cached_waypoints');

    for (final wp in waypoints) {
      batch.insert('cached_waypoints', {
        'id': wp.id,
        'data': jsonEncode(wp.toJson()),
        'cached_at': now,
      });
    }

    await batch.commit(noResult: true);
  }

  Future<List<Waypoint>> getCachedWaypoints() async {
    await _ensureTables();
    final db = await _db.database;
    final rows = await db.query('cached_waypoints', orderBy: 'cached_at DESC');

    return rows.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return Waypoint.fromJson(data);
    }).toList();
  }

  Future<void> cacheWaypoint(Waypoint wp) async {
    await _ensureTables();
    final db = await _db.database;
    await db.insert(
      'cached_waypoints',
      {
        'id': wp.id,
        'data': jsonEncode(wp.toJson()),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeCachedWaypoint(String id) async {
    final db = await _db.database;
    await db.delete('cached_waypoints', where: 'id = ?', whereArgs: [id]);
  }

  // ── Today's Route Cache ──────────────────────

  Future<void> cacheTodayRoute(RouteModel route) async {
    await _ensureTables();
    final db = await _db.database;
    await db.insert(
      'cached_routes',
      {
        'id': 'today',
        'data': jsonEncode(route.toJson()),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<RouteModel?> getCachedTodayRoute() async {
    await _ensureTables();
    final db = await _db.database;
    final rows = await db.query(
      'cached_routes',
      where: 'id = ?',
      whereArgs: ['today'],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final data =
        jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
    return RouteModel.fromJson(data);
  }

  // ── Visits Cache ─────────────────────────────

  Future<void> cacheVisits(List<Visit> visits) async {
    await _ensureTables();
    final db = await _db.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    batch.delete('cached_visits');

    for (final visit in visits) {
      batch.insert('cached_visits', {
        'id': visit.id,
        'data': jsonEncode(visit.toJson()),
        'cached_at': now,
      });
    }

    await batch.commit(noResult: true);
  }

  Future<List<Visit>> getCachedVisits() async {
    await _ensureTables();
    final db = await _db.database;
    final rows = await db.query('cached_visits', orderBy: 'cached_at DESC');

    return rows.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return Visit.fromJson(data);
    }).toList();
  }

  // ── Offline Action Queue ─────────────────────

  Future<void> queueAction(OfflineAction action) async {
    await _ensureTables();
    final db = await _db.database;
    await db.insert('offline_actions', action.toMap());
  }

  Future<List<OfflineAction>> getPendingActions() async {
    await _ensureTables();
    final db = await _db.database;
    final rows = await db.query(
      'offline_actions',
      orderBy: 'created_at ASC',
    );

    return rows.map((row) => OfflineAction.fromMap(row)).toList();
  }

  Future<void> clearAction(String id) async {
    final db = await _db.database;
    await db.delete('offline_actions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetry(String id) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE offline_actions SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  /// Create a new offline action with a generated UUID
  OfflineAction createAction(
    String type,
    Map<String, dynamic> data,
  ) {
    return OfflineAction(
      id: _uuid.v4(),
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );
  }
}
