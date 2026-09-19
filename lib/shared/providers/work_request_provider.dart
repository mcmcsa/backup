import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/work_request_model.dart';
import '../services/work_request_service.dart';

class WorkRequestProvider extends ChangeNotifier {
  List<WorkRequest> _requests = [];
  bool _isLoading = false;
  String? _error;
  bool _isFetching = false;

  Timer? _autoRefreshTimer;
  StreamSubscription? _changeSubscription;
  StreamSubscription? _authSubscription;
  RealtimeChannel? _realtimeChannel;

  List<WorkRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  WorkRequestProvider() {
    fetchRequests();
    _setupLiveSync();
  }

  void _setupLiveSync() {
    // 1. In-memory mutation event listener (triggers instant update on create/edit/status change)
    _changeSubscription = WorkRequestService.onWorkRequestsChanged.listen((_) {
      refreshRequests(silent: true);
    });

    // 2. Supabase Auth state listener (auto-refresh on login or token refresh)
    try {
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.tokenRefreshed ||
            data.event == AuthChangeEvent.userUpdated) {
          refreshRequests(silent: true);
        } else if (data.event == AuthChangeEvent.signedOut) {
          _requests = [];
          notifyListeners();
        }
      });
    } catch (_) {}

    // 3. Supabase Realtime WebSocket subscription
    try {
      _realtimeChannel = WorkRequestService.listenToAllWorkRequests((updated) {
        _requests = updated;
        _error = null;
        notifyListeners();
      });
    } catch (_) {}

    // 4. Background auto-refresh polling timer (every 6 seconds, AJAX-style silent fetch)
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      refreshRequests(silent: true);
    });
  }

  Future<void> fetchRequests({bool silent = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    // Only display full loading state if explicitly requested or if we have no data yet
    if (!silent && _requests.isEmpty) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final data = await WorkRequestService.fetchAll();
      _requests = data;
      _error = null;
    } catch (e) {
      if (_requests.isEmpty) {
        _error = e.toString();
      }
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshRequests({bool silent = false}) async {
    await fetchRequests(silent: silent);
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _changeSubscription?.cancel();
    _authSubscription?.cancel();
    try {
      _realtimeChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }
}

