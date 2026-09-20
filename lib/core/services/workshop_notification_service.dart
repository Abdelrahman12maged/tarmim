import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service for native on-device push notifications and automated schedules.
/// Specifically configured for the workshop owner's daily routine:
/// - 3:00 AM Daily Closing Recap (تقرير الإغلاق الليلي)
/// - 10:00 AM Daily Morning Schedule (الملخص الصباحي)
/// - Instant actionable alerts for overdue/unclaimed tickets
class WorkshopNotificationService {
  static final WorkshopNotificationService _instance = WorkshopNotificationService._internal();
  factory WorkshopNotificationService() => _instance;
  WorkshopNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String channelId = 'tarmim_workshop_alerts_v1';
  static const String channelName = 'تنبيهات ورشة تِرميم';
  static const String channelDescription = 'إشعارات تقارير الإغلاق، الأجهزة المتأخرة، وتنبيهات الصيانة اليومية';

  static const int idClosingRecap = 1001;
  static const int idMorningBriefing = 1002;
  static const int idImmediateAlert = 1003;

  /// Initializes timezone and platform notification settings.
  Future<void> init() async {
    if (kIsWeb) return; // Native notifications are mobile/desktop only
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification tapped with payload: ${response.payload}');
        },
      );

      // Create Android Notification Channel
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

        // Request runtime permission on Android 13+
        await androidPlugin.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('WorkshopNotificationService initialized successfully.');
    } catch (e) {
      debugPrint('Error initializing WorkshopNotificationService: $e');
    }
  }

  NotificationDetails _getNotificationDetails({String? subText}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        subText: subText ?? 'تِرميم',
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Sends an immediate local notification (e.g. for testing or high-priority alerts).
  Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? subText,
  }) async {
    if (kIsWeb || !_isInitialized) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        _getNotificationDetails(subText: subText),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing immediate notification: $e');
    }
  }

  /// Schedules recurring Daily Closing Recap at exactly 3:00 AM.
  Future<void> scheduleDailyClosingRecap({
    required int deliveredCount,
    required double totalRevenue,
    required int readyWaitingCount,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        3, // 03:00 AM
        0,
      );

      // If 3:00 AM already passed today, schedule for tomorrow 3:00 AM
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final formattedRev = totalRevenue.toStringAsFixed(0);
      final body = 'أهلاً بك! إنجاز اليوم: سلّمت $deliveredCount جهاز، وحصّلت $formattedRev ج.م. '
          'يوجد $readyWaitingCount جهاز بالرف جاهز للاستلام.';

      await _plugin.zonedSchedule(
        idClosingRecap,
        '📊 تقرير إغلاق الورشة (3:00 ص)',
        body,
        scheduledDate,
        _getNotificationDetails(subText: 'تقرير الإغلاق'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeats daily at 3:00 AM
      );

      debugPrint('Scheduled 3:00 AM Closing Recap at: $scheduledDate');
    } catch (e) {
      debugPrint('Error scheduling closing recap: $e');
    }
  }

  /// Schedules recurring Daily Morning Briefing at 10:00 AM.
  Future<void> scheduleDailyMorningBriefing({
    required int inDiagnosisCount,
    required int readyCount,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        10, // 10:00 AM
        0,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final body = 'صباح الخير ☀️! جدول عمل الورشة اليوم: لديك $inDiagnosisCount أجهزة قيد الفحص، و$readyCount أجهزة جاهزة للتسليم.';

      await _plugin.zonedSchedule(
        idMorningBriefing,
        '☀️ جدول صيانة اليوم (10:00 ص)',
        body,
        scheduledDate,
        _getNotificationDetails(subText: 'صباح الخير'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeats daily at 10:00 AM
      );

      debugPrint('Scheduled 10:00 AM Morning Briefing at: $scheduledDate');
    } catch (e) {
      debugPrint('Error scheduling morning briefing: $e');
    }
  }
}
