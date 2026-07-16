import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:sayurpintar/core/network/api_client.dart';
import 'package:sayurpintar/core/network/api_endpoints.dart';
import 'package:sayurpintar/core/storage/database_helper.dart';
import 'package:sayurpintar/core/utils/connectivity_service.dart';

// ─── Offline Action Model ───────────────────────────

class OfflineAction {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;
  bool failed;

  OfflineAction({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.failed = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'data': data,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'failed': failed ? 1 : 0,
      };

  factory OfflineAction.fromMap(Map<String, dynamic> map) => OfflineAction(
        id: map['id'] as String,
        type: map['type'] as String,
        data: Map<String, dynamic>.from(map['data'] as Map),
        createdAt: DateTime.parse(map['created_at'] as String),
        retryCount: map['retry_count'] as int? ?? 0,
        failed: (map['failed'] as int? ?? 0) == 1,
      );
}

// ─── Sync Result ────────────────────────────────────

class SyncResult {
  final bool offline;
  final int synced;
  final int failed;
  final List<String> failedIds;

  const SyncResult({
    this.offline = false,
    this.synced = 0,
    this.failed = 0,
    this.failedIds = const [],
  });

  @override
  String toString() =>
      'SyncResult(offline: $offline, synced: $synced, failed: $failed)';
}

// ─── Sync Manager ───────────────────────────────────

class SyncManager {
  static SyncManager? _instance;
  static const _uuid = Uuid();
  static const int maxRetries = 3;

  final DatabaseHelper _db = DatabaseHelper();
  final ConnectivityService _connectivity = ConnectivityService();

  bool _isSyncing = false;
  StreamSubscription<bool>? _connectivitySub;
  final StreamController<SyncResult> _syncResultController =
      StreamController<SyncResult>.broadcast();

  SyncManager._();

  factory SyncManager() {
    _instance ??= SyncManager._();
    return _instance!;
  }

  /// Stream of sync results for UI observation.
  Stream<SyncResult> get onSyncResult => _syncResultController.stream;

  /// Whether a sync is currently in progress.
  bool get isSyncing => _isSyncing;

  // ─── Queue an action for later sync ──────────────

  Future<void> queueAction(
    String type,
    Map<String, dynamic> data,
  ) async {
    final action = OfflineAction(
      id: _uuid.v4(),
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );
    await _insertAction(action);
  }

  // ─── Sync all pending actions when online ────────

  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      return const SyncResult();
    }

    final connected = await _connectivity.isConnected;
    if (!connected) {
      return const SyncResult(offline: true);
    }

    _isSyncing = true;
    int synced = 0;
    int failed = 0;
    final failedIds = <String>[];

