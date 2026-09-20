// Public tracking screen — Screen 6 (no auth required).
//
// Shows repair progress steps, inspection photo, financial summary,
// workshop location, and contact buttons.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tarmim/core/widgets/buttons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/url_helper.dart';
import '../../../core/services/shop_profile_service.dart';
import '../../../core/di/injection.dart';
import '../../tickets/domain/ticket_entity.dart';
import '../../tickets/domain/ticket_repository.dart';
import '../../tickets/presentation/tickets_cubit.dart';
import '../../tickets/presentation/tickets_state.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  TicketEntity? _ticket;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    final cleanId = widget.ticketId.replaceAll('#', '').trim();

    // 1. Try from loaded cubit if in active session
    try {
      final state = context.read<TicketsCubit>().state;
      if (state is TicketsLoaded) {
        final target = cleanId.toLowerCase();
        final found = state.allTickets.firstWhere((t) {
          final tNum = t.ticketNumber.replaceAll('#', '').trim().toLowerCase();
          return t.id.toLowerCase() == target ||
              tNum == target ||
              tNum == 'tr-$target' ||
              'tr-$tNum' == target;
        });
        if (mounted) {
          setState(() {
            _ticket = found;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    // 2. Query backend repository
    try {
      final ticket = await getIt<TicketRepository>().getTicket(cleanId);
      if (ticket != null) {
        if (mounted) {
          setState(() {
            _ticket = ticket;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _ticket = null;
        _isLoading = false;
      });
    }
  }

  Widget _buildNotFoundScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF334155)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.search_off_rounded,
                        color: Color(0xFFF87171),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'لم يتم العثور على التذكرة',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(
                        '#${widget.ticketId}',
                        style: const TextStyle(
                          color: Color(0xFF2DD4BF),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'يرجى التأكد من كتابة رقم التذكرة أو رقم الهاتف بشكل صحيح، أو مراجعة ورشة الصيانة مباشرة.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/track'),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text(
                          'العودة لبوابة البحث',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
        ),
      );
    }

    final ticket = _ticket;
    if (ticket == null) {
      return _buildNotFoundScreen(context);
    }

    final isReady = ticket.status == TicketStatus.readyForPickup;
    final isCancelled = ticket.status == TicketStatus.cancelled;

    final profile = getIt<ShopProfileService>().getProfile();
    final isOldMock = ticket.shopName == null ||
        ticket.shopName!.trim().isEmpty ||
        ticket.shopName == 'ورشة النور للإصلاح والصيانة' ||
        ticket.shopName == 'ورشة النور' ||
        ticket.shopName == 'ورشة الصيانة';

    final resolvedShopName = isOldMock ? profile.name : ticket.shopName!;
    final resolvedShopPhone = (ticket.shopPhone != null && ticket.shopPhone!.trim().isNotEmpty)
        ? ticket.shopPhone!
        : profile.phone;
    final resolvedShopAddress = (ticket.shopAddress != null && ticket.shopAddress!.trim().isNotEmpty)
        ? ticket.shopAddress!
        : profile.address;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? TarmeemColors.darkSurface : TarmeemColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Shop header banner ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ShopBanner(shopName: resolvedShopName),
          ),

          // ── Ready banner ──────────────────────────────────────────────
          if (isReady)
            SliverToBoxAdapter(
              child: _ReadyBanner(ticket: ticket),
            ),

          // ── Cancelled banner ──────────────────────────────────────────
          if (isCancelled)
            SliverToBoxAdapter(
              child: _CancelledTrackingBanner(ticket: ticket),
            ),

          // ── Main content ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Ticket info card
                  _TicketInfoCard(ticket: ticket),
                  const SizedBox(height: 16),
                  // Progress steps
                  _ProgressSteps(ticket: ticket),
                  const SizedBox(height: 16),
                  // Inspection photo
                  _InspectionPhoto(ticket: ticket),
                  const SizedBox(height: 16),
                  // Financial summary
                  _FinancialCard(ticket: ticket),
                  const SizedBox(height: 16),
                  // Warranty note
                  _WarrantyNote(
                    shopName: resolvedShopName,
                    warrantyText: profile.warranty,
                  ),
                  const SizedBox(height: 16),
                  // Map / location
                  _LocationCard(
                    shopName: resolvedShopName,
                    shopAddress: resolvedShopAddress,
                    shopPhone: resolvedShopPhone,
                    hours: profile.hours,
                  ),
                  const SizedBox(height: 20),
                  // Contact buttons
                  PrimaryButton(
                    label: 'الاتصال بالورشة مباشرة ($resolvedShopPhone)',
                    icon: const Icon(Icons.phone_outlined, size: 18),
                    onPressed: () => UrlHelper.makePhoneCall(resolvedShopPhone, context: context),
                  ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: 'محادثة الورشة عبر واتساب',
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    onPressed: () {},
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'هذه الصفحة تُفتح تلقائياً دون تسجيل دخول.\nصممت خصيصاً لإطلاع العميل الكريم على حالة الغرض.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline,
                      height: 1.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom nav is only for mobile workshop view, hidden on web customer view
      bottomNavigationBar: kIsWeb ? null : _TrackingBottomNav(),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _ShopBanner extends StatelessWidget {
  const _ShopBanner({this.shopName});
  final String? shopName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF134E4A),
            Color(0xFF0F766E),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (kIsWeb) {
                context.go('/');
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!kIsWeb) ...[
                  const Icon(Icons.arrow_forward_ios,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kIsWeb ? 'بوابة التتبع' : '• عودة',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                    Text(
                      'تِرميم',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  shopName ?? 'ورشة الصيانة',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'مركز صيانة معتمد',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.handyman, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}

class _ReadyBanner extends StatelessWidget {
  const _ReadyBanner({required this.ticket});
  final TicketEntity ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TarmeemColors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: TarmeemColors.primaryContainer.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'إشعار فوري من الورشة',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '🎉 غرضك جاهز للاستلام الآن!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          Text(
            'تم الانتهاء من كافة أعمال الإصلاح الدقيقة والمعايرة بنجاح تام، بانتظار زيارتك.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.6,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time_outlined,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                'اكتمل الإصلاح الساعة ${formatRelativeTime(DateTime.now())}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelledTrackingBanner extends StatelessWidget {
  const _CancelledTrackingBanner({required this.ticket});
  final TicketEntity ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.assignment_return_outlined, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'مسترجع بدون إصلاح',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Text(
                'تم إلغاء الإصلاح بناءً على رغبتكم',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '📦 جهازكم جاهز للاستلام الآن من مقر الورشة بالحالة التي تم تسليمه بها. يرجى إبراز رقم التذكرة عند الحضور للاستلام.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              height: 1.5,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _TicketInfoCard extends StatelessWidget {
  const _TicketInfoCard({required this.ticket});
  final TicketEntity ticket;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            children: [
              Text(
                'رقم إيصال الصيانة',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? TarmeemColors.primary.withValues(alpha: 0.2) : TarmeemColors.primaryFixed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${ticket.ticketNumber}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.deviceModel,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? TarmeemColors.darkOnSurface : null,
            ),
            textAlign: TextAlign.right,
          ),
          if (ticket.serialNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              'الرقم التسلسلي: ${ticket.serialNumber}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Specs chips
          const Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              _SpecChip(
                  icon: Icons.watch_outlined, label: 'تشحيم آلي بسيل سويسري'),
              _SpecChip(icon: Icons.water_drop_outlined, label: 'ضبط التوقيت'),
              _SpecChip(
                  icon: Icons.arrow_drop_down_outlined,
                  label: 'فحص الضغط القياسي الأصلي'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, size: 13, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.secondary),
        ],
      ),
    );
  }
}

class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.ticket});
  final TicketEntity ticket;

  static const _steps = [
    _Step(
      label: 'تم الاستلام بالورشة',
      detail: 'الاستلام في الورشة',
      time: '16 أكتوبر، 11:00 ص',
      status: TicketStatus.inDiagnosis,
    ),
    _Step(
      label: 'قيد الفحص والتشخيص الميكانيكي',
      detail: 'بدأ فريق الصيانة',
      time: '17 أكتوبر، 01:30 م',
      status: TicketStatus.inDiagnosis,
    ),
    _Step(
      label: 'توفير القطعة البديلة واستيداعها',
      detail: 'طلب من المورد',
      time: '19 أكتوبر، 10:00 ص',
      status: TicketStatus.waitingForPart,
    ),
    _Step(
      label: 'جاهز للاستلام بالغرفة الأمامية',
      detail: 'الانتظار بخزينة التسليم',
      time: 'اليوم، 02:30 م',
      status: TicketStatus.readyForPickup,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCancelled = ticket.status == TicketStatus.cancelled;
    final activeSteps = isCancelled
        ? const [
            _Step(
              label: 'تم الاستلام بالورشة',
              detail: 'الاستلام وتوثيق حالة الجهاز',
              time: 'تم الاستلام',
              status: TicketStatus.inDiagnosis,
            ),
            _Step(
              label: 'الفحص والتشخيص الفني',
              detail: 'معاينة العطل ومصارحة العميل بالتكلفة',
              time: 'تم الفحص',
              status: TicketStatus.inDiagnosis,
            ),
            _Step(
              label: 'إلغاء أعمال الصيانة',
              detail: 'تراجع العميل أو تعذر توفير القطع',
              time: 'تم الإلغاء',
              status: TicketStatus.cancelled,
            ),
            _Step(
              label: 'جاهز للاستلام واسترجاع الجهاز',
              detail: 'الجهاز بانتظار استلام العميل بالورشة',
              time: 'جاهز الآن',
              status: TicketStatus.cancelled,
            ),
          ]
        : _steps;

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
            children: [
              Text(
                isCancelled ? 'تم إلغاء الإصلاح 🛑' : 'المرحلة ${ticket.status.index + 1} من 4',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                'مراحل وخطوات العمل',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? TarmeemColors.darkOnSurface : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...activeSteps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            final isPast = isCancelled ? i < 3 : ticket.status.index > i;
            final isCurrent = isCancelled ? i == 3 : ticket.status.index == i;
            final isFuture = isCancelled ? false : ticket.status.index < i;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    if (i > 0)
                      Container(
                        width: 1,
                        height: 16,
                        color: isPast || isCurrent
                            ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                            : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
                      ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isPast
                            ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                            : isCurrent
                                ? (isDark ? TarmeemColors.primary.withValues(alpha: 0.25) : TarmeemColors.primaryFixed)
                                : (isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent
                              ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                              : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        isPast ? Icons.check_rounded : Icons.circle_outlined,
                        size: 14,
                        color: isPast
                            ? Colors.white
                            : isCurrent
                                ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                                : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outlineVariant),
                      ),
                    ),
                    if (i < _steps.length - 1)
                      Container(
                        width: 1,
                        height: 40,
                        color: isPast
                            ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                            : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isFuture)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'المرحلة القادمة',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              step.time,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                step.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isFuture
                                      ? (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant)
                                      : (isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          step.detail,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                            color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.label,
    required this.detail,
    required this.time,
    required this.status,
  });

  final String label;
  final String detail;
  final String time;
  final TicketStatus status;
}

class _InspectionPhoto extends StatelessWidget {
  const _InspectionPhoto({required this.ticket});
  final TicketEntity ticket;

  void _showZoomDialog(BuildContext context, String path, String tag) {
    final isRemote = path.startsWith('http') || path.startsWith('data:');

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: isRemote
                    ? Image.network(
                        path,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          height: 250,
                          color: Colors.black87,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                          ),
                        ),
                      )
                    : (kIsWeb
                        ? Image.network(path, fit: BoxFit.contain)
                        : Image.file(File(path), fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGallery({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required List<String> images,
    required String tagLabel,
    required bool isDark,
  }) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${images.length}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            reverse: true, // RTL order
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, idx) {
              final p = images[idx];
              final isRemote = p.startsWith('http') || p.startsWith('data:');

              Widget buildImg() {
                if (isRemote) {
                  return Image.network(
                    p,
                    fit: BoxFit.cover,
                    width: 110,
                    height: 120,
                    loadingBuilder: (c, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 110,
                        height: 120,
                        color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerHigh,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      width: 110,
                      height: 120,
                      color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerHigh,
                      child: Icon(Icons.broken_image_outlined,
                          color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline, size: 28),
                    ),
                  );
                }
                return kIsWeb
                    ? Image.network(p, fit: BoxFit.cover, width: 110, height: 120)
                    : Image.file(
                        File(p),
                        fit: BoxFit.cover,
                        width: 110,
                        height: 120,
                        errorBuilder: (_, __, ___) => Container(
                          width: 110,
                          height: 120,
                          color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerHigh,
                          child: const Icon(Icons.broken_image_outlined, size: 28),
                        ),
                      );
              }

              return GestureDetector(
                onTap: () => _showZoomDialog(context, p, tagLabel),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      buildImg(),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.zoom_in, color: Colors.white, size: 10),
                              const SizedBox(width: 3),
                              Text(
                                tagLabel,
                                style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final intakeImages = ticket.allImages
        .where((p) => !kIsWeb || p.startsWith('http') || p.startsWith('data:'))
        .toList();

    final afterImages = ticket.afterRepairImages
        .where((p) => !kIsWeb || p.startsWith('http') || p.startsWith('data:'))
        .toList();

    final totalCount = intakeImages.length + afterImages.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 18, color: TarmeemColors.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'توثيق صور الجهاز',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (totalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: TarmeemColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$totalCount صورة 📸',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: TarmeemColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (totalCount == 0)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 36,
                    color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'توثيق فحص واستلام الجهاز',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'يتم رفع صور توثيق الجهاز وفحصه فور البدء بالصيانة من الفني.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // 1. After-repair photos (if device is fixed / ready / delivered, show after photos first with pride)
            if (afterImages.isNotEmpty) ...[
              _buildPhotoGallery(
                context: context,
                title: 'صور الجهاز بعد الصيانة والإصلاح ✨',
                icon: Icons.verified_rounded,
                color: const Color(0xFF10B981),
                images: afterImages,
                tagLabel: 'بعد الصيانة ✅',
                isDark: isDark,
              ),
              if (intakeImages.isNotEmpty) const SizedBox(height: 16),
            ],

            // 2. Intake photos
            if (intakeImages.isNotEmpty) ...[
              _buildPhotoGallery(
                context: context,
                title: 'صور استلام وفحص الجهاز (قبل الصيانة)',
                icon: Icons.camera_alt_outlined,
                color: const Color(0xFF2563EB),
                images: intakeImages,
                tagLabel: 'قبل الصيانة',
                isDark: isDark,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  const _FinancialCard({required this.ticket});
  final TicketEntity ticket;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasParts = ticket.partsCost > 0;
    final laborFee = (ticket.estimatedCost - ticket.partsCost).clamp(0.0, double.infinity);

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
            children: [
              if (hasParts)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? TarmeemColors.primary.withValues(alpha: 0.25)
                        : TarmeemColors.primaryFixed.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'فاتورة تفصيلية',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                    ),
                  ),
                ),
              const Spacer(),
              Icon(Icons.receipt_long_outlined,
                  size: 18, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
              const SizedBox(width: 6),
              Text(
                'تفاصيل الفاتورة وقيمة الصيانة',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? TarmeemColors.darkOnSurface : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (ticket.estimatedCost <= 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'جهازك قيد الفحص والتشخيص الفني حالياً. سيتم تحديد التكلفة النهائية للمصنعية وقطع الغيار فور انتهاء الفحص.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            if (hasParts) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C1810) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatCurrency(ticket.partsCost),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          ticket.partsDescription != null && ticket.partsDescription!.isNotEmpty
                              ? 'قطع الغيار: ${ticket.partsDescription}'
                              : 'قطع الغيار المستخدمة',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.build_circle_outlined, size: 16, color: Color(0xFFEA580C)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (ticket.deposit > 0) ...[
              const SizedBox(height: 12),
              _FinRow(
                label: 'العربون المُسدد بالإيصال',
                amount: -ticket.deposit,
                isTotal: false,
              ),
            ],
          ] else ...[
            if (hasParts) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C1810) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatCurrency(ticket.partsCost),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          ticket.partsDescription != null && ticket.partsDescription!.isNotEmpty
                              ? 'قطع الغيار: ${ticket.partsDescription}'
                              : 'قطع الغيار المستخدمة',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.build_circle_outlined, size: 16, color: Color(0xFFEA580C)),
                      ],
                    ),
                  ],
                ),
              ),
              _FinRow(
                label: 'أتعاب الفحص والمصنعية 🛠️',
                amount: laborFee,
                isTotal: false,
              ),
              const SizedBox(height: 8),
              Divider(height: 16, thickness: 0.5, color: isDark ? TarmeemColors.darkCardBorder : null),
            ],
            _FinRow(
              label: hasParts ? 'إجمالي الفاتورة (قطع + مصنعية)' : 'إجمالي تكلفة الفحص والإصلاح',
              amount: ticket.estimatedCost,
              isTotal: false,
            ),
            const SizedBox(height: 8),
            _FinRow(
              label: 'العربون المُسدد بالإيصال',
              amount: -ticket.deposit,
              isTotal: false,
            ),
            Divider(height: 20, color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.surfaceContainerHigh),
            _FinRow(
              label: 'المبلغ المتبقي للدفع عند الاستلام',
              amount: ticket.remainingAmount,
              isTotal: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _FinRow extends StatelessWidget {
  const _FinRow({
    required this.label,
    required this.amount,
    required this.isTotal,
  });

  final String label;
  final double amount;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          formatCurrency(amount.abs()),
          style: TextStyle(
            fontSize: isTotal ? 20 : 15,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: amount < 0
                ? (isDark ? const Color(0xFF34D399) : TarmeemColors.waitingText)
                : isTotal
                    ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                    : (isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface),
          ),
        ),
        const Spacer(),
        if (amount < 0) ...[
          Icon(Icons.check_circle_outline,
              size: 14, color: isDark ? const Color(0xFF34D399) : TarmeemColors.readyDot),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _WarrantyNote extends StatelessWidget {
  const _WarrantyNote({
    required this.shopName,
    required this.warrantyText,
  });

  final String shopName;
  final String warrantyText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? TarmeemColors.darkSurfaceContainer
            : TarmeemColors.primaryFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.primaryFixed),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined,
              size: 20, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
          const Spacer(),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'ضمان $shopName المعتمد',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  warrantyText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onPrimaryFixedVariant,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.shopName,
    required this.shopAddress,
    required this.shopPhone,
    required this.hours,
  });

  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String hours;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Map placeholder
          Container(
            height: 140,
            width: double.infinity,
            color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerHigh,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.map_outlined,
                    size: 56, color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          shopName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    Icon(Icons.place_outlined,
                        size: 16, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                    const SizedBox(width: 6),
                    Text(
                      'موقع الورشة وساعات الزيارة',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? TarmeemColors.darkOnSurface : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  shopAddress,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  hours,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'الحصول على الاتجاهات في خرائط Google',
                  icon: const Icon(Icons.directions_outlined, size: 16),
                  onPressed: () {
                    final mapsUri = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$shopName $shopAddress')}',
                    );
                    launchUrl(mapsUri, mode: LaunchMode.externalApplication);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingBottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.surfaceContainerHigh),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: 2,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
        unselectedItemColor: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          if (i == 0 || i == 1 || i == 3) context.go('/login');
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_repair_service_outlined),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'العملاء',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            activeIcon: Icon(Icons.receipt_long),
            label: 'الأغراض',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
