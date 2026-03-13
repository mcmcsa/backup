import '../models/building_model.dart';
import '../models/department_model.dart';
import '../models/request_type_model.dart';
import '../services/building_service.dart';
import '../services/department_service.dart';
import '../services/request_type_service.dart';

/// Utility class for caching and retrieving dropdown data
/// This prevents repeated database calls and improves performance
class DropdownDataHelper {
  static final DropdownDataHelper _instance = DropdownDataHelper._internal();
  
  late List<Building>? _buildingsCache;
  late List<Department>? _departmentsCache;
  late List<RequestType>? _requestTypesCache;
  
  DateTime? _buildingsCacheTime;
  DateTime? _departmentsCacheTime;
  DateTime? _requestTypesCacheTime;
  
  // Cache duration: 1 hour
  static const Duration _cacheDuration = Duration(hours: 1);

  factory DropdownDataHelper() {
    return _instance;
  }

  DropdownDataHelper._internal() {
    _buildingsCache = null;
    _departmentsCache = null;
    _requestTypesCache = null;
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
      final departments = await DepartmentService.fetchAll();
      for (final dept in departments) {
        if (dept.name == name) return dept;
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
      'Student',
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

  /// Get floor options
  List<String> getFloors() {
    return [
      '1st Floor',
      '2nd Floor',
      '3rd Floor',
      '4th Floor',
      '5th Floor',
      '6th Floor',
    ];
  }

  /// Get room type options
  List<String> getRoomTypes() {
    return [
      'Laboratory',
      'Lecture Hall',
      'Seminar Room',
      'Office',
      'Storage',
      'Conference Room',
    ];
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
      'ongoing',
      'done',
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
    _requestTypesCache = null;
    _buildingsCacheTime = null;
    _departmentsCacheTime = null;
    _requestTypesCacheTime = null;
  }

  /// Check if cache is still valid
  bool _isCacheValid(DateTime? cacheTime) {
    if (cacheTime == null) return false;
    return DateTime.now().difference(cacheTime) < _cacheDuration;
  }
}
