import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cost_tracking_model.dart';

class CostTrackingService {
  static final _supabase = Supabase.instance.client;
  static const String _tableName = 'work_request_costs';
  static const String _bucketName = 'cost_receipts';

  /// Fetch cost for a specific work request
  static Future<WorkRequestCost?> fetchByWorkRequestId(String workRequestId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('work_request_id', workRequestId)
          .maybeSingle();
      
      if (response == null) return null;
      return WorkRequestCost.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch cost tracking: $e');
    }
  }

  /// Upsert cost tracking data
  static Future<WorkRequestCost> upsert(WorkRequestCost cost) async {
    try {
      final data = cost.toJson();
      if (data['id'] == '') data.remove('id'); // let db generate if new

      final response = await _supabase
          .from(_tableName)
          .upsert(data, onConflict: 'work_request_id')
          .select()
          .single();
          
      return WorkRequestCost.fromJson(response);
    } catch (e) {
      throw Exception('Failed to upsert cost tracking: $e');
    }
  }

  /// Upload receipt attachment bytes and return the public URL (Web Safe)
  static Future<String> uploadReceiptBytes(String workRequestId, Uint8List bytes, String extension) async {
    try {
      final fileName = '${workRequestId}_${DateTime.now().millisecondsSinceEpoch}$extension';
      
      await _supabase.storage.from(_bucketName).uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      
      final publicUrl = _supabase.storage.from(_bucketName).getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload receipt: $e');
    }
  }

  /// Delete cost tracking data
  static Future<void> delete(String id) async {
    try {
      await _supabase.from(_tableName).delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete cost tracking: $e');
    }
  }
}
