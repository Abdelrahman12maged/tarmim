import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/shop_profile_service.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/exit_dialog.dart';
import '../../tickets/data/ticket_datasource.dart';
import '../../subscription/presentation/subscription_cubit.dart';
import '../../branches/presentation/branches_cubit.dart';
import '../../auth/presentation/auth_cubit.dart';
import 'theme_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_forward_ios,
                    color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'الإعدادات',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: isDark ? TarmeemColors.darkOnSurface : null,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          // Theme section
          const _SectionLabel('المظهر'),
          const SizedBox(height: 8),
          _ThemeTile(),
          const SizedBox(height: 20),

          // Shop Profile Section
          const _SectionLabel('بيانات المحل والورشة'),
          const SizedBox(height: 8),
          const _ShopProfileTile(),
          const SizedBox(height: 20),

          // Branches & Subscription Sections (Owner-only)
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, authState) {
              final isOwner = authState is AuthAuthenticated ? authState.isOwner : true;
              if (!isOwner) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('حساب فرع تابع 🏬', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                'أنت مسجل الدخول بصلاحيات فرع تابع. إدارة الفروع والتراخيص متاحة للإدارة الرئيسية فقط.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.verified_user_outlined, color: TarmeemColors.readyDot),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Branches Section
                  const _SectionLabel('فروع المحل'),
                  const SizedBox(height: 8),
                  const _BranchManagementTile(),
                  const SizedBox(height: 20),

                  // Subscription & License section
                  const _SectionLabel('ترخيص واشتراك الورشة'),
                  const SizedBox(height: 8),
                  BlocBuilder<SubscriptionCubit, SubscriptionState>(
                    builder: (context, subState) {
                      return Material(
                        color: isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => context.push('/subscription'),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_back_ios,
                                    size: 16, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      subState.isLicensed
                                          ? 'نسخة مرخصة بالكامل (Pro) 💎'
                                          : (subState.isExpired
                                              ? 'انتهت الفترة التجريبية 🔒'
                                              : 'نسخة تجريبية (${subState.trialDaysRemaining} يوم متبقي) ✨'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subState.isLicensed
                                          ? 'اشتراكك نشط ومدعوم سحابياً مدى الحياة.'
                                          : 'اضغط هنا للاشتراك وتفعيل كود الترخيص.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.workspace_premium_outlined,
                                    size: 26, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),

          // Cloud Sync Section
          const _SectionLabel('المزامنة السحابية'),
          const SizedBox(height: 8),
          Material(
            color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('جارِ مزامنة البيانات مع السحابة...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                final syncManager = getIt<SyncManager>();
                final dataSource = getIt<TicketDataSource>();
                final success = await syncManager.syncPending(dataSource);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'اكتملت المزامنة بنجاح! كافة البيانات محدثة سحابياً ✅'
                          : 'تعذر الاتصال بالسحابة، البيانات محفوظة محلياً على جهازك 📱'),
                      backgroundColor: success
                          ? TarmeemColors.readyDot
                          : TarmeemColors.secondary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_ios,
                        size: 16, color: TarmeemColors.outline),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'مزامنة البيانات الآن',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'رفع العمليات المحفوظة أوفلاين إلى السحابة',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.sync,
                        size: 24, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // SMS & SIM Settings Section
          const _SectionLabel('خدمات الرسائل القصيرة (SMS)'),
          const SizedBox(height: 8),
          Material(
            color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => context.push('/settings/sms'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_ios,
                        size: 16, color: TarmeemColors.outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'إرسال SMS من شريحة الموبايل',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? TarmeemColors.darkOnSurface : null,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'إدارة الشرائح (Dual SIM)، الإرسال في الخلفية، والأتمتة',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.sim_card_outlined,
                          size: 22, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),


          // Onboarding guide tile
          Material(
            color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => context.push('/onboarding'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_ios,
                        size: 16, color: TarmeemColors.outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'جولة تعريفية بمميزات التطبيق',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? TarmeemColors.darkOnSurface : null,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'إرشادات استخدام إدارة الأجهزة، الواتساب الصامت، والـ SMS',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF312E81).withValues(alpha: 0.5) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.explore_outlined,
                          size: 22, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // App info
          const _SectionLabel('معلومات التطبيق'),
          const SizedBox(height: 8),
          const _InfoTile(
            icon: Icons.handyman_outlined,
            title: AppConstants.appName,
            subtitle: 'الإصدار 1.0.0 (Pro)',
          ),
          const SizedBox(height: 8),
          const _InfoTile(
            icon: Icons.shield_outlined,
            title: 'بيانات ورشتك',
            subtitle: 'محفوظة ومحمية محلياً وسحابياً',
          ),
          const SizedBox(height: 32),
          // Logout
          Material(
            color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.35) : TarmeemColors.errorContainer,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () async {
                final shouldLogout = await ExitDialog.showLogout(context);
                if (shouldLogout == true && context.mounted) {
                  context.read<AuthCubit>().logout();
                  context.go('/login');
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: isDark ? Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_outlined,
                        color: isDark ? const Color(0xFFFCA5A5) : TarmeemColors.onErrorContainer, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'تسجيل الخروج',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isDark ? const Color(0xFFFCA5A5) : TarmeemColors.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      textAlign: TextAlign.right,
    );
  }
}

class _ThemeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'وضع العرض',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isDark ? TarmeemColors.darkOnSurface : null,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ThemeOption(
                    label: 'داكن',
                    icon: Icons.dark_mode_outlined,
                    isSelected: state.themeMode == ThemeMode.dark,
                    onTap: () => context.read<ThemeCubit>().setTheme(ThemeMode.dark),
                  ),
                  const SizedBox(width: 8),
                  _ThemeOption(
                    label: 'تلقائي',
                    icon: Icons.brightness_auto_outlined,
                    isSelected: state.themeMode == ThemeMode.system,
                    onTap: () => context.read<ThemeCubit>().setTheme(ThemeMode.system),
                  ),
                  const SizedBox(width: 8),
                  _ThemeOption(
                    label: 'فاتح',
                    icon: Icons.light_mode_outlined,
                    isSelected: state.themeMode == ThemeMode.light,
                    onTap: () => context.read<ThemeCubit>().setTheme(ThemeMode.light),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
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

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                : (isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow),
            borderRadius: BorderRadius.circular(12),
            border: !isSelected && isDark ? Border.all(color: TarmeemColors.darkOutlineVariant) : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
      ),
      child: Row(
        children: [
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isDark ? TarmeemColors.darkOnSurface : null,
              )),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 20, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
          ),
        ],
      ),
    );
  }
}

