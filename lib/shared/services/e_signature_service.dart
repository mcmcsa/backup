import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/e_signature_model.dart';

class ESignatureService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'e_signatures';

  /// Fetch all signatures for a work request
  static Future<List<ESignature>> fetchByWorkRequest(String workRequestId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('work_request_id', workRequestId)
        .order('signed_at', ascending: true);
    return (data as List).map((e) => ESignature.fromMap(e)).toList();
  }

  /// Fetch signatures by type for a work request
  static Future<List<ESignature>> fetchByType(String workRequestId, String signatureType) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('work_request_id', workRequestId)
        .eq('signature_type', signatureType)
        .order('signed_at', ascending: true);
    return (data as List).map((e) => ESignature.fromMap(e)).toList();
  }

  /// Fetch a specific signature
  static Future<ESignature?> fetchById(String id) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return ESignature.fromMap(data);
  }

  /// Check if a specific user has signed for a specific type
  static Future<bool> hasUserSigned(String workRequestId, String signerId, String signatureType) async {
    final data = await _db
        .from(_table)
        .select('id')
        .eq('work_request_id', workRequestId)
        .eq('signer_id', signerId)
        .eq('signature_type', signatureType);
    return (data as List).isNotEmpty;
  }

  /// Insert a new signature
  static Future<ESignature> insert(ESignature signature) async {
    final data = await _db
        .from(_table)
        .insert(signature.toInsertMap())
        .select()
        .single();
    return ESignature.fromMap(data);
  }

  /// Fetch all signatures by a specific signer
  static Future<List<ESignature>> fetchBySigner(String signerId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('signer_id', signerId)
        .order('signed_at', ascending: false);
    return (data as List).map((e) => ESignature.fromMap(e)).toList();
  }
}
