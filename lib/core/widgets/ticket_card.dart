// Ticket card widget — Redesigned for production clarity, fast actions,
// and high visual contrast.
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/url_helper.dart';
import '../../../core/widgets/status_badge.dart';
import '../../features/tickets/domain/ticket_entity.dart';

class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.ticket,
    this.onTap,
    this.onWhatsAppTap,
    this.onStatusTap,
    this.onTrackTap,
  });

  final TicketEntity ticket;
  final VoidCallback? onTap;
  final VoidCallback? onWhatsAppTap;
  final VoidCallback? onStatusTap;
  final VoidCallback? onTrackTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isReady = ticket.status == TicketStatus.readyForPickup;
    final isDelivered = ticket.status == TicketStatus.delivered;
    final isCancelled = ticket.status == TicketStatus.cancelled;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? TarmeemColors.darkSurfaceContainer
            : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isReady
              ? const Color(0xFF10B981)
              : (isCancelled
                  ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.7) : const Color(0xFFFECACA))
                  : (isDelivered
                      ? (isDark ? TarmeemColors.darkOutlineVariant.withValues(alpha: 0.6) : TarmeemColors.outlineVariant.withValues(alpha: 0.6))
                      : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder))),
          width: isReady ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isReady
                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Row 1: Device Model, Ticket # & Status ─────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge (Left in RTL)
                    GestureDetector(
                      onTap: onStatusTap ?? onTap,
                      child: StatusBadge(status: ticket.status),
                    ),

                    const SizedBox(width: 10),

                    // Device details (Center/Right in RTL)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  ticket.deviceModel,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                                    letterSpacing: 0.1,
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#${ticket.ticketNumber}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (ticket.issueDescription.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              ticket.issueDescription,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Device Icon Avatar
                    _DeviceTypeAvatar(deviceType: ticket.deviceType),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(height: 1, thickness: 0.8, color: isDark ? TarmeemColors.darkOutlineVariant : const Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // ── Row 2: Customer info + Remaining Amount / Financials ────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Financial Badge (Left in RTL)
                    Builder(
                      builder: (context) {
                        final isUnestimated = ticket.estimatedCost <= 0;
                        final Color badgeBg;
                        final Color badgeBorder;
                        final Color badgeTextColor;
                        final String badgeText;
                        final IconData? badgeIcon;

                        if (isDelivered) {
                          badgeBg = isDark ? TarmeemColors.darkDeliveredBackground : TarmeemColors.deliveredBackground;
                          badgeBorder = isDark ? TarmeemColors.darkDeliveredBorder : TarmeemColors.deliveredBorder;
                          badgeTextColor = isDark ? TarmeemColors.darkDeliveredText : TarmeemColors.deliveredText;
                          badgeText = 'مسدد بالكامل ✅';
                          badgeIcon = null;
                        } else if (isUnestimated) {
                          if (ticket.deposit > 0) {
                            badgeBg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7);
                            badgeBorder = isDark ? const Color(0xFFB45309).withValues(alpha: 0.5) : const Color(0xFFFDE68A);
                            badgeTextColor = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
                            badgeText = 'عربون: ${formatCurrency(ticket.deposit)} 🔍';
                            badgeIcon = Icons.payments_outlined;
                          } else {
                            badgeBg = isDark ? TarmeemColors.darkSurfaceContainerHigh : const Color(0xFFF1F5F9);
                            badgeBorder = isDark ? TarmeemColors.darkOutlineVariant : const Color(0xFFE2E8F0);
                            badgeTextColor = isDark ? TarmeemColors.darkOnSurfaceVariant : const Color(0xFF475569);
                            badgeText = 'قيد الفحص 🔍';
                            badgeIcon = null;
                          }
                        } else if (ticket.remainingAmount > 0) {
                          badgeBg = isReady
                              ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7))
                              : (isDark ? TarmeemColors.darkSurfaceContainerHigh : const Color(0xFFF8FAFC));
                          badgeBorder = isReady
                              ? (isDark ? const Color(0xFFB45309).withValues(alpha: 0.5) : const Color(0xFFF59E0B))
                              : (isDark ? TarmeemColors.darkOutlineVariant : const Color(0xFFE2E8F0));
                          badgeTextColor = isReady
                              ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309))
                              : (isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface);
                          badgeText = 'المتبقي: ${formatCurrency(ticket.remainingAmount)}';
                          badgeIcon = isReady ? Icons.monetization_on_outlined : null;
                        } else {
                          badgeBg = isDark ? TarmeemColors.darkReadyBackground : TarmeemColors.readyBackground;
                          badgeBorder = isDark ? TarmeemColors.darkReadyBorder : TarmeemColors.readyBorder;
                          badgeTextColor = isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText;
                          badgeText = 'خالص الحساب ✅';
                          badgeIcon = null;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: badgeBorder, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (badgeIcon != null) ...[
                                Icon(badgeIcon, size: 13, color: badgeTextColor),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                badgeText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: badgeTextColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Customer Name & Phone (Right in RTL)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              ticket.customerName,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              formatEgyptianPhone(ticket.customerPhone),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person_rounded,
                              size: 16, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Row 3: Action Buttons (WhatsApp, Call, SMS) & Meta ──────
                Row(
                  children: [
                    // Action Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // WhatsApp
                        _ActionButton(
                          icon: Icons.chat_rounded,
                          label: 'واتساب',
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                          bgColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFD1FAE5),
                          onTap: () {
                            if (onWhatsAppTap != null) {
                              onWhatsAppTap!();
                            } else {
                              _openWhatsAppFromCard(context);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        // Call
                        _ActionButton(
                          icon: Icons.phone_rounded,
                          label: 'اتصال',
                          color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                          bgColor: isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed,
                          onTap: () => UrlHelper.makePhoneCall(
                            ticket.customerPhone,
                            context: context,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // SMS
                        _ActionButton(
                          icon: Icons.sms_outlined,
                          label: 'SMS',
                          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                          bgColor: isDark ? const Color(0xFF312E81).withValues(alpha: 0.5) : const Color(0xFFEEF2FF),
                          onTap: () => _openSmsFromCard(context),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Time elapsed + Shelf if present
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ticket.shelfLocation != null &&
                            ticket.shelfLocation!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ticket.shelfLocation!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? TarmeemColors.darkSecondary : TarmeemColors.secondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Builder(builder: (ctx) {
                          final daysSince = DateTime.now()
                              .difference(ticket.createdAt)
                              .inDays;
                          final isOld = !isDelivered && daysSince >= 7;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isDelivered
                                    ? formatRelativeTime(ticket.createdAt)
                                    : (daysSince == 0
                                        ? 'اليوم'
                                        : 'منذ $daysSince ${daysSince == 1 ? "يوم" : "أيام"}'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isOld
                                      ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                      : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline),
                                  fontWeight:
                                      isOld ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: isOld
                                    ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                    : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSmsFromCard(BuildContext context) {
    final cleanPhone = ticket.customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم هاتف العميل غير مسجل أو فارغ.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final shop = ticket.shopName ?? AppConstants.defaultShopName;
    final String message;
    if (ticket.status == TicketStatus.readyForPickup) {
      message =
          'أهلاً بك أ/ ${ticket.customerName}، جهازك (${ticket.deviceModel}) جاهز للاستلام بورشة $shop. المتبقي: ${formatCurrency(ticket.remainingAmount)}. رابط الفاتورة: ${buildTrackingUrl(ticket.ticketNumber)}';
    } else if (ticket.status == TicketStatus.delivered) {
      message =
          'شكراً لثقتكم بورشة $shop أ/ ${ticket.customerName}. تم تسليم جهازك (${ticket.deviceModel}) بنجاح. رابط الفاتورة: ${buildTrackingUrl(ticket.ticketNumber)}';
    } else {
      message =
          'أهلاً بك أ/ ${ticket.customerName}، تم تسجيل تذكرة صيانة لجهازك (${ticket.deviceModel}) برقم #${ticket.ticketNumber} بورشة $shop. رابط المتابعة: ${buildTrackingUrl(ticket.ticketNumber)}';
    }

    UrlHelper.sendSms(
      phone: ticket.customerPhone,
      message: message,
      context: context,
    );
  }

  void _openWhatsAppFromCard(BuildContext context) {
    final cleanPhone = ticket.customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم هاتف العميل غير مسجل أو فارغ.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final shop = ticket.shopName ?? AppConstants.defaultShopName;
    final String message;
    if (ticket.status == TicketStatus.readyForPickup) {
      message = buildReadyForPickupMessage(
        customerName: ticket.customerName,
        deviceModel: ticket.deviceModel,
        remainingAmount: ticket.remainingAmount,
        shopName: shop,
        ticketNumber: ticket.ticketNumber,
        ticketId: ticket.id,
        estimatedCost: ticket.estimatedCost,
        partsCost: ticket.partsCost,
        laborCost: ticket.laborCost,
        deposit: ticket.deposit,
        partsDescription: ticket.partsDescription,
      );
    } else if (ticket.status == TicketStatus.delivered) {
      message = buildDeliveredThankYouMessage(
        customerName: ticket.customerName,
        deviceModel: ticket.deviceModel,
        shopName: shop,
        ticketNumber: ticket.ticketNumber,
        ticketId: ticket.id,
        totalPaid: ticket.estimatedCost > 0 ? ticket.estimatedCost : ticket.deposit,
        remainingAmount: ticket.remainingAmount,
      );
    } else if (ticket.status == TicketStatus.cancelled) {
      message = buildCancelledPickupMessage(
        customerName: ticket.customerName,
        deviceModel: ticket.deviceModel,
        shopName: shop,
        ticketNumber: ticket.ticketNumber,
        ticketId: ticket.id,
        inspectionFee: ticket.estimatedCost,
        remainingAmount: ticket.remainingAmount,
      );
    } else {
      message = buildNewTicketReceiptMessage(
        customerName: ticket.customerName,
        ticketNumber: ticket.ticketNumber,
        deviceModel: ticket.deviceModel,
        estimatedCost: ticket.estimatedCost,
        deposit: ticket.deposit,
        remainingAmount: ticket.remainingAmount,
        shopName: shop,
        ticketId: ticket.id,
        partsCost: ticket.partsCost,
        partsDescription: ticket.partsDescription,
      );
    }

    UrlHelper.openWhatsApp(
      phone: ticket.customerPhone,
      message: message,
      context: context,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _DeviceTypeAvatar extends StatelessWidget {
  const _DeviceTypeAvatar({required this.deviceType});
  final DeviceType deviceType;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (deviceType) {
      case DeviceType.mobile:
        icon = Icons.smartphone_outlined;
      case DeviceType.laptop:
        icon = Icons.laptop_outlined;
      case DeviceType.watch:
        icon = Icons.watch_outlined;
      case DeviceType.home:
        icon = Icons.kitchen_outlined;
      case DeviceType.other:
        icon = Icons.build_outlined;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
    );
  }
}
