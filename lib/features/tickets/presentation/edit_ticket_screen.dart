/// Edit Ticket Screen — allows modifying an existing repair ticket.
///
/// Pre-fills all fields from the existing ticket and saves via updateTicket().
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/supabase_storage_service.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/ticket_entity.dart';
import '../domain/ticket_repository.dart';
import 'tickets_cubit.dart';

class EditTicketScreen extends StatefulWidget {
  const EditTicketScreen({super.key, required this.ticket});
  final TicketEntity ticket;

  @override
  State<EditTicketScreen> createState() => _EditTicketScreenState();
}

class _EditTicketScreenState extends State<EditTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _issueCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _depositCtrl;
  late final TextEditingController _partsCostCtrl;
  late final TextEditingController _partsWholesaleCtrl;
  late final TextEditingController _partsDescCtrl;
  late final TextEditingController _laborCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _shelfCtrl;
  late DeviceType _deviceType;
  String? _imageUrl;
  bool _isUploadingPhoto = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final t = widget.ticket;
    _nameCtrl = TextEditingController(text: t.customerName);
    _phoneCtrl = TextEditingController(text: t.customerPhone);
    _modelCtrl = TextEditingController(text: t.deviceModel);
    _issueCtrl = TextEditingController(text: t.issueDescription);
    _costCtrl = TextEditingController(
      text: t.estimatedCost > 0 ? t.estimatedCost.toStringAsFixed(0) : '',
    );
    _depositCtrl = TextEditingController(
      text: t.deposit > 0 ? t.deposit.toStringAsFixed(0) : '',
    );
    _partsCostCtrl = TextEditingController(
      text: t.partsCost > 0 ? t.partsCost.toStringAsFixed(0) : '',
    );
    _partsWholesaleCtrl = TextEditingController(
      text: t.partsWholesaleCost > 0 ? t.partsWholesaleCost.toStringAsFixed(0) : '',
    );
    _partsDescCtrl = TextEditingController(text: t.partsDescription ?? '');
    _laborCtrl = TextEditingController(
      text: t.laborCost > 0 ? t.laborCost.toStringAsFixed(0) : '',
    );
    _serialCtrl = TextEditingController(text: t.serialNumber ?? '');
    _shelfCtrl = TextEditingController(text: t.shelfLocation ?? '');
    _deviceType = t.deviceType;
    _imageUrl = t.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _modelCtrl.dispose();
    _issueCtrl.dispose();
    _costCtrl.dispose();
    _depositCtrl.dispose();
    _partsCostCtrl.dispose();
    _partsWholesaleCtrl.dispose();
    _partsDescCtrl.dispose();
    _laborCtrl.dispose();
    _serialCtrl.dispose();
    _shelfCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final cost = double.tryParse(_costCtrl.text.replaceAll(',', '')) ?? 0;
    final deposit = double.tryParse(_depositCtrl.text.replaceAll(',', '')) ?? 0;
    final partsCost = double.tryParse(_partsCostCtrl.text.replaceAll(',', '')) ?? 0;
    final partsWholesale = double.tryParse(_partsWholesaleCtrl.text.replaceAll(',', '')) ?? 0;
    final partsDesc = _partsDescCtrl.text.trim();

    final updated = widget.ticket.copyWith(
      customerName: _nameCtrl.text.trim(),
      customerPhone: _phoneCtrl.text.trim(),
      deviceType: _deviceType,
      deviceModel: _modelCtrl.text.trim(),
      issueDescription: _issueCtrl.text.trim(),
      estimatedCost: cost,
      deposit: deposit,
      partsCost: partsCost,
      partsWholesaleCost: partsWholesale,
      partsDescription: partsDesc.isEmpty ? null : partsDesc,
      serialNumber: _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
      shelfLocation: _shelfCtrl.text.trim().isEmpty ? null : _shelfCtrl.text.trim(),
      imageUrl: _imageUrl,
    );

    try {
      await getIt<TicketRepository>().updateTicket(updated);
      if (mounted) {
        context.read<TicketsCubit>().loadTickets();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث بيانات التذكرة #${widget.ticket.ticketNumber} بنجاح ✅'),
            backgroundColor: TarmeemColors.readyDot,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: TarmeemColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      // Set local preview immediately
      setState(() => _imageUrl = picked.path);

      if (SupabaseConfig.isConfigured) {
        setState(() => _isUploadingPhoto = true);
        final storage = getIt<SupabaseStorageService>();
        final publicUrl = await storage.uploadTicketImage(
          file: picked,
          ticketNumber: widget.ticket.ticketNumber,
        );
        if (!mounted) return;
        setState(() => _isUploadingPhoto = false);

        if (publicUrl != null) {
          setState(() => _imageUrl = publicUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفع صورة الجهاز بنجاح على سحابة Supabase ☁️✅'),
              backgroundColor: TarmeemColors.readyDot,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حفظ الصورة للمعاينة 📱'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'إعداد Supabase',
              onPressed: () => context.push('/settings/supabase'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isUploadingPhoto = false);
      debugPrint('Error picking/uploading image: $e');

      final errStr = e.toString().toLowerCase();
      final isBucketNotFound = errStr.contains('bucket not found') || errStr.contains('nosuchbucket');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBucketNotFound
                ? 'سلة التخزين (ticket-images) غير منشأة في Supabase! يرجى إنشاؤها وتفعيل Public Bucket.'
                : 'تعذر الرفع إلى Supabase: $e (تم حفظ المعاينة)'),
            backgroundColor: TarmeemColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
          icon: Icon(Icons.arrow_forward_ios,
              color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'تعديل بيانات التذكرة',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '#${widget.ticket.ticketNumber}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: TarmeemColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Customer Info Section ──────────────────────────────────
              const _SectionHeader(icon: Icons.person_outline, label: 'بيانات العميل'),
              const SizedBox(height: 12),
              TarmeemTextField(
                controller: _nameCtrl,
                label: 'اسم العميل',
                hint: 'مثال: أحمد عبد الله',
                prefixIcon: const Icon(Icons.person_outline,
                    color: TarmeemColors.outline, size: 20),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'اسم العميل مطلوب' : null,
              ),
              const SizedBox(height: 14),
              PhoneTextField(
                controller: _phoneCtrl,
                countryCode: '+20',
                countryFlag: '🇪🇬',
              ),
              const SizedBox(height: 20),

              // ── Device Section ────────────────────────────────────────
              const _SectionHeader(icon: Icons.devices_outlined, label: 'بيانات الجهاز'),
              const SizedBox(height: 12),
              _DeviceTypeSelector(
                selected: _deviceType,
                onSelect: (t) => setState(() => _deviceType = t),
              ),
              const SizedBox(height: 12),
              TarmeemTextField(
                controller: _modelCtrl,
                label: '',
                hint: 'الموديل أو النوع (مثال: آيفون 13 برو)',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'نوع الجهاز مطلوب' : null,
              ),
              const SizedBox(height: 14),
              TarmeemTextField(
                controller: _serialCtrl,
                label: 'الرقم التسلسلي (اختياري)',
                hint: 'IMEI أو سيريال نمبر',
                prefixIcon: const Icon(Icons.qr_code_outlined,
                    color: TarmeemColors.outline, size: 20),
              ),
              const SizedBox(height: 14),
              TarmeemTextField(
                controller: _shelfCtrl,
                label: 'موقع الرف (اختياري)',
                hint: 'مثال: A3 أو رف 2',
                prefixIcon: const Icon(Icons.shelves,
                    color: TarmeemColors.outline, size: 20),
              ),
              const SizedBox(height: 20),

              // ── Issue Section ─────────────────────────────────────────
              const _SectionHeader(icon: Icons.build_outlined, label: 'وصف العطل'),
              const SizedBox(height: 12),
              TarmeemTextField(
                controller: _issueCtrl,
                label: '',
                hint: 'وصف العطل أو المطلوب',
                maxLines: 4,
                minLines: 3,
                validator: (v) => v == null || v.trim().length < 5
                    ? 'يرجى توضيح العطل'
                    : null,
              ),
              const SizedBox(height: 20),

              // ── Photo ─────────────────────────────────────────────────
              const _SectionHeader(icon: Icons.photo_camera_outlined, label: 'صورة الجهاز'),
              const SizedBox(height: 12),
              _PhotoSection(
                imageUrl: _imageUrl,
                isUploading: _isUploadingPhoto,
                onPickCamera: () => _pickImage(ImageSource.camera),
                onPickGallery: () => _pickImage(ImageSource.gallery),
                onRemove: () {
                  if (_imageUrl != null && _imageUrl!.startsWith('http')) {
                    getIt<SupabaseStorageService>().deleteImageByUrl(_imageUrl!);
                  }
                  setState(() => _imageUrl = null);
                },
              ),
              const SizedBox(height: 20),

              // ── Cost Section ──────────────────────────────────────────
              const _SectionHeader(icon: Icons.payments_outlined, label: 'التكلفة والعربون'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TarmeemTextField(
                      controller: _partsCostCtrl,
                      label: 'سعر بيع القطعة للعميل',
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      prefixIcon: const Icon(Icons.build_circle_outlined,
                          color: TarmeemColors.outline, size: 18),
                      onChanged: (v) {
                        final p = double.tryParse(v.replaceAll(',', '')) ?? 0;
                        final l = double.tryParse(_laborCtrl.text.replaceAll(',', '')) ?? 0;
                        final total = l + p;
                        _costCtrl.text = total > 0 ? total.toStringAsFixed(0) : '';
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TarmeemTextField(
                      controller: _laborCtrl,
                      label: 'أجرة المصنعية (أجرة يدك)',
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      prefixIcon: const Icon(Icons.handyman_outlined,
                          color: TarmeemColors.outline, size: 18),
                      onChanged: (v) {
                        final l = double.tryParse(v.replaceAll(',', '')) ?? 0;
                        final p = double.tryParse(_partsCostCtrl.text.replaceAll(',', '')) ?? 0;
                        final total = l + p;
                        _costCtrl.text = total > 0 ? total.toStringAsFixed(0) : '';
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TarmeemTextField(
                      controller: _partsWholesaleCtrl,
                      label: 'سعر شراء القطعة (جملة)',
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      prefixIcon: const Icon(Icons.shopping_bag_outlined,
                          color: TarmeemColors.outline, size: 18),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TarmeemTextField(
                      controller: _partsDescCtrl,
                      label: 'اسم قطعة الغيار',
                      hint: 'مثال: شاشة OLED، بطارية...',
                      prefixIcon: const Icon(Icons.inventory_2_outlined,
                          color: TarmeemColors.outline, size: 18),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final pCost = double.tryParse(_partsCostCtrl.text.replaceAll(',', '')) ?? 0;
                  final pWhole = double.tryParse(_partsWholesaleCtrl.text.replaceAll(',', '')) ?? 0;
                  if (pCost > 0 && pWhole > 0) {
                    final profit = pCost - pWhole;
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    if (profit >= 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? TarmeemColors.darkReadyBackground : TarmeemColors.readyBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? TarmeemColors.darkReadyBorder : TarmeemColors.readyBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 16, color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'مكسبك الإضافي في قطعة الغيار: +${profit.toStringAsFixed(0)} ج.م ✨ (يُضاف لصافي أرباح الورشة)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تنبيه: سعر شراء القطعة (${pWhole.toStringAsFixed(0)}) أكبر من سعر البيع للعميل (${pCost.toStringAsFixed(0)})!',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TarmeemTextField(
                      controller: _depositCtrl,
                      label: 'العربون المدفوع',
                      hint: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      prefixIcon: const Icon(Icons.arrow_downward,
                          color: TarmeemColors.outline, size: 18),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TarmeemTextField(
                      controller: _costCtrl,
                      label: 'إجمالي الفاتورة للعميل',
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      prefixIcon: const Icon(Icons.attach_money,
                          color: TarmeemColors.outline, size: 18),
                      onChanged: (v) {
                        final c = double.tryParse(v.replaceAll(',', '')) ?? 0;
                        final p = double.tryParse(_partsCostCtrl.text.replaceAll(',', '')) ?? 0;
                        final l = (c - p).clamp(0.0, double.infinity);
                        _laborCtrl.text = l > 0 ? l.toStringAsFixed(0) : '';
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _QuickDepositPill(
                    label: 'مسح',
                    onTap: () {
                      _depositCtrl.text = '';
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 6),
                  _QuickDepositPill(
                    label: '+100',
                    onTap: () {
                      final d = double.tryParse(_depositCtrl.text.replaceAll(',', '')) ?? 0;
                      _depositCtrl.text = (d + 100).toStringAsFixed(0);
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 6),
                  _QuickDepositPill(
                    label: '+50',
                    onTap: () {
                      final d = double.tryParse(_depositCtrl.text.replaceAll(',', '')) ?? 0;
                      _depositCtrl.text = (d + 50).toStringAsFixed(0);
                      setState(() {});
                    },
                  ),
                  const Spacer(),
                  Text(
                    'إضافة سريعة للعربون:',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: TarmeemColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    _costCtrl.text = '';
                    _partsCostCtrl.text = '';
                    _partsWholesaleCtrl.text = '';
                    _laborCtrl.text = '';
                    _partsDescCtrl.text = '';
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF0D9488)),
                  label: const Text(
                    'مسح الأسعار (إعادة الجهاز لحالة قيد الفحص 🔍)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final cost = double.tryParse(_costCtrl.text.replaceAll(',', '')) ?? 0;
                  final partsCost = double.tryParse(_partsCostCtrl.text.replaceAll(',', '')) ?? 0;
                  final partsWholesale = double.tryParse(_partsWholesaleCtrl.text.replaceAll(',', '')) ?? 0;
                  final deposit = double.tryParse(_depositCtrl.text.replaceAll(',', '')) ?? 0;
                  if (cost <= 0 && partsCost <= 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
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
                                'الجهاز حالياً غير محدد السعر (قيد الفحص والتشخيص 🔍). إدخال المصنعية وقطع الغيار هنا يُحدد الفاتورة تلقائياً للعميل.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final labor = (cost - partsCost).clamp(0.0, double.infinity);
                  final partsProfit = (partsCost - partsWholesale).clamp(0.0, double.infinity);
                  final netProfit = (cost - (partsWholesale > 0 ? partsWholesale : partsCost)).clamp(0.0, double.infinity);
                  final remaining = (cost - deposit).clamp(0.0, double.infinity);

                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${labor.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              const Text('🛠️ مصنعية الورشة (أجرة يدك):'),
                            ],
                          ),
                          if (partsCost > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${partsCost.toStringAsFixed(0)} ج.م',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEA580C))),
                                Text('⚙️ سعر بيع القطعة للعميل ${_partsDescCtrl.text.trim().isNotEmpty ? "(${_partsDescCtrl.text.trim()})" : ""}:'),
                              ],
                            ),
                          ],
                          if (partsWholesale > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${partsWholesale.toStringAsFixed(0)} ج.م',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                const Text('📦 سعر شراء القطعة (جملة على الورشة):'),
                              ],
                            ),
                          ],
                          if (partsProfit > 0 && partsCost > 0 && partsWholesale > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('+${partsProfit.toStringAsFixed(0)} ج.م',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                                    )),
                                const Text('✨ مكسبك في قطعة الغيار:'),
                              ],
                            ),
                          ],
                          const Divider(height: 14, thickness: 0.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${cost.toStringAsFixed(0)} ج.م',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)),
                              const Text('🧾 إجمالي الفاتورة للعميل:'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${remaining.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              const Text('💰 المتبقي عند الاستلام:'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? TarmeemColors.darkReadyBackground : TarmeemColors.readyBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? TarmeemColors.darkReadyBorder : TarmeemColors.readyBorder),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${netProfit.toStringAsFixed(0)} ج.م',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'صافي ربح الورشة المؤكد ✨:',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.trending_up, size: 16, color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText),
                                      ],
                                    ),
                                  ],
                                ),
                                if (partsProfit > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '(أجرة المصنعية ${labor.toStringAsFixed(0)} ج.م + مكسب قطعة الغيار ${partsProfit.toStringAsFixed(0)} ج.م)',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // ── Save Button ───────────────────────────────────────────
              PrimaryButton(
                label: 'حفظ التعديلات',
                icon: const Icon(Icons.save_outlined, size: 20),
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _save,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 16, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
      ],
    );
  }
}

class _DeviceTypeSelector extends StatelessWidget {
  const _DeviceTypeSelector({
    required this.selected,
    required this.onSelect,
  });
  final DeviceType selected;
  final void Function(DeviceType) onSelect;

  static const _types = [
    (DeviceType.mobile, '📱', 'موبايل'),
    (DeviceType.laptop, '💻', 'لابتوب'),
    (DeviceType.watch, '⌚', 'ساعة'),
    (DeviceType.home, '🏠', 'كهربائيات'),
    (DeviceType.other, '🔧', 'أخرى'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: _types.map((e) {
          final (type, emoji, label) = e;
          final isSelected = selected == type;
          return GestureDetector(
            onTap: () => onSelect(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer)
                    : (isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer)
                      : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : (isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.imageUrl,
    required this.isUploading,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemove,
  });
  final String? imageUrl;
  final bool isUploading;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (isUploading) {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: TarmeemColors.primaryFixed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: TarmeemColors.primaryContainer.withValues(alpha: 0.3),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 10),
            Text(
              'جارِ رفع صورة الجهاز إلى Supabase... ☁️',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TarmeemColors.primaryContainer,
              ),
            ),
          ],
        ),
      );
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final isRemote = imageUrl!.startsWith('http');
      return Stack(
        alignment: Alignment.topLeft,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: isRemote
                ? Image.network(
                    imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 180,
                        color: TarmeemColors.surfaceContainerHigh,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: TarmeemColors.surfaceContainerHigh,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: TarmeemColors.outline, size: 40),
                      ),
                    ),
                  )
                : (kIsWeb
                    ? Image.network(imageUrl!,
                        height: 180, width: double.infinity, fit: BoxFit.cover)
                    : Image.file(File(imageUrl!),
                        height: 180, width: double.infinity, fit: BoxFit.cover)),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRemote ? Icons.cloud_done : Icons.phone_android,
                    size: 13,
                    color: isRemote ? TarmeemColors.readyDot : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isRemote ? 'Supabase Storage ☁️' : 'تخزين محلي 📱',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton.filled(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemove,
              style: IconButton.styleFrom(
                backgroundColor: TarmeemColors.error,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('المعرض'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPickCamera,
                  icon: const Icon(Icons.photo_camera_outlined, size: 16),
                  label: const Text('الكاميرا'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? TarmeemColors.primary : TarmeemColors.primaryContainer,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          if (!SupabaseConfig.isConfigured) ...[
            const SizedBox(height: 8),
            Text(
              'سحابة Supabase غير مهيأة — اضغط في الإعدادات لتفعيل الرفع السحابي',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickDepositPill extends StatelessWidget {
  const _QuickDepositPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

