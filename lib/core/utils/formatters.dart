/// Formatting utilities for Tarmeem.
///
/// Currency, date, and number formatting helpers used across the app.
/// Centralised here to avoid duplication across screens.
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Formats a [double] amount as Arabic currency (e.g. "١٬٢٥٠ ج.م").

///
/// [useArabicNumerals] — when true uses Eastern Arabic digits (١٢٣),
/// when false uses Western Arabic digits (123).
String formatCurrency(
  double amount, {
  String currencySymbol = 'ج.م',
  bool useArabicNumerals = false,
}) {
  final formatted = NumberFormat('#,##0.##', 'en_US').format(amount);
  final number = useArabicNumerals ? _toArabicNumerals(formatted) : formatted;
  return '$number $currencySymbol';
}

/// Formats a [DateTime] in Arabic-friendly long format.
/// Example: "١٨ أكتوبر ٢٠٢٣"
String formatDateArabic(DateTime date, {bool useArabicNumerals = true}) {
  final months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  final day = useArabicNumerals
      ? _toArabicNumerals(date.day.toString())
      : date.day.toString();
  final year = useArabicNumerals
      ? _toArabicNumerals(date.year.toString())
      : date.year.toString();
  return '$day ${months[date.month - 1]} $year';
}

/// Formats a [DateTime] as a relative time string in Arabic.
/// Example: "منذ يومين", "اليوم ١١:٣٠ ص", "أمس"
String formatRelativeTime(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inDays == 0) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return 'اليوم ${_toArabicNumerals(hour12.toString())}:${_toArabicNumerals(minute)} $period';
  } else if (diff.inDays == 1) {
    return 'أمس';
  } else if (diff.inDays < 7) {
    return 'منذ ${_toArabicDays(diff.inDays)}';
  } else {
    return formatDateArabic(date);
  }
}

/// Converts Western Arabic numerals to Eastern Arabic numerals.
/// Example: "123" → "١٢٣"
String toArabicNumerals(String input) => _toArabicNumerals(input);

String _toArabicNumerals(String input) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var result = input;
  for (int i = 0; i < western.length; i++) {
    result = result.replaceAll(western[i], eastern[i]);
  }
  return result;
}

String _toArabicDays(int days) {
  switch (days) {
    case 2:
      return 'يومين';
    case 3:
      return '٣ أيام';
    default:
      return '${_toArabicNumerals(days.toString())} أيام';
  }
}

/// Formats an Egyptian phone number into readable format.
/// e.g. "01012345678" -> "010 1234 5678"
/// or "+201012345678" -> "010 1234 5678"
String formatEgyptianPhone(String phone) {
  var digits = phone.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.startsWith('20') && digits.length >= 12) {
    digits = digits.substring(2);
  }
  if (!digits.startsWith('0') &&
      (digits.startsWith('10') ||
          digits.startsWith('11') ||
          digits.startsWith('12') ||
          digits.startsWith('15'))) {
    digits = '0$digits';
  }
  if (digits.length == 11) {
    return '${digits.substring(0, 3)} ${digits.substring(3, 7)} ${digits.substring(7)}';
  }
  return phone;
}

/// Generates a WhatsApp deep link URL for a given phone number.
/// Handles Egyptian format (01xxxxxxxxx) by prefixing 20.
String whatsAppUrl(String phone, {String? message}) {
  var cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
  if (cleanPhone.startsWith('0')) {
    cleanPhone = '20${cleanPhone.substring(1)}';
  } else if (!cleanPhone.startsWith('20') && cleanPhone.length == 10) {
    cleanPhone = '20$cleanPhone';
  }
  final encoded = message != null ? Uri.encodeComponent(message) : '';
  return 'https://wa.me/$cleanPhone${message != null ? '?text=$encoded' : ''}';
}

/// Generates a public tracking URL for a ticket using its ticketNumber (e.g. TR-4082) or ID.
String buildTrackingUrl(String ticketIdentifier) {
  final clean = ticketIdentifier.replaceAll('#', '').trim();
  return '${AppConstants.publicTrackingBaseUrl}$clean';
}

