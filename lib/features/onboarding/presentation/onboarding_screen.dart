/// Interactive Onboarding Screen.
///
/// Features 4 animated, beautifully styled slides highlighting the core value
/// propositions of the Tarmeem / Fixly application.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String prefHasSeenOnboarding = 'tarmim_has_seen_onboarding';

  /// Checks if the user has already seen the onboarding flow.
  static bool hasSeen(SharedPreferences prefs) {
    return prefs.getBool(prefHasSeenOnboarding) ?? false;
  }

  /// Marks the onboarding as completed.
  static Future<void> markSeen(SharedPreferences prefs) async {
    await prefs.setBool(prefHasSeenOnboarding, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      title: 'إدارة ورشتك وتذاكر الصيانة الذكية',
      subtitle: 'سجّل استلام الأجهزة وتابع مراحل الإصلاح خطوة بخطوة',
      description:
          'تسجيل تفاصيل الأعطال بالصور، وتحديد الأرفف والأرقام التسلسلية، وإدارة التكلفة والعربون والمبالغ المتبقية في شاشة واحدة منسقة.',
      badge: 'استلام ومتابعة الأجهزة 📱',
      badgeColor: Color(0xFF4F46E5),
      icon: Icons.precision_manufacturing_outlined,
      highlights: [
        '📸 التقاط صور لحالة الجهاز فور الاستلام',
        '🔖 كود تتبع ورقم إيصال فريد لكل جهاز',
        '💰 حساب العربون والمتبقي بدقة متناهية',
      ],
      gradient: [Color(0xFF1E1B4B), Color(0xFF312E81)],
      accentColor: Color(0xFF818CF8),
    ),
    _OnboardingItem(
      title: 'إرسال إشعارات الواتساب الرسمية والآمنة',
      subtitle: 'تواصل مباشر مع عملائك برابط التتبع المباشر',
      description:
          'أرسل إيصالات الاستلام، عروض الأسعار، ورسائل "جاهز للاستلام" مباشرة إلى واتساب العميل بنقرة واحدة وبأمان تام 100% عبر تطبيق الواتساب الرسمي.',
      badge: 'واتساب مباشر وآمن ⚡',
      badgeColor: Color(0xFF059669),
      icon: Icons.chat_bubble_outline_rounded,
      highlights: [
        '🔒 إرسال رسمي آمن 100% بدون أي مخاطرة بحظر رقمك',
        '🧾 إيصال منسق يحمل بيانات الجهاز ورابط التتبع الحي',
        '🟢 تنبيه العميل باكتمال الصيانة فوراً بنقرة واحدة',
      ],
      gradient: [Color(0xFF064E3B), Color(0xFF065F46)],
      accentColor: Color(0xFF34D399),
    ),
    _OnboardingItem(
      title: 'إرسال SMS رسمي من شريحة هاتفك مباشرة',
      subtitle: 'أرخص تكلفة مراسلة محلية بدون وسطاء',
      description:
          'استفد من شريحة هاتفك (Dual SIM) لإرسال رسائل نصية قصيرة رسمية للزبائن مباشرة من باقة خطك العادية بتكلفة محلية لا تذكر.',
      badge: 'SMS الشريحة المباشر 💬',
      badgeColor: Color(0xFF2563EB),
      icon: Icons.sim_card_outlined,
      highlights: [
        '📶 دعم الشريحة المزدوجة واختيار الشريحة المفضلة',
        '💸 أرخص تكلفة رسائل محلية (أقل من قرشين للرسالة)',
        '🔍 تقارير تسليم وتأكيد الإرسال فورياً في التطبيق',
      ],
      gradient: [Color(0xFF172554), Color(0xFF1E3A8A)],
      accentColor: Color(0xFF60A5FA),
    ),
    _OnboardingItem(
      title: 'رابط تتبع حي وفاتورة رقمية للعميل',
      subtitle: 'الزبون يتابع جهازه من أي متصفح دون تثبيت برامج',
      description:
          'رابط ويب مخصص لكل جهاز يُرسل للعميل، يستطيع من خلاله متابعة مراحل الصيانة والفاتورة والتقرير الفني مباشرة من متصفح هاتفه.',
      badge: 'متابعة حية عبر الإنترنت 🌐',
      badgeColor: Color(0xFF7C3AED),
      icon: Icons.public_outlined,
      highlights: [
        '🔗 صفحة ويب حية ومحدثة لحظة بلحظة للزبون',
        '📄 فحص الفاتورة والمبلغ المطلوب وتقرير الصيانة',
        '🌟 احترافية تميز ورشتك عن جميع المنافسين',
      ],
      gradient: [Color(0xFF2E1065), Color(0xFF4C1D95)],
      accentColor: Color(0xFFA78BFA),
    ),
  ];

  Future<void> _finishOnboarding() async {
    final prefs = getIt<SharedPreferences>();
    await OnboardingScreen.markSeen(prefs);
    if (!mounted) return;
    context.go('/login');
  }

  void _nextPage() {
    if (_currentIndex < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentIndex == _items.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with brand and Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Skip button
                  if (!isLastPage)
                    TextButton(
                      onPressed: _finishOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: const Text(
                        'تخطي',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    const SizedBox(width: 60),

                  const Spacer(),

                  // Brand name & logo
                  Row(
                    children: [
                      const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF10B981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.build_outlined,
                            color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildPage(item);
                },
              ),
            ),

            // Bottom controls: Indicators & CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                children: [
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_items.length, (idx) {
                      final isSelected = idx == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSelected ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _items[_currentIndex].accentColor
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _items[_currentIndex]
                                        .accentColor
                                        .withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      // Back button (if not first page)
                      if (_currentIndex > 0) ...[
                        IconButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white70, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Next / Start Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _items[_currentIndex].accentColor,
                            foregroundColor: const Color(0xFF0F172A),
                            elevation: 8,
                            shadowColor: _items[_currentIndex]
                                .accentColor
                                .withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLastPage ? 'ابدأ الاستخدام الآن 🚀' : 'التالي',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isLastPage
                                    ? Icons.check_circle_outline
                                    : Icons.arrow_forward_ios,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingItem item) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),

          // Illustration Hero Container
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: item.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: item.accentColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: item.gradient.last.withValues(alpha: 0.4),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glowing radial background
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.accentColor.withValues(alpha: 0.15),
                  ),
                ),
                // Main Icon
                Icon(
                  item.icon,
                  size: 80,
                  color: item.accentColor,
                ),
                // Badge overlay
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: item.badgeColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          // Title
          Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            item.subtitle,
            style: TextStyle(
              color: item.accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          // Description
          Text(
            item.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Highlights card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: item.highlights.map((h) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: Text(
                          h,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _OnboardingItem {
  final String title;
  final String subtitle;
  final String description;
  final String badge;
  final Color badgeColor;
  final IconData icon;
  final List<String> highlights;
  final List<Color> gradient;
  final Color accentColor;

  const _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.highlights,
    required this.gradient,
    required this.accentColor,
  });
}
