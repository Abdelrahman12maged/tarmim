// New Repair Ticket screen — Screen 3.
//
// Matches the mockup: customer info, device type chips, issue description,
// estimated cost + deposit with quick-add buttons, WhatsApp toggle, submit CTA.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/url_helper.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/native_sms_service.dart';
import '../../../core/services/supabase_storage_service.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/ticket_repository.dart';
import 'new_ticket_cubit.dart';

const Map<DeviceType, List<String>> _commonBrands = {
  DeviceType.mobile: [
    'آبل iPhone',
    'سامسونج Galaxy',
    'شاومي Xiaomi',
    'أوبو Oppo',
    'ريلمي Realme',
    'فيفو Vivo',
    'هواوي Huawei',
    'إنفينكس Infinix',
  ],
  DeviceType.laptop: [
    'ديل Dell',
    'اتش بي HP',
    'لينوفو Lenovo',
    'ماك بوك Mac',
    'أسوس Asus',
    'إيسر Acer',
  ],
  DeviceType.home: [
    'توشيبا Toshiba',
    'شارب Sharp',
    'إل جي LG',
    'سامسونج Samsung',
    'ميانتا Mienta',
    'تورنيدو Tornado',
    'فيليبس Philips',
    'بلاك آند ديكر',
  ],
  DeviceType.watch: [
    'آبل ووتش Apple Watch',
    'سامسونج ووتش Galaxy Watch',
    'هواوي ووتش Watch',
    'كاسيو G-Shock',
  ],
  DeviceType.other: [
    'بلايستيشن PlayStation',
    'إكس بوكس Xbox',
    'شاشة تلفزيون',
    'راوتر نت',
    'ريسيفر',
  ],
};

const Map<DeviceType, List<String>> _commonFaults = {
  DeviceType.mobile: [
    'تغيير شاشة / باغة',
    'تغيير بطارية',
    'سوكت / مدخل شحن',
    'فاصل باور / لا يفتح',
    'سقوط في الماء 💧',
    'سماعة / مايك',
    'سوفت وير / فورمات',
    'صيانة كاميرا',
  ],
  DeviceType.laptop: [
    'تثبيت ويندوز وسوفت وير',
    'تغيير شاشة مكسورة',
    'تغيير بطارية / شاحن',
    'تنظيف ومعجون حراري',
    'تغيير كيبورد تالف',
    'ترقية SSD ورامات',
    'فاصل باور نهائياً',
  ],
  DeviceType.home: [
    'فاصل باور نهائياً',
    'صوت عالي واهتزاز',
    'ماس كهربائي / شرز',
    'ضعف في الأداء والكفاءة',
    'عطل لوحة التحكم والأزرار',
    'تنظيف وصيانة دورية',
  ],
  DeviceType.watch: [
    'تغيير شاشة مكسورة',
    'تغيير بطارية',
    'عطل شحن وقاعدة',
    'دخول ماء ورطوبة',
  ],
  DeviceType.other: [
    'فحص وتشخيص شامل',
    'فاصل باور نهائياً',
    'مدخل الشحن / الباور',
    'صيانة وتنظيف داخلي',
  ],
};

