import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'work_request_service.dart';
import 'e_signature_service.dart';
import 'offline_sync_service.dart';
import '../models/work_request_model.dart';
import '../models/e_signature_model.dart';

void registerOfflineHandlers() {
  OfflineSyncService().registerHandler('submit_work_request', (payload) async {
    try {
      final requestMap = payload['request'] as Map<String, dynamic>;
      final request = WorkRequest.fromMap(requestMap);
      final signatureData = payload['signature'] as String?;
      final offlineImagePaths = (payload['images'] as List<dynamic>?)?.cast<String>() ?? [];

      // 1. Insert Work Request
      final inserted = await WorkRequestService.insert(request);

      // 2. Upload Images
      List<String> uploadedUrls = [];
      for (int i = 0; i < offlineImagePaths.length; i++) {
        final path = offlineImagePaths[i];
        try {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final ext = path.split('.').last;
            final fileName = '${inserted.id}/image_$i.$ext';
            
            await Supabase.instance.client.storage
                .from('work-request-attachments')
                .uploadBinary(fileName, bytes);
            
            final url = Supabase.instance.client.storage
                .from('work-request-attachments')
                .getPublicUrl(fileName);
            uploadedUrls.add(url);
            
            // Cleanup local file
            await file.delete();
          }
        } catch (e) {
          debugPrint('Failed to upload offline image: $e');
        }
      }

      // Update with URLs if any
      if (uploadedUrls.isNotEmpty) {
        final updatedRequest = inserted.copyWith(attachmentUrls: uploadedUrls);
        await WorkRequestService.update(updatedRequest);
      }

      // 3. Insert Signature
      if (signatureData != null && request.requestorId != null) {
        await ESignatureService.insert(ESignature(
          id: '',
          workRequestId: inserted.id,
          signerId: request.requestorId!,
          signerName: request.requestorName ?? 'Unknown',
          signerRole: 'teacher',
          signatureType: 'approval',
          signatureData: signatureData,
          signedAt: DateTime.now(),
        ));
      }
      
      return true; // Success
    } catch (e) {
      debugPrint('Failed to sync offline work request: $e');
      return false; // Fail, keep in queue
    }
  });
}
