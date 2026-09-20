/// Dashboard & Advanced Analytics Screen.
///
/// Provides deep financial reports, cash-on-shelf tracking, operational efficiency,
/// device distribution charts, and urgent action items for the workshop owner.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../notifications/domain/workshop_alert_model.dart';
import '../../notifications/presentation/notification_center_sheet.dart';
import '../../tickets/domain/ticket_entity.dart';
import '../../tickets/presentation/tickets_cubit.dart';
import '../../tickets/presentation/tickets_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedPeriodIndex = 0; // 0: اليوم, 1: هذا الأسبوع, 2: هذا الشهر, 3: كافة الفترات

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'لوحة التحكم والإحصائيات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'مركز التنبيهات',
            onPressed: () => NotificationCenterSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'تحديث البيانات',
            onPressed: () => context.read<TicketsCubit>().loadTickets(),
          ),
        ],
      ),
      body: BlocBuilder<TicketsCubit, TicketsState>(
        builder: (context, state) {
          final allTickets = state is TicketsLoaded ? state.allTickets : <TicketEntity>[];
          final alerts = WorkshopAlertAnalyzer.analyzeTickets(allTickets);

          // Filter tickets by selected timeframe
          final filteredTickets = _filterTickets(allTickets);

          // ── Financial Metrics ─────────────────────────────────────────────
          final totalEstimated = filteredTickets.fold<double>(
              0.0, (sum, t) => sum + t.estimatedCost);

          final totalLaborCost = filteredTickets.fold<double>(
              0.0, (sum, t) => sum + t.laborCost);

          final totalPartsCost = filteredTickets.fold<double>(
              0.0, (sum, t) => sum + t.partsCost);

          final totalPartsWholesale = filteredTickets.fold<double>(
              0.0,
              (sum, t) =>
                  sum + (t.partsWholesaleCost > 0 ? t.partsWholesaleCost : 0.0));

          final totalPartsProfit = filteredTickets.fold<double>(
              0.0, (sum, t) => sum + t.partsProfit);

          final totalNetProfit = filteredTickets.fold<double>(
              0.0, (sum, t) => sum + t.netProfit);

          // Cash collected: deposits on all active + remaining on delivered in this period
          final totalCollected = filteredTickets.fold<double>(
              0.0,
              (sum, t) =>
                  sum +
                  t.deposit +
                  (t.status == TicketStatus.delivered ? t.remainingAmount : 0.0));

          // Cash on shelf: remaining amounts on devices currently ready for pickup right now
          final cashOnShelf = allTickets
              .where((t) => t.status == TicketStatus.readyForPickup)
              .fold<double>(0.0, (sum, t) => sum + t.remainingAmount);

          // Total outstanding debt (customers owe this right now on active tickets)
          final totalRemaining = allTickets
              .where((t) => !t.status.isCompleted)
              .fold<double>(0.0, (sum, t) => sum + t.remainingAmount);

          // Average ticket value
          final avgTicketValue = filteredTickets.isNotEmpty
              ? totalEstimated / filteredTickets.length
              : 0.0;

          // ── Operational & Speed Metrics ───────────────────────────────────
          final inDiagnosisCount = filteredTickets
              .where((t) => t.status == TicketStatus.inDiagnosis)
              .length;
          final waitingPartCount = filteredTickets
              .where((t) => t.status == TicketStatus.waitingForPart)
              .length;
          final readyCount = filteredTickets
              .where((t) => t.status == TicketStatus.readyForPickup)
              .length;
          final deliveredCount = filteredTickets
              .where((t) => t.status == TicketStatus.delivered)
              .length;
          final cancelledCount = filteredTickets
              .where((t) => t.status == TicketStatus.cancelled)
              .length;

          final completedCount = readyCount + deliveredCount;
          final completionRate = filteredTickets.isNotEmpty
              ? (completedCount / filteredTickets.length) * 100
              : 0.0;

          // ── Device Type Distribution ──────────────────────────────────────
          final mobileCount = filteredTickets
              .where((t) => t.deviceType == DeviceType.mobile)
              .length;
          final laptopCount = filteredTickets
              .where((t) => t.deviceType == DeviceType.laptop)
              .length;
          final watchCount = filteredTickets
              .where((t) => t.deviceType == DeviceType.watch)
              .length;
          final otherCount = filteredTickets.length - mobileCount - laptopCount - watchCount;

          return RefreshIndicator(
            onRefresh: () async => context.read<TicketsCubit>().loadTickets(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Urgent Action Alert Queue (if any alerts exist) ────────
                  if (alerts.isNotEmpty) ...[
                    _UrgentActionBanner(
                      alertCount: alerts.length,
                      firstAlert: alerts.first,
                      onTap: () => NotificationCenterSheet.show(context),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Time Period Filter Chips ──────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FilterChip(
                          label: 'اليوم ☀️',
                          isSelected: _selectedPeriodIndex == 0,
                          onTap: () => setState(() => _selectedPeriodIndex = 0),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'هذا الأسبوع',
                          isSelected: _selectedPeriodIndex == 1,
                          onTap: () => setState(() => _selectedPeriodIndex = 1),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'هذا الشهر',
                          isSelected: _selectedPeriodIndex == 2,
                          onTap: () => setState(() => _selectedPeriodIndex = 2),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'كافة الفترات',
                          isSelected: _selectedPeriodIndex == 3,
                          onTap: () => setState(() => _selectedPeriodIndex = 3),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Workshop Summary & 3:00 AM Closing Banner ─────────────
                  _ClosingScheduleInfoCard(
                    deliveredCount: deliveredCount,
                    totalCollected: totalCollected,
                    cashOnShelf: cashOnShelf,
                    periodIndex: _selectedPeriodIndex,
                  ),

                  const SizedBox(height: 18),

                  // ── Section Title: Financial Deep Dive ────────────────────
                  const _SectionHeader(
                    title: 'التقرير المالي وحركة الخزينة',
                    icon: Icons.account_balance_wallet_outlined,
                    color: Color(0xFF0F766E),
                  ),
                  const SizedBox(height: 10),

                  // Row 0: Net Profit vs Parts Cost
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'صافي أرباح الورشة ✨',
                          value: formatCurrency(totalNetProfit),
                          subtitle: totalPartsProfit > 0
                              ? 'المصنعية (${formatCurrency(totalLaborCost)}) + أرباح القطع (+${formatCurrency(totalPartsProfit)})'
                              : 'المصنعية الصافية المؤكدة',
                          color: const Color(0xFF16A34A),
                          icon: Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          title: 'قطع الغيار ⚙️',
                          value: formatCurrency(totalPartsCost),
                          subtitle: totalPartsWholesale > 0
                              ? 'شراء: ${formatCurrency(totalPartsWholesale)} • مكسب: +${formatCurrency(totalPartsProfit)}'
                              : (totalPartsCost > 0
                                  ? 'إجمالي سعر بيع القطع بالفواتير'
                                  : 'لا توجد قطع مسجلة'),
                          color: const Color(0xFFEA580C),
                          icon: Icons.build_circle_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 1: Actual Cash Collected vs Cash on Shelf
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'المحصل الفعلي بالدرج',
                          value: formatCurrency(totalCollected),
                          subtitle: 'عربون + سداد عند التسليم',
                          color: const Color(0xFF0D9488),
                          icon: Icons.point_of_sale_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          title: 'أموال الرف المعلقة 💰',
                          value: formatCurrency(cashOnShelf),
                          subtitle: 'أجهزة جاهزة بانتظار التحصيل',
                          color: const Color(0xFFF59E0B),
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 2: Total Debt vs Average Ticket Value
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'إجمالي المتبقي بالخارج',
                          value: formatCurrency(totalRemaining),
                          subtitle: 'مستحقات قيد الصيانة والجاهز',
                          color: const Color(0xFFE11D48),
                          icon: Icons.pending_actions_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          title: 'متوسط قيمة الإصلاح',
                          value: formatCurrency(avgTicketValue),
                          subtitle: 'متوسط الفاتورة لكل جهاز',
                          color: TarmeemColors.primaryContainer,
                          icon: Icons.analytics_outlined,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── Section Title: Workshop Pipeline ──────────────────────
                  const _SectionHeader(
                    title: 'خط سير الصيانة والأجهزة الحالية',
                    icon: Icons.timeline_outlined,
                    color: TarmeemColors.primaryContainer,
                  ),
                  const SizedBox(height: 10),

                  // Pipeline Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.85,
                    children: [
                      _PipelineCard(
                        status: 'قيد الفحص والتشخيص',
                        count: inDiagnosisCount,
                        color: TarmeemColors.diagnosisText,
                        bgColor: TarmeemColors.diagnosisBackground,
                        icon: Icons.search_outlined,
                        onTap: () => context.go('/'),
                      ),
                      _PipelineCard(
                        status: 'بانتظار قطع الغيار',
                        count: waitingPartCount,
                        color: TarmeemColors.waitingText,
                        bgColor: TarmeemColors.waitingBackground,
                        icon: Icons.inventory_2_outlined,
                        onTap: () => context.go('/'),
                      ),
                      _PipelineCard(
                        status: 'جاهز للاستلام بالرف',
                        count: readyCount,
                        color: TarmeemColors.readyText,
                        bgColor: TarmeemColors.readyBackground,
                        icon: Icons.check_circle_outlined,
                        onTap: () => context.go('/'),
                      ),
                      _PipelineCard(
                        status: 'تم التسليم بنجاح',
                        count: deliveredCount,
                        color: TarmeemColors.deliveredText,
                        bgColor: TarmeemColors.deliveredBackground,
                        icon: Icons.done_all_outlined,
                        onTap: () => context.go('/'),
                      ),
                    ],
                  ),

                  if (cancelledCount > 0) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => context.go('/'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.cancel_outlined, size: 20, color: Colors.blueGrey),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'أجهزة مسترجعة بدون إصلاح',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.blueGrey.shade800,
                                    ),
                                  ),
                                  Text(
                                    'تم إلغاؤها واسترجاعها للعميل',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white38 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '$cancelledCount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.blueGrey.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  // ── Operational Speed & Success Rate ──────────────────────
                  _OperationalEfficiencyCard(
                    totalTickets: filteredTickets.length,
                    completedTickets: completedCount,
                    completionRate: completionRate,
                    inProgressCount: inDiagnosisCount + waitingPartCount,
                  ),

                  const SizedBox(height: 22),

                  // ── Device Types Distribution ─────────────────────────────
                  _DeviceDistributionCard(
                    isDark: isDark,
                    total: filteredTickets.length,
                    mobileCount: mobileCount,
                    laptopCount: laptopCount,
                    watchCount: watchCount,
                    otherCount: otherCount,
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<TicketEntity> _filterTickets(List<TicketEntity> tickets) {
    if (_selectedPeriodIndex == 3) return tickets; // All time

    final now = DateTime.now();

    bool isInPeriod(DateTime dt) {
      if (_selectedPeriodIndex == 0) {
        // Today (from 00:00 to 23:59)
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      } else if (_selectedPeriodIndex == 1) {
        // This week (last 7 days)
        final weekAgo = now.subtract(const Duration(days: 7));
        return dt.isAfter(weekAgo);
      } else {
        // This month
        return dt.year == now.year && dt.month == now.month;
      }
    }

    return tickets.where((t) {
      if (isInPeriod(t.createdAt)) return true;
      for (final entry in t.statusHistory) {
        if (isInPeriod(entry.timestamp)) return true;
      }
      return false;
    }).toList();
  }
}

// ── Sub-widgets & Components ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: color),
      ],
    );
  }
}

class _UrgentActionBanner extends StatelessWidget {
  const _UrgentActionBanner({
    required this.alertCount,
    required this.firstAlert,
    required this.onTap,
  });

  final int alertCount;
  final WorkshopAlert firstAlert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE11D48).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE11D48).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE11D48),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$alertCount تنبيهات تتطلب تدخلاً سريعاً!',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFFE11D48),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'عرض الكل ❯',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firstAlert.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosingScheduleInfoCard extends StatelessWidget {
  const _ClosingScheduleInfoCard({
    required this.deliveredCount,
    required this.totalCollected,
    required this.cashOnShelf,
    this.periodIndex = 0,
  });

  final int deliveredCount;
  final double totalCollected;
  final double cashOnShelf;
  final int periodIndex;

  String get _deliveredLabel {
    switch (periodIndex) {
      case 1:
        return 'سُلّم الأسبوع';
      case 2:
        return 'سُلّم الشهر';
      case 3:
        return 'إجمالي المسلّم';
      case 0:
      default:
        return 'سُلّم اليوم';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF042F2E),
            Color(0xFF0F766E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.nightlight_round,
                  color: Color(0xFFFBBF24),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'نظام تقرير الإغلاق التلقائي (3:00 ص) 🌙',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'يتم إرسال إشعار ملخص يومي لهاتفك يوضح حصاد الورشة والمتبقي بالرف.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniStat(label: _deliveredLabel, value: '$deliveredCount جهاز'),
                Container(width: 1, height: 24, color: Colors.white24),
                _MiniStat(label: 'المحصل', value: formatCurrency(totalCollected)),
                Container(width: 1, height: 24, color: Colors.white24),
                _MiniStat(label: 'معلق بالرف', value: formatCurrency(cashOnShelf)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _OperationalEfficiencyCard extends StatelessWidget {
  const _OperationalEfficiencyCard({
    required this.totalTickets,
    required this.completedTickets,
    required this.completionRate,
    required this.inProgressCount,
  });

  final int totalTickets;
  final int completedTickets;
  final double completionRate;
  final int inProgressCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${completionRate.toStringAsFixed(0)}% مكتمل',
                  style: const TextStyle(
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                'كفاءة وسرعة إنجاز الورشة',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: totalTickets > 0 ? (completedTickets / totalTickets) : 0,
              minHeight: 10,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'قيد العمل بالورشة: $inProgressCount جهاز',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                ),
              ),
              Text(
                'أجهزة منتهية: $completedTickets من أصل $totalTickets',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceDistributionCard extends StatelessWidget {
  const _DeviceDistributionCard({
    required this.isDark,
    required this.total,
    required this.mobileCount,
    required this.laptopCount,
    required this.watchCount,
    required this.otherCount,
  });

  final bool isDark;
  final int total;
  final int mobileCount;
  final int laptopCount;
  final int watchCount;
  final int otherCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? TarmeemColors.darkSurfaceContainer
            : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إجمالي: $total جهاز',
                style: const TextStyle(
                  fontSize: 11,
                  color: TarmeemColors.outline,
                ),
              ),
              Text(
                'توزيع أنواع الأجهزة المستلمة',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DeviceCountBadge(
                label: 'موبايل',
                count: mobileCount,
                percent: total > 0 ? (mobileCount / total * 100).toInt() : 0,
                icon: Icons.smartphone_outlined,
              ),
              _DeviceCountBadge(
                label: 'لابتوب',
                count: laptopCount,
                percent: total > 0 ? (laptopCount / total * 100).toInt() : 0,
                icon: Icons.laptop_outlined,
              ),
              _DeviceCountBadge(
                label: 'ساعات',
                count: watchCount,
                percent: total > 0 ? (watchCount / total * 100).toInt() : 0,
                icon: Icons.watch_outlined,
              ),
              _DeviceCountBadge(
                label: 'أخرى',
                count: otherCount,
                percent: total > 0 ? (otherCount / total * 100).toInt() : 0,
                icon: Icons.devices_other_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer)
              : (isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLow),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer)
                : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({
    required this.status,
    required this.count,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.onTap,
  });

  final String status;
  final int count;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const Spacer(),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCountBadge extends StatelessWidget {
  const _DeviceCountBadge({
    required this.label,
    required this.count,
    required this.percent,
    required this.icon,
  });

  final String label;
  final int count;
  final int percent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.primaryFixed,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: TarmeemColors.outline,
          ),
        ),
        Text(
          '$percent%',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F766E),
          ),
        ),
      ],
    );
  }
}
