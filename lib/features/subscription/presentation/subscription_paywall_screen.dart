/// Subscription & Licensing Paywall Screen.
///
/// Displayed when the 14-day trial expires, or accessible from Settings
/// to upgrade/activate the workshop license.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/utils/url_helper.dart';
import '../../../core/widgets/buttons.dart';
import 'subscription_cubit.dart';

class SubscriptionPaywallScreen extends StatefulWidget {
  const SubscriptionPaywallScreen({super.key, this.isModal = false});
  final bool isModal;

  @override
  State<SubscriptionPaywallScreen> createState() =>
      _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends State<SubscriptionPaywallScreen> {
  final _keyController = TextEditingController();
  int _selectedPlanIndex = 1; // Default to Yearly (Most popular)

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _contactSales(BuildContext context) {
    const adminPhone = '201000000000'; // Admin WhatsApp
    const message = 'مرحباً، أرغب في الاشتراك وتفعيل نسخة تطبيق «تِرميم» لورشتي 🛠️';
    UrlHelper.openWhatsApp(
      phone: adminPhone,
      message: message,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<SubscriptionCubit, SubscriptionState>(
      listener: (context, state) {
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: TarmeemColors.readyDot,
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (widget.isModal && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: TarmeemColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).brightness == Brightness.dark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: Text(
              'ترقية واشتراك الورشة',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero Banner ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        TarmeemColors.primaryContainer,
                        Color(0xFF0D9488),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: TarmeemColors.primaryContainer.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.workspace_premium_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.isLicensed
                            ? 'نسختك مفعلة بالكامل ✅'
                            : (state.isExpired
                                ? 'انتهت الفترة التجريبية لورشتك ⏳'
                                : 'متبقي ${state.trialDaysRemaining} يوم بالتجربة المجانية ✨'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.isLicensed
                            ? 'أنت تستمتع بكافة ميزات تِرميم السحابية مدى الحياة.'
                            : 'انضم لمئات الورش التي نظمت أعمالها وزادت أرباحها ورضا عملائها عبر تِرميم.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Value Benefits ──────────────────────────────────────────
                Text(
                  'ماذا تكسب عند ترخيص ورشتك؟',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                _BenefitItem(
                  icon: Icons.cloud_done_outlined,
                  title: 'حفظ سحابي غير محدود',
                  subtitle: 'بيانات أجهزتك وزبائنك آمنة ولا تضيع حتى لو تعطل هاتفك.',
                ),
                _BenefitItem(
                  icon: Icons.chat_bubble_outline,
                  title: 'روابط تتبع حية للعملاء عبر واتساب & SMS',
                  subtitle: 'وفّر وقت اتصالات الزبائن المتكررة وارفع برستيج ورشتك.',
                ),
                _BenefitItem(
                  icon: Icons.point_of_sale_outlined,
                  title: 'حصر دقيق للمستحقات والأرباح',
                  subtitle: 'لن تنسى أي عربون أو متبقي طرف أي عميل بعد اليوم.',
                ),
                _BenefitItem(
                  icon: Icons.offline_bolt_outlined,
                  title: 'يعمل بدون إنترنت (Offline-First)',
                  subtitle: 'سجل أجهزتك في أي وقت، والتطبيق يتزامن تلقائياً.',
                ),

                const SizedBox(height: 24),

                // ── Pricing Plans ───────────────────────────────────────────
                Text(
                  'اختر الباقة المناسبة لورشتك:',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),

                // Plan 1: Monthly
                _PlanCard(
                  title: 'الاشتراك الشهري',
                  price: '150 ج.م',
                  period: 'شهرياً',
                  isSelected: _selectedPlanIndex == 0,
                  badge: 'مرونة الدفع',
                  onTap: () => setState(() => _selectedPlanIndex = 0),
                ),
                const SizedBox(height: 10),

                // Plan 2: Yearly (Recommended)
                _PlanCard(
                  title: 'الاشتراك السنوي',
                  price: '1,200 ج.م',
                  period: 'سنوياً',
                  isSelected: _selectedPlanIndex == 1,
                  badge: 'الأكثر توفيراً (وفر شهرين كاملين) 🔥',
                  isHighlighted: true,
                  onTap: () => setState(() => _selectedPlanIndex = 1),
                ),
                const SizedBox(height: 10),

                // Plan 3: Lifetime
                _PlanCard(
                  title: 'شراء ترخيص دائم للمحل',
                  price: '2,500 ج.م',
                  period: 'تدفع مرة واحدة فقط مدى الحياة',
                  isSelected: _selectedPlanIndex == 2,
                  badge: 'راحة بال دائمة 💎',
                  onTap: () => setState(() => _selectedPlanIndex = 2),
                ),

                const SizedBox(height: 24),

                // ── Primary CTA: WhatsApp ───────────────────────────────────
                PrimaryButton(
                  label: 'تواصل للتفعيل الفوري عبر واتساب 💬',
                  icon: const Icon(Icons.chat_outlined, size: 20),
                  onPressed: () => _contactSales(context),
                ),

                const SizedBox(height: 24),

                // ── Activation Key Input ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'هل تملك كود تفعيل؟',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              if (_keyController.text.trim().isNotEmpty) {
                                context
                                    .read<SubscriptionCubit>()
                                    .activateKey(_keyController.text.trim());
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).brightness == Brightness.dark ? TarmeemColors.primary : TarmeemColors.primaryContainer,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              minimumSize: const Size(64, 44),
                            ),
                            child: const Text('تفعيل'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _keyController,
                              textAlign: TextAlign.center,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: 'مثال: TARMEEM-PRO-2026',
                                hintStyle: const TextStyle(fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.primaryFixed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.isSelected,
    required this.badge,
    required this.onTap,
    this.isHighlighted = false,
  });

  final String title;
  final String price;
  final String period;
  final bool isSelected;
  final String badge;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? TarmeemColors.primary.withValues(alpha: 0.25) : TarmeemColors.primaryFixed.withValues(alpha: 0.5))
              : (isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? (isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer)
                : (isHighlighted
                    ? TarmeemColors.secondary
                    : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder)),
            width: isSelected || isHighlighted ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: isSelected,
              onChanged: (_) => onTap(),
              activeColor: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                  ),
                ),
                Text(
                  period,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? TarmeemColors.secondaryContainer
                        : TarmeemColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isHighlighted
                          ? TarmeemColors.onSecondaryContainer
                          : TarmeemColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
