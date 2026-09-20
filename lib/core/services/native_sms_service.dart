import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Information about a physical or eSIM SIM card available on the device.
class SimCardInfo {
  final int subscriptionId;
  final int slotIndex;
  final String displayName;
  final String carrierName;
  final String countryIso;
  final bool isDefault;

  const SimCardInfo({
    required this.subscriptionId,
    required this.slotIndex,
    required this.displayName,
    required this.carrierName,
    required this.countryIso,
    this.isDefault = false,
  });

  factory SimCardInfo.fromMap(Map<dynamic, dynamic> map) {
    return SimCardInfo(
      subscriptionId: (map['subscriptionId'] as num?)?.toInt() ?? -1,
      slotIndex: (map['slotIndex'] as num?)?.toInt() ?? 0,
      displayName: (map['displayName'] as String?) ?? 'شريحة غير محددة',
      carrierName: (map['carrierName'] as String?) ?? 'شبكة غير معروفة',
      countryIso: (map['countryIso'] as String?) ?? '',
      isDefault: (map['isDefault'] as bool?) ?? false,
    );
  }
}

/// Detailed result of a direct in-app SMS transmission.
class SmsSendResult {
  final bool isSuccess;
  final String code;
  final String message;

  const SmsSendResult({
    required this.isSuccess,
    required this.code,
    required this.message,
  });

  bool get isPermissionDenied => code == 'permission_denied';
  bool get isNoCreditOrGeneric => code == 'no_credit_or_generic';
  bool get isNoService => code == 'no_service';
  bool get isRadioOff => code == 'radio_off';

  @override
  String toString() => 'SmsSendResult(isSuccess: $isSuccess, code: $code, message: $message)';
}

/// Professional service for sending direct background SMS via native Android SIM cards.
class NativeSmsService {
  static const MethodChannel _channel = MethodChannel('com.tarmim.fixly/sms');

  static const String _prefSimKey = 'tarmim_preferred_sim_sub_id';
  static const String _prefAutoSmsKey = 'tarmim_auto_sms_enabled';
  static const String _prefAutoReadyKey = 'tarmim_auto_ready_sms_enabled';

  final SharedPreferences _prefs;

  NativeSmsService(this._prefs);