class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  final _partsCostCtrl = TextEditingController();
  final _partsWholesaleCtrl = TextEditingController();
  final _partsDescCtrl = TextEditingController();
  final _laborCtrl = TextEditingController();

  String? _detectedReturningCustomer;
  int _detectedCustomerTicketCount = 0;

  @override
  void initState() {
    super.initState();
    // Pre-fill from cubit state (set by router from customer profile extra data)
    final cubitState = context.read<NewTicketCubit>().state;
    if (cubitState.customerName.isNotEmpty) {
      _nameCtrl.text = cubitState.customerName;
    }
    if (cubitState.customerPhone.isNotEmpty) {
      _phoneCtrl.text = cubitState.customerPhone;
      _onPhoneChanged(cubitState.customerPhone);
    }
    if (cubitState.partsCost > 0) {
      _partsCostCtrl.text = cubitState.partsCost.toStringAsFixed(0);
    }
    if (cubitState.partsWholesaleCost > 0) {
      _partsWholesaleCtrl.text =
          cubitState.partsWholesaleCost.toStringAsFixed(0);
    }
    if (cubitState.partsDescription != null &&
        cubitState.partsDescription!.isNotEmpty) {
      _partsDescCtrl.text = cubitState.partsDescription!;
    }
    if (cubitState.estimatedCost > 0) {
      _costCtrl.text = cubitState.estimatedCost.toStringAsFixed(0);
    }
    if (cubitState.laborCost > 0) {
      _laborCtrl.text = cubitState.laborCost.toStringAsFixed(0);
    }
  }

  void _onPhoneChanged(String phone) async {
    context.read<NewTicketCubit>().setCustomerPhone(phone);
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length >= 10) {
      try {
        final repo = getIt<TicketRepository>();
        final tickets = await repo.getTicketsByCustomer(clean);
        if (tickets.isNotEmpty && mounted) {
          final lastTicket = tickets.first;
          setState(() {
            _detectedReturningCustomer = lastTicket.customerName;
            _detectedCustomerTicketCount = tickets.length;
          });
          if (_nameCtrl.text.trim().isEmpty) {
            _nameCtrl.text = lastTicket.customerName;
            context
                .read<NewTicketCubit>()
                .setCustomerName(lastTicket.customerName);
          }
        }
      } catch (e) {
        debugPrint('Error looking up customer: $e');
      }
    } else {
      if (_detectedReturningCustomer != null) {
        setState(() {
          _detectedReturningCustomer = null;
          _detectedCustomerTicketCount = 0;
        });
      }
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocListener<NewTicketCubit, NewTicketState>(
      listener: (context, state) {
        if (state.isSuccess && state.createdTicket != null) {
          final ticket = state.createdTicket!;

          // 1. Auto-dispatch receipt SMS silently from phone SIM
          if (ticket.customerPhone.isNotEmpty) {
            final smsService = getIt<NativeSmsService>();
            if (smsService.isAutoReceiptSmsEnabled()) {
              smsService.sendTicketReceipt(
                phone: ticket.customerPhone,
                customerName: ticket.customerName,
                deviceModel: ticket.deviceModel,
                ticketId: ticket.id,
                ticketNumber: ticket.ticketNumber,
                shopName: ticket.shopName,
              );
            }
          }

          // 2. Open WhatsApp if toggle is active
          if (state.sendWhatsAppLink && ticket.customerPhone.isNotEmpty) {
            final message = buildNewTicketReceiptMessage(
              customerName: ticket.customerName,
              ticketNumber: ticket.ticketNumber,
              deviceModel: ticket.deviceModel,
              estimatedCost: ticket.estimatedCost,
              deposit: ticket.deposit,
              remainingAmount: ticket.remainingAmount,
              shopName: ticket.shopName ?? 'ورشة الصيانة',
              ticketId: ticket.id,
              partsCost: ticket.partsCost,
              partsDescription: ticket.partsDescription,
            );

            UrlHelper.openWhatsApp(
              phone: ticket.customerPhone,
              message: message,
              context: context,
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('تم حفظ الغرض برقم #${ticket.ticketNumber} بنجاح ✅'),
              backgroundColor: TarmeemColors.readyDot,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
          context.go('/ticket/${ticket.id}');
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: TarmeemColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_forward_ios,
                color: isDark
                    ? TarmeemColors.darkOnSurface
                    : TarmeemColors.onSurface,
                size: 20),
            onPressed: () => context.pop(),
          ),
          centerTitle: true,
          title: Column(
            children: [
              Text(
                'استلام جهاز جديد',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isDark
                          ? TarmeemColors.darkPrimary
                          : TarmeemColors.primaryContainer,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
              ),
              Text(
                'إصدار تذكرة صيانة وإيصال إلكتروني',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? TarmeemColors.darkOnSurfaceVariant
                          : TarmeemColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: TarmeemColors.primaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.handyman_rounded,
                    color: TarmeemColors.primaryContainer, size: 20),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? TarmeemColors.darkSurfaceContainer
                    : TarmeemColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? TarmeemColors.darkCardBorder
                      : TarmeemColors.cardBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Section 1: Customer Information ─────────────────────────
                  const _SectionHeader(
                    title: 'بيانات العميل',
                    icon: Icons.person_outline_rounded,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 12),
                  TarmeemTextField(
                    controller: _nameCtrl,
                    label: 'اسم العميل',
                    hint: 'مثال: أحمد عبد الله',
                    prefixIcon: const Icon(Icons.person_outline,
                        color: TarmeemColors.outline, size: 20),
                    onChanged:
                        context.read<NewTicketCubit>().setCustomerName,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'اسم العميل مطلوب'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  PhoneTextField(
                    controller: _phoneCtrl,
                    countryCode: '+20',
                    countryFlag: '🇪🇬',
                    onChanged: _onPhoneChanged,
                  ),
                  if (_detectedReturningCustomer != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        _nameCtrl.text = _detectedReturningCustomer!;
                        context
                            .read<NewTicketCubit>()
                            .setCustomerName(_detectedReturningCustomer!);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF2563EB)
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.touch_app_outlined,
                                size: 15, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'عميل سابق: $_detectedReturningCustomer (لديه $_detectedCustomerTicketCount أجهزة سابقة) — انقر للتعبئة',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1D4ED8),
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.verified_user_rounded,
                                size: 16, color: Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  Divider(
                    height: 1,
                    thickness: 0.8,
                    color: isDark
                        ? TarmeemColors.darkCardBorder
                        : const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(height: 18),

                  // ── Section 2: Device Details & Issue ───────────────────────
                  const _SectionHeader(
                    title: 'تفاصيل الجهاز والعطل',
                    icon: Icons.devices_outlined,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<NewTicketCubit, NewTicketState>(
                    builder: (context, state) {
                      return _DeviceTypeSelector(
                        selected: state.deviceType,
                        onSelect:
                            context.read<NewTicketCubit>().setDeviceType,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<NewTicketCubit, NewTicketState>(
                    builder: (context, state) {
                      final brands = _commonBrands[state.deviceType] ??
                          _commonBrands[DeviceType.mobile]!;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          children: brands.map((brand) {
                            final brandPrefix = brand.split(' ').first;
                            final isBrandSelected =
                                _modelCtrl.text.contains(brandPrefix);
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ActionChip(
                                label: Text(brand),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isBrandSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isBrandSelected
                                      ? const Color(0xFF7C3AED)
                                      : TarmeemColors.onSurfaceVariant,
                                ),
                                backgroundColor: isBrandSelected
                                    ? const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.12)
                                    : TarmeemColors.surfaceContainerLow,
                                side: BorderSide(
                                  color: isBrandSelected
                                      ? const Color(0xFF7C3AED)
                                          .withValues(alpha: 0.5)
                                      : TarmeemColors.outlineVariant
                                          .withValues(alpha: 0.6),
                                  width: isBrandSelected ? 1.5 : 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 0),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onPressed: () {
                                  if (_modelCtrl.text.isEmpty) {
                                    _modelCtrl.text = '$brand ';
                                  } else {
                                    bool replaced = false;
                                    for (final b in brands) {
                                      final bFirst = b.split(' ').first;
                                      if (_modelCtrl.text
                                          .startsWith(bFirst)) {
                                        _modelCtrl.text = _modelCtrl
                                            .text
                                            .replaceFirst(
                                                bFirst, brand);
                                        replaced = true;
                                        break;
                                      }
                                    }
                                    if (!replaced) {
                                      _modelCtrl.text =
                                          '$brand ${_modelCtrl.text}'
                                              .trim();
                                    }
                                  }
                                  _modelCtrl.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                        offset: _modelCtrl.text.length),
                                  );
                                  context
                                      .read<NewTicketCubit>()
                                      .setDeviceModel(_modelCtrl.text);
                                  setState(() {});
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TarmeemTextField(
                    controller: _modelCtrl,
                    label: 'موديل أو وصف الجهاز',
                    hint: 'مثال: آيفون 13 برو، ساعة رولكس، لابتوب ديل...',
                    prefixIcon: const Icon(Icons.phone_iphone_outlined,
                        color: TarmeemColors.outline, size: 20),
                    onChanged: (v) {
                      context.read<NewTicketCubit>().setDeviceModel(v);
                      setState(() {});
                    },
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'نوع الجهاز مطلوب'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<NewTicketCubit, NewTicketState>(
                    builder: (context, state) {
                      final faults = _commonFaults[state.deviceType] ??
                          _commonFaults[DeviceType.mobile]!;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          children: faults.map((fault) {
                            final isFaultSelected =
                                _issueCtrl.text.contains(fault);
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ActionChip(
                                label: Text(fault),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isFaultSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isFaultSelected
                                      ? const Color(0xFF047857)
                                      : TarmeemColors.onSurfaceVariant,
                                ),
                                backgroundColor: isFaultSelected
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.14)
                                    : TarmeemColors.surfaceContainerLow,
                                side: BorderSide(
                                  color: isFaultSelected
                                      ? const Color(0xFF10B981)
                                          .withValues(alpha: 0.6)
                                      : TarmeemColors.outlineVariant
                                          .withValues(alpha: 0.6),
                                  width: isFaultSelected ? 1.5 : 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 0),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onPressed: () {
                                  if (_issueCtrl.text.isEmpty) {
                                    _issueCtrl.text = fault;
                                  } else if (_issueCtrl.text
                                      .contains(fault)) {
                                    final text = _issueCtrl.text
                                        .replaceAll('، $fault', '')
                                        .replaceAll('$fault، ', '')
                                        .replaceAll(fault, '')
                                        .trim();
                                    _issueCtrl.text = text;
                                  } else {
                                    _issueCtrl.text =
                                        '${_issueCtrl.text}، $fault';
                                  }
                                  _issueCtrl.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                        offset: _issueCtrl.text.length),
                                  );
                                  context
                                      .read<NewTicketCubit>()
                                      .setIssueDescription(
                                          _issueCtrl.text);
                                  setState(() {});
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  TarmeemTextField(
                    controller: _issueCtrl,
                    label: 'وصف العطل أو المطلوب صيانته',
                    hint:
                        'مثال: الشاشة مكسورة ولا تضيء، تغيير الترس الداخلي...',
                    prefixIcon: const Icon(Icons.build_outlined,
                        color: TarmeemColors.outline, size: 20),
                    maxLines: 3,
                    minLines: 2,
                    onChanged: (v) {
                      context.read<NewTicketCubit>().setIssueDescription(v);
                      setState(() {});
                    },
                    validator: (v) => v == null || v.trim().length < 5
                        ? 'يرجى توضيح العطل (5 أحرف على الأقل)'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  const _DevicePhotoSection(),

                  const SizedBox(height: 18),
                  Divider(
                    height: 1,
                    thickness: 0.8,
                    color: isDark
                        ? TarmeemColors.darkCardBorder
                        : const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(height: 18),

                  // ── Section 3: Financials & Costs ───────────────────────────
                  _CostSection(
                    costCtrl: _costCtrl,
                    depositCtrl: _depositCtrl,
                    partsCostCtrl: _partsCostCtrl,
                    partsWholesaleCtrl: _partsWholesaleCtrl,
                    partsDescCtrl: _partsDescCtrl,
                    laborCtrl: _laborCtrl,
                  ),

                  const SizedBox(height: 18),
                  Divider(
                    height: 1,
                    thickness: 0.8,
                    color: isDark
                        ? TarmeemColors.darkCardBorder
                        : const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(height: 18),

                  // ── Section 4: Customer Notification & Submit ───────────────
                  _WhatsAppToggle(),
                  const SizedBox(height: 16),
                  BlocBuilder<NewTicketCubit, NewTicketState>(
                    builder: (context, state) {
                      return PrimaryButton(
                        label: 'حفظ واستلام الجهاز ＋ إصدار الإيصال',
                        icon: const Icon(Icons.receipt_long_outlined,
                            size: 20),
                        isLoading: state.isSubmitting,
                        onPressed: state.isValid
                            ? () {
                                if (_formKey.currentState!.validate()) {
                                  context.read<NewTicketCubit>().submit();
                                }
                              }
                            : null,
                      );
                    },
                  ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.color,
  });

  final String title;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor =
        color ?? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                fontSize: 15,
              ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(width: 8),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: effectiveColor, size: 18),
        ),
      ],
    );
  }
}


class _DeviceTypeSelector extends StatelessWidget {
  const _DeviceTypeSelector({required this.selected, required this.onSelect});
  final DeviceType selected;
  final void Function(DeviceType) onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: DeviceType.values.reversed.map((type) {
          final isSelected = selected == type;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => onSelect(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? TarmeemColors.primary.withValues(alpha: 0.25)
                          : TarmeemColors.secondaryContainer)
                      : (isDark
                          ? TarmeemColors.darkSurfaceContainerHigh
                          : TarmeemColors.surfaceContainerLowest),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: isSelected
                        ? (isDark
                            ? TarmeemColors.darkPrimary
                            : TarmeemColors.onSecondaryContainer)
                        : (isDark
                            ? TarmeemColors.darkCardBorder
                            : TarmeemColors.outlineVariant),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(type.iconLabel, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? (isDark
                                ? TarmeemColors.darkPrimary
                                : TarmeemColors.onSecondaryContainer)
                            : (isDark
                                ? TarmeemColors.darkOnSurfaceVariant
                                : TarmeemColors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CostSection extends StatefulWidget {
  const _CostSection({
    required this.costCtrl,
    required this.depositCtrl,
    required this.partsCostCtrl,
    required this.partsWholesaleCtrl,
    required this.partsDescCtrl,
    required this.laborCtrl,
  });
  final TextEditingController costCtrl;
  final TextEditingController depositCtrl;
  final TextEditingController partsCostCtrl;
  final TextEditingController partsWholesaleCtrl;
  final TextEditingController partsDescCtrl;
  final TextEditingController laborCtrl;

  @override
  State<_CostSection> createState() => _CostSectionState();
}

class _CostSectionState extends State<_CostSection> {
  bool _quoteAfterDiagnosis = true;

  @override
  void initState() {
    super.initState();
    final currentCost = double.tryParse(widget.costCtrl.text) ?? 0;
    final currentParts = double.tryParse(widget.partsCostCtrl.text) ?? 0;
    final currentWholesale =
        double.tryParse(widget.partsWholesaleCtrl.text) ?? 0;
    if (currentCost > 0 || currentParts > 0 || currentWholesale > 0) {
      _quoteAfterDiagnosis = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<NewTicketCubit, NewTicketState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              title: 'التكاليف وتحديد السعر',
              icon: Icons.payments_outlined,
              color:
                  isDark ? TarmeemColors.darkPrimary : const Color(0xFF0D9488),
            ),
            const SizedBox(height: 14),
              // ── Segmented Switch ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? TarmeemColors.darkSurfaceContainer
                      : TarmeemColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: (isDark
                              ? TarmeemColors.darkCardBorder
                              : TarmeemColors.outlineVariant)
                          .withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    // Option 2: Fixed Cost Agreed
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _quoteAfterDiagnosis = false;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_quoteAfterDiagnosis
                                ? (isDark
                                    ? TarmeemColors.darkSurfaceContainerHigh
                                    : TarmeemColors.surfaceContainerLowest)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !_quoteAfterDiagnosis
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                          alpha: isDark ? 0.2 : 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_outlined,
                                    size: 15,
                                    color: !_quoteAfterDiagnosis
                                        ? (isDark
                                            ? TarmeemColors.darkPrimary
                                            : TarmeemColors.primaryContainer)
                                        : (isDark
                                            ? TarmeemColors.darkOnSurfaceVariant
                                            : TarmeemColors.onSurfaceVariant),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'تم الاتفاق على السعر',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: !_quoteAfterDiagnosis
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: !_quoteAfterDiagnosis
                                          ? (isDark
                                              ? TarmeemColors.darkPrimary
                                              : TarmeemColors.primaryContainer)
                                          : (isDark
                                              ? TarmeemColors
                                                  .darkOnSurfaceVariant
                                              : TarmeemColors.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Option 1: Quote After Diagnosis (Default)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _quoteAfterDiagnosis = true;
                          });
                          widget.costCtrl.text = '';
                          widget.laborCtrl.text = '';
                          widget.partsCostCtrl.text = '';
                          widget.partsWholesaleCtrl.text = '';
                          widget.partsDescCtrl.text = '';
                          context.read<NewTicketCubit>().setEstimatedCost(0);
                          context
                              .read<NewTicketCubit>()
                              .setPartsCost(0, autoUpdateTotal: false);
                          context
                              .read<NewTicketCubit>()
                              .setPartsWholesaleCost(0);
                          context.read<NewTicketCubit>().setLaborCost(0);
                          context
                              .read<NewTicketCubit>()
                              .setPartsDescription('');
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 4),
                          decoration: BoxDecoration(
                            color: _quoteAfterDiagnosis
                                ? (isDark
                                    ? TarmeemColors.primary
                                    : const Color(0xFF0D9488))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _quoteAfterDiagnosis
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF0D9488)
                                          .withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    size: 15,
                                    color: _quoteAfterDiagnosis
                                        ? Colors.white
                                        : (isDark
                                            ? TarmeemColors.darkOnSurfaceVariant
                                            : TarmeemColors.onSurfaceVariant),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'السعر بعد الفحص (كشف)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _quoteAfterDiagnosis
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: _quoteAfterDiagnosis
                                          ? Colors.white
                                          : (isDark
                                              ? TarmeemColors
                                                  .darkOnSurfaceVariant
                                              : TarmeemColors.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Minimal Mode: Quote After Diagnosis ───────────────────────
              if (_quoteAfterDiagnosis) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? TarmeemColors.primary
                            : const Color(0xFF0D9488))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: (isDark
                                ? TarmeemColors.darkPrimary
                                : const Color(0xFF0D9488))
                            .withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: isDark
                              ? TarmeemColors.darkPrimary
                              : const Color(0xFF0D9488),
                          size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'يتم استلام الجهاز بحالة (قيد الفحص والتشخيص 🔍)، وإبلاغ العميل بالتكلفة بعد المعاينة.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF5EEAD4)
                                : const Color(0xFF0F766E),
                            height: 1.35,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Deposit Row (optional)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Quick add buttons for deposit
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QuickDepositPill(
                            label: 'مسح',
                            onTap: () {
                              widget.depositCtrl.text = '';
                              context.read<NewTicketCubit>().setDeposit(0);
                            },
                          ),
                          const SizedBox(width: 6),
                          _QuickDepositPill(
                            label: '+100',
                            onTap: () {
                              context.read<NewTicketCubit>().addToDeposit(100);
                              widget.depositCtrl.text =
                                  (state.deposit + 100).toStringAsFixed(0);
                            },
                          ),
                          const SizedBox(width: 6),
                          _QuickDepositPill(
                            label: '+50',
                            onTap: () {
                              context.read<NewTicketCubit>().addToDeposit(50);
                              widget.depositCtrl.text =
                                  (state.deposit + 50).toStringAsFixed(0);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('عربون مدفوع (اختياري)',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  )),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: widget.depositCtrl,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'))
                            ],
                            onChanged: (v) {
                              final d = double.tryParse(v) ?? 0;
                              context.read<NewTicketCubit>().setDeposit(d);
                            },
                            decoration: InputDecoration(
                              prefixText: 'ج.م ',
                              hintText: '0',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 11),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF0D9488), width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // ── Full Agreed Price Calculator ────────────────────────────
                // Row 1: Parts Wholesale Cost & Parts Customer Price
                Row(
                  children: [
                    // Parts Wholesale Cost (تمن شراء القطعة على الورشة)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '(تُخصم من الإجمالي)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: TarmeemColors.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                Text('سعر شراء القطعة',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: widget.partsWholesaleCtrl,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'))
                            ],
                            onChanged: (v) {
                              final w = double.tryParse(v) ?? 0;
                              context
                                  .read<NewTicketCubit>()
                                  .setPartsWholesaleCost(w);
                            },
                            decoration: InputDecoration(
                              prefixText: 'ج.م ',
                              hintText: '0',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFFEA580C), width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Parts Customer Selling Price (سعر بيع القطعة للعميل)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '(المضاف للفاتورة)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFFEA580C),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                Text('سعر القطعة للعميل',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: widget.partsCostCtrl,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'))
                            ],
                            onChanged: (v) {
                              final p = double.tryParse(v) ?? 0;
                              context
                                  .read<NewTicketCubit>()
                                  .setPartsCost(p, autoUpdateTotal: true);
                              final s = context.read<NewTicketCubit>().state;
                              widget.costCtrl.text = s.estimatedCost > 0
                                  ? s.estimatedCost.toStringAsFixed(0)
                                  : '';
                            },
                            decoration: InputDecoration(
                              prefixText: 'ج.م ',
                              hintText: '0',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: TarmeemColors.secondary, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Parts profit indicator badge
                if (state.partsCost > 0 || state.partsWholesaleCost > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? TarmeemColors.darkReadyBackground
                          : TarmeemColors.readyBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isDark
                              ? TarmeemColors.darkReadyBorder
                              : TarmeemColors.readyBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '+${state.partsProfit.toStringAsFixed(0)} ج.م',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? TarmeemColors.darkReadyText
                                : TarmeemColors.readyText,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'مكسبك في قطعة الغيار (يُضاف لأرباح الورشة) ✨:',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? TarmeemColors.darkReadyText
                                    : TarmeemColors.readyText,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.trending_up,
                                size: 15,
                                color: isDark
                                    ? TarmeemColors.darkReadyText
                                    : TarmeemColors.readyText),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Parts Description (Optional)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                        'بيان أو اسم قطعة الغيار (يظهر للعميل في التتبع والفاتورة)',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: TarmeemColors.onSurfaceVariant,
                            )),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: widget.partsDescCtrl,
                      textDirection: TextDirection.rtl,
                      onChanged: (v) =>
                          context.read<NewTicketCubit>().setPartsDescription(v),
                      decoration: InputDecoration(
                        hintText: 'مثال: شاشة أصلية OLED، بطارية، آيسي باور...',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: TarmeemColors.secondary, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Row 2: Labor fee & Total Cost
                Row(
                  children: [
                    // Labor fee
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '(أتعاب يد الفني)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF16A34A),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                Text('أجرة المصنعية',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: widget.laborCtrl,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'))
                            ],
                            onChanged: (v) {
                              final l = double.tryParse(v) ?? 0;
                              context.read<NewTicketCubit>().setLaborCost(l);
                              final s = context.read<NewTicketCubit>().state;
                              widget.costCtrl.text = s.estimatedCost > 0
                                  ? s.estimatedCost.toStringAsFixed(0)
                                  : '';
                            },
                            decoration: InputDecoration(
                              prefixText: 'ج.م ',
                              hintText: '0',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: TarmeemColors.primaryContainer,
                                    width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Total Cost to Customer
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '(المصنعية + سعر القطعة)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: TarmeemColors.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                Text('إجمالي الفاتورة للعميل',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: widget.costCtrl,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'))
                            ],
                            onChanged: (v) {
                              final c = double.tryParse(v) ?? 0;
                              context
                                  .read<NewTicketCubit>()
                                  .setEstimatedCost(c);
                              final s = context.read<NewTicketCubit>().state;
                              widget.laborCtrl.text = s.laborCost > 0
                                  ? s.laborCost.toStringAsFixed(0)
                                  : '';
                            },
                            decoration: InputDecoration(
                              prefixText: 'ج.م ',
                              hintText: '0',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: TarmeemColors.secondary, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Deposit Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('العربون المدفوع',
                              style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: widget.depositCtrl,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'))
                            ],
                            onChanged: (v) {
                              final d = double.tryParse(v) ?? 0;
                              context.read<NewTicketCubit>().setDeposit(d);
                            },
                            decoration: InputDecoration(
                              prefixText: 'ج.م ',
                              hintText: '0',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: TarmeemColors.secondary, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quick deposit buttons
                Text(
                  'إضافة سريعة للعربون:',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: TarmeemColors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Full amount button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.read<NewTicketCubit>().setFullDeposit();
                          widget.depositCtrl.text =
                              state.estimatedCost.toStringAsFixed(0);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: TarmeemColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'كامل المبلغ',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: TarmeemColors.onSecondaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...AppConstants.quickDepositAmounts.reversed.map((amt) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () {
                            context.read<NewTicketCubit>().addToDeposit(amt);
                            widget.depositCtrl.text =
                                (state.deposit + amt).toStringAsFixed(0);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: TarmeemColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: TarmeemColors.outlineVariant),
                            ),
                            child: Text(
                              '+${amt.toInt()}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                // Financial Breakdown & Net Profit Display
                if (state.estimatedCost > 0 || state.partsCost > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? TarmeemColors.darkSurfaceContainer
                          : TarmeemColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: (isDark
                                  ? TarmeemColors.darkCardBorder
                                  : TarmeemColors.outlineVariant)
                              .withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatCurrency(state.laborCost),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const Text('🛠️ أجرة المصنعية (أتعاب اليد):'),
                          ],
                        ),
                        if (state.partsCost > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatCurrency(state.partsCost),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFFEA580C)),
                              ),
                              Text(
                                '⚙️ سعر بيع قطع الغيار ${state.partsDescription != null && state.partsDescription!.isNotEmpty ? "(${state.partsDescription})" : ""}:',
                              ),
                            ],
                          ),
                          if (state.partsWholesaleCost > 0) ...[
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'تكلفتها: ${formatCurrency(state.partsWholesaleCost)} • مكسبك: +${formatCurrency(state.partsProfit)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: isDark
                                        ? TarmeemColors.darkReadyText
                                        : TarmeemColors.readyText,
                                  ),
                                ),
                                Text(
                                  'حساب القطعة للورشة:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? TarmeemColors.darkOnSurfaceVariant
                                        : TarmeemColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                        const Divider(height: 16, thickness: 0.5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatCurrency(state.estimatedCost),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: TarmeemColors.primaryContainer),
                            ),
                            const Text('🧾 إجمالي الفاتورة للعميل:'),
                          ],
                        ),
                        if (state.deposit > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '- ${formatCurrency(state.deposit)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: TarmeemColors.waitingText),
                              ),
                              const Text('💵 العربون المدفوع:'),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatCurrency(state.remainingAmount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: TarmeemColors.primaryContainer),
                            ),
                            const Text('💰 المتبقي عند الاستلام:'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? TarmeemColors.darkReadyBackground
                                : TarmeemColors.readyBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isDark
                                    ? TarmeemColors.darkReadyBorder
                                    : TarmeemColors.readyBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatCurrency(state.netProfit),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: isDark
                                          ? TarmeemColors.darkReadyText
                                          : TarmeemColors.readyText,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'صافي ربح الورشة المؤكد ✨:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: isDark
                                              ? TarmeemColors.darkReadyText
                                              : TarmeemColors.readyText,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.trending_up,
                                      size: 16,
                                      color: isDark
                                          ? TarmeemColors.darkReadyText
                                          : TarmeemColors.readyText),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (state.partsProfit > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '(أجرة المصنعية ${formatCurrency(state.laborCost)} + مكسب قطعة الغيار ${formatCurrency(state.partsProfit)})',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? TarmeemColors.darkOnSurfaceVariant
                                  : TarmeemColors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
            ],
          ],
       ] );
      },
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isDark
              ? TarmeemColors.darkSurfaceContainerHigh
              : TarmeemColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isDark
                  ? TarmeemColors.darkCardBorder
                  : TarmeemColors.outlineVariant),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? TarmeemColors.darkOnSurface : null,
              ),
        ),
      ),
    );
  }
}