class _ShopProfileTile extends StatefulWidget {
  const _ShopProfileTile();

  @override
  State<_ShopProfileTile> createState() => _ShopProfileTileState();
}

class _ShopProfileTileState extends State<_ShopProfileTile> {
  late ShopProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = getIt<ShopProfileService>().getProfile();
  }

  void _openEditSheet() {
    final nameCtrl = TextEditingController(text: _profile.name);
    final phoneCtrl = TextEditingController(text: _profile.phone);
    final addressCtrl = TextEditingController(text: _profile.address);
    final hoursCtrl = TextEditingController(text: _profile.hours);
    final warrantyCtrl = TextEditingController(text: _profile.warranty);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: TarmeemColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      Row(
                        children: [
                          Text(
                            'بيانات المحل والورشة الرسمية',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.storefront_outlined,
                              color: TarmeemColors.primaryContainer),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    'تظهر هذه البيانات للعملاء في صفحة تتبع الأجهزة وفي الإيصالات المطبوعة.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: TarmeemColors.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 18),
                  TarmeemTextField(
                    controller: nameCtrl,
                    label: 'اسم المحل أو الورشة',
                    hint: 'مثال: مركز النور لصيانة الأجهزة',
                    prefixIcon: const Icon(Icons.store_outlined, size: 20),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'اسم الورشة مطلوب' : null,
                  ),
                  const SizedBox(height: 14),
                  TarmeemTextField(
                    controller: phoneCtrl,
                    label: 'رقم هاتف / واتساب التواصل',
                    hint: 'مثال: 01012345678',
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'رقم الهاتف مطلوب' : null,
                  ),
                  const SizedBox(height: 14),
                  TarmeemTextField(
                    controller: addressCtrl,
                    label: 'عنوان ومقر الورشة',
                    hint: 'مثال: شارع التحرير، وسط البلد، القاهرة',
                    prefixIcon: const Icon(Icons.place_outlined, size: 20),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null,
                  ),
                  const SizedBox(height: 14),
                  TarmeemTextField(
                    controller: hoursCtrl,
                    label: 'ساعات العمل الرسمية',
                    hint: 'مثال: يومياً من 10 ص حتى 10 م (الجمعة عطلة)',
                    prefixIcon: const Icon(Icons.access_time_outlined, size: 20),
                  ),
                  const SizedBox(height: 14),
                  TarmeemTextField(
                    controller: warrantyCtrl,
                    label: 'سياسة وضمان الصيانة للعميل',
                    hint: 'مثال: ضمان 30 يوماً على كافة أعمال الإصلاح وتغيير القطع',
                    maxLines: 3,
                    prefixIcon: const Icon(Icons.verified_user_outlined, size: 20),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'حفظ وتحديث بيانات الورشة',
                    icon: const Icon(Icons.check, size: 20),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      await getIt<ShopProfileService>().saveProfile(
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        hours: hoursCtrl.text.trim(),
                        warranty: warrantyCtrl.text.trim(),
                      );
                      setState(() {
                        _profile = getIt<ShopProfileService>().getProfile();
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                'تم تحديث بيانات المحل والورشة بنجاح ✅'),
                            backgroundColor: TarmeemColors.readyDot,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _openEditSheet,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_back_ios,
                      size: 16, color: TarmeemColors.outline),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _profile.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? TarmeemColors.darkOnSurface : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'هاتف: ${_profile.phone}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? TarmeemColors.darkSecondaryContainer : TarmeemColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.storefront_outlined,
                        size: 24, color: isDark ? TarmeemColors.darkSecondary : TarmeemColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        size: 14, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                    const SizedBox(width: 6),
                    Text(
                      'تعديل البيانات',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                      ),
                    ),
                    const Spacer(),
                    Expanded(
                      child: Text(
                        _profile.address,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.place_outlined,
                        size: 14, color: TarmeemColors.outline),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchManagementTile extends StatelessWidget {
  const _BranchManagementTile();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<BranchesCubit, BranchesState>(
      builder: (context, state) {
        final count = state.branches.length;
        final activeName = state.activeBranch?.name ?? 'الفرع الرئيسي';

        return Material(
          color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => context.push('/settings/branches'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_ios, size: 16, color: TarmeemColors.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'إدارة فروع المحل ($count)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? TarmeemColors.darkOnSurface : null,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'الفرع النشط حالياً: $activeName',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.storefront_outlined,
                      size: 22,
                      color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

