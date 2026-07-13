import 'dart:async';
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
  }

  Future<bool> checkInternetNow() async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none)) {
      return false;
    }
    return true;
  }

  void dispose() {
    _subscription?.cancel();
    isConnected.dispose();
  }
}
