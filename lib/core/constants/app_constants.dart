/// App-wide constants for Tarmeem.
///
/// Route names, Firestore collection paths, and other shared string constants.
abstract class AppConstants {
  // ── App info ──────────────────────────────────────────────────────────────
  static const String appName = 'ترميم';
  static const String appNameEn = 'Tarmeem';
  static const String appTagline = 'إدارة بسيطة لأعمال الإصلاح والصيانة لكافة الورش';

  // ── Firestore collection paths ────────────────────────────────────────────
  static const String ticketsCollection = 'tickets';
  static const String customersCollection = 'customers';
  static const String shopsCollection = 'shops';
  static const String statusHistorySubcollection = 'statusHistory';

  // ── Shared Preferences keys ───────────────────────────────────────────────
  static const String prefThemeMode = 'theme_mode';
  static const String prefAuthToken = 'auth_token';
  static const String prefShopId = 'shop_id';
  static const String prefShopName = 'shop_name';
  static const String prefShopPhone = 'shop_phone';
  static const String prefShopAddress = 'shop_address';
  static const String prefShopHours = 'shop_hours';
  static const String prefShopWarranty = 'shop_warranty';

  // ── WhatsApp ──────────────────────────────────────────────────────────────
  static const String whatsAppBaseUrl = 'https://wa.me/';

  // ── Ticket number prefix & shop defaults ──────────────────────────────────
  static const String ticketPrefix = 'TR-';
  static const String defaultShopName = 'مركز ترميم لصيانة الأجهزة';
  static const String defaultShopPhone = '01012345678';
  static const String defaultShopAddress = 'شارع التحرير، وسط البلد، القاهرة';
  static const String defaultShopHours = 'السبت إلى الخميس: 10:00 ص - 10:00 م';
  static const String defaultShopWarranty = 'ضمان معتمد لمدة 30 يوماً على كافة أعمال الإصلاح وتغيير القطع الأصلية.';
  static const String publicTrackingBaseUrl = 'https://tarmim-769e5.web.app/track/';


  // ── Dev/test bypass credentials ───────────────────────────────────────────
  static const String testPhone = '+201000000000';
  static const String testPin = '123456';

  // ── Responsive breakpoints ────────────────────────────────────────────────
  static const double tabletBreakpoint = 600.0;

  // ── Quick deposit amounts ─────────────────────────────────────────────────
  static const List<double> quickDepositAmounts = [50, 100, 200];
}

/// Device type options for ticket creation.
enum DeviceType {
  mobile,
  laptop,
  watch,
  home,
  other;

  /// Arabic label for display.
  String get label {
    switch (this) {
      case DeviceType.mobile:
        return 'موبايل';
      case DeviceType.laptop:
        return 'لابتوب';
      case DeviceType.watch:
        return 'ساعة / خُنى';
      case DeviceType.home:
        return 'منزلي';
      case DeviceType.other:
        return 'أخرى...';
    }
  }

  /// Icon name for display.
  String get iconLabel {
    switch (this) {
      case DeviceType.mobile:
        return '📱';
      case DeviceType.laptop:
        return '💻';
      case DeviceType.watch:
        return '⌚';
      case DeviceType.home:
        return '🏠';
      case DeviceType.other:
        return '🔧';
    }
  }
}

/// Repair ticket statuses.
enum TicketStatus {
  inDiagnosis,
  waitingForPart,
  readyForPickup,
  delivered,
  cancelled;

  /// Arabic display label.
  String get label {
    switch (this) {
      case TicketStatus.inDiagnosis:
        return 'قيد الفحص';
      case TicketStatus.waitingForPart:
        return 'بانتظار قطعة';
      case TicketStatus.readyForPickup:
        return 'جاهز للاستلام';
      case TicketStatus.delivered:
        return 'تم التسليم';
      case TicketStatus.cancelled:
        return 'مسترجع بدون إصلاح';
    }
  }

  /// Firestore string value.
  String get value {
    switch (this) {
      case TicketStatus.inDiagnosis:
        return 'in_diagnosis';
      case TicketStatus.waitingForPart:
        return 'waiting_for_part';
      case TicketStatus.readyForPickup:
        return 'ready_for_pickup';
      case TicketStatus.delivered:
        return 'delivered';
      case TicketStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Parse from Firestore string.
  static TicketStatus fromValue(String value) {
    switch (value) {
      case 'in_diagnosis':
        return TicketStatus.inDiagnosis;
      case 'waiting_for_part':
        return TicketStatus.waitingForPart;
      case 'ready_for_pickup':
        return TicketStatus.readyForPickup;
      case 'delivered':
        return TicketStatus.delivered;
      case 'cancelled':
        return TicketStatus.cancelled;
      default:
        return TicketStatus.inDiagnosis;
    }
  }

  /// Returns true if this status is after [other] in the progression.
  bool isAfter(TicketStatus other) {
    return index > other.index;
  }

  /// Returns true if this status is completed (delivered or cancelled).
  bool get isCompleted => this == TicketStatus.delivered || this == TicketStatus.cancelled;

  /// Returns true if this status is cancelled.
  bool get isCancelled => this == TicketStatus.cancelled;
}
