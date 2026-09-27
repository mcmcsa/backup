import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  // Expose network state
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isCheckingConnection = ValueNotifier<bool>(false);

  Future<void> initialize() async {
    // Initial check
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    // Listen to changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    bool hasConnection = !results.contains(ConnectivityResult.none);
    // If it only contains 'none', it's offline. 
    // connectivity_plus 5.0+ returns List<ConnectivityResult>.
    if (results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none)) {
      hasConnection = false;
    } else {
      hasConnection = true;
    }
    
    if (isConnected.value != hasConnection) {
      isConnected.value = hasConnection;
    }

    // If connectivity_plus says we have connection, verify actual internet reachability
    if (hasConnection && !kIsWeb) {
      checkRealConnection();
    }
  }

  /// Performs an actual DNS resolution / socket test to ensure data actually flows
  Future<bool> checkRealConnection() async {
    isCheckingConnection.value = true;
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none)) {
        if (isConnected.value) isConnected.value = false;
        return false;
      }

      if (!kIsWeb) {
        // Test real DNS lookup on mobile platforms
        final lookup = await InternetAddress.lookup('dns.google')
            .timeout(const Duration(seconds: 4));
        final hasReal = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
        if (isConnected.value != hasReal) {
          isConnected.value = hasReal;
        }
        return hasReal;
      } else {
        if (!isConnected.value) isConnected.value = true;
        return true;
      }
    } catch (_) {
      if (isConnected.value) isConnected.value = false;
      return false;
    } finally {
      isCheckingConnection.value = false;
    }
  }

  /// Mark status as offline immediately when any HTTP or socket error occurs
  void markOffline() {
    if (isConnected.value) {
      isConnected.value = false;
    }
  }

  /// Mark status as online
  void markOnline() {
    if (!isConnected.value) {
      isConnected.value = true;
    }
  }

  Future<bool> checkInternetNow() async {
    return checkRealConnection();
  }

  void dispose() {
    _subscription?.cancel();
    isConnected.dispose();
    isCheckingConnection.dispose();
  }
}