/// Generates an initial receipt & tracking WhatsApp message upon device intake.
String buildNewTicketReceiptMessage({
  required String customerName,
  required String ticketNumber,
  required String deviceModel,
  required double estimatedCost,
  required double deposit,
  required double remainingAmount,
  required String shopName,
  String? ticketId,
  double? partsCost,
  String? partsDescription,
}) {
  final identifier = ticketNumber.isNotEmpty ? ticketNumber : (ticketId ?? '');
  final trackingUrl = buildTrackingUrl(identifier);
  final partsLine = (partsCost != null && partsCost > 0)
      ? '⚙️ قطع الغيار (${partsDescription != null && partsDescription.isNotEmpty ? partsDescription : "مستهلكات"}): ${formatCurrency(partsCost)}\n'
      : '';
  final costSection = estimatedCost > 0
      ? '💰 التكلفة الإجمالية: ${formatCurrency(estimatedCost)}\n'
        '💵 العربون المدفوع: ${formatCurrency(deposit)}\n'
        '⏳ المتبقي عند الاستلام: ${formatCurrency((estimatedCost - deposit).clamp(0.0, double.infinity))}\n\n'
      : '💰 التكلفة الإجمالية: تُحدد بعد الفحص والمعاينة 🔍\n'
        '💵 العربون المدفوع: ${deposit > 0 ? formatCurrency(deposit) : "بدون عربون"}\n'
        '⏳ المتبقي عند الاستلام: يُحسب بعد تحديد التكلفة\n\n';

  return 'مرحباً أ/ $customerName 🌷\n'
      'تم استلام جهازك ($deviceModel) بنجاح في $shopName.\n\n'
      '📋 رقم الإيصال: #$ticketNumber\n'
      '$partsLine'
      '$costSection'
      '🔍 يمكنك متابعة حالة صيانة جهازك وتفاصيل الفاتورة في أي وقت عبر هذا الرابط:\n'
      '$trackingUrl\n\n'
      'نسعد بخدمتكم دائماً!';
}

/// Generates a ready-for-pickup WhatsApp message for a ticket, with full invoice breakdown if priced.
String buildReadyForPickupMessage({
  required String customerName,
  required String deviceModel,
  required double remainingAmount,
  required String shopName,
  String? ticketNumber,
  String? ticketId,
  double? estimatedCost,
  double? partsCost,
  double? laborCost,
  double? deposit,
  String? partsDescription,
}) {
  final identifier = (ticketNumber != null && ticketNumber.isNotEmpty)
      ? ticketNumber
      : (ticketId ?? '');
  final trackingPart = identifier.isNotEmpty
      ? '\n🔍 رابط الفاتورة وتتبع الجهاز: ${buildTrackingUrl(identifier)}'
      : '';

  final invoiceDetails = (estimatedCost != null && estimatedCost > 0)
      ? '\n\n🧾 تفاصيل الفاتورة والحساب:'
        '\n💰 إجمالي التكلفة: ${formatCurrency(estimatedCost)}'
        '${(partsCost != null && partsCost > 0) ? "\n⚙️ قطع الغيار${partsDescription != null && partsDescription.isNotEmpty ? " ($partsDescription)" : ""}: ${formatCurrency(partsCost)}" : ""}'
        '${(laborCost != null && laborCost > 0) ? "\n🛠️ أجرة المصنعية: ${formatCurrency(laborCost)}" : ""}'
        '${(deposit != null && deposit > 0) ? "\n💵 العربون المسدد: ${formatCurrency(deposit)}" : ""}'
        '\n⏳ المبلغ المتبقي للسداد: ${formatCurrency(remainingAmount)}'
      : '\nالمبلغ المتبقي: ${formatCurrency(remainingAmount)}';

  return 'أهلاً أ/ $customerName 🌷\n'
      'نود إبلاغكم بأن جهازك ($deviceModel) أصبح *جاهزاً للاستلام الآن* في *$shopName*.$invoiceDetails\n$trackingPart\n\nنسعد بزيارتكم دائماً!';
}

