// Login and Shop Registration screen — Screen 1.
//
// Tailored for Egypt (+20) with phone number and secret password/PIN.
// Supports both:
// - Login for existing workshops
// - Registration for new workshops (with shop name)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/widgets/buttons.dart';
import 'auth_cubit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shopNameController = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final shopName = _shopNameController.text.trim();

    if (_isRegisterMode) {
      context.read<AuthCubit>().register(
            phone: phone,
            password: password,
            shopName: shopName.isNotEmpty ? shopName : 'ورشة $phone',
          );
    } else {
      context.read<AuthCubit>().login(
            phone: phone,
            password: password,
          );
    }
  }

  void _showAccountNotFoundDialog(String phone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.storefront_outlined,
              size: 32,
              color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
            ),
          ),
          title: const Text(
            'هذا الرقم غير مسجل',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'لم يتم العثور على ورشة مسجلة برقم الهاتف:\n$phone\n\nهل ترغب في تسجيل حساب ورشة جديد بهذا الرقم الآن؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    setState(() {
                      _isRegisterMode = true;
                      _errorMessage = null;
                      _phoneController.text = phone;
                    });
                  },
                  icon: const Icon(Icons.add_business_rounded, color: Colors.white, size: 18),
                  label: const Text('تسجيل ورشة جديدة بهذا الرقم',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TarmeemColors.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('التحقق من رقم الهاتف مجدداً'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/');
        } else if (state is AuthAccountNotFound) {
          _showAccountNotFoundDialog(state.phone);
        } else if (state is AuthError) {
          setState(() {
            _errorMessage = state.message;
          });
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // ── Logo ────────────────────────────────────────────────
                  const _TarmeemLogo(),
                  const SizedBox(height: 18),

                  // ── Title + tagline ──────────────────────────────────────
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'نظام إدارة الورش ومراكز الصيانة في مصر 🇪🇬',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // ── Auth Mode Selector (دخول / تسجيل ورشة جديدة) ─────────
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isRegisterMode = false;
                                _errorMessage = null;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isRegisterMode
                                    ? (isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'تسجيل الدخول',
                                style: TextStyle(
                                  color: !_isRegisterMode
                                      ? Colors.white
                                      : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isRegisterMode = true;
                                _errorMessage = null;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isRegisterMode
                                    ? (isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'حساب ورشة جديد',
                                style: TextStyle(
                                  color: _isRegisterMode
                                      ? Colors.white
                                      : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Login Card ───────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF134E4A).withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Shop Name (Shown only in registration mode)
                        if (_isRegisterMode) ...[
                          Text(
                            'اسم الورشة / المحل',
                            style: theme.textTheme.labelLarge,
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _shopNameController,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              hintText: 'مثال: ورشة النور للإلكترونيات',
                              prefixIcon: Icon(
                                Icons.storefront_outlined,
                                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline,
                                size: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
                              ),
                            ),
                            validator: (v) {
                              if (_isRegisterMode && (v == null || v.trim().isEmpty)) {
                                return 'يرجى كتابة اسم الورشة أو المحل';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Phone number label
                        Text(
                          'رقم الهاتف المحمول (مصر)',
                          style: theme.textTheme.labelLarge,
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 8),

                        // ── Phone field ──────────────────────────────────
                        _EgyptianPhoneField(controller: _phoneController),
                        const SizedBox(height: 18),

                        // ── Password / PIN label ─────────────────────────
                        Text(
                          _isRegisterMode ? 'الرقم السري الجديد' : 'الرقم السري / كلمة المرور',
                          style: theme.textTheme.labelLarge,
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 8),

                        // ── Password field ───────────────────────────────
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            hintText: 'أدخل 4 أرقام أو حروف على الأقل',
                            hintTextDirection: TextDirection.rtl,
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 4) {
                              return 'الرقم السري يجب أن يكون 4 خانات على الأقل';
                            }
                            return null;
                          },
                        ),

                        // ── Error Message Banner ─────────────────────────
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: TarmeemColors.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: TarmeemColors.onErrorContainer,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: TarmeemColors.onErrorContainer,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // ── Submit button ─────────────────────────────────
                        BlocBuilder<AuthCubit, AuthState>(
                          builder: (context, state) {
                            final isLoading = state is AuthLoading;
                            return PrimaryButton(
                              label: _isRegisterMode ? 'إنشاء حساب ورشة جديد' : 'دخول إلى الورشة',
                              icon: Icon(
                                _isRegisterMode ? Icons.app_registration : Icons.arrow_back,
                                size: 18,
                              ),
                              isLoading: isLoading,
                              onPressed: isLoading ? null : _submit,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Switch Mode Link ─────────────────────────────────────
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isRegisterMode = !_isRegisterMode;
                        _errorMessage = null;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _isRegisterMode
                            ? 'لديك حساب ورشة بالفعل؟ تسجيل الدخول'
                            : 'لا تملك حساباً؟ اضغط هنا لإنشاء ورشة جديدة',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.secondary,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Security note ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 16,
                        color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.secondary,
                      ),
                      Flexible(
                        child: Text(
                          'بيانات ورشتك وحساباتك مشفرة ومحفوظة سحابياً',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _TarmeemLogo extends StatelessWidget {
  const _TarmeemLogo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1B6B65),
                TarmeemColors.primaryContainer,
                Color(0xFF002E2B),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.build_circle_outlined,
                  color: Colors.white,
                  size: 36,
                ),
                const SizedBox(height: 2),
                Text(
                  'ترميم',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLowest,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Icon(
              Icons.handyman_outlined,
              color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _EgyptianPhoneField extends StatelessWidget {
  const _EgyptianPhoneField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
        LengthLimitingTextInputFormatter(13),
      ],
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
        color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
      ),
      decoration: InputDecoration(
        hintText: '010 1234 5678',
        hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant).withValues(alpha: 0.4),
          letterSpacing: 1.2,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        // Egyptian country code prefix container (No overflow guaranteed)
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 8, right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇪🇬', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                '+20',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 24,
                color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant,
              ),
            ],
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.secondary,
            width: 1.5,
          ),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'يرجى إدخال رقم الهاتف المحمول';
        }
        final cleaned = v.replaceAll(RegExp(r'\s'), '');
        if (cleaned.length < 10) {
          return 'رقم الهاتف يجب أن يتكون من 11 رقماً (مثال: 01012345678)';
        }
        return null;
      },
    );
  }
}