  /// Checks if SEND_SMS and READ_PHONE_STATE permissions are granted.
  Future<bool> checkPermissions() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkPermissions');
      final hasSms = result?['hasSmsPermission'] as bool? ?? false;
      return hasSms;
    } catch (e) {
      debugPrint('Error checking SMS permissions: $e');
      return false;
    }
  }

  /// Requests SMS and Phone State runtime permissions from the operating system.
  Future<bool> requestPermissions() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermissions');
      return granted ?? false;
    } catch (e) {
      debugPrint('Error requesting SMS permissions: $e');
      return false;
    }
  }

  /// Retrieves the list of active SIM cards installed on the Android device.
  Future<List<SimCardInfo>> getSimCards() async {
    try {
      final list = await _channel.invokeListMethod<Map<dynamic, dynamic>>('getSimCards');
      if (list == null || list.isEmpty) {
        return [];
      }
      return list.map((item) => SimCardInfo.fromMap(item)).toList();
    } catch (e) {
      debugPrint('Error getting SIM cards: $e');
      return [];
    }
  }

  /// Gets the currently saved preferred subscription ID for SMS dispatch.
  int? getPreferredSubscriptionId() {
    final val = _prefs.getInt(_prefSimKey);
    return val == -1 ? null : val;
  }

  /// Sets and persists the preferred SIM card subscription ID.
  Future<void> setPreferredSubscriptionId(int? subscriptionId) async {
    if (subscriptionId == null || subscriptionId == -1) {
      await _prefs.remove(_prefSimKey);
    } else {
      await _prefs.setInt(_prefSimKey, subscriptionId);
    }
  }

  /// Checks if automatic receipt SMS dispatch upon ticket creation is enabled.
  bool isAutoReceiptSmsEnabled() {
    return _prefs.getBool(_prefAutoSmsKey) ?? true;
  }

  /// Toggles automatic receipt SMS dispatch.
  Future<void> setAutoReceiptSmsEnabled(bool enabled) async {
    await _prefs.setBool(_prefAutoSmsKey, enabled);
  }

  /// Checks if automatic ready-for-pickup SMS dispatch is enabled.
  bool isAutoReadySmsEnabled() {
    return _prefs.getBool(_prefAutoReadyKey) ?? true;
  }

  /// Toggles automatic ready-for-pickup SMS dispatch.
  Future<void> setAutoReadySmsEnabled(bool enabled) async {
    await _prefs.setBool(_prefAutoReadyKey, enabled);
  }

  /// Sends a direct SMS through the device's selected SIM card in the background.
  Future<SmsSendResult> sendDirectSms({
    required String phone,
    required String message,
    int? subscriptionId,
  }) async {
    // 1. Sanitize phone number
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      return const SmsSendResult(
        isSuccess: false,
        code: 'invalid_phone',
        message: 'رقم هاتف العميل غير صالح أو فارغ.',
      );
    }

    // 2. Check and request permissions if needed
    final hasPerms = await checkPermissions();
    if (!hasPerms) {
      final granted = await requestPermissions();
      if (!granted) {
        return const SmsSendResult(
          isSuccess: false,
          code: 'permission_denied',
          message: 'يرجى تفعيل إذن إرسال الرسائل (SMS) في إعدادات التطبيق للمتابعة.',
        );
      }
    }

    // 3. Determine which SIM subscription to use
    final effectiveSubId = subscriptionId ?? getPreferredSubscriptionId();

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>('sendDirectSms', {
        'phone': cleanPhone,
        'message': message,
        'subscriptionId': effectiveSubId,
      });

      if (response == null) {
        return const SmsSendResult(
          isSuccess: false,
          code: 'empty_response',
          message: 'لم يتم استلام رد من مشغل الاتصالات.',
        );
      }

      final success = response['success'] as bool? ?? false;
      final code = (response['code'] as String?) ?? (success ? 'sent' : 'unknown_failure');
      final msg = (response['message'] as String?) ?? (success ? 'تم إرسال الرسالة بنجاح' : 'فشل إرسال الرسالة');

      return SmsSendResult(
        isSuccess: success,
        code: code,
        message: msg,
      );
    } on PlatformException catch (pe) {
      return SmsSendResult(
        isSuccess: false,
        code: pe.code,
        message: pe.message ?? 'حدث خطأ غير متوقع أثناء إرسال الرسالة عبر الشريحة.',
      );
    } catch (e) {
      return SmsSendResult(
        isSuccess: false,
        code: 'unexpected_error',
        message: 'خطأ غير متوقع: $e',
      );
    }
  }

  /// Helper to send a new ticket intake receipt via direct SIM SMS.
  Future<SmsSendResult> sendTicketReceipt({
    required String phone,
    required String customerName,
    required String deviceModel,
    required String ticketId,
    String? ticketNumber,
    String? shopName,
    String? pin,
  }) {
    final effectiveShopName = shopName ?? AppConstants.defaultShopName;
    final effectiveTicketNum = (ticketNumber != null && ticketNumber.isNotEmpty)
        ? ticketNumber
        : (ticketId.length >= 6 ? ticketId.substring(0, 6) : ticketId);
    final trackingUrl = '${AppConstants.publicTrackingBaseUrl}$effectiveTicketNum';

    final text = 'مرحباً $customerName، تم استلام جهازك ($deviceModel) في $effectiveShopName برقم تذكرة #$effectiveTicketNum.\n'
        'يمكنك متابعة حالة الصيانة مباشرة عبر الرابط:\n$trackingUrl';

    return sendDirectSms(phone: phone, message: text);
  }

  /// Helper to send ready-for-pickup notification via direct SIM SMS.
  Future<SmsSendResult> sendReadyForPickup({
    required String phone,
    required String customerName,
    required String deviceModel,
    required double remainingAmount,
    required String ticketId,
    String? ticketNumber,
    String? shopName,
  }) {
    final effectiveShopName = shopName ?? AppConstants.defaultShopName;
    final effectiveTicketNum = (ticketNumber != null && ticketNumber.isNotEmpty)
        ? ticketNumber
        : (ticketId.length >= 6 ? ticketId.substring(0, 6) : ticketId);
    final formattedAmount = remainingAmount > 0 ? '${remainingAmount.toStringAsFixed(0)} ج.م' : 'خالص بالكامل';
    final trackingUrl = '${AppConstants.publicTrackingBaseUrl}$effectiveTicketNum';

    final text = 'عزيزنا $customerName، تم الانتهاء من صيانة جهازك ($deviceModel) بنجاح في $effectiveShopName وهو جاهز للاستلام الآن 🎉\n'
        'رقم التذكرة: #$effectiveTicketNum\n'
        'المبلغ المطلوب: $formattedAmount\n'
        'رابط الفاتورة والمتابعة: $trackingUrl\n'
        'نسعد بزيارتك في مواعيد العمل.';

    return sendDirectSms(phone: phone, message: text);
  }
}
