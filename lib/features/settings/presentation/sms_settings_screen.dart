import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/native_sms_service.dart';
import '../../../core/theme/color_tokens.dart';

class SmsSettingsScreen extends StatefulWidget {
  const SmsSettingsScreen({super.key});

  @override
  State<SmsSettingsScreen> createState() => _SmsSettingsScreenState();
}

class _SmsSettingsScreenState extends State<SmsSettingsScreen> {
  final NativeSmsService _smsService = getIt<NativeSmsService>();
  final TextEditingController _testPhoneController = TextEditingController();

  List<SimCardInfo> _simCards = [];
  int? _selectedSubId;
  bool _hasPermissions = false;
  bool _isLoadingSims = true;
  bool _isSendingTest = false;
  SmsSendResult? _lastTestResult;

  bool _autoReceiptEnabled = false;
  bool _autoReadyEnabled = false;

  @override
  void initState() {
    super.initState();
    _autoReceiptEnabled = _smsService.isAutoReceiptSmsEnabled();
    _autoReadyEnabled = _smsService.isAutoReadySmsEnabled();
    _selectedSubId = _smsService.getPreferredSubscriptionId();
    _loadSimCardsAndPermissions();
  }

  @override
  void dispose() {
    _testPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSimCardsAndPermissions() async {
    setState(() => _isLoadingSims = true);
    final hasPerms = await _smsService.checkPermissions();
    List<SimCardInfo> sims = [];
    if (hasPerms) {
      sims = await _smsService.getSimCards();
    }

    if (mounted) {
      setState(() {
        _hasPermissions = hasPerms;
        _simCards = sims;
        _isLoadingSims = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await _smsService.requestPermissions();
    if (!mounted) return;
    setState(() => _hasPermissions = granted);
    if (granted) {
      final sims = await _smsService.getSimCards();
      if (!mounted) return;
      setState(() => _simCards = sims);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل أذونات إرسال الرسائل والشرائح بنجاح ✅'),
          backgroundColor: TarmeemColors.readyDot,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفض الإذن. يرجى تفعيله من إعدادات الهاتف لإرسال الرسائل مباشرة.'),
          backgroundColor: TarmeemColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendTestSms() async {
    final phone = _testPhoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة رقم هاتف لإرسال الرسالة التجريبية إليه.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSendingTest = true;
      _lastTestResult = null;
    });

    final testMessage = 'تجربة إرسال رسالة من تطبيق ترميم لإدارة ورش الصيانة بنجاح 🎉';
    final result = await _smsService.sendDirectSms(
      phone: phone,
      message: testMessage,
      subscriptionId: _selectedSubId,
    );

    if (mounted) {
      setState(() {
        _isSendingTest = false;
        _lastTestResult = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess
                ? 'تم إرسال الرسالة التجريبية بنجاح عبر الشريحة! ✅'
                : 'فشل الإرسال: ${result.message}',
          ),
          backgroundColor: result.isSuccess ? TarmeemColors.readyDot : TarmeemColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios, color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'إرسال SMS من شريحة الموبايل',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header / Info banner
          _buildInfoBanner(),
          const SizedBox(height: 16),

          // Permission Status Card
          _buildPermissionCard(),
          const SizedBox(height: 20),

          // Dual SIM Selection Card
          _buildSimSelectionCard(),
          const SizedBox(height: 20),

          // Automation Settings
          _buildAutomationCard(),
          const SizedBox(height: 20),

          // Live Test Transmission
          _buildTestCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.primaryFixed,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'إرسال مباشر واقتصادي 💡',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'يتم الإرسال مباشرة من شريحة المحل في الخلفية دون فتح أي تطبيقات خارجية، وتعتمد التكلفة على باقة رسائل شريحتك (حوالي 15 ج.م لـ 1,000 رسالة).',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? TarmeemColors.darkSurfaceContainerHigh : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.sim_card_outlined, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _hasPermissions
                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                      : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _hasPermissions ? 'مفعلة وجاهزة' : 'بحاجة لتفعيل',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _hasPermissions
                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF166534))
                        : (isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'صلاحية إرسال الرسائل (SEND_SMS)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _hasPermissions
                ? 'التطبيق يمتلك إذن إرسال الرسائل مباشرة وقراءة معلومات الشرائح في الخلفية.'
                : 'يحتاج التطبيق إلى إذن إرسال الرسائل وقراءة حالة الشرائح لإرسال إشعارات العملاء مباشرة.',
            style: TextStyle(fontSize: 12, color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
            textAlign: TextAlign.right,
          ),
          if (!_hasPermissions) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _requestPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.security, size: 18),
                label: const Text('منح صلاحية الإرسال والشرائح', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimSelectionCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.refresh, size: 20, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                onPressed: _loadSimCardsAndPermissions,
                tooltip: 'إعادة فحص الشرائح',
              ),
              const Spacer(),
              const Text(
                'اختيار الشريحة المرسلة (Dual SIM)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'حدد الشريحة التي تحتوي على باقة رسائل لإرسال إشعارات الصيانة منها:',
            style: TextStyle(fontSize: 12, color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),

          if (_isLoadingSims)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (!_hasPermissions)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: TarmeemColors.secondary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'يرجى منح الأذونات أعلاه لعرض شرائح الهاتف المتوفرة واختيارها.',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            )
          else if (_simCards.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: TarmeemColors.secondary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لم يتم العثور على شرائح SIM نشطة في الهاتف حالياً، سيتم استخدام شريحة النظام الافتراضية.',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Default system SIM option
            _buildSimTile(
              title: 'شريحة النظام الافتراضية (تلقائي)',
              subtitle: 'استخدام الشريحة المعينة في إعدادات الأندرويد كافتراضية',
              isSelected: _selectedSubId == null,
              onTap: () async {
                setState(() => _selectedSubId = null);
                await _smsService.setPreferredSubscriptionId(null);
              },
            ),
            const SizedBox(height: 8),
            // Discovered SIM cards
            for (final sim in _simCards) ...[
              _buildSimTile(
                title: sim.displayName,
                subtitle: 'المشغل: ${sim.carrierName} (فتحة الشريحة ${sim.slotIndex + 1})',
                isSelected: _selectedSubId == sim.subscriptionId,
                onTap: () async {
                  setState(() => _selectedSubId = sim.subscriptionId);
                  await _smsService.setPreferredSubscriptionId(sim.subscriptionId);
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSimTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isSelected
          ? (isDark ? TarmeemColors.primary.withValues(alpha: 0.25) : TarmeemColors.primaryFixed)
          : (isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer)
                  : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected
                    ? (isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer)
                    : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isSelected
                            ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                            : (isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface),
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.sim_card,
                color: isSelected
                    ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                    : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutomationCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          const Text(
            'الأتمتة والإرسال التلقائي ⚡',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'تحكم في الحالات التي يتم فيها إرسال رسائل SMS تلقائياً للعملاء:',
            style: TextStyle(fontSize: 12, color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: isDark ? TarmeemColors.primary.withValues(alpha: 0.5) : TarmeemColors.primaryFixed,
            activeThumbColor: isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer,
            title: const Text(
              'إرسال إيصال استلام تلقائياً عند تسجيل جهاز جديد',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
            subtitle: Text(
              'يتضمن رقم التذكرة، تفاصيل الجهاز، ورابط التتبع المباشر',
              style: TextStyle(fontSize: 11, color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
              textAlign: TextAlign.right,
            ),
            value: _autoReceiptEnabled,
            onChanged: (val) async {
              setState(() => _autoReceiptEnabled = val);
              await _smsService.setAutoReceiptSmsEnabled(val);
            },
          ),
          const Divider(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: isDark ? TarmeemColors.primary.withValues(alpha: 0.5) : TarmeemColors.primaryFixed,
            activeThumbColor: isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer,
            title: const Text(
              'إرسال إشعار تلقائياً عند جاهزية الجهاز للاستلام',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
            subtitle: Text(
              'ينبه العميل باكتمال الصيانة والمبلغ المطلوب للاستلام',
              style: TextStyle(fontSize: 11, color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
              textAlign: TextAlign.right,
            ),
            value: _autoReadyEnabled,
            onChanged: (val) async {
              setState(() => _autoReadyEnabled = val);
              await _smsService.setAutoReadySmsEnabled(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          const Text(
            'اختبار الإرسال المباشر للرسالة 🚀',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'أدخل رقم هاتفك أو هاتف الورشة للتحقق من الرصيد وعمل الشريحة في الخلفية:',
            style: TextStyle(fontSize: 12, color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _testPhoneController,
            keyboardType: TextInputType.phone,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              hintText: '01012345678',
              prefixIcon: const Icon(Icons.phone_android, size: 20),
              filled: true,
              fillColor: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isSendingTest || !_hasPermissions) ? null : _sendTestSms,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSendingTest
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('جارِ الإرسال عبر الشريحة...', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    )
                  : const Text(
                      'إرسال رسالة اختبارية الآن',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
            ),
          ),
          if (_lastTestResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _lastTestResult!.isSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _lastTestResult!.isSuccess ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _lastTestResult!.isSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _lastTestResult!.isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _lastTestResult!.message,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _lastTestResult!.isSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