class _WhatsAppToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<NewTicketCubit, NewTicketState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? TarmeemColors.darkSurfaceContainer
                : TarmeemColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (isDark
                      ? TarmeemColors.darkCardBorder
                      : TarmeemColors.outlineVariant)
                  .withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Toggle
              Switch(
                value: state.sendWhatsAppLink,
                onChanged: (_) =>
                    context.read<NewTicketCubit>().toggleWhatsApp(),
                activeThumbColor: isDark
                    ? TarmeemColors.darkPrimary
                    : TarmeemColors.primaryContainer,
              ),
              const SizedBox(width: 8),
              // Text + icon
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            'إرسال رابط التتبع عبر واتساب',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: isDark
                                      ? TarmeemColors.darkOnSurface
                                      : TarmeemColors.onSurface,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark
                                ? TarmeemColors.primary.withValues(alpha: 0.25)
                                : TarmeemColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.send_outlined,
                              color: isDark
                                  ? TarmeemColors.darkPrimary
                                  : TarmeemColors.onSecondaryContainer,
                              size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'يتلقى العميل إيصالاً رقمياً فورياً لحالة الجهاز',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? TarmeemColors.darkOnSurfaceVariant
                                : TarmeemColors.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DevicePhotoSection extends StatefulWidget {
  const _DevicePhotoSection();

  @override
  State<_DevicePhotoSection> createState() => _DevicePhotoSectionState();
}

