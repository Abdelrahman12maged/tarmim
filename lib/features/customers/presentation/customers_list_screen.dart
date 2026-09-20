/// Customers List screen — shows all workshop customers derived from tickets.
///
/// Supports search by name or phone, view total devices, outstanding balance,
/// and quick WhatsApp or profile navigation.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/url_helper.dart';
import '../../tickets/domain/ticket_entity.dart';
import '../../tickets/presentation/tickets_cubit.dart';
import '../../tickets/presentation/tickets_state.dart';

class _CustomerSummary {
  _CustomerSummary({
    required this.name,
    required this.phone,
    required this.totalTickets,
    required this.activeTickets,
    required this.totalRemaining,
    required this.latestTicket,
  });

  final String name;
  final String phone;
  final int totalTickets;
  final int activeTickets;
  final double totalRemaining;
  final TicketEntity latestTicket;
}

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_CustomerSummary> _deriveCustomers(List<TicketEntity> tickets) {
    final map = <String, List<TicketEntity>>{};
    for (final t in tickets) {
      if (t.customerPhone.isEmpty) continue;
      map.putIfAbsent(t.customerPhone, () => []).add(t);
    }

    final list = <_CustomerSummary>[];
    map.forEach((phone, customerTickets) {
      final name = customerTickets.first.customerName.isNotEmpty
          ? customerTickets.first.customerName
          : 'عميل غير مسجل';
      final active = customerTickets
          .where((t) => !t.status.isCompleted)
          .length;
      final remaining = customerTickets.fold<double>(
        0,
        (sum, t) => sum + (!t.status.isCompleted ? t.remainingAmount : 0),
      );

      list.add(_CustomerSummary(
        name: name,
        phone: phone,
        totalTickets: customerTickets.length,
        activeTickets: active,
        totalRemaining: remaining,
        latestTicket: customerTickets.first,
      ));
    });

    if (_searchQuery.trim().isEmpty) return list;

    final q = _searchQuery.trim().toLowerCase();
    return list.where((c) {
      return c.name.toLowerCase().contains(q) || c.phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios,
              color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'قائمة العملاء',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
          ),
        ),
      ),
      body: BlocBuilder<TicketsCubit, TicketsState>(
        builder: (context, state) {
          if (state is TicketsLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
              ),
            );
          }

          final allTickets = state is TicketsLoaded ? state.allTickets : <TicketEntity>[];
          final customers = _deriveCustomers(allTickets);

          return Column(
            children: [
              // Search box
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? TarmeemColors.darkOnSurface : null,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم العميل أو رقم الهاتف...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant).withValues(alpha: 0.6),
                    ),
                    hintTextDirection: TextDirection.rtl,
                    prefixIcon: Icon(Icons.search,
                        color: isDark ? TarmeemColors.darkOutline : TarmeemColors.outline, size: 20),
                    filled: true,
                    fillColor: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLowest,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? TarmeemColors.darkOutlineVariant : TarmeemColors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? TarmeemColors.darkOutlineVariant : TarmeemColors.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.secondary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // Total count banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${customers.length} عميل',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'سجل عملاء الورشة',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Customers List
              Expanded(
                child: customers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 56,
                              color: TarmeemColors.outlineVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'لا توجد نتائج مطابقة لبحثك'
                                  : 'لا يوجد عملاء مسجلين حتى الآن',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: TarmeemColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        itemCount: customers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final c = customers[index];
                          return _CustomerCard(
                            customer: c,
                            onTap: () => context.push('/customer/${c.phone}'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onTap,
  });

  final _CustomerSummary customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasActive = customer.activeTickets > 0;
    final hasDebt = customer.totalRemaining > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasDebt
              ? (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.5) : TarmeemColors.error.withValues(alpha: 0.3))
              : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
          width: hasDebt ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                // ── Top Row: Quick Actions (Left in RTL) & Avatar + Info (Right in RTL) ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Quick Action Buttons (Left side in RTL)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // WhatsApp Button
                        Material(
                          color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => UrlHelper.openWhatsApp(
                              phone: customer.phone,
                              context: context,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.chat_outlined,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Call Button
                        Material(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => UrlHelper.makePhoneCall(
                              customer.phone,
                              context: context,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.phone_outlined,
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 12),

                    // Customer Name & Phone (Right side in RTL)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            customer.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                formatEgyptianPhone(customer.phone),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.phone_iphone_outlined,
                                size: 13,
                                color: isDark ? TarmeemColors.darkOutline : TarmeemColors.outline,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Avatar (Far Right in RTL)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  TarmeemColors.darkPrimaryContainer,
                                  const Color(0xFF0F172A),
                                ]
                              : [
                                  TarmeemColors.primaryContainer.withValues(alpha: 0.15),
                                  TarmeemColors.primaryContainer.withValues(alpha: 0.05),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? TarmeemColors.darkOutlineVariant : TarmeemColors.primaryContainer.withValues(alpha: 0.2),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        customer.name.trim().isNotEmpty
                            ? customer.name.trim()[0]
                            : 'ع',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Divider ──────────────────────────────────────────
                Container(
                  height: 1,
                  color: isDark ? TarmeemColors.darkOutlineVariant : TarmeemColors.outlineVariant.withValues(alpha: 0.5),
                ),

                const SizedBox(height: 10),

                // ── Bottom Row: Stats & Badges ────────────────────────
                Row(
                  children: [
                    // Arrow icon to view profile
                    Icon(
                      Icons.arrow_back_ios_new,
                      size: 13,
                      color: isDark ? TarmeemColors.darkOutline : TarmeemColors.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'الملف',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? TarmeemColors.darkOutline : TarmeemColors.outline,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),

                    const Spacer(),

                    // Total Devices badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${customer.totalTickets} أجهزة',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.devices_outlined,
                            size: 12,
                            color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),

                    if (hasActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? TarmeemColors.darkDiagnosisBackground : TarmeemColors.diagnosisBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${customer.activeTickets} بالورشة',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isDark ? TarmeemColors.darkDiagnosisText : TarmeemColors.diagnosisText,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.build_circle_outlined,
                              size: 12,
                              color: isDark ? TarmeemColors.darkDiagnosisText : TarmeemColors.diagnosisText,
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (hasDebt) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : TarmeemColors.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'متبقي: ${formatCurrency(customer.totalRemaining)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isDark ? const Color(0xFFFCA5A5) : TarmeemColors.onErrorContainer,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 12,
                              color: isDark ? const Color(0xFFFCA5A5) : TarmeemColors.onErrorContainer,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
