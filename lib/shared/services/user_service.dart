import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Fetch names for a list of user IDs
  static Future<Map<String, String>> fetchNamesByIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    
    // Filter out null, empty, and duplicates
    final cleanIds = ids
        .where((id) => id.isNotEmpty && id != 'null')
        .toSet()
        .toList();
        
    if (cleanIds.isEmpty) return {};

    try {
      final List<dynamic> data = await _db
          .from('users')
          .select('id, name')
          .inFilter('id', cleanIds);
      
      final Map<String, String> names = {};
      for (final item in data) {
        if (item['id'] != null && item['name'] != null) {
          names[item['id'].toString()] = item['name'].toString();
        }
      }
      return names;
    } catch (e, stack) {
      print('DEBUG: UserService.fetchNamesByIds error: $e');
      print(stack);
      // Return empty map on error, will fallback to original ID/role
      return {};
    }
  }
}
