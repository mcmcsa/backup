import 'package:flutter/foundation.dart';
import '../services/faculty_user_service.dart';

class UserProvider extends ChangeNotifier {
  List<FacultyUserAccount> _users = [];
  bool _isLoading = false;
  String? _error;

  List<FacultyUserAccount> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchUsers() async {
    if (_users.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await FacultyUserService.fetchAllFacultyUsers();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await FacultyUserService.fetchAllFacultyUsers();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
