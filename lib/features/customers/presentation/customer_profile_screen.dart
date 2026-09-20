/// Customer Profile screen — Screen 5.
///
/// Shows avatar with initials, stats row, loyalty badge, internal note,
/// full ticket history list, and new ticket CTA.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/url_helper.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/status_badge.dart';
import '../../tickets/domain/ticket_entity.dart';
import 'customer_cubit.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key, required this.customerPhone});
  final String customerPhone;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CustomerCubit>().loadCustomer(widget.customerPhone);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios,
              color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'ملف العميل',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'سجل بيانات وإصلاحات العميل',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.handyman, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
      body: BlocBuilder<CustomerCubit, CustomerState>(
        builder: (context, state) {
          if (state is CustomerLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: TarmeemColors.primaryContainer,
              ),
            );
          }
          if (state is CustomerError) {
            return Center(child: Text(state.message));
          }
          if (state is CustomerLoaded) {
            return _CustomerProfileBody(
              customer: state.customer,
              tickets: state.tickets,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _CustomerProfileBody extends StatelessWidget {
  const _CustomerProfileBody({required this.customer, required this.tickets});
  final dynamic customer;
  final List<TicketEntity> tickets;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          children: [
            const SizedBox(height: 16),
            // ── Avatar + Name ────────────────────────────────────────────
            _CustomerHeader(customer: customer),
            const SizedBox(height: 16),
            // ── Contact buttons ──────────────────────────────────────────
            _ContactButtons(phone: customer.phone),
            const SizedBox(height: 16),
            // ── Stats ────────────────────────────────────────────────────
            _StatsSection(customer: customer),
            const SizedBox(height: 16),
            // ── Internal note ────────────────────────────────────────────
            if (customer.internalNote != null)
              _InternalNote(note: customer.internalNote!),
            const SizedBox(height: 16),
            // ── Ticket history ────────────────────────────────────────────
            _TicketHistory(tickets: tickets),
          ],
        ),
        // ── Sticky bottom CTA ─────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? TarmeemColors.darkSurfaceContainer
                  : TarmeemColors.surfaceContainerLowest,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? TarmeemColors.darkCardBorder
                      : TarmeemColors.surfaceContainerHigh,
                ),
              ),
            ),
            child: PrimaryButton(
              label: 'تسجيل غرض جديد لهذا العميل',
              icon: const Icon(Icons.add_box_outlined, size: 20),
              onPressed: () => context.push(
                '/ticket/new',
                extra: {
                  'customerName': customer.name as String,
                  'customerPhone': customer.phone as String,
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({required this.customer});
  final dynamic customer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
      ),
      child: Row(
        children: [
          // Edit icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
            ),
            child: Icon(Icons.edit_outlined,
                size: 18, color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
          ),
          const Spacer(),
          // Name + loyalty badge + phone
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                customer.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              if (customer.isLoyal)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? TarmeemColors.darkReadyBackground : TarmeemColors.readyBackground,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: isDark ? TarmeemColors.darkReadyBorder : TarmeemColors.readyBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🟢', style: TextStyle(fontSize: 8)),
                      const SizedBox(width: 4),
                      Text(
                        'عميل دائم وموثوق',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                '+20 ${customer.phone}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                customer.name.isNotEmpty ? customer.name[0] : '؟',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactButtons extends StatelessWidget {
  const _ContactButtons({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PrimaryButton(
            label: 'مراسلة واتساب',
            icon: const Icon(Icons.chat_outlined, size: 18),
            onPressed: () => UrlHelper.openWhatsApp(
              phone: phone,
              context: context,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SecondaryButton(
            label: 'اتصال هاتفي',
            icon: const Icon(Icons.phone_outlined, size: 18),
            onPressed: () => UrlHelper.makePhoneCall(
              phone,
              context: context,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.customer});
  final dynamic customer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatBox(
          icon: Icons.schedule_outlined,
          label: 'التزام بالمواعيد',
          value: '${customer.attendanceRate}%',
          color: TarmeemColors.readyText,
        ),
        const SizedBox(width: 10),
        _StatBox(
          icon: Icons.payments_outlined,
          label: 'إجمالي التعاملات (ج.م)',
          value: formatCurrency(customer.totalTransactions,
              currencySymbol: ''),
          color: TarmeemColors.primaryContainer,
        ),
        const SizedBox(width: 10),
        _StatBox(
          icon: Icons.watch_outlined,
          label: 'أغراض مصلحة',
          value: customer.ticketCount.toString(),
          color: TarmeemColors.secondary,
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _InternalNote extends StatelessWidget {
  const _InternalNote({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isDark ? TarmeemColors.darkDiagnosisDot : TarmeemColors.diagnosisDot;
    final textColor = isDark ? TarmeemColors.darkDiagnosisText : TarmeemColors.diagnosisText;
    final bgColor = isDark ? TarmeemColors.darkDiagnosisBackground : TarmeemColors.diagnosisBackground;
    final borderColor = isDark ? TarmeemColors.darkDiagnosisBorder : TarmeemColors.diagnosisBorder;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'مرئي للفريق فقط',
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ملاحظة الورشة الداخلية:',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.sticky_note_2_outlined,
                      size: 16, color: dotColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                  height: 1.6,
                ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _TicketHistory extends StatelessWidget {
  const _TicketHistory({required this.tickets});
  final List<TicketEntity> tickets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            Text(
              'مرتب بالأحدث',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: TarmeemColors.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? TarmeemColors.primary : TarmeemColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  tickets.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'سجل الأغراض والتذاكر',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tickets.map((ticket) => _HistoryTicketCard(ticket: ticket)),
      ],
    );
  }
}

class _HistoryTicketCard extends StatelessWidget {
  const _HistoryTicketCard({required this.ticket});
  final TicketEntity ticket;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = !ticket.status.isCompleted;

    return Material(
      color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => context.push('/ticket/${ticket.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? (isDark ? TarmeemColors.primary.withValues(alpha: 0.4) : TarmeemColors.primaryContainer.withValues(alpha: 0.2))
                  : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Header
              Row(
                children: [
                  StatusBadge(status: ticket.status, compact: true),
                  const Spacer(),
                  Text(
                    '#${ticket.ticketNumber}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Device model
              Text(
                ticket.deviceModel,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 6),
              // Issue
              Text(
                ticket.issueDescription,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Date + amount
              Row(
                children: [
                  if (ticket.status == TicketStatus.delivered)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 14, color: isDark ? TarmeemColors.darkReadyDot : TarmeemColors.readyDot),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'مدفوع بالكامل: ${formatCurrency(ticket.estimatedCost)}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (ticket.status == TicketStatus.cancelled)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cancel_outlined,
                              size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              ticket.estimatedCost > 0
                                  ? 'رسوم فحص: ${formatCurrency(ticket.estimatedCost)}'
                                  : 'مسترجع بدون إصلاح',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (ticket.remainingAmount > 0)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.monetization_on_outlined,
                              size: 14, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'المتبقي: ${formatCurrency(ticket.remainingAmount)}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (ticket.estimatedCost <= 0)
                    Flexible(
                      child: Text(
                        ticket.deposit > 0 ? 'عربون: ${formatCurrency(ticket.deposit)} 🔍' : 'قيد الفحص 🔍',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: TarmeemColors.outline),
                      const SizedBox(width: 4),
                      Text(
                        formatDateArabic(ticket.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: TarmeemColors.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isActive) ...[
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'عرض تفاصيل وإجراءات الغرض',
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  onPressed: () => context.push('/ticket/${ticket.id}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