    try {
      final actions = await _getPendingActions();

      for (final action in actions) {
        try {
          await _executeAction(action);
          await _deleteAction(action.id);
          synced++;
        } catch (e) {
          action.retryCount++;
          if (action.retryCount >= maxRetries) {
            action.failed = true;
            await _markActionFailed(action.id);
            failed++;
            failedIds.add(action.id);
          } else {
            await _updateAction(action);
          }
        }
      }

      final result = SyncResult(
        offline: false,
        synced: synced,
        failed: failed,
        failedIds: failedIds,
      );

      _syncResultController.add(result);
      return result;
    } finally {
      _isSyncing = false;
    }
  }

  // ─── Execute individual action based on type ─────

  Future<void> _executeAction(OfflineAction action) async {
    final dio = ApiClient().dio;

    switch (action.type) {
      case 'add_waypoint':
        await dio.post(
          ApiEndpoints.waypoints,
          data: action.data,
        );
        break;

      case 'update_waypoint':
        final id = action.data['id'];
        await dio.put(
          '${ApiEndpoints.waypoints}/$id',
          data: action.data,
        );
        break;

      case 'delete_waypoint':
        final id = action.data['id'];
        await dio.delete('${ApiEndpoints.waypoints}/$id');
        break;

      case 'mark_visited':
        final visitId = action.data['visit_id'];
        await dio.post(
          '${ApiEndpoints.todayVisits}/$visitId/arrive',
          data: action.data,
        );
        break;

      case 'mark_completed':
        final visitId = action.data['visit_id'];
        await dio.post(
          '${ApiEndpoints.todayVisits}/$visitId/complete',
          data: action.data,
        );
        break;

      case 'skip_visit':
        final visitId = action.data['visit_id'];
        await dio.post(
          '${ApiEndpoints.todayVisits}/$visitId/skip',
          data: action.data,
        );
        break;

      case 'update_location':
        // Skip — latest location will be sent on next update.
        // Delete the action immediately.
        break;

      case 'start_route':
        await dio.post(ApiEndpoints.startRoute, data: action.data);
        break;

      case 'complete_route':
        await dio.post(ApiEndpoints.completeRoute, data: action.data);
        break;

      default:
        // Unknown action type — delete it to avoid infinite retry.
        break;
    }
  }

  // ─── Listen to connectivity changes and auto-sync ─

  void listenAndAutoSync() {
    _connectivitySub?.cancel();
    _connectivitySub =
        _connectivity.onConnectivityChanged.listen((connected) {
      if (connected && !_isSyncing) {
        syncAll();
      }
    });
  }

  // ─── Stop listening ──────────────────────────────

  void stopListening() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // ─── Database helpers for the action queue ───────

  Future<void> _insertAction(OfflineAction action) async {
    final db = await _db.database;
    await db.insert('offline_actions', {
      'id': action.id,
      'type': action.type,
      'data': action.data.toString(), // JSON-encoded
      'created_at': action.createdAt.toIso8601String(),
      'retry_count': action.retryCount,
      'failed': action.failed ? 1 : 0,
    });
  }

  Future<List<OfflineAction>> _getPendingActions() async {
    final db = await _db.database;
    final rows = await db.query(
      'offline_actions',
      where: 'failed = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map((r) {
      final dataStr = r['data'] as String;
      // Simple parse — data is stored as a string representation
      return OfflineAction(
        id: r['id'] as String,
        type: r['type'] as String,
        data: _parseDataString(dataStr),
        createdAt: DateTime.parse(r['created_at'] as String),
        retryCount: r['retry_count'] as int? ?? 0,
        failed: (r['failed'] as int? ?? 0) == 1,
      );
    }).toList();
  }

  Future<void> _deleteAction(String id) async {
    final db = await _db.database;
    await db.delete('offline_actions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _updateAction(OfflineAction action) async {
    final db = await _db.database;
    await db.update(
      'offline_actions',
      {
        'retry_count': action.retryCount,
        'failed': action.failed ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [action.id],
    );
  }

  Future<void> _markActionFailed(String id) async {
    final db = await _db.database;
    await db.update(
      'offline_actions',
      {'failed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Parse a simple map string representation back to Map.
  /// This handles the format from `Map.toString()`.
  Map<String, dynamic> _parseDataString(String data) {
    try {
      // Remove surrounding braces
      final trimmed = data.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final inner = trimmed.substring(1, trimmed.length - 1);
        final result = <String, dynamic>{};
        // Simple key: value parsing
        for (final part in _splitPairs(inner)) {
          final colonIdx = part.indexOf(':');
          if (colonIdx > 0) {
            final key = part.substring(0, colonIdx).trim();
            final value = part.substring(colonIdx + 1).trim();
            result[key] = _parseValue(value);
          }
        }
        return result;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  List<String> _splitPairs(String inner) {
    final pairs = <String>[];
    final buffer = StringBuffer();
    int depth = 0;
    for (int i = 0; i < inner.length; i++) {
      final ch = inner[i];
      if (ch == '{' || ch == '[') depth++;
      if (ch == '}' || ch == ']') depth--;
      if (ch == ',' && depth == 0) {
        pairs.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    if (buffer.isNotEmpty) pairs.add(buffer.toString());
    return pairs;
  }

  dynamic _parseValue(String value) {
    if (value == 'null') return null;
    if (value == 'true') return true;
    if (value == 'false') return false;
    final asInt = int.tryParse(value);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(value);
    if (asDouble != null) return asDouble;
    // Strip quotes
    if (value.startsWith("'") && value.endsWith("'")) {
      return value.substring(1, value.length - 1);
    }
    if (value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  /// Dispose resources.
  void dispose() {
    _connectivitySub?.cancel();
    _syncResultController.close();
  }
}
