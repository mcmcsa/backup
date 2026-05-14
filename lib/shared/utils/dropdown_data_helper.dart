import '../models/building_model.dart';
import '../models/department_model.dart';
import '../models/floor_model.dart';
import '../models/request_type_model.dart';
import '../models/room_type_model.dart';
import '../services/building_service.dart';
import '../services/department_service.dart';
import '../services/floor_service.dart';
import '../services/request_type_service.dart';
import '../services/room_type_service.dart';

/// Utility class for caching and retrieving dropdown data
/// This prevents repeated database calls and improves performance
class DropdownDataHelper {
  static final DropdownDataHelper _instance = DropdownDataHelper._internal();
  
  late List<Building>? _buildingsCache;
  late List<Department>? _departmentsCache;
  late List<Floor>? _floorsCache;
  late List<RequestType>? _requestTypesCache;
  late List<RoomType>? _roomTypesCache;
  
  DateTime? _buildingsCacheTime;
  DateTime? _departmentsCacheTime;
  DateTime? _floorsCacheTime;
  DateTime? _requestTypesCacheTime;
  DateTime? _roomTypesCacheTime;
  
  // Cache duration: 1 hour
  static const Duration _cacheDuration = Duration(hours: 1);

  factory DropdownDataHelper() {
    return _instance;
  }

  DropdownDataHelper._internal() {
    _buildingsCache = null;
    _departmentsCache = null;
    _floorsCache = null;
    _requestTypesCache = null;
    _roomTypesCache = null;
  }

  /// Get buildings list with caching
  /// Returns building names as strings
  Future<List<String>> getBuildingNames() async {
    try {
      if (_isCacheValid(_buildingsCacheTime)) {
        return _buildingsCache?.map((b) => b.name).toList() ?? [];
      }

      final buildings = await BuildingService.fetchAll();
      _buildingsCache = buildings;
      _buildingsCacheTime = DateTime.now();
      
      return buildings.map((b) => b.name).toList();
    } catch (e) {
      print('Error fetching buildings: $e');
      // Return empty list on error
      return [];
    }
  }

  /// Get building names for a specific department.
  Future<List<String>> getBuildingNamesByDepartment(String departmentId) async {
    try {
      final buildings = await BuildingService.fetchByDepartment(departmentId);
      return buildings.map((b) => b.name).toList();
    } catch (e) {
      print('Error fetching buildings by department: $e');
      return [];
    }
  }

  /// Get building by name
  Future<Building?> getBuildingByName(String name) async {
    try {
      final buildings = await BuildingService.fetchAll();
      return buildings.cast<Building?>().firstWhere(
        (b) => b?.name == name,
        orElse: () => null,
      );
    } catch (e) {
      print('Error fetching building: $e');
      return null;
    }
  }

  /// Get departments list with caching
  /// Returns department names as strings
  Future<List<String>> getDepartmentNames() async {
    try {
      if (_isCacheValid(_departmentsCacheTime)) {
        return _departmentsCache?.map((d) => d.name).toList() ?? [];
      }

      final departments = await DepartmentService.fetchAll();
      _departmentsCache = departments;
      _departmentsCacheTime = DateTime.now();
      
      return departments.map((d) => d.name).toList();
    } catch (e) {
      print('Error fetching departments: $e');
      return [];
    }
  }

  /// Get department by name
  Future<Department?> getDepartmentByName(String name) async {
    try {
      final normalizedName = name.trim().toLowerCase();
      if (normalizedName.isEmpty) return null;

      final departments = await DepartmentService.fetchAll();
      for (final dept in departments) {
        if (dept.name.trim().toLowerCase() == normalizedName) return dept;
      }
      return null;
    } catch (e) {
      print('Error fetching department: $e');
      return null;
    }
  }

  /// Get request types list with caching
  /// Returns request type names as strings
  Future<List<String>> getRequestTypeNames() async {
    try {
      if (_isCacheValid(_requestTypesCacheTime)) {
        return _requestTypesCache?.map((r) => r.name).toList() ?? [];
      }

      final requestTypes = await RequestTypeService.fetchAll();
      _requestTypesCache = requestTypes;
      _requestTypesCacheTime = DateTime.now();
      
      return requestTypes.map((r) => r.name).toList();
    } catch (e) {
      print('Error fetching request types: $e');
      return [
        'Ocular Inspection',
        'Installation',
        'Repair',
        'Replacement',
        'Remediation',
      ];
    }
  }

  /// Get request type by name
  Future<RequestType?> getRequestTypeByName(String name) async {
    try {
      final requestTypes = await RequestTypeService.fetchAll();
      for (final rt in requestTypes) {
        if (rt.name == name) return rt;
      }
      return null;
    } catch (e) {
      print('Error fetching request type: $e');
      return null;
    }
  }

  /// Standard positions available in the system
  List<String> getPositions() {
    return [
      'Teacher',
      'Professor',
      'Assistant Professor',
      'Instructor',
      'Staff',
      'Administrator',
      'Maintenance Manager',
      'Technician',
    ];
  }

  /// Standard colleges/departments common across PSU
  List<String> getColleges() {
    return [
      'College of Arts and Sciences',
      'College of Engineering',
      'College of Business',
      'College of Education',
      'College of Information Technology',
    ];
  }

  /// Get floor names list with caching
  Future<List<String>> getFloorNames({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh && _isCacheValid(_floorsCacheTime)) {
        return _floorsCache?.map((f) => f.name).toList() ?? [];
      }

      final floors = await FloorService.fetchAll();
      _floorsCache = floors;
      _floorsCacheTime = DateTime.now();

      return floors.map((f) => f.name).toList();
    } catch (e) {
      print('Error fetching floors: $e');
      return [];
    }
  }

  /// Get room type options
  Future<List<String>> getRoomTypes() async {
    try {
      if (_isCacheValid(_roomTypesCacheTime)) {
        return _roomTypesCache?.map((r) => r.name).toList() ?? [];
      }

      final roomTypes = await RoomTypeService.fetchAll();
      _roomTypesCache = roomTypes;
      _roomTypesCacheTime = DateTime.now();

      return roomTypes.map((r) => r.name).toList();
    } catch (e) {
      print('Error fetching room types: $e');
      return [];
    }
  }

  /// Get room status options
  List<String> getRoomStatuses() {
    return [
      'available',
      'reserved',
      'maintenance',
      'inactive',
    ];
  }

  /// Get work request status options
  List<String> getWorkRequestStatuses() {
    return [
      'pending',
      'approved',
      'in_progress',
      'under_maintenance',
      'completed',
      'rework',
      'cancelled',
    ];
  }

  /// Get priority options
  List<String> getPriorities() {
    return [
      'low',
      'medium',
      'high',
    ];
  }

  /// Clear all caches
  void clearCache() {
    _buildingsCache = null;
    _departmentsCache = null;
    _floorsCache = null;
    _requestTypesCache = null;
    _roomTypesCache = null;
    _buildingsCacheTime = null;
    _departmentsCacheTime = null;
    _floorsCacheTime = null;
    _requestTypesCacheTime = null;
    _roomTypesCacheTime = null;
  }

  /// Check if cache is still valid
  bool _isCacheValid(DateTime? cacheTime) {
    if (cacheTime == null) return false;
    return DateTime.now().difference(cacheTime) < _cacheDuration;
  }
}
