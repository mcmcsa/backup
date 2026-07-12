import 'package:flutter/foundation.dart';
import '../models/room_model.dart';
import '../services/room_service.dart';

class RoomProvider extends ChangeNotifier {
  List<Room> _rooms = [];
  bool _isLoading = false;
  String? _error;

  List<Room> get rooms => _rooms;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRooms() async {
    if (_rooms.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _rooms = await RoomService.fetchAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshRooms() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _rooms = await RoomService.fetchAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
