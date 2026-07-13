import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

// Represents an action to be executed when online
class OfflineAction {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  OfflineAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
  };

  factory OfflineAction.fromMap(Map<String, dynamic> map) => OfflineAction(
    id: map['id'],
    type: map['type'],
    payload: map['payload'],
    timestamp: DateTime.parse(map['timestamp']),
  );
}

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _queueKey = 'offline_action_queue';
  final ValueNotifier<int> queueCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  
  // Callback registry to handle syncing different types of actions
  final Map<String, Future<bool> Function(Map<String, dynamic>)> _handlers = {};

  Future<void> initialize() async {
    await _updateQueueCount();
  }

  void registerHandler(String type, Future<bool> Function(Map<String, dynamic>) handler) {
    _handlers[type] = handler;
  }

  // --- Queue Management ---
  
  Future<void> queueAction(String type, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final action = OfflineAction(
      id: const Uuid().v4(),
      type: type,
      payload: payload,
      timestamp: DateTime.now(),
    );

    final currentQueueStr = prefs.getStringList(_queueKey) ?? [];
    currentQueueStr.add(jsonEncode(action.toMap()));
    await prefs.setStringList(_queueKey, currentQueueStr);
    
    await _updateQueueCount();
  }

  Future<List<OfflineAction>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final currentQueueStr = prefs.getStringList(_queueKey) ?? [];
    return currentQueueStr
        .map((str) => OfflineAction.fromMap(jsonDecode(str)))
        .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> _updateQueueCount() async {
    final q = await getQueue();
    queueCount.value = q.length;
  }

  // --- Sync Engine ---

  Future<void> syncNow() async {
    if (isSyncing.value) return;
    
    final prefs = await SharedPreferences.getInstance();
    final queue = await getQueue();
    if (queue.isEmpty) return;

    isSyncing.value = true;
    
    List<OfflineAction> remainingQueue = List.from(queue);

    try {
      for (final action in queue) {
        final handler = _handlers[action.type];
        if (handler != null) {
          // Attempt to sync
          bool success = await handler(action.payload);
          if (success) {
            remainingQueue.removeWhere((a) => a.id == action.id);
          } else {
            // Stop syncing if one fails (to maintain chronological order constraints)
            break; 
          }
        } else {
          // Unknown action, discard to prevent blocking
          remainingQueue.removeWhere((a) => a.id == action.id);
        }
      }
    } catch (e) {
      debugPrint('Sync error: $e');
    } finally {
      // Save remaining queue
      final remainingStrs = remainingQueue.map((a) => jsonEncode(a.toMap())).toList();
      await prefs.setStringList(_queueKey, remainingStrs);
      await _updateQueueCount();
      isSyncing.value = false;
    }
  }

  // --- Caching Getters/Setters ---

  Future<void> setCachedData(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_$key', jsonEncode(data));
  }

  Future<dynamic> getCachedData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('cache_$key');
    if (str != null) {
      return jsonDecode(str);
    }
    return null;
  }

  // --- Offline File Storage ---
  Future<String?> saveFileOffline(String fileName, List<int> bytes) async {
    if (kIsWeb) return null; // Cannot reliably use path_provider on web
    try {
      final directory = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${directory.path}/offline_cache');
      if (!await offlineDir.exists()) {
        await offlineDir.create(recursive: true);
      }
      final file = File('${offlineDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Failed to save offline file: $e');
      return null;
    }
  }
}
