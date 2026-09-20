import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../network/supabase_client.dart';

/// Diagnostic result for testing Supabase storage connection.
class SupabaseStorageTestResult {
  final bool isSuccess;
  final String message;
  final String? bucketName;

  const SupabaseStorageTestResult({
    required this.isSuccess,
    required this.message,
    this.bucketName,
  });
}

/// Service handling uploading and managing ticket inspection images via Supabase Storage.
class SupabaseStorageService {
  /// Uploads a device intake photo to Supabase Storage and returns its public HTTPS URL.
  Future<String?> uploadTicketImage({
    required XFile file,
    required String ticketNumber,
    String? shopId,
  }) async {
    try {
      if (!SupabaseConfig.isConfigured) {
        debugPrint(
          'SupabaseStorageService: Supabase is not configured yet with valid credentials.',
        );
        return null;
      }

      final client = SupabaseConfig.clientSafe;
      if (client == null) {
        debugPrint('SupabaseStorageService: Supabase client is null.');
        return null;
      }

      final bucket = SupabaseConfig.activeBucket;
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('ملف الصورة فارغ');
      }

      // Determine file extension & content type
      final nameLower = file.name.toLowerCase();
      String ext = '.jpg';
      String contentType = 'image/jpeg';

      if (nameLower.endsWith('.png')) {
        ext = '.png';
        contentType = 'image/png';
      } else if (nameLower.endsWith('.webp')) {
        ext = '.webp';
        contentType = 'image/webp';
      } else if (nameLower.endsWith('.heic')) {
        ext = '.heic';
        contentType = 'image/heic';
      }

      // Scope storage path by shop for clean tenant isolation
      String effectiveShopId = shopId ?? '';
      if (effectiveShopId.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          effectiveShopId = prefs.getString(AppConstants.prefShopId) ?? 'default';
        } catch (_) {
          effectiveShopId = 'default';
        }
      }
      final safeShopId = effectiveShopId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final safeTicketNum = ticketNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'shops/$safeShopId/tickets/${safeTicketNum}_$timestamp$ext';

      final storage = client.storage.from(bucket);

      debugPrint('SupabaseStorageService: Uploading to $bucket/$storagePath (${bytes.length} bytes)...');

      int attempts = 0;
      const maxAttempts = 2;
      while (attempts < maxAttempts) {
        attempts++;
        try {
          await storage
              .uploadBinary(
                storagePath,
                bytes,
                fileOptions: FileOptions(
                  contentType: contentType,
                  upsert: true,
                ),
              )
              .timeout(const Duration(seconds: 6));
          break;
        } catch (uploadErr) {
          final errStr = uploadErr.toString().toLowerCase();
          final isNetworkTimeout = errStr.contains('timed out') ||
              errStr.contains('socketexception') ||
              errStr.contains('network is unreachable') ||
              errStr.contains('connection refused') ||
              errStr.contains('failed host lookup');

          // If connection to server timed out or network is unreachable, retrying immediately is futile
          if (isNetworkTimeout || attempts >= maxAttempts) {
            rethrow;
          }
          debugPrint('SupabaseStorageService: upload attempt $attempts failed ($uploadErr). Retrying in 500ms...');
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      final publicUrl = storage.getPublicUrl(storagePath);
      debugPrint('SupabaseStorageService: Upload successful! Public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('SupabaseStorageService upload error: $e');
      rethrow;
    }
  }

  /// Tests connection to Supabase and checks if the storage bucket exists and is accessible.
  Future<SupabaseStorageTestResult> testStorageConnection() async {
    try {
      if (!SupabaseConfig.isConfigured) {
        return const SupabaseStorageTestResult(
          isSuccess: false,
          message: 'بيانات الاعتماد غير مكتملة. يرجى إدخال عنوان المشروع (URL) والمفتاح العام (Anon Key).',
        );
      }

      final client = SupabaseConfig.clientSafe;
      if (client == null) {
        return const SupabaseStorageTestResult(
          isSuccess: false,
          message: 'تعذر تهيئة عميل Supabase. يرجى التحقق من صحة الرابط والمفتاح.',
        );
      }

      final bucket = SupabaseConfig.activeBucket;
      final storage = client.storage.from(bucket);

      // Attempt to list items in bucket to verify bucket existence and permissions
      await storage.list(path: 'tickets', searchOptions: const SearchOptions(limit: 1));

      return SupabaseStorageTestResult(
        isSuccess: true,
        message: 'تم الاتصال بسحابة Supabase وسلة التخزين ($bucket) بنجاح تام! جاهز لرفع صور الأجهزة ☁️✅',
        bucketName: bucket,
      );
    } catch (e) {
      debugPrint('SupabaseStorageService test error: $e');
      final errStr = e.toString().toLowerCase();

      if (errStr.contains('bucket not found') || errStr.contains('not_found')) {
        return SupabaseStorageTestResult(
          isSuccess: false,
          message: 'سلة التخزين (${SupabaseConfig.activeBucket}) غير موجودة في مشروعك! يرجى إنشاؤها وتفعيل خيار Public Bucket أو تشغيل كود SQL المرفق.',
          bucketName: SupabaseConfig.activeBucket,
        );
      }

      if (errStr.contains('invalid api key') || errStr.contains('jwt')) {
        return const SupabaseStorageTestResult(
          isSuccess: false,
          message: 'مفتاح الـ Anon Key غير صالح أو انتهت صلاحيته. يرجى نسخه من لوحة تحكم Supabase > Project Settings > API.',
        );
      }

      return SupabaseStorageTestResult(
        isSuccess: false,
        message: 'تعذر الاتصال بـ Supabase: $e',
        bucketName: SupabaseConfig.activeBucket,
      );
    }
  }

  /// Removes an uploaded image from Supabase Storage if no longer needed.
  Future<bool> deleteImageByUrl(String imageUrl) async {
    try {
      final client = SupabaseConfig.clientSafe;
      if (client == null || !imageUrl.startsWith('http')) return false;

      final bucket = SupabaseConfig.activeBucket;
      // Extract storage path from public URL
      // URL format: https://.../storage/v1/object/public/{bucket}/{path}
      final pattern = '/storage/v1/object/public/$bucket/';
      if (!imageUrl.contains(pattern)) return false;

      final path = imageUrl.substring(imageUrl.indexOf(pattern) + pattern.length);
      await client.storage.from(bucket).remove([path]);
      debugPrint('SupabaseStorageService: Removed file: $path');
      return true;
    } catch (e) {
      debugPrint('SupabaseStorageService delete error: $e');
      return false;
    }
  }
}
