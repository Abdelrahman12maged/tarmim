/// Input validation utilities for Tarmeem form fields.
///
/// All validators return null on success, or an Arabic error string on failure.
abstract class TarmeemValidators {
  /// Validates a phone number (must have at least 9 digits).
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'رقم الهاتف مطلوب';
    }
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 9) {
      return 'رقم الهاتف غير صحيح';
    }
    return null;
  }

  /// Validates a customer name (required, at least 2 chars).
  static String? customerName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'اسم العميل مطلوب';
    }
    if (value.trim().length < 2) {
      return 'الاسم قصير جداً';
    }
    return null;
  }

  /// Validates issue description (required, at least 10 chars).
  static String? issueDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'وصف العطل مطلوب';
    }
    if (value.trim().length < 10) {
      return 'يرجى توضيح العطل بشكل أكثر تفصيلاً';
    }
    return null;
  }

  /// Validates an optional currency amount (must be >= 0 if provided).
  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return 'المبلغ غير صحيح';
    }
    return null;
  }

  /// Validates a 6-digit PIN.
  static String? pin(String? value) {
    if (value == null || value.length != 6) {
      return 'رمز PIN يجب أن يكون 6 أرقام';
    }
    return null;
  }

  /// Validates device model / type (required).
  static String? deviceModel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'نوع الجهاز مطلوب';
    }
    return null;
  }
}
