import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/services/supabase_storage_service.dart';
import '../../../core/theme/color_tokens.dart';

class SupabaseSettingsScreen extends StatefulWidget {
  const SupabaseSettingsScreen({super.key});

  @override
  State<SupabaseSettingsScreen> createState() => _SupabaseSettingsScreenState();
}

class _SupabaseSettingsScreenState extends State<SupabaseSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _urlCtrl;
  late TextEditingController _anonKeyCtrl;
  late TextEditingController _bucketCtrl;

  bool _obscureKey = true;
  bool _isLoading = false;
  bool _isTesting = false;
  SupabaseStorageTestResult? _testResult;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(
      text: SupabaseConfig.activeUrl != SupabaseConfig.placeholderUrl
          ? SupabaseConfig.activeUrl
          : '',
    );
    _anonKeyCtrl = TextEditingController(
      text: SupabaseConfig.activeAnonKey != SupabaseConfig.placeholderAnonKey
          ? SupabaseConfig.activeAnonKey
          : '',
    );
    _bucketCtrl = TextEditingController(
      text: SupabaseConfig.activeBucket,
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _anonKeyCtrl.dispose();
    _bucketCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    final prefs = getIt<SharedPreferences>();
    final success = await SupabaseConfig.updateCredentials(
      url: _urlCtrl.text.trim(),
      anonKey: _anonKeyCtrl.text.trim(),
      bucket: _bucketCtrl.text.trim(),
      prefs: prefs,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ مفاتيح سحابة Supabase بنجاح! ☁️✅'),
          backgroundColor: TarmeemColors.readyDot,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ البيانات. يرجى التأكد من صحة الرابط والمفتاح.'),
          backgroundColor: TarmeemColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    if (_urlCtrl.text.trim().isEmpty || _anonKeyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال الرابط والمفتاح أولاً لتجربة الاتصال'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Auto-save first
    await _saveSettings();

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final storageService = getIt<SupabaseStorageService>();
    final result = await storageService.testStorageConnection();

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _testResult = result;
    });
  }

  void _copySqlScript() {
    const sql = '''
-- 1. Create ticket-images storage bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('ticket-images', 'ticket-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Allow public access to read and upload device photos
CREATE POLICY "Public Access ticket-images"
ON storage.objects FOR SELECT
USING (bucket_id = 'ticket-images');

CREATE POLICY "Public Upload ticket-images"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'ticket-images');

CREATE POLICY "Public Update ticket-images"
ON storage.objects FOR UPDATE
USING (bucket_id = 'ticket-images');

CREATE POLICY "Public Delete ticket-images"
ON storage.objects FOR DELETE
USING (bucket_id = 'ticket-images');
''';

    Clipboard.setData(const ClipboardData(text: sql));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ كود SQL لتهيئة سلة التخزين في الحافظة 📋'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: TarmeemColors.primaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = SupabaseConfig.isConfigured;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_forward_ios,
                color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface, size: 20),
            onPressed: () => context.pop(),
          ),
          centerTitle: true,
          title: Text(
            'إعدادات Supabase وتخزين الصور',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Status Banner Card ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isConfigured
                        ? (isDark ? TarmeemColors.darkReadyBackground : TarmeemColors.readyBadgeBg)
                        : (isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isConfigured
                          ? (isDark ? TarmeemColors.darkReadyBorder : TarmeemColors.readyDot.withValues(alpha: 0.5))
                          : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isConfigured
                              ? (isDark ? TarmeemColors.darkReadyDot.withValues(alpha: 0.15) : TarmeemColors.readyDot.withValues(alpha: 0.15))
                              : TarmeemColors.secondary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isConfigured
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                          color: isConfigured
                              ? (isDark ? TarmeemColors.darkReadyDot : TarmeemColors.readyDot)
                              : TarmeemColors.secondary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConfigured
                                  ? 'سحابة Supabase مهيأة ونشطة 🟢'
                                  : 'سحابة Supabase غير مهيأة بعد ⚠️',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isConfigured
                                    ? (isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText)
                                    : (isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isConfigured
                                  ? 'يتم رفع صور الأجهزة مباشرة إلى سلة (${SupabaseConfig.activeBucket}) وتتوفر بروابط عامة للعملاء.'
                                  : 'أدخل مفاتيح مشروعك بالأسفل لتخزين صور الأجهزة سحابياً وظهورها بصفحة التتبع.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Diagnostic Test Result ──────────────────────────────────
                if (_testResult != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _testResult!.isSuccess
                          ? TarmeemColors.readyBadgeBg
                          : TarmeemColors.errorContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _testResult!.isSuccess
                            ? TarmeemColors.readyDot
                            : TarmeemColors.error,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _testResult!.isSuccess
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: _testResult!.isSuccess
                              ? TarmeemColors.readyDot
                              : TarmeemColors.error,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _testResult!.message,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _testResult!.isSuccess
                                  ? TarmeemColors.readyText
                                  : TarmeemColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // ── Credentials Form Card ───────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بيانات الاتصال بالمشروع',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 14),

                      // Project URL
                      TextFormField(
                        controller: _urlCtrl,
                        keyboardType: TextInputType.url,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'رابط المشروع (Project URL)',
                          hintText: 'https://xxxxxxxx.supabase.co',
                          prefixIcon: const Icon(Icons.link, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surface,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'رابط المشروع مطلوب';
                          }
                          if (!val.trim().startsWith('http')) {
                            return 'يجب أن يبدأ الرابط بـ https://';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Anon Key
                      TextFormField(
                        controller: _anonKeyCtrl,
                        obscureText: _obscureKey,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'المفتاح العام (anon public key)',
                          hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6...',
                          prefixIcon: const Icon(Icons.key, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureKey
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscureKey = !_obscureKey),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surface,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'المفتاح العام مطلوب';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Bucket Name
                      TextFormField(
                        controller: _bucketCtrl,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'اسم سلة تخزين الصور (Storage Bucket)',
                          hintText: 'ticket-images',
                          prefixIcon: const Icon(Icons.folder_special, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surface,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'اسم سلة التخزين مطلوب';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isTesting ? null : _testConnection,
                              icon: _isTesting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.network_check, size: 18),
                              label: Text(_isTesting
                                  ? 'جارِ الفحص...'
                                  : 'اختبار الاتصال'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _saveSettings,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save, size: 18),
                              label: Text(_isLoading
                                  ? 'جارِ الحفظ...'
                                  : 'حفظ وتفعيل'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
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
                const SizedBox(height: 20),

                // ── Quick Setup Guide & SQL Card ────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: TarmeemColors.secondary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'خطوات تجهيز سلة التخزين في Supabase',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '1. افتح لوحة تحكم مشروعك في supabase.com.\n'
                        '2. انتقل إلى قائمة Storage ثم أنشئ Bucket جديد باسم "ticket-images".\n'
                        '3. تأكد من تفعيل خيار (Public bucket) ليتمكن العملاء من فتح الصورة.\n'
                        '4. أو انسخ كود SQL بالأسفل والصقه في SQL Editor لتنفيذ كل شيء بنقرة واحدة.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _copySqlScript,
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('نسخ كود SQL لإنشاء السلة والسياسات'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
