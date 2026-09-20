// Home screen — Screen 2.
//
// Shows ticket list grouped/filterable by status, search bar, quick stats row,
// floating add button, and bottom navigation bar.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../../core/widgets/ticket_card.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../branches/domain/branch_entity.dart';
import '../../branches/presentation/branches_cubit.dart';
import '../../notifications/presentation/notification_center_sheet.dart';
import '../../notifications/domain/workshop_alert_model.dart';
import '../presentation/tickets_cubit.dart';
import '../presentation/tickets_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<TicketsCubit>().loadTickets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ──────────────────────────────────────────────────
            _HomeAppBar(),
            const SizedBox(height: 4),

            // ── Search Bar ───────────────────────────────────────────────
            _SearchBar(
              controller: _searchController,
              onChanged: (q) => context.read<TicketsCubit>().search(q),
            ),
            const SizedBox(height: 10),

            // ── Filter Chips Bar ─────────────────────────────────────────
            BlocBuilder<TicketsCubit, TicketsState>(
              builder: (context, state) {
                final counts = state is TicketsLoaded
                    ? [
                        state.totalActive,
                        state.countForStatus(TicketStatus.readyForPickup),
                        state.countForStatus(TicketStatus.inDiagnosis),
                        state.countForStatus(TicketStatus.waitingForPart),
                        state.countForStatus(TicketStatus.delivered),
                        state.countForStatus(TicketStatus.cancelled),
                      ]
                    : null;
                return FilterChipBar(
                  options: const ['النشطة بالورشة', 'جاهز للاستلام', 'قيد الفحص', 'بانتظار قطعة', 'تم التسليم', 'مسترجع / ملغي'],
                  selectedIndex: state is TicketsLoaded ? state.selectedFilter : 0,
                  onSelected: (i) => context.read<TicketsCubit>().selectFilter(i),
                  counts: counts,
                );
              },
            ),
            const SizedBox(height: 8),

            // ── Ticket List with Pull to Refresh ─────────────────────────
            Expanded(
              child: BlocBuilder<TicketsCubit, TicketsState>(
                builder: (context, state) {
                  if (state is TicketsLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: TarmeemColors.primaryContainer,
                      ),
                    );
                  } else if (state is TicketsError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: TarmeemColors.error,
                        ),
                      ),
                    );
                  } else if (state is TicketsLoaded) {
                    final tickets = state.displayTickets;
                    if (tickets.isEmpty) {
                      return _EmptyState(
                        hasFilter: state.selectedFilter != 0 ||
                            state.searchQuery.isNotEmpty,
                      );
                    }
                    return RefreshIndicator(
                      color: TarmeemColors.primaryContainer,
                      onRefresh: () async {
                        context.read<TicketsCubit>().loadTickets();
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                        itemCount: tickets.length,
                        itemBuilder: (ctx, i) {
                          final ticket = tickets[i];
                          return TicketCard(
                            ticket: ticket,
                            onTap: () => context.push('/ticket/${ticket.id}'),
                            onStatusTap: () =>
                                context.push('/ticket/${ticket.id}'),
                          );
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),

      // ── Floating "Add" Button ─────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ticket/new'),
        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
        label: const Text(
          'استلام جهاز جديد ＋',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        backgroundColor: TarmeemColors.primaryContainer,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Actions side (Notification only)
          const _NotificationBellButton(),

          // Workshop branding side (RTL start)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, authState) {
                      final shopName = authState is AuthAuthenticated &&
                              authState.shopName != null &&
                              authState.shopName!.isNotEmpty
                          ? authState.shopName!
                          : 'ترميم للصيانة';
                      return Text(
                        shopName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, authState) {
                          final isOwner = authState is AuthAuthenticated ? authState.isOwner : true;
                          final assignedBranchName = authState is AuthAuthenticated ? authState.branchName : null;

                          return BlocBuilder<BranchesCubit, BranchesState>(
                            builder: (context, branchState) {
                              final activeBranch = branchState.activeBranch;
                              final branches = branchState.branches;
                              final String branchName;
                              if (!isOwner) {
                                branchName = assignedBranchName ?? activeBranch?.name ?? 'الفرع التابع';
                              } else {
                                branchName = activeBranch != null ? activeBranch.name : 'جميع الفروع';
                              }

                              return GestureDetector(
                                onTap: isOwner
                                    ? () => _showBranchSelectorSheet(context, branches, activeBranch)
                                    : () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('أنت مسجل الدخول بصلاحيات "$branchName" 🏬'),
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed).withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isOwner)
                                        Icon(Icons.keyboard_arrow_down_rounded,
                                            size: 13,
                                            color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                                      else
                                        Icon(Icons.lock_outline_rounded,
                                            size: 11,
                                            color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                                      const SizedBox(width: 4),
                                      Text(
                                        branchName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.storefront_rounded,
                                          size: 12,
                                          color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [TarmeemColors.darkPrimary, const Color(0xFF0F766E)]
                        : [TarmeemColors.primaryContainer, const Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBranchSelectorSheet(BuildContext context, List<BranchEntity> branches, BranchEntity? activeBranch) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(modalContext);
                      context.push('/settings/branches');
                    },
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('إدارة الفروع 🏢'),
                  ),
                  Text(
                    'اختر الفرع الحالي للعمل',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...branches.map((b) {
                final isSelected = b.id == activeBranch?.id;
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: isSelected
                      ? (isDark
                          ? TarmeemColors.darkPrimaryContainer.withValues(alpha: 0.3)
                          : TarmeemColors.primaryFixed.withValues(alpha: 0.4))
                      : null,
                  leading: isSelected
                      ? const Icon(Icons.check_circle, color: TarmeemColors.readyDot)
                      : const Icon(Icons.storefront_outlined),
                  title: Text(
                    b.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                    ),
                  ),
                  subtitle: b.phone != null ? Text(b.phone!) : null,
                  onTap: () async {
                    await context.read<BranchesCubit>().selectBranch(b);
                    if (context.mounted) {
                      context.read<TicketsCubit>().switchBranch(b.id);
                      context.read<AuthCubit>().updateActiveBranch(branchId: b.id, branchName: b.name);
                      Navigator.pop(modalContext);
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: activeBranch == null
                    ? (isDark
                        ? TarmeemColors.darkPrimaryContainer.withValues(alpha: 0.3)
                        : TarmeemColors.primaryFixed.withValues(alpha: 0.4))
                    : null,
                leading: activeBranch == null
                    ? const Icon(Icons.check_circle, color: TarmeemColors.readyDot)
                    : const Icon(Icons.all_inbox_rounded),
                title: Text(
                  'عرض جميع فروع الورشة',
                  style: TextStyle(
                    fontWeight: activeBranch == null ? FontWeight.bold : FontWeight.normal,
                    color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                  ),
                ),
                subtitle: const Text('عرض كافة التذاكر الموزعة على كل الفروع معاً'),
                onTap: () async {
                  await context.read<BranchesCubit>().selectBranch(null);
                  if (context.mounted) {
                    context.read<TicketsCubit>().switchBranch(null);
                    context.read<AuthCubit>().updateActiveBranch(branchId: 'all', branchName: 'جميع الفروع');
                    Navigator.pop(modalContext);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TicketsCubit, TicketsState>(
      builder: (context, state) {
        final tickets = state is TicketsLoaded ? state.allTickets : [];
        final alerts = WorkshopAlertAnalyzer.analyzeTickets(tickets.cast());
        final hasAlerts = alerts.isNotEmpty;
        final hasHighUrgency = alerts.any((a) => a.urgency == AlertUrgency.high);

        return Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              icon: Icon(
                hasAlerts ? Icons.notifications_active_outlined : Icons.notifications_none_outlined,
                size: 24,
                color: hasAlerts ? (hasHighUrgency ? const Color(0xFFE11D48) : const Color(0xFFF59E0B)) : null,
              ),
              tooltip: 'مركز التنبيهات',
              onPressed: () => NotificationCenterSheet.show(context),
            ),
            if (hasAlerts)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: hasHighUrgency ? const Color(0xFFE11D48) : const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    alerts.length > 9 ? '+9' : '${alerts.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final void Function(String) onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_updateHasText);
  }

  void _updateHasText() {
    final has = widget.controller.text.isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateHasText);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Filter icon button
          BlocBuilder<TicketsCubit, TicketsState>(
            builder: (context, state) {
              final hasActiveFilter = state is TicketsLoaded &&
                  (state.deviceTypeFilter != null || !state.sortNewestFirst);

              return GestureDetector(
                onTap: () => _showFilterSheet(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasActiveFilter
                        ? (isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed)
                        : (isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLowest),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasActiveFilter
                          ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                          : (isDark ? TarmeemColors.darkOutlineVariant : TarmeemColors.outlineVariant),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.tune_outlined,
                        color: hasActiveFilter
                            ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                            : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
                        size: 20,
                      ),
                      if (hasActiveFilter)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          // Search field
          Expanded(
            child: TextField(
              controller: widget.controller,
              textDirection: TextDirection.rtl,
              onChanged: widget.onChanged,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'ابحث باسم العميل، الهاتف، أو نوع الغرض...',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant).withValues(alpha: 0.6),
                ),
                hintTextDirection: TextDirection.rtl,
                prefixIcon: Icon(Icons.search,
                    color: isDark ? TarmeemColors.darkOutline : TarmeemColors.outline, size: 20),
                suffixIcon: _hasText
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: isDark ? TarmeemColors.darkOutline : TarmeemColors.outline),
                        onPressed: () {
                          widget.controller.clear();
                          widget.onChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLowest,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? TarmeemColors.darkOutlineVariant : TarmeemColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? TarmeemColors.darkOutlineVariant : TarmeemColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showFilterSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BlocProvider.value(
      value: context.read<TicketsCubit>(),
      child: const _FilterSheet(),
    ),
  );
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? TarmeemColors.darkOutlineVariant : TarmeemColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  context.read<TicketsCubit>().clearFilters();
                  Navigator.pop(context);
                },
                child: Text(
                  'إعادة ضبط',
                  style: TextStyle(color: isDark ? TarmeemColors.darkSecondary : TarmeemColors.secondary),
                ),
              ),
              const Spacer(),
              Text(
                'فلترة وترتيب',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.tune_outlined,
                  color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer, size: 18),
            ],
          ),
          const SizedBox(height: 16),

          // Device type filter
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'نوع الجهاز',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: BlocBuilder<TicketsCubit, TicketsState>(
              builder: (context, state) {
                final selectedType = state is TicketsLoaded
                    ? state.deviceTypeFilter
                    : null;
                return Row(
                  children: [
                    _DeviceFilterChip(
                      label: 'الكل',
                      emoji: '🗂️',
                      isSelected: selectedType == null,
                      onTap: () => context
                          .read<TicketsCubit>()
                          .setDeviceTypeFilter(null),
                    ),
                    ...DeviceType.values.map((dt) {
                      final emoji = switch (dt) {
                        DeviceType.mobile => '📱',
                        DeviceType.laptop => '💻',
                        DeviceType.watch => '⌚',
                        DeviceType.home => '🏠',
                        DeviceType.other => '🔧',
                      };
                      final label = switch (dt) {
                        DeviceType.mobile => 'موبايل',
                        DeviceType.laptop => 'لابتوب',
                        DeviceType.watch => 'ساعة',
                        DeviceType.home => 'كهربائيات',
                        DeviceType.other => 'أخرى',
                      };
                      return _DeviceFilterChip(
                        label: label,
                        emoji: emoji,
                        isSelected: selectedType == dt,
                        onTap: () => context
                            .read<TicketsCubit>()
                            .setDeviceTypeFilter(dt),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Sort order
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الترتيب',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          BlocBuilder<TicketsCubit, TicketsState>(
            builder: (context, state) {
              final newestFirst =
                  state is TicketsLoaded ? state.sortNewestFirst : true;
              return Row(
                children: [
                  Expanded(
                    child: _SortOptionTile(
                      label: 'الأقدم أولاً',
                      icon: Icons.arrow_upward,
                      isSelected: !newestFirst,
                      onTap: () => context
                          .read<TicketsCubit>()
                          .setSortOrder(newestFirst: false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SortOptionTile(
                      label: 'الأحدث أولاً',
                      icon: Icons.arrow_downward,
                      isSelected: newestFirst,
                      onTap: () => context
                          .read<TicketsCubit>()
                          .setSortOrder(newestFirst: true),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DeviceFilterChip extends StatelessWidget {
  const _DeviceFilterChip({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
              : (isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                : (isDark ? TarmeemColors.darkOutlineVariant : TarmeemColors.outlineVariant),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
              : (isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                : (isDark ? TarmeemColors.darkOutlineVariant : TarmeemColors.outlineVariant),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilter ? Icons.search_off_outlined : Icons.inbox_outlined,
                size: 40,
                color: isDark ? TarmeemColors.darkOutline : TarmeemColors.outline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter ? 'لا توجد نتائج مطابقة' : 'لا توجد أجهزة صيانة حالياً',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? TarmeemColors.darkOnSurface : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilter
                  ? 'جرّب البحث بكلمات أخرى أو تغيير الفلاتر المحددة'
                  : 'ابدأ باستلام أول جهاز صيانة وإصدار إيصال فوري للعميل',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasFilter) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => context.push('/ticket/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('استلام جهاز جديد الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
