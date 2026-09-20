import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../tickets/presentation/tickets_cubit.dart';
import '../../tickets/presentation/tickets_state.dart';
import '../domain/workshop_alert_model.dart';

/// Interactive modal bottom sheet displaying real-time actionable workshop alerts.
class NotificationCenterSheet extends StatefulWidget {
  const NotificationCenterSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationCenterSheet(),
    );
  }

  @override
  State<NotificationCenterSheet> createState() => _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<NotificationCenterSheet> {
  int _selectedFilterIndex = 0; // 0: الكل, 1: عاجل, 2: أموال معلقة, 3: قطع غيار

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BlocBuilder<TicketsCubit, TicketsState>(
          builder: (context, state) {
            final tickets = state is TicketsLoaded ? state.allTickets : [];
            final allAlerts = WorkshopAlertAnalyzer.analyzeTickets(tickets.cast());

            // Filter alerts
            final filteredAlerts = allAlerts.where((alert) {
              if (_selectedFilterIndex == 1) return alert.urgency == AlertUrgency.high;
              if (_selectedFilterIndex == 2) return alert.type == WorkshopAlertType.readyUnclaimed;
              if (_selectedFilterIndex == 3) return alert.type == WorkshopAlertType.waitingPart;
              return true;
            }).toList();

            return Column(
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Header Row ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active,
                          color: Color(0xFF0F766E),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تنبيهات الورشة التفاعلية',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            allAlerts.isEmpty
                                ? 'لا توجد أجهزة متأخرة حالياً'
                                : '${allAlerts.length} أمور تتطلب انتباهك ومتابعتك',
                            style: TextStyle(
                              fontSize: 12,
                              color: allAlerts.isEmpty ? Colors.green : const Color(0xFFE11D48),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // ── Filter Chips ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterTab(
                          label: 'الكل (${allAlerts.length})',
                          isSelected: _selectedFilterIndex == 0,
                          onTap: () => setState(() => _selectedFilterIndex = 0),
                        ),
                        const SizedBox(width: 8),
                        _FilterTab(
                          label: 'عاجل ⚠️',
                          isSelected: _selectedFilterIndex == 1,
                          onTap: () => setState(() => _selectedFilterIndex = 1),
                        ),
                        const SizedBox(width: 8),
                        _FilterTab(
                          label: 'أموال معلقة 💰',
                          isSelected: _selectedFilterIndex == 2,
                          onTap: () => setState(() => _selectedFilterIndex = 2),
                        ),
                        const SizedBox(width: 8),
                        _FilterTab(
                          label: 'قطع غيار ⏳',
                          isSelected: _selectedFilterIndex == 3,
                          onTap: () => setState(() => _selectedFilterIndex = 3),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),

                // ── Alerts List ─────────────────────────────────────────────
                Expanded(
                  child: filteredAlerts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified_rounded,
                                    size: 54,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'كل شيء يسير بسلاسة! 🎉',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'لا توجد أجهزة متأخرة أو أموال معلقة بالرف في هذا التصنيف.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredAlerts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final alert = filteredAlerts[index];
                            return _AlertCard(alert: alert);
                          },
                        ),
                ),

                // ── Footer: 3:00 AM Reminder Note ───────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  child: Row(
                    children: [
                      const Icon(Icons.nightlight_round, size: 16, color: Color(0xFF0F766E)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'تقرير الإغلاق الليلي يصلك تلقائياً يومياً في تمام الساعة 3:00 فجراً 🌙',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final WorkshopAlert alert;

  Color _getUrgencyColor() {
    switch (alert.urgency) {
      case AlertUrgency.high:
        return const Color(0xFFE11D48);
      case AlertUrgency.medium:
        return const Color(0xFFF59E0B);
      case AlertUrgency.info:
        return const Color(0xFF0F766E);
    }
  }

  IconData _getIcon() {
    switch (alert.type) {
      case WorkshopAlertType.overdue:
        return Icons.warning_amber_rounded;
      case WorkshopAlertType.waitingPart:
        return Icons.inventory_2_outlined;
      case WorkshopAlertType.readyUnclaimed:
        return Icons.payments_outlined;
      default:
        return Icons.info_outline;
    }
  }

  void _sendWhatsAppReminder(BuildContext context) async {
    final phone = alert.customerPhone ?? '';
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final internationalPhone = cleanPhone.startsWith('0')
        ? '20${cleanPhone.substring(1)}'
        : (cleanPhone.startsWith('20') ? cleanPhone : '20$cleanPhone');

    final ticketNum = (alert.ticketNumber != null && alert.ticketNumber!.isNotEmpty)
        ? alert.ticketNumber!
        : (alert.ticketId != null && alert.ticketId!.length >= 6
            ? alert.ticketId!.substring(0, 6)
            : (alert.ticketId ?? ''));
    final trackingUrl = buildTrackingUrl(ticketNum);

    String message = '';
    if (alert.type == WorkshopAlertType.readyUnclaimed) {
      final rem = alert.remainingAmount != null && alert.remainingAmount! > 0
          ? 'المبلغ المتبقي: ${alert.remainingAmount!.toStringAsFixed(0)} ج.م'
          : 'الحساب خالص بالكامل';
      message = 'مرحباً ${alert.customerName}، نود إعلامك بأن جهازك (${alert.deviceModel}) جاهز للاستلام بورشة الصيانة 🎉.\n'
          'رقم التذكرة: #$ticketNum\n$rem\n'
          'يمكنك الاطلاع على التقرير: $trackingUrl\n'
          'نسعد بزيارتك في مواعيد العمل.';
    } else {
      message = 'مرحباً ${alert.customerName}، نتابع معك صيانة جهازك (${alert.deviceModel}) برقم تذكرة #$ticketNum.\n'
          'يمكنك متابعة الحالة لحظياً عبر الرابط: $trackingUrl';
    }

    final url = Uri.parse('https://wa.me/$internationalPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _callCustomer() async {
    final phone = alert.customerPhone ?? '';
    if (phone.isEmpty) return;
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getUrgencyColor();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getIcon(), size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'منذ ${alert.daysElapsed} يوم',
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            alert.message,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Action Buttons Row ─────────────────────────────────────────
          Row(
            children: [
              // WhatsApp reminder button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _sendWhatsAppReminder(context),
                  icon: const Icon(Icons.chat_bubble_outline, size: 15),
                  label: const Text('واتساب تذكير', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Call button
              IconButton.filledTonal(
                tooltip: 'اتصال بالعميل',
                onPressed: _callCustomer,
                icon: const Icon(Icons.phone_outlined, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // View ticket details button
              if (alert.ticketId != null)
                IconButton.filledTonal(
                  tooltip: 'عرض التذكرة',
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/ticket/${alert.ticketId}');
                  },
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
