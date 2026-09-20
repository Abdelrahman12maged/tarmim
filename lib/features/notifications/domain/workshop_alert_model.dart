import '../../../core/constants/app_constants.dart';
import '../../tickets/domain/ticket_entity.dart';

/// Categories of alerts relevant to the workshop owner.
enum WorkshopAlertType {
  overdue,          // Delayed diagnosis (>48h)
  waitingPart,      // Blocked on spare parts
  readyUnclaimed,   // Finished & ready, customer hasn't picked up (>3 days)
  closingRecap,     // 3:00 AM closing report
  morningBriefing,  // 10:00 AM morning schedule
}

/// Urgency level for badge color and sorting.
enum AlertUrgency {
  high,    // Red - requires urgent attention
  medium,  // Orange/Amber - requires follow-up
  info,    // Teal/Blue - informational
}

/// Actionable alert model presented to the workshop owner.
class WorkshopAlert {
  final String id;
  final WorkshopAlertType type;
  final String title;
  final String message;
  final AlertUrgency urgency;
  final DateTime timestamp;
  final String? ticketId;
  final String? ticketNumber;
  final String? customerName;
  final String? customerPhone;
  final String? deviceModel;
  final double? remainingAmount;
  final int daysElapsed;

  const WorkshopAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.urgency,
    required this.timestamp,
    this.ticketId,
    this.ticketNumber,
    this.customerName,
    this.customerPhone,
    this.deviceModel,
    this.remainingAmount,
    this.daysElapsed = 0,
  });
}

/// Smart engine that scans workshop tickets and generates real-time actionable alerts.
class WorkshopAlertAnalyzer {
  static List<WorkshopAlert> analyzeTickets(List<TicketEntity> tickets) {
    final alerts = <WorkshopAlert>[];
    final now = DateTime.now();

    for (final ticket in tickets) {
      final daysSinceCreated = now.difference(ticket.createdAt).inDays;
      final hoursSinceCreated = now.difference(ticket.createdAt).inHours;

      // 1. Overdue diagnosis (> 48 hours without diagnosis)
      if (ticket.status == TicketStatus.inDiagnosis && hoursSinceCreated >= 48) {
        alerts.add(
          WorkshopAlert(
            id: 'overdue_${ticket.id}',
            type: WorkshopAlertType.overdue,
            title: 'جهاز متأخر في الفحص (${ticket.deviceModel})',
            message: 'مر على استلام جهاز ${ticket.customerName} أكثر من $daysSinceCreated أيام وما زال قيد التشخيص.',
            urgency: AlertUrgency.high,
            timestamp: ticket.createdAt,
            ticketId: ticket.id,
            ticketNumber: ticket.ticketNumber,
            customerName: ticket.customerName,
            customerPhone: ticket.customerPhone,
            deviceModel: ticket.deviceModel,
            remainingAmount: ticket.remainingAmount,
            daysElapsed: daysSinceCreated,
          ),
        );
      }

      // 2. Waiting for spare parts (> 24 hours)
      if (ticket.status == TicketStatus.waitingForPart) {
        alerts.add(
          WorkshopAlert(
            id: 'part_${ticket.id}',
            type: WorkshopAlertType.waitingPart,
            title: 'متابعة قطعة غيار (${ticket.deviceModel})',
            message: 'جهاز ${ticket.customerName} معلق بانتظار توفير القطعة. تواصل مع الموردين لإنجازه.',
            urgency: AlertUrgency.medium,
            timestamp: ticket.createdAt,
            ticketId: ticket.id,
            ticketNumber: ticket.ticketNumber,
            customerName: ticket.customerName,
            customerPhone: ticket.customerPhone,
            deviceModel: ticket.deviceModel,
            remainingAmount: ticket.remainingAmount,
            daysElapsed: daysSinceCreated,
          ),
        );
      }

      // 3. Ready for pickup but unclaimed (> 2 days) — Money on the shelf!
      if (ticket.status == TicketStatus.readyForPickup) {
        final readyHistory = ticket.statusHistory.where((h) => h.status == TicketStatus.readyForPickup);
        final readyDate = readyHistory.isNotEmpty ? readyHistory.last.timestamp : ticket.createdAt;
        final daysReady = now.difference(readyDate).inDays;

        if (daysReady >= 2) {
          final formattedAmount = ticket.remainingAmount > 0
              ? 'متبقي ${ticket.remainingAmount.toStringAsFixed(0)} ج.م'
              : 'خالص بالكامل';

          alerts.add(
            WorkshopAlert(
              id: 'unclaimed_${ticket.id}',
              type: WorkshopAlertType.readyUnclaimed,
              title: 'جهاز جاهز لم يُستلم (${ticket.deviceModel})',
              message: 'انتهت صيانة جهاز ${ticket.customerName} منذ $daysReady أيام في الرف ($formattedAmount). أرسل له تذكيراً بالاستلام.',
              urgency: AlertUrgency.high,
              timestamp: readyDate,
              ticketId: ticket.id,
              ticketNumber: ticket.ticketNumber,
              customerName: ticket.customerName,
              customerPhone: ticket.customerPhone,
              deviceModel: ticket.deviceModel,
              remainingAmount: ticket.remainingAmount,
              daysElapsed: daysReady,
            ),
          );
        }
      }
    }

    // Sort by Urgency (high first), then by newest
    alerts.sort((a, b) {
      if (a.urgency != b.urgency) {
        return a.urgency.index.compareTo(b.urgency.index);
      }
      return b.timestamp.compareTo(a.timestamp);
    });

    return alerts;
  }
}