class _DevicePhotoSectionState extends State<_DevicePhotoSection> {
  bool _isUploading = false;
  String? _uploadStatusText;

  Future<void> _pickFromCamera(BuildContext context, {String? fallbackId}) async {
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<NewTicketCubit>();

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;

      // Local preview immediately
      cubit.addImage(file.path);

      if (SupabaseConfig.isConfigured) {
        setState(() {
          _isUploading = true;
          _uploadStatusText = 'جارِ رفع صورة الجهاز إلى سحابة Supabase... ☁️';
        });

        final storageService = getIt<SupabaseStorageService>();
        final ticketIdentifier = (fallbackId != null && fallbackId.isNotEmpty)
            ? fallbackId
            : 'TR_${DateTime.now().millisecondsSinceEpoch % 100000}';

        final publicUrl = await storageService.uploadTicketImage(
          file: file,
          ticketNumber: ticketIdentifier,
        );

        if (!mounted) return;
        setState(() {
          _isUploading = false;
          _uploadStatusText = null;
        });

        if (publicUrl != null) {
          // Replace local path with remote publicUrl
          cubit.replaceImageUrl(file.path, publicUrl);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('تم رفع الصورة بنجاح على سحابة Supabase ☁️✅'),
              backgroundColor: TarmeemColors.readyDot,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('تعذر الاتصال بالسحابة حالياً. تم حفظ الصورة محلياً على الجهاز 📱'),
              backgroundColor: Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadStatusText = null;
      });
      debugPrint('Error uploading camera photo: $e');
    }
  }

  Future<void> _pickFromGallery(BuildContext context, {String? fallbackId}) async {
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<NewTicketCubit>();

    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (files.isEmpty || !mounted) return;

      // Add local paths immediately for instant UI feedback
      final localPaths = files.map((f) => f.path).toList();
      cubit.addImages(localPaths);

      if (SupabaseConfig.isConfigured) {
        setState(() {
          _isUploading = true;
          _uploadStatusText = 'جارِ رفع ${files.length} صور إلى Supabase... ☁️';
        });

        final storageService = getIt<SupabaseStorageService>();
        final ticketIdentifier = (fallbackId != null && fallbackId.isNotEmpty)
            ? fallbackId
            : 'TR_${DateTime.now().millisecondsSinceEpoch % 100000}';

        int uploadedCount = 0;
        final currentImages = List<String>.from(cubit.state.images);

        for (int i = 0; i < files.length; i++) {
          if (!mounted) break;
          final f = files[i];
          setState(() {
            _uploadStatusText = 'جارِ رفع صورة (${i + 1} من ${files.length})... ☁️';
          });

          try {
            final publicUrl = await storageService.uploadTicketImage(
              file: f,
              ticketNumber: ticketIdentifier,
            );
            if (publicUrl != null) {
              final idx = currentImages.indexOf(f.path);
              if (idx != -1) {
                currentImages[idx] = publicUrl;
              }
              uploadedCount++;
            }
          } catch (err) {
            debugPrint('Error uploading single image: $err');
            final errStr = err.toString().toLowerCase();
            if (errStr.contains('timed out') || errStr.contains('socketexception')) {
              break;
            }
          }
        }

        if (!mounted) return;
        setState(() {
          _isUploading = false;
          _uploadStatusText = null;
        });

        cubit.updateImages(currentImages);

        if (uploadedCount > 0) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('تم رفع $uploadedCount صورة بنجاح على سحابة Supabase ☁️✅'),
              backgroundColor: TarmeemColors.readyDot,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (files.isNotEmpty) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('تعذر الاتصال بالسحابة حالياً بسبب الشبكة. تم حفظ الصور محلياً على الجهاز 📱'),
              backgroundColor: Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadStatusText = null;
      });
      debugPrint('Error uploading gallery photos: $e');
    }
  }

  void _showImageZoom(BuildContext context, String imagePath) {
    final isRemote = imagePath.startsWith('http');
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
                    ? Image.network(imagePath, fit: BoxFit.contain)
                    : (kIsWeb
                        ? Image.network(imagePath, fit: BoxFit.contain)
                        : Image.file(File(imagePath), fit: BoxFit.contain)),
              ),
            ),
            IconButton.filled(
              icon: const Icon(Icons.close, color: Colors.white, size: 22),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<NewTicketCubit, NewTicketState>(
      builder: (context, state) {
        final allImages = state.images.isNotEmpty
            ? state.images
            : (state.imageUrl != null && state.imageUrl!.isNotEmpty
                ? [state.imageUrl!]
                : <String>[]);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? TarmeemColors.darkSurfaceContainerHigh
                : TarmeemColors.surfaceContainerLow.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? TarmeemColors.darkCardBorder
                  : TarmeemColors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (allImages.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: TarmeemColors.primaryContainer.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library, size: 14, color: TarmeemColors.primaryContainer),
                          const SizedBox(width: 4),
                          Text(
                            '${allImages.length} صور مرفقة',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: TarmeemColors.primaryContainer,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (SupabaseConfig.isConfigured)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: TarmeemColors.readyBadgeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_done, size: 13, color: TarmeemColors.readyDot),
                          SizedBox(width: 4),
                          Text(
                            'Supabase ☁️',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: TarmeemColors.readyText,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'توثيق حالة الجهاز بالصور',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.camera_alt_outlined, size: 18, color: TarmeemColors.secondary),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Uploading Progress Indicator
              if (_isUploading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: TarmeemColors.primaryFixed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: TarmeemColors.primaryContainer.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _uploadStatusText ?? 'جارِ المعالجة...',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: TarmeemColors.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),

              // Gallery Thumbnails List
              if (allImages.isNotEmpty) ...[
                SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    itemCount: allImages.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, index) {
                      // Last item is the "Add More" tile
                      if (index == allImages.length) {
                        return GestureDetector(
                          onTap: () => _pickFromGallery(context, fallbackId: state.customerPhone),
                          child: Container(
                            width: 100,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? TarmeemColors.darkSurfaceContainer
                                  : TarmeemColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: TarmeemColors.primaryContainer.withValues(alpha: 0.5),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 28, color: TarmeemColors.primaryContainer),
                                SizedBox(height: 6),
                                Text(
                                  'إضافة صورة',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: TarmeemColors.primaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final imagePath = allImages[index];
                      final isRemote = imagePath.startsWith('http');

                      Widget buildImg() {
                        if (isRemote) {
                          return Image.network(
                            imagePath,
                            fit: BoxFit.cover,
                            width: 110,
                            height: 130,
                            errorBuilder: (_, __, ___) => Container(
                              color: TarmeemColors.surfaceContainerHigh,
                              width: 110,
                              height: 130,
                              child: const Icon(Icons.broken_image_outlined,
                                  color: TarmeemColors.outline),
                            ),
                          );
                        }
                        return kIsWeb
                            ? Image.network(imagePath, fit: BoxFit.cover, width: 110, height: 130)
                            : Image.file(
                                File(imagePath),
                                fit: BoxFit.cover,
                                width: 110,
                                height: 130,
                                errorBuilder: (_, __, ___) => Container(
                                  color: TarmeemColors.surfaceContainerHigh,
                                  width: 110,
                                  height: 130,
                                  child: const Icon(Icons.broken_image_outlined,
                                      color: TarmeemColors.outline),
                                ),
                              );
                      }

                      return Stack(
                        alignment: Alignment.topLeft,
                        children: [
                          GestureDetector(
                            onTap: () => _showImageZoom(context, imagePath),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: buildImg(),
                            ),
                          ),
                          // Badge: index or primary
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                index == 0 ? 'رئيسية ⭐' : '#${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // Delete button
                          Positioned(
                            top: 4,
                            left: 4,
                            child: GestureDetector(
                              onTap: () {
                                if (isRemote) {
                                  getIt<SupabaseStorageService>().deleteImageByUrl(imagePath);
                                }
                                context.read<NewTicketCubit>().removeImage(index);
                              },
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: TarmeemColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickFromCamera(context, fallbackId: state.customerPhone),
                        icon: const Icon(Icons.camera_alt, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('التقاط بالكاميرا'),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickFromGallery(context, fallbackId: state.customerPhone),
                        icon: const Icon(Icons.photo_library, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('إضافة من المعرض'),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Initial Buttons when no images selected yet
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickFromGallery(context, fallbackId: state.customerPhone),
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('المعرض (صور متعددة)'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickFromCamera(context, fallbackId: state.customerPhone),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('الكاميرا'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TarmeemColors.primaryContainer,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
