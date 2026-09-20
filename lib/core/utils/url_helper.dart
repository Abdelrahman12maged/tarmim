import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'formatters.dart';

class UrlHelper {
  /// Opens WhatsApp chat with a customer and an optional pre-filled message.
  static Future<bool> openWhatsApp({
    required String phone,
    String? message,
    BuildContext? context,
  }) async {
    final urlString = whatsAppUrl(phone, message: message);
    final uri = Uri.parse(urlString);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح واتساب. يرجى التأكد من تثبيت التطبيق على جهازك.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return launched;
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء فتح واتساب: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  /// Dials a phone number directly by opening the phone dialer app.
  static Future<bool> makePhoneCall(
    String phone, {
    BuildContext? context,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رقم الهاتف غير متوفر.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
    final uri = Uri(scheme: 'tel', path: cleanPhone);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح تطبيق الاتصال.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return launched;
    } catch (e) {
      debugPrint('Error making phone call: $e');
      return false;
    }
  }

  /// Sends a direct SMS text message to the customer by opening the SMS app.
  static Future<bool> sendSms({
    required String phone,
    required String message,
    BuildContext? context,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رقم هاتف العميل غير متوفر أو غير صالح.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final Uri uri;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      uri = Uri.parse('sms:$cleanPhone&body=${Uri.encodeComponent(message)}');
    } else {
      uri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح تطبيق الرسائل القصيرة (SMS).'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return launched;
    } catch (e) {
      debugPrint('Error launching SMS: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء فتح تطبيق الرسائل: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }
}