/// Generates a price quotation / estimate WhatsApp message for a customer to approve.
String buildPriceQuoteMessage({
  required String customerName,
  required String deviceModel,
  required double estimatedCost,
  required double partsCost,
  required double laborCost,
  required double deposit,
  required double remainingAmount,
  required String shopName,
  String? partsDescription,
  String? ticketNumber,
  String? ticketId,
}) {
  final identifier = (ticketNumber != null && ticketNumber.isNotEmpty)
      ? ticketNumber
      : (ticketId ?? '');
  final trackingPart = identifier.isNotEmpty
      ? '\n🔍 رابط الفاتورة والتتبع: ${buildTrackingUrl(identifier)}'
      : '';
  final partsPart = partsCost > 0
      ? '\n⚙️ قطع الغيار${partsDescription != null && partsDescription.isNotEmpty ? " ($partsDescription)" : ""}: ${formatCurrency(partsCost)}\n🛠️ أجرة المصنعية: ${formatCurrency(laborCost)}'
      : '';
  final depositPart = deposit > 0 ? '\n💵 العربون المسدد: ${formatCurrency(deposit)}' : '';

  return 'مرحباً أ/ $customerName 🌟\n'
      'تم الانتهاء من فحص ومعاينة جهازك ($deviceModel) في *$shopName*.\n\n'
      '📋 تفاصيل عرض السعر والتكلفة المقدرة:\n'
      '💰 إجمالي التكلفة: ${formatCurrency(estimatedCost)}$partsPart$depositPart\n'
      '⏳ المبلغ المتبقي عند الاستلام: ${formatCurrency(remainingAmount)}$trackingPart\n\n'
      'يرجى إفادتنا بموافقتكم لنبدأ بعملية الصيانة فوراً. شكراً لثقتكم بنا ✨';
}

/// Generates a thank-you & delivery WhatsApp message for a customer with digital receipt link.
String buildDeliveredThankYouMessage({
  required String customerName,
  required String deviceModel,
  required String shopName,
  String? ticketNumber,
  String? ticketId,
  double? totalPaid,
  double? remainingAmount,
}) {
  final identifier = (ticketNumber != null && ticketNumber.isNotEmpty)
      ? ticketNumber
      : (ticketId ?? '');
  final trackingPart = identifier.isNotEmpty
      ? '\n🧾 يمكنك استعراض وتحميل فاتورتك الإلكترونية عبر الرابط:\n${buildTrackingUrl(identifier)}'
      : '';
  final paymentStatus = (remainingAmount != null && remainingAmount > 0)
      ? '\n💵 المسدد: ${formatCurrency(totalPaid ?? 0)} • المتبقي: ${formatCurrency(remainingAmount)}'
      : (totalPaid != null && totalPaid > 0
          ? '\n✅ الفاتورة: مسددة بالكامل (${formatCurrency(totalPaid)})'
          : '');

  return 'أهلاً أ/ $customerName 🌷\n'
      'نشكركم لزيارتكم وثقتكم بنا في *$shopName*.\n'
      'تم تسليم جهازكم ($deviceModel) بنجاح.$paymentStatus\n'
      '$trackingPart\n\n'
      'نسعد دائماً بخدمتكم وتمنياتنا لكم بتجربة موفقة! ✨';
}

/// Generates a cancellation and pickup WhatsApp notification for a customer when repair is cancelled.
String buildCancelledPickupMessage({
  required String customerName,
  required String deviceModel,
  required String shopName,
  String? ticketNumber,
  String? ticketId,
  double? inspectionFee,
  double? refundedAmount,
  double? remainingAmount,
  String? reason,
}) {
  final identifier = (ticketNumber != null && ticketNumber.isNotEmpty)
      ? ticketNumber
      : (ticketId ?? '');
  final trackingPart = identifier.isNotEmpty
      ? '\n📄 لمتابعة التفاصيل وإيصال الاسترجاع الإلكتروني:\n${buildTrackingUrl(identifier)}'
      : '';

  final reasonPart = (reason != null && reason.trim().isNotEmpty)
      ? '\n📌 سبب الإلغاء: $reason'
      : '';

  String financialStatus = '';
  if (refundedAmount != null && refundedAmount > 0) {
    financialStatus = '\n💵 العربون المسترد لحضرتكم بالورشة: ${formatCurrency(refundedAmount)}';
  }
  if (inspectionFee != null && inspectionFee > 0) {
    financialStatus += '\n🔍 رسوم الفحص والكشف: ${formatCurrency(inspectionFee)}';
  }
  if (remainingAmount != null && remainingAmount > 0) {
    financialStatus += '\n⏳ المتبقي سداده عند الاستلام: ${formatCurrency(remainingAmount)}';
  }

  return 'أهلاً أ/ $customerName 🌷\n'
      'نود إحاطتكم بأنه تم إنهاء وإلغاء أعمال الصيانة لجهازكم ($deviceModel) في *$shopName*.$reasonPart\n'
      '📦 جهازكم جاهز للاستلام الآن من مقر الورشة.$financialStatus\n'
      '$trackingPart\n\n'
      'شاكرين ومقدرين تواصلكم معنا دائماً ✨';
}




