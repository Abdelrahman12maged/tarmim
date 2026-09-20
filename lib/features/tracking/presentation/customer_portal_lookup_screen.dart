import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Public web landing portal for customers to track their repair status.
class CustomerPortalLookupScreen extends StatefulWidget {
  const CustomerPortalLookupScreen({super.key});

  @override
  State<CustomerPortalLookupScreen> createState() => _CustomerPortalLookupScreenState();
}

class _CustomerPortalLookupScreenState extends State<CustomerPortalLookupScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uri = Uri.base;
      if (uri.hasFragment && uri.fragment.contains('/track/')) {
        final path = uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}';
        context.go(path);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch([String? overrideQuery]) {
    final query = (overrideQuery ?? _searchController.text).trim();
    if (query.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال رقم التذكرة أو رقم الهاتف للمتابعة';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    // Clean ticket number (e.g. #TR-4082 -> TR-4082)
    final cleanId = query.replaceAll('#', '').trim();
    context.go('/track/$cleanId');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header Gradient Banner ──────────────────────────────────
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFF0F766E),
                      Color(0xFF134E4A),
                      Color(0xFF0F172A),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // App Logo
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF14B8A6).withValues(alpha: 0.4),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF14B8A6).withValues(alpha: 0.25),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.build_circle_outlined,
                                size: 48,
                                color: Color(0xFF14B8A6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          'تِرميم — بوابة متابعة الصيانة',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'تابع حالة جهازك ومراحل الفحص والإصلاح لحظة بلحظة وبكل شفافية',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),

                        // ── Search Card ───────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF334155),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'أدخل رقم إيصال الصيانة أو رقم الهاتف',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _searchController,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'مثال: TR-1001 أو 01012345678',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 14,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.receipt_long_outlined,
                                    color: Color(0xFF14B8A6),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF475569)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF334155)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 2),
                                  ),
                                ),
                                onSubmitted: (_) => _submitSearch(),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 18),
                              ElevatedButton(
                                onPressed: () => _submitSearch(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D9488),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'تتبع حالة الجهاز الآن',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Features Section ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مميزات بوابة متابعة الصيانة',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'صُممت هذه الصفحة خصيصاً لخدمة عملاء ورش الصيانة المعتمدة',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _FeatureTile(
                          icon: Icons.notifications_active_outlined,
                          title: 'متابعة حية للمراحل',
                          subtitle: 'تعرف بدقة على موعد فحص جهازك، توفير القطع البديلة، وجاهزيته للاستلام.',
                        ),
                        const SizedBox(height: 12),
                        const _FeatureTile(
                          icon: Icons.camera_alt_outlined,
                          title: 'توثيق الفحص بالصور',
                          subtitle: 'مشاهدة صور فحص الجهاز عند الاستلام وتوثيق حالته الميكانيكية.',
                        ),
                        const SizedBox(height: 12),
                        const _FeatureTile(
                          icon: Icons.payments_outlined,
                          title: 'شفافية الحساب والفاتورة',
                          subtitle: 'تفصيل واضح للتكلفة الإجمالية، العربون المسدد، والمبلغ المتبقي للاستلام.',
                        ),
                        const SizedBox(height: 12),
                        const _FeatureTile(
                          icon: Icons.verified_user_outlined,
                          title: 'ضمان معتمد من الورشة',
                          subtitle: 'شهادة ضمان رقمية تحميك وتوضح مدة الضمان على القطع والإصلاح.',
                        ),
                        const SizedBox(height: 48),

                        // Footer note
                        Center(
                          child: Text(
                            'تِرميم — نظام إدارة ومتابعة الصيانة لكافة الورش ومراكز الخدمة\nجميع الحقوق محفوظة © 2026',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                              height: 1.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF2DD4BF), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
