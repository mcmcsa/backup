import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cost_tracking_model.dart';
import '../models/work_request_model.dart';
import '../models/work_request_model.dart';
import 'work_request_service.dart';
import 'offline_sync_service.dart';

class CostAnalyticsService {
  static final _supabase = Supabase.instance.client;

  /// Fetch all costs joined with work request details
  static Future<List<Map<String, dynamic>>> fetchCostAnalytics() async {
    try {
      final response = await _supabase.from('work_request_costs').select('''
        *,
        work_requests (
          id,
          title,
          department,
          building_name,
          assigned_to_id,
          accepted_by_name,
          completed_by_name
        )
      ''');

      final results = List<Map<String, dynamic>>.from(response);
      
      // Cache results for offline use
      try {
        await OfflineSyncService().setCachedData('cost_analytics', results);
      } catch (_) {}
      
      return results;
    } catch (e) {
      // Try fetching from cache
      try {
        final cached = await OfflineSyncService().getCachedData('cost_analytics');
        if (cached != null) {
          return List<Map<String, dynamic>>.from(cached);
        }
      } catch (_) {}
      
      throw Exception('Failed to fetch cost analytics: $e');
    }
  }

  /// Get Monthly Expenses
  static Map<String, double> getMonthlyExpenses(List<Map<String, dynamic>> data) {
    final Map<String, double> expenses = {};
    for (var item in data) {
      final date = DateTime.parse(item['created_at']);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final totalCost = (item['total_cost'] as num?)?.toDouble() ?? 0.0;
      
      expenses[monthKey] = (expenses[monthKey] ?? 0.0) + totalCost;
    }
    return expenses;
  }

  /// Get Yearly Expenses
  static Map<String, double> getYearlyExpenses(List<Map<String, dynamic>> data) {
    final Map<String, double> expenses = {};
    for (var item in data) {
      final date = DateTime.parse(item['created_at']);
      final yearKey = '${date.year}';
      final totalCost = (item['total_cost'] as num?)?.toDouble() ?? 0.0;
      
      expenses[yearKey] = (expenses[yearKey] ?? 0.0) + totalCost;
    }
    return expenses;
  }

  /// Get Cost by Department
  static Map<String, double> getCostByDepartment(List<Map<String, dynamic>> data) {
    final Map<String, double> costs = {};
    for (var item in data) {
      final request = item['work_requests'];
      final dept = request?['department'] ?? 'Unknown';
      final totalCost = (item['total_cost'] as num?)?.toDouble() ?? 0.0;
      
      costs[dept] = (costs[dept] ?? 0.0) + totalCost;
    }
    return costs;
  }

  /// Get Cost by Building
  static Map<String, double> getCostByBuilding(List<Map<String, dynamic>> data) {
    final Map<String, double> costs = {};
    for (var item in data) {
      final request = item['work_requests'];
      final bldg = request?['building_name'] ?? 'Unknown';
      final totalCost = (item['total_cost'] as num?)?.toDouble() ?? 0.0;
      
      costs[bldg] = (costs[bldg] ?? 0.0) + totalCost;
    }
    return costs;
  }

  /// Get Cost by Personnel
  static Map<String, double> getCostByPersonnel(List<Map<String, dynamic>> data) {
    final Map<String, double> costs = {};
    for (var item in data) {
      final request = item['work_requests'];
      final personnel = request?['completed_by_name'] ?? request?['accepted_by_name'] ?? 'Unassigned';
      final totalCost = (item['total_cost'] as num?)?.toDouble() ?? 0.0;
      
      costs[personnel] = (costs[personnel] ?? 0.0) + totalCost;
    }
    return costs;
  }

  /// Get Top Most Expensive Repairs
  static List<Map<String, dynamic>> getTopExpensiveRepairs(List<Map<String, dynamic>> data, {int limit = 10}) {
    data.sort((a, b) {
      final costA = (a['total_cost'] as num?)?.toDouble() ?? 0.0;
      final costB = (b['total_cost'] as num?)?.toDouble() ?? 0.0;
      return costB.compareTo(costA);
    });
    
    return data.take(limit).toList();
  }
}
