import 'package:flutter/material.dart';
import '../theme/color_tokens.dart';

/// A modern, themed confirmation dialog for exiting the application or logging out.
class ExitDialog extends StatelessWidget {
  const ExitDialog({
    super.key,
    this.title = 'الخروج من التطبيق',
    this.message = 'هل أنت متأكد من رغبتك في إغلاق تطبيق ترميم؟',
    this.subMessage = 'يمكنك العودة في أي وقت وستجد كافة بيانات ورشتك محفوظة ومزامنة بأمان.',
    this.confirmLabel = 'خروج الآن',
    this.cancelLabel = 'البقاء في التطبيق',
    this.icon = Icons.power_settings_new_rounded,
    this.isDanger = true,
  });

  final String title;
  final String message;
  final String subMessage;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final bool isDanger;

  /// Shows the exit confirmation dialog with a smooth animated transition.
  /// Returns `true` if the user confirms exit, `false` or `null` otherwise.
  static Future<bool?> show(BuildContext context) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => const ExitDialog(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  /// Shows a logout confirmation dialog.
  /// Returns `true` if the user confirms logout, `false` or `null` otherwise.
  static Future<bool?> showLogout(BuildContext context) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => const ExitDialog(
        title: 'تسجيل الخروج',
        message: 'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
        subMessage: 'سيتطلب ذلك إدخال رقم الهاتف ورمز الدخول مرة أخرى عند فتح التطبيق.',
        confirmLabel: 'تسجيل خروج',
        cancelLabel: 'إلغاء',
        icon: Icons.logout_rounded,
        isDanger: true,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryDanger = Color(0xFFEF4444);
    final dangerContainer = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 0,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Icon with glowing circular badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDanger
                      ? dangerContainer
                      : (isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDanger
                        ? primaryDanger.withValues(alpha: 0.3)
                        : (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDanger ? primaryDanger : TarmeemColors.primaryContainer).withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isDanger
                      ? (isDark ? const Color(0xFFFCA5A5) : primaryDanger)
                      : (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Main Message
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // Sub Message
              Text(
                subMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Action Buttons Row
              Row(
                children: [
                  // Cancel / Stay Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(
                          color: isDark ? TarmeemColors.darkOutlineVariant : TarmeemColors.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        foregroundColor: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                      ),
                      child: Text(
                        cancelLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Confirm Exit Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        backgroundColor: isDanger ? const Color(0xFFDC2626) : TarmeemColors.primaryContainer,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isDanger ? Icons.check_rounded : Icons.arrow_forward_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            confirmLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
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
      ),
    );
  }
}
