import 'package:flutter/foundation.dart';
import '../models/work_request_model.dart';
import '../services/work_request_service.dart';

class WorkRequestProvider extends ChangeNotifier {
  List<WorkRequest> _requests = [];
  bool _isLoading = false;
  String? _error;

  List<WorkRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  WorkRequestProvider() {
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await WorkRequestService.fetchAll();
      _requests = data;
    } catch (e) {
      _error = e.toString();
      _requests = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshRequests() async {
    await fetchRequests();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
