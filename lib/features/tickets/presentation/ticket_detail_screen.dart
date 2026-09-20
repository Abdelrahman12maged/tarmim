/// Ticket Detail screen — Screen 4.
///
/// Status selector grid, WhatsApp notify preview, financial summary,
/// and status history timeline.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/url_helper.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/services/native_sms_service.dart';
import '../../../core/services/supabase_storage_service.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/ticket_entity.dart';
import '../domain/ticket_repository.dart';
import 'edit_ticket_screen.dart';
import 'tickets_cubit.dart';
import 'tickets_state.dart';

enum _DeliveryChoice {
  fullyPaid,
  keepDebt,
}

class _CancellationSettlementData {
  const _CancellationSettlementData({
    required this.inspectionFee,
    required this.settledDeposit,
    required this.refundAmount,
    required this.remainingDue,
    required this.reason,
    required this.note,
  });

  final double inspectionFee;
  final double settledDeposit;
  final double refundAmount;
  final double remainingDue;
  final String reason;
  final String note;
}

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  TicketEntity? _ticket;

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    final state = context.read<TicketsCubit>().state;
    if (state is TicketsLoaded) {
      try {
        final found = state.allTickets.firstWhere((t) => t.id == widget.ticketId);
        if (mounted) setState(() => _ticket = found);
        return;
      } catch (_) {}
    }

    try {
      final ticket = await getIt<TicketRepository>().getTicket(widget.ticketId);
      if (mounted && ticket != null) {
        setState(() => _ticket = ticket);
      }
    } catch (_) {}
  }

  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadPhoto({
    required bool isAfterRepair,
    required ImageSource source,
  }) async {
    final ticket = _ticket;
    if (ticket == null) return;

    try {
      final picker = ImagePicker();
      final List<XFile> filesToProcess = [];

      if (source == ImageSource.gallery) {
        final pickedList = await picker.pickMultiImage(
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 85,
        );
        if (pickedList.isEmpty) return;
        filesToProcess.addAll(pickedList);
      } else {
        final picked = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 85,
        );
        if (picked == null) return;
        filesToProcess.add(picked);
      }

      if (!mounted || filesToProcess.isEmpty) return;

      // 1. Optimistic local update: add images immediately so user sees them right away
      final List<String> initialLocalPaths = filesToProcess.map((f) => f.path).toList();
      TicketEntity immediateTicket;
      if (isAfterRepair) {
        final list = List<String>.from(ticket.afterRepairImages)..addAll(initialLocalPaths);
        immediateTicket = ticket.copyWith(afterRepairImages: list);
      } else {
        final list = List<String>.from(ticket.allImages)..addAll(initialLocalPaths);
        immediateTicket = ticket.copyWith(
          images: list,
          imageUrl: list.isNotEmpty ? list.first : null,
        );
      }

      await getIt<TicketRepository>().updateTicket(immediateTicket);
      if (mounted) {
        setState(() {
          _ticket = immediateTicket;
          _isUploadingPhoto = SupabaseConfig.isConfigured;
        });
        context.read<TicketsCubit>().loadTickets();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAfterRepair
                ? 'تم توثيق ${initialLocalPaths.length} صورة للجهاز بنجاح 📸'
                : 'تم حفظ ${initialLocalPaths.length} صورة لاستلام الجهاز بنجاح 📷✅'),
            backgroundColor: TarmeemColors.readyDot,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 2. Cloud synchronization in background if Supabase is configured
      if (SupabaseConfig.isConfigured) {
        final storage = getIt<SupabaseStorageService>();
        final prefix = isAfterRepair ? 'after' : 'intake';
        TicketEntity currentTicket = immediateTicket;
        bool hasCloudUpdates = false;

        for (int i = 0; i < filesToProcess.length; i++) {
          final f = filesToProcess[i];
          try {
            final publicUrl = await storage.uploadTicketImage(
              file: f,
              ticketNumber: '${ticket.ticketNumber}_${prefix}_${DateTime.now().millisecondsSinceEpoch % 100000}_$i',
            );
            if (publicUrl != null) {
              hasCloudUpdates = true;
              if (isAfterRepair) {
                final list = List<String>.from(currentTicket.afterRepairImages);
                final idx = list.indexOf(f.path);
                if (idx != -1) {
                  list[idx] = publicUrl;
                } else {
                  list.add(publicUrl);
                }
                currentTicket = currentTicket.copyWith(afterRepairImages: list);
              } else {
                final list = List<String>.from(currentTicket.allImages);
                final idx = list.indexOf(f.path);
                if (idx != -1) {
                  list[idx] = publicUrl;
                } else {
                  list.add(publicUrl);
                }
                currentTicket = currentTicket.copyWith(
                  images: list,
                  imageUrl: list.isNotEmpty ? list.first : null,
                );
              }
            }
          } catch (uploadErr) {
            debugPrint('Background image upload notice: $uploadErr');
            // If connection to server timed out, stop further uploads in this batch
            break;
          }
        }

        if (hasCloudUpdates) {
          await getIt<TicketRepository>().updateTicket(currentTicket);
        }

        if (mounted) {
          setState(() {
            _ticket = currentTicket;
            _isUploadingPhoto = false;
          });
          context.read<TicketsCubit>().loadTickets();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isUploadingPhoto = false);
      debugPrint('Error in _pickAndUploadPhoto: $e');
    }
  }

  void _showImageZoom(BuildContext context, String path) {
    final isRemote = path.startsWith('http');
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
                    ? Image.network(path, fit: BoxFit.contain)
                    : (kIsWeb
                        ? Image.network(path, fit: BoxFit.contain)
                        : Image.file(File(path), fit: BoxFit.contain)),
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

  void _showAddPhotoSheet(BuildContext context, {required bool isAfterRepair}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? TarmeemColors.darkSurfaceContainer
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAfterRepair ? 'توثيق صور الجهاز بعد الصيانة 📸' : 'إضافة صور للجهاز عند الاستلام 📷',
              style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(sheetCtx);
                _pickAndUploadPhoto(isAfterRepair: isAfterRepair, source: ImageSource.camera);
              },
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('التقاط صورة بالكاميرا 📷'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TarmeemColors.primaryContainer,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheetCtx);
                _pickAndUploadPhoto(isAfterRepair: isAfterRepair, source: ImageSource.gallery);
              },
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('اختيار صورة أو عدة صور من المعرض 🖼️'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePhoto(
    BuildContext context, {
    required String path,
    required bool isAfterRepair,
  }) async {
    final ticket = _ticket;
    if (ticket == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('تأكيد حذف الصورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.red, size: 22),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من حذف هذه الصورة المرفقة من التذكرة؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      TicketEntity updated;
      if (isAfterRepair) {
        final list = List<String>.from(ticket.afterRepairImages)..remove(path);
        updated = ticket.copyWith(afterRepairImages: list);
      } else {
        final list = List<String>.from(ticket.allImages)..remove(path);
        updated = ticket.copyWith(
          images: list,
          imageUrl: list.isNotEmpty ? list.first : null,
        );
      }

      await getIt<TicketRepository>().updateTicket(updated);
      if (context.mounted) {
        setState(() => _ticket = updated);
        context.read<TicketsCubit>().loadTickets();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الصورة بنجاح ✅'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showManagePartsSheet(BuildContext context, TicketEntity ticket) async {
    final descCtrl = TextEditingController(text: ticket.partsDescription ?? '');
    final partsCostCtrl = TextEditingController(
      text: ticket.partsCost > 0 ? ticket.partsCost.toStringAsFixed(0) : '',
    );
    final partsWholesaleCtrl = TextEditingController(
      text: ticket.partsWholesaleCost > 0 ? ticket.partsWholesaleCost.toStringAsFixed(0) : '',
    );
    final laborCtrl = TextEditingController(
      text: ticket.laborCost > 0
          ? ticket.laborCost.toStringAsFixed(0)
          : (ticket.estimatedCost > 0
              ? (ticket.estimatedCost - ticket.partsCost).clamp(0.0, double.infinity).toStringAsFixed(0)
              : ''),
    );
    // Default: auto-add part cost to customer invoice total
    bool autoAddToCustomer = true;
    bool updateStatusToWaiting = ticket.status == TicketStatus.inDiagnosis;

    double currentLabor = ticket.laborCost > 0
        ? ticket.laborCost
        : (ticket.estimatedCost > 0
            ? (ticket.estimatedCost - ticket.partsCost).clamp(0.0, double.infinity)
            : 0.0);
    double newPartsCost = ticket.partsCost;
    double newPartsWholesaleCost = ticket.partsWholesaleCost;
    double newEstimatedCost = ticket.estimatedCost;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            void recalculate() {
              final p = double.tryParse(partsCostCtrl.text.replaceAll(',', '')) ?? 0;
              final w = double.tryParse(partsWholesaleCtrl.text.replaceAll(',', '')) ?? 0;
              final l = double.tryParse(laborCtrl.text.replaceAll(',', '')) ?? 0;
              newPartsCost = p;
              newPartsWholesaleCost = w;
              currentLabor = l;
              if (autoAddToCustomer) {
                newEstimatedCost = l + p;
              } else {
                newEstimatedCost = ticket.estimatedCost > 0 ? ticket.estimatedCost : (l + p);
              }
            }

            final partsProfit = (newPartsCost - newPartsWholesaleCost).clamp(0.0, double.infinity);
            final remaining = (newEstimatedCost - ticket.deposit).clamp(0.0, double.infinity);
            final profit = (newEstimatedCost - (newPartsWholesaleCost > 0 ? newPartsWholesaleCost : newPartsCost)).clamp(0.0, double.infinity);

            final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: TarmeemColors.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: TarmeemColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${ticket.ticketNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: TarmeemColors.onSecondaryContainer,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              ticket.partsCost > 0 ? 'تعديل قطع الغيار' : 'إضافة قطعة غيار للصيانة',
                              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.settings_suggest_outlined,
                                color: TarmeemColors.primaryContainer, size: 24),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'أدخل بيانات القطعة لحساب تكلفتها على العميل وضمان حفظ أرباحك الصافية',
                      style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                            color: TarmeemColors.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 20),

                    // Field 1: Parts Description
                    Text('اسم أو بيان قطعة الغيار',
                        style: Theme.of(sheetContext).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: descCtrl,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'مثال: شاشة OLED أصلية، بطارية، آيسي باور...',
                        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: TarmeemColors.primaryContainer, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Field 2: Parts Selling Price (To Customer)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '(سعر البيع للعميل بالفاتورة)',
                          style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                color: TarmeemColors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                        ),
                        const SizedBox(width: 4),
                        Text('سعر بيع القطعة للعميل',
                            style: Theme.of(sheetContext).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: partsCostCtrl,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      onChanged: (_) {
                        setModalState(() {
                          recalculate();
                        });
                      },
                      decoration: InputDecoration(
                        prefixText: 'ج.م ',
                        hintText: '0',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: TarmeemColors.secondary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Field 3: Parts Wholesale Purchase Cost (Workshop Cost)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('سعر شراء القطعة (جملة على الورشة)',
                            style: Theme.of(sheetContext).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          '(يُخصم من الإجمالي لحساب صافي أرباحك)',
                          style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                color: TarmeemColors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: partsWholesaleCtrl,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      onChanged: (_) {
                        setModalState(() {
                          recalculate();
                        });
                      },
                      decoration: InputDecoration(
                        prefixText: 'ج.م ',
                        hintText: '0',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF475569), width: 1.5),
                        ),
                      ),
                    ),
                    if (newPartsCost > 0 && newPartsWholesaleCost > 0) ...[
                      const SizedBox(height: 10),
                      if (newPartsCost >= newPartsWholesaleCost)
                        Container(
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
                                  'مكسبك الإضافي في قطعة الغيار: +${partsProfit.toStringAsFixed(0)} ج.م ✨ (يُضاف لصافي أرباح الورشة)',
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
                        )
                      else
                        Container(
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
                                  'تنبيه: سعر شراء القطعة (${newPartsWholesaleCost.toStringAsFixed(0)}) أكبر من سعر البيع للعميل (${newPartsCost.toStringAsFixed(0)})!',
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
                    ],
                    const SizedBox(height: 14),

                    // Field 4: Labor Fee (Technician Labor)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '(أتعاب يد الفني)',
                          style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF16A34A),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 4),
                        Text('أجرة المصنعية',
                            style: Theme.of(sheetContext).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: TarmeemColors.primaryContainer,
                                )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: laborCtrl,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      onChanged: (_) {
                        setModalState(() {
                          recalculate();
                        });
                      },
                      decoration: InputDecoration(
                        prefixText: 'ج.م ',
                        hintText: '0',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: TarmeemColors.primaryContainer, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Option 1: Auto add to customer invoice
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Switch(
                            value: autoAddToCustomer,
                            activeThumbColor: TarmeemColors.primaryContainer,
                            onChanged: (val) {
                              setModalState(() {
                                autoAddToCustomer = val;
                                recalculate();
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'إضافة تكلفة القطعة تلقائياً على فاتورة العميل',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  textAlign: TextAlign.right,
                                ),
                                Text(
                                  autoAddToCustomer
                                      ? 'الفاتورة الجديدة = المصنعية الحالية (${currentLabor.toStringAsFixed(0)}) + سعر بيع القطعة (${newPartsCost.toStringAsFixed(0)})'
                                      : 'ستبقى فاتورة العميل كما هي وتتحمل الورشة التكلفة',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (ticket.status == TicketStatus.inDiagnosis) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: updateStatusToWaiting,
                              activeColor: TarmeemColors.secondary,
                              onChanged: (val) {
                                setModalState(() {
                                  updateStatusToWaiting = val ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'تحديث حالة الجهاز تلقائياً إلى "بانتظار قطع الغيار" 📦',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Live Financial Calculation Preview Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? TarmeemColors.darkSurfaceContainerHigh : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? TarmeemColors.darkCardBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Row(
                            children: [
                              Spacer(),
                              Text(
                                'المعادلة المالية الناتجة',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: TarmeemColors.primaryContainer),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.calculate_outlined, size: 16, color: TarmeemColors.primaryContainer),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${newPartsCost.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEA580C))),
                              const Text('سعر بيع القطعة للعميل:'),
                            ],
                          ),
                          if (newPartsWholesaleCost > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${newPartsWholesaleCost.toStringAsFixed(0)} ج.م',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                const Text('سعر شراء القطعة (جملة على الورشة):'),
                              ],
                            ),
                          ],
                          if (partsProfit > 0 && newPartsCost > 0 && newPartsWholesaleCost > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('+${partsProfit.toStringAsFixed(0)} ج.م',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                                    )),
                                const Text('مكسبك في قطعة الغيار:'),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${currentLabor.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                              const Text('مصنعية الورشة (أجرة يدك):'),
                            ],
                          ),
                          const Divider(height: 14, thickness: 0.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${newEstimatedCost.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: TarmeemColors.primaryContainer, fontSize: 15)),
                              const Text('إجمالي الفاتورة للعميل:'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${remaining.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              const Text('المتبقي على العميل:'),
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
                                      '${profit.toStringAsFixed(0)} ج.م',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'صافي أرباح الورشة ✨:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                                            fontSize: 12,
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
                                    '(أجرة المصنعية ${currentLabor.toStringAsFixed(0)} ج.م + مكسب القطعة ${partsProfit.toStringAsFixed(0)} ج.م)',
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
                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline, size: 20),
                            label: const Text('حفظ وتحديث الفاتورة والأرباح', style: TextStyle(fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TarmeemColors.primaryContainer,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              final desc = descCtrl.text.trim();
                              final newHistory = List<StatusHistoryEntry>.from(ticket.statusHistory);
                              final targetStatus = updateStatusToWaiting ? TicketStatus.waitingForPart : ticket.status;

                              newHistory.add(
                                StatusHistoryEntry(
                                  status: targetStatus,
                                  timestamp: DateTime.now(),
                                  note: 'تم تسجيل قطع غيار: ${desc.isNotEmpty ? desc : "بدون بيان"} (سعر بيع: ${newPartsCost.toStringAsFixed(0)} ج.م${newPartsWholesaleCost > 0 ? "، تكلفة شراء: ${newPartsWholesaleCost.toStringAsFixed(0)} ج.م" : ""})، والفاتورة أصبحت ${newEstimatedCost.toStringAsFixed(0)} ج.م.',
                                ),
                              );

                              final updatedTicket = ticket.copyWith(
                                partsCost: newPartsCost,
                                partsWholesaleCost: newPartsWholesaleCost,
                                partsDescription: desc.isEmpty ? null : desc,
                                estimatedCost: newEstimatedCost,
                                status: targetStatus,
                                statusHistory: newHistory,
                              );

                              try {
                                await getIt<TicketRepository>().updateTicket(updatedTicket);
                                if (context.mounted) {
                                  Navigator.pop(sheetContext);
                                  context.read<TicketsCubit>().loadTickets();
                                  setState(() {
                                    _ticket = updatedTicket;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تم تحديث قطع الغيار وتعديل الفاتورة إلى ${newEstimatedCost.toStringAsFixed(0)} ج.م بنجاح ✅'),
                                      backgroundColor: TarmeemColors.readyDot,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('حدث خطأ أثناء الحفظ: $e'),
                                      backgroundColor: TarmeemColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPriceEstimationSheet(
    BuildContext context,
    TicketEntity ticket, {
    bool isTriggeredByReadyStatus = false,
  }) async {
    final laborCtrl = TextEditingController(
      text: ticket.laborCost > 0 ? ticket.laborCost.toStringAsFixed(0) : '',
    );
    final partsCostCtrl = TextEditingController(
      text: ticket.partsCost > 0 ? ticket.partsCost.toStringAsFixed(0) : '',
    );
    final partsWholesaleCtrl = TextEditingController(
      text: ticket.partsWholesaleCost > 0 ? ticket.partsWholesaleCost.toStringAsFixed(0) : '',
    );
    final partsDescCtrl = TextEditingController(
      text: ticket.partsDescription ?? '',
    );
    final depositCtrl = TextEditingController(
      text: ticket.deposit > 0 ? ticket.deposit.toStringAsFixed(0) : '',
    );
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final labor = double.tryParse(laborCtrl.text.replaceAll(',', '')) ?? 0;
            final parts = double.tryParse(partsCostCtrl.text.replaceAll(',', '')) ?? 0;
            final wholesale = double.tryParse(partsWholesaleCtrl.text.replaceAll(',', '')) ?? 0;
            final deposit = double.tryParse(depositCtrl.text.replaceAll(',', '')) ?? 0;
            final totalCost = labor + parts;
            final remaining = (totalCost > 0)
                ? (totalCost - deposit).clamp(0.0, double.infinity)
                : 0.0;
            final partsProfit = (parts - wholesale).clamp(0.0, double.infinity);
            final netProfit = (totalCost - (wholesale > 0 ? wholesale : parts)).clamp(0.0, double.infinity);

            Future<void> savePriceAndProceed({required bool markReady}) async {
              if (totalCost <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال أجرة المصنعية أو تكلفة قطع الغيار لتحديد السعر'),
                    backgroundColor: TarmeemColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              setModalState(() => isSubmitting = true);

              final updatedTicket = ticket.copyWith(
                estimatedCost: totalCost,
                partsCost: parts,
                partsWholesaleCost: wholesale,
                partsDescription: partsDescCtrl.text.trim().isEmpty
                    ? null
                    : partsDescCtrl.text.trim(),
                deposit: deposit,
              );

              try {
                final repo = getIt<TicketRepository>();
                await repo.updateTicket(updatedTicket);

                if (markReady) {
                  if (context.mounted) {
                    await context
                        .read<TicketsCubit>()
                        .updateStatus(ticket.id, TicketStatus.readyForPickup);

                    if (ticket.customerPhone.isNotEmpty) {
                      final readyMsg = buildReadyForPickupMessage(
                        customerName: ticket.customerName,
                        deviceModel: ticket.deviceModel,
                        remainingAmount: remaining,
                        shopName: ticket.shopName ?? AppConstants.defaultShopName,
                        ticketNumber: ticket.ticketNumber,
                        ticketId: ticket.id,
                        estimatedCost: totalCost,
                        partsCost: parts,
                        laborCost: labor,
                        deposit: deposit,
                        partsDescription: partsDescCtrl.text.trim().isEmpty
                            ? null
                            : partsDescCtrl.text.trim(),
                      );

                      // 1. Send SMS silently via native SIM without opening SMS app
                      final smsService = getIt<NativeSmsService>();
                      smsService.sendReadyForPickup(
                        phone: ticket.customerPhone,
                        customerName: ticket.customerName,
                        deviceModel: ticket.deviceModel,
                        remainingAmount: remaining,
                        ticketId: ticket.id,
                        ticketNumber: ticket.ticketNumber,
                        shopName: ticket.shopName,
                      );

                      if (context.mounted) {
                        // 2. Open WhatsApp directly with ready-for-pickup message
                        UrlHelper.openWhatsApp(
                          phone: ticket.customerPhone,
                          message: readyMsg,
                          context: context,
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إرسال رسالة SMS وفتح واتساب لإشعار العميل بالاستلام 📱✅'),
                            backgroundColor: TarmeemColors.readyDot,
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  }
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    if (mounted) setState(() => _ticket = updatedTicket.copyWith(status: TicketStatus.readyForPickup));
                  }
                } else {
                  if (context.mounted) {
                    context.read<TicketsCubit>().loadTickets();
                    Navigator.pop(ctx);
                    if (mounted) setState(() => _ticket = updatedTicket);

                    _promptSendPriceQuote(
                      context,
                      updatedTicket,
                      estimatedCost: totalCost,
                      partsCost: parts,
                      laborCost: labor,
                      deposit: deposit,
                      remaining: remaining,
                      partsDescription: partsDescCtrl.text.trim(),
                    );
                  }
                }
              } catch (e) {
                setModalState(() => isSubmitting = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('حدث خطأ أثناء الحفظ: $e'),
                      backgroundColor: TarmeemColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }

            final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isTriggeredByReadyStatus
                                ? const Color(0xFFFEF3C7)
                                : TarmeemColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${ticket.ticketNumber}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isTriggeredByReadyStatus
                                  ? const Color(0xFFB45309)
                                  : TarmeemColors.onSecondaryContainer,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isTriggeredByReadyStatus
                                  ? 'تحديد التكلفة وتأكيد الجاهزية 🚀'
                                  : 'تحديد سعر الصيانة والفاتورة 🏷️',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              ticket.deviceModel,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: TarmeemColors.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (isTriggeredByReadyStatus)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'لتغيير حالة الجهاز إلى "جاهز للاستلام"، يرجى تحديد تكلفة الصيانة لإصدار الفاتورة للعميل وإرسال إشعار الجاهزية بالمبلغ المطلوب.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'يمكنك تسعير الصيانة وحفظها كعرض سعر لأخذ موافقة العميل أولاً قبل بدء العمل، أو تأكيد الجاهزية للاستلام فوراً.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E40AF),
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'سعر بيع القطعة للعميل ⚙️',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: partsCostCtrl,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                                onChanged: (_) => setModalState(() {}),
                                decoration: InputDecoration(
                                  prefixText: 'ج.م ',
                                  hintText: '0',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: TarmeemColors.secondary, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'أجرة المصنعية (أجرة يدك) 🛠️',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: TarmeemColors.primaryContainer,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: laborCtrl,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                                onChanged: (_) => setModalState(() {}),
                                decoration: InputDecoration(
                                  prefixText: 'ج.م ',
                                  hintText: '0',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: TarmeemColors.primaryContainer, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'سعر شراء القطعة (جملة) 📦',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: TarmeemColors.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: partsWholesaleCtrl,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                                onChanged: (_) => setModalState(() {}),
                                decoration: InputDecoration(
                                  prefixText: 'ج.م ',
                                  hintText: '0',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF475569), width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'اسم أو بيان القطعة (اختياري)',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: TarmeemColors.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: partsDescCtrl,
                                textDirection: TextDirection.rtl,
                                decoration: InputDecoration(
                                  hintText: 'مثال: شاشة OLED، بطارية...',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (parts > 0 && wholesale > 0) ...[
                      const SizedBox(height: 10),
                      if (parts >= wholesale)
                        Container(
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
                                  'مكسبك الإضافي في قطعة الغيار: +${partsProfit.toStringAsFixed(0)} ج.م ✨ (يُضاف لصافي أرباح الورشة)',
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
                        )
                      else
                        Container(
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
                                  'تنبيه: سعر شراء القطعة (${wholesale.toStringAsFixed(0)}) أكبر من سعر البيع للعميل (${parts.toStringAsFixed(0)})!',
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
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _QuickPricePill(
                                label: 'مسح',
                                onTap: () => setModalState(() => depositCtrl.text = ''),
                              ),
                              const SizedBox(width: 6),
                              _QuickPricePill(
                                label: '+100',
                                onTap: () {
                                  final d = double.tryParse(depositCtrl.text.replaceAll(',', '')) ?? 0;
                                  setModalState(() => depositCtrl.text = (d + 100).toStringAsFixed(0));
                                },
                              ),
                              const SizedBox(width: 6),
                              _QuickPricePill(
                                label: '+50',
                                onTap: () {
                                  final d = double.tryParse(depositCtrl.text.replaceAll(',', '')) ?? 0;
                                  setModalState(() => depositCtrl.text = (d + 50).toStringAsFixed(0));
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
                              Text('العربون المدفوع بالإيصال',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      )),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: depositCtrl,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (_) => setModalState(() {}),
                                decoration: InputDecoration(
                                  prefixText: 'ج.م ',
                                  hintText: '0',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
                        ),
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
                          if (parts > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${parts.toStringAsFixed(0)} ج.م',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEA580C))),
                                Text('⚙️ سعر بيع القطعة للعميل ${partsDescCtrl.text.trim().isNotEmpty ? "(${partsDescCtrl.text.trim()})" : ""}:'),
                              ],
                            ),
                          ],
                          if (wholesale > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${wholesale.toStringAsFixed(0)} ج.م',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                const Text('📦 سعر شراء القطعة (جملة على الورشة):'),
                              ],
                            ),
                          ],
                          if (partsProfit > 0 && parts > 0 && wholesale > 0) ...[
                            const SizedBox(height: 4),
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
                              Text(
                                '${totalCost.toStringAsFixed(0)} ج.م',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: TarmeemColors.primaryContainer,
                                  fontSize: 16,
                                ),
                              ),
                              const Text('🧾 إجمالي الفاتورة للعميل:'),
                            ],
                          ),
                          if (deposit > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '- ${deposit.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: TarmeemColors.waitingText,
                                  ),
                                ),
                                const Text('💵 العربون المدفوع:'),
                              ],
                            ),
                          ],
                          const Divider(height: 14, thickness: 0.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${remaining.toStringAsFixed(0)} ج.م',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                              const Text(
                                '💰 المطلوب دفعه عند الاستلام:',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? TarmeemColors.darkReadyBackground : TarmeemColors.readyBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? TarmeemColors.darkReadyBorder : TarmeemColors.readyBorder),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${netProfit.toStringAsFixed(0)} ج.م',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'صافي أرباح الورشة المؤكد ✨:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.trending_up, size: 14, color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText),
                                      ],
                                    ),
                                  ],
                                ),
                                if (partsProfit > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '(أجرة المصنعية ${labor.toStringAsFixed(0)} ج.م + مكسب القطعة ${partsProfit.toStringAsFixed(0)} ج.م)',
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
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () => savePriceAndProceed(markReady: true),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          isTriggeredByReadyStatus
                              ? 'تأكيد السعر وتغيير الحالة إلى جاهز للاستلام 🚀'
                              : 'حفظ وتغيير الحالة إلى جاهز للاستلام 🚀',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TarmeemColors.primaryContainer,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () => savePriceAndProceed(markReady: false),
                        icon: const Icon(Icons.request_quote_outlined, size: 18, color: Color(0xFF16A34A)),
                        label: const Text(
                          'حفظ السعر فقط وإرسال عرض السعر للعميل 💬',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF16A34A), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء', style: TextStyle(color: TarmeemColors.onSurfaceVariant)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _quickFeeChip(String label, double value, TextEditingController ctrl, VoidCallback onUpdate) {
    return InkWell(
      onTap: () {
        ctrl.text = value == 0 ? '0' : value.toStringAsFixed(0);
        onUpdate();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: TarmeemColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TarmeemColors.outlineVariant),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<_CancellationSettlementData?> _showCancellationSettlementDialog(BuildContext context, TicketEntity ticket) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feeCtrl = TextEditingController(text: '0');
    final noteCtrl = TextEditingController();
    String selectedReason = 'رفض العميل لتكلفة الإصلاح';

    final reasons = [
      'رفض العميل لتكلفة الإصلاح',
      'عدم توفر قطع الغيار',
      'تراجع العميل عن الصيانة',
      'الجهاز غير قابل للإصلاح',
    ];

    return showDialog<_CancellationSettlementData>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final parsedFee = double.tryParse(feeCtrl.text.trim()) ?? 0.0;
            final deposit = ticket.deposit;
            final double refundAmount = (deposit > parsedFee) ? (deposit - parsedFee) : 0.0;
            final double remainingDue = (parsedFee > deposit) ? (parsedFee - deposit) : 0.0;
            final double settledDeposit = (deposit > parsedFee) ? parsedFee : deposit;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? TarmeemColors.darkSurfaceContainer : Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'تسوية إلغاء الإصلاح واسترجاع الجهاز',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.assignment_return_outlined, color: Color(0xFFEF4444), size: 22),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'سيتم إلغاء أعمال الصيانة وتسجيل الجهاز كمسترجع للعميل.',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Ticket Info Badge
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatCurrency(deposit),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: TarmeemColors.readyDot),
                          ),
                          const Text('العربون المدفوع سابقاً:', style: TextStyle(fontSize: 11.5, color: TarmeemColors.outline)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Reason Selector
                    const Text('سبب الإلغاء:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: reasons.map((r) {
                        final isSel = selectedReason == r;
                        return ChoiceChip(
                          label: Text(r, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.normal)),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) setDialogState(() => selectedReason = r);
                          },
                          selectedColor: isDark ? TarmeemColors.darkPrimaryContainer : const Color(0xFFFEE2E2),
                          backgroundColor: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                          labelStyle: TextStyle(
                            color: isSel
                                ? (isDark ? Colors.white : const Color(0xFF991B1B))
                                : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Inspection Fee Input
                    const Text('رسوم الفحص والكشف (إن وُجدت):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: feeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.left,
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: 'ج.م',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 6),
                    // Quick fee presets
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _quickFeeChip('100 ج', 100, feeCtrl, () => setDialogState(() {})),
                        const SizedBox(width: 6),
                        _quickFeeChip('50 ج', 50, feeCtrl, () => setDialogState(() {})),
                        const SizedBox(width: 6),
                        _quickFeeChip('0 (مجاني)', 0, feeCtrl, () => setDialogState(() {})),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Live Settlement Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: refundAmount > 0
                            ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFECFDF5))
                            : (remainingDue > 0
                                ? (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.5) : const Color(0xFFFEF2F2))
                                : (isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: refundAmount > 0
                              ? const Color(0xFFA7F3D0)
                              : (remainingDue > 0 ? const Color(0xFFFECACA) : TarmeemColors.outlineVariant),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                refundAmount > 0
                                    ? formatCurrency(refundAmount)
                                    : (remainingDue > 0 ? formatCurrency(remainingDue) : '0 ج.م'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: refundAmount > 0
                                      ? const Color(0xFF059669)
                                      : (remainingDue > 0 ? TarmeemColors.error : TarmeemColors.onSurfaceVariant),
                                ),
                              ),
                              Text(
                                refundAmount > 0
                                    ? 'المبلغ المسترد للعميل بالدرج:'
                                    : (remainingDue > 0 ? 'المتبقي للتحصيل من العميل:' : 'تسوية متكافئة:'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: refundAmount > 0
                                      ? const Color(0xFF059669)
                                      : (remainingDue > 0 ? TarmeemColors.error : TarmeemColors.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            refundAmount > 0
                                ? 'يتم رد هذا المبلغ للعميل من العربون المتبقي بعد خصم الفحص.'
                                : (remainingDue > 0
                                    ? 'يدفع العميل هذا المبلغ كرسوم فحص عند استلام جهازه.'
                                    : 'لا يوجد رد مالي ولا متبقي تحصيل.'),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Additional Note Input
                    TextField(
                      controller: noteCtrl,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'ملاحظة إضافية عن سبب الإلغاء (اختياري)...',
                        hintStyle: const TextStyle(fontSize: 11.5),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(
                          ctx,
                          _CancellationSettlementData(
                            inspectionFee: parsedFee,
                            settledDeposit: settledDeposit,
                            refundAmount: refundAmount,
                            remainingDue: remainingDue,
                            reason: selectedReason,
                            note: noteCtrl.text.trim(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.assignment_return_outlined, size: 18),
                      label: const Text(
                        'تأكيد إلغاء الإصلاح واسترجاع الجهاز 🛑',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: const Text('تراجع', style: TextStyle(color: TarmeemColors.outline)),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleCancellationSettlement(BuildContext context, TicketEntity ticket) async {
    final cubit = context.read<TicketsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await _showCancellationSettlementDialog(context, ticket);
    if (result == null || !mounted) return;

    final repo = getIt<TicketRepository>();

    String noteText = 'تم إلغاء الإصلاح (${result.reason}).';
    if (result.inspectionFee > 0) {
      noteText += ' رسوم الفحص: ${formatCurrency(result.inspectionFee)}.';
    } else {
      noteText += ' الفحص مجاني.';
    }
    if (result.refundAmount > 0) {
      noteText += ' تم رد ${formatCurrency(result.refundAmount)} للعميل من العربون.';
    }
    if (result.remainingDue > 0) {
      noteText += ' متبقي ${formatCurrency(result.remainingDue)} رسوم فحص للتحصيل عند التسليم.';
    }
    if (result.note.isNotEmpty) {
      noteText += ' ملاحظة: ${result.note}';
    }

    final updated = ticket.copyWith(
      estimatedCost: result.inspectionFee,
      deposit: result.settledDeposit,
      status: TicketStatus.cancelled,
    );

    await repo.updateTicket(updated);
    await cubit.updateStatus(
      ticket.id,
      TicketStatus.cancelled,
      note: noteText,
    );

    if (mounted) setState(() => _ticket = updated);
    cubit.loadTickets();

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('تم إلغاء صيانة الجهاز #${ticket.ticketNumber} وتسجيله كمسترجع بنجاح.'),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: ticket.customerPhone.isNotEmpty
            ? SnackBarAction(
                label: 'إشعار بواتساب 💬',
                textColor: Colors.white,
                onPressed: () {
                  final msg = buildCancelledPickupMessage(
                    customerName: ticket.customerName,
                    deviceModel: ticket.deviceModel,
                    shopName: ticket.shopName ?? AppConstants.defaultShopName,
                    ticketNumber: ticket.ticketNumber,
                    ticketId: ticket.id,
                    inspectionFee: result.inspectionFee,
                    refundedAmount: result.refundAmount,
                    remainingAmount: result.remainingDue,
                    reason: result.reason,
                  );
                  UrlHelper.openWhatsApp(
                    phone: ticket.customerPhone,
                    message: msg,
                    context: context,
                  );
                },
              )
            : null,
      ),
    );
  }

  Future<_DeliveryChoice?> _showDeliverySettlementDialog(BuildContext context, TicketEntity ticket) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remaining = ticket.remainingAmount;
    final hasRemaining = remaining > 0;

    return showDialog<_DeliveryChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? TarmeemColors.darkSurfaceContainer : Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'تسليم الجهاز وتسوية الحساب',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_outline, color: TarmeemColors.readyDot, size: 22),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'هل تأكدت من تسليم الغرض للعميل واستلامه؟',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ticket.customerPhone,
                        style: const TextStyle(fontSize: 11.5, color: TarmeemColors.outline),
                      ),
                      Text(
                        ticket.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ticket.deviceModel,
                    style: const TextStyle(color: TarmeemColors.onSurfaceVariant, fontSize: 12),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatCurrency(ticket.estimatedCost),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                      const Text('إجمالي الفاتورة:', style: TextStyle(fontSize: 11.5, color: TarmeemColors.outline)),
                    ],
                  ),
                  if (ticket.deposit > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatCurrency(ticket.deposit),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: TarmeemColors.readyDot),
                        ),
                        const Text('العربون المسدد مسبقاً:', style: TextStyle(fontSize: 11.5, color: TarmeemColors.outline)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasRemaining
                          ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
                          : (isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasRemaining ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          hasRemaining ? formatCurrency(remaining) : 'مسددة بالكامل ✅',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: hasRemaining ? TarmeemColors.error : const Color(0xFF16A34A),
                          ),
                        ),
                        Text(
                          hasRemaining ? 'المتبقي للتحصيل بالدرج:' : 'حالة الحساب:',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: hasRemaining ? TarmeemColors.error : const Color(0xFF16A34A),
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
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasRemaining) ...[
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, _DeliveryChoice.fullyPaid),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.point_of_sale, size: 18),
                  label: Text(
                    'تم استلام كامل الحساب (سداد ${formatCurrency(remaining)})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, _DeliveryChoice.keepDebt),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.pending_actions, size: 16),
                  label: Text(
                    'تسليم مع بقاء دَين على العميل (${formatCurrency(remaining)})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, _DeliveryChoice.fullyPaid),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TarmeemColors.primaryContainer,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text(
                    'نعم، تأكيد التسليم ✅',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('إلغاء', style: TextStyle(color: TarmeemColors.outline)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeliverySettlement(BuildContext context, TicketEntity ticket) async {
    final cubit = context.read<TicketsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final choice = await _showDeliverySettlementDialog(context, ticket);
    if (choice == null || !mounted) return;

    final repo = getIt<TicketRepository>();

    if (choice == _DeliveryChoice.fullyPaid) {
      final updated = ticket.copyWith(
        deposit: ticket.estimatedCost,
        status: TicketStatus.delivered,
      );
      await repo.updateTicket(updated);
      await cubit.updateStatus(
        ticket.id,
        TicketStatus.delivered,
        note: ticket.remainingAmount > 0
            ? 'تم تسليم الغرض وسداد كامل الحساب (${formatCurrency(ticket.remainingAmount)}) بالدرج. الفاتورة مسددة بالكامل.'
            : 'تم تسليم الغرض للعميل (الفاتورة مسددة بالكامل مسبقاً).',
      );
      if (mounted) setState(() => _ticket = updated);
    } else {
      final updated = ticket.copyWith(status: TicketStatus.delivered);
      await repo.updateTicket(updated);
      await cubit.updateStatus(
        ticket.id,
        TicketStatus.delivered,
        note: 'تم تسليم الغرض مع بقاء دَين آجل على العميل بقيمة ${formatCurrency(ticket.remainingAmount)}.',
      );
      if (mounted) setState(() => _ticket = updated);
    }

    if (!mounted) return;
    cubit.loadTickets();

    final totalPaid = choice == _DeliveryChoice.fullyPaid ? ticket.estimatedCost : ticket.deposit;
    final remainingDebt = choice == _DeliveryChoice.fullyPaid ? 0.0 : ticket.remainingAmount;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('تم تسليم الجهاز #${ticket.ticketNumber} بنجاح 🎉'),
        backgroundColor: TarmeemColors.readyDot,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: ticket.customerPhone.isNotEmpty
            ? SnackBarAction(
                label: 'إرسال شكر بواتساب 💬',
                textColor: Colors.white,
                onPressed: () {
                  final msg = buildDeliveredThankYouMessage(
                    customerName: ticket.customerName,
                    deviceModel: ticket.deviceModel,
                    shopName: ticket.shopName ?? AppConstants.defaultShopName,
                    ticketNumber: ticket.ticketNumber,
                    ticketId: ticket.id,
                    totalPaid: totalPaid,
                    remainingAmount: remainingDebt,
                  );
                  UrlHelper.openWhatsApp(
                    phone: ticket.customerPhone,
                    message: msg,
                    context: context,
                  );
                },
              )
            : null,
      ),
    );
  }

  Future<void> _confirmReopenTicket(BuildContext context, TicketEntity ticket) async {
    final cubit = context.read<TicketsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final isCancelled = ticket.status == TicketStatus.cancelled;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              isCancelled ? 'إعادة فتح التذكرة للصيانة' : 'إعادة فتح التذكرة للتعديل',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Icon(Icons.lock_open, color: isCancelled ? const Color(0xFFEF4444) : TarmeemColors.diagnosisDot, size: 22),
          ],
        ),
        content: Text(
          isCancelled
              ? 'التذكرة حالياً في حالة "مسترجع بدون إصلاح".\nهل تريد إعادة فتحها وتغيير حالتها إلى "قيد الفحص" لمتابعة الصيانة مجدداً؟'
              : 'التذكرة حالياً في حالة "تم التسليم ومغلقة".\nهل تريد إعادة فتحها وتغيير حالتها إلى "جاهز للاستلام" للسماح بإجراء تعديلات؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TarmeemColors.primaryContainer,
              foregroundColor: Colors.white,
            ),
            child: const Text('نعم، إعادة فتح التذكرة'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final targetStatus = isCancelled ? TicketStatus.inDiagnosis : TicketStatus.readyForPickup;
      final noteMsg = isCancelled
          ? 'تمت إعادة فتح التذكرة لمتابعة الصيانة وتغيير حالتها إلى قيد الفحص.'
          : 'تمت إعادة فتح التذكرة وتعديل حالتها إلى جاهز للاستلام.';

      await cubit.updateStatus(
        ticket.id,
        targetStatus,
        note: noteMsg,
      );
      final updated = ticket.copyWith(status: targetStatus);
      if (mounted) setState(() => _ticket = updated);
      cubit.loadTickets();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تمت إعادة فتح التذكرة بنجاح. يمكنك الآن متابعة العمل وتعديل بياناتها ✅'),
          backgroundColor: TarmeemColors.readyDot,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _promptSendPriceQuote(
    BuildContext context,
    TicketEntity ticket, {
    required double estimatedCost,
    required double partsCost,
    required double laborCost,
    required double deposit,
    required double remaining,
    String? partsDescription,
  }) {
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('تم حفظ السعر بنجاح ✅', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            SizedBox(width: 8),
            Icon(Icons.check_circle_outline, color: TarmeemColors.readyDot, size: 22),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'التكلفة الإجمالية: ${formatCurrency(estimatedCost)} • المتبقي: ${formatCurrency(remaining)}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: TarmeemColors.primaryContainer),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            const Text(
              'هل ترغب بإرسال رسالة عرض السعر للعميل عبر واتساب لأخذ موافقته قبل بدء الإصلاح؟',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dlgCtx);
              _sendPriceQuoteWorkflow(
                context,
                ticket,
                estimatedCost: estimatedCost,
                partsCost: partsCost,
                laborCost: laborCost,
                deposit: deposit,
                remainingAmount: remaining,
                partsDescription: partsDescription,
              );
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('إرسال عرض السعر 💬'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPriceQuoteWorkflow(
    BuildContext context,
    TicketEntity ticket, {
    required double estimatedCost,
    required double partsCost,
    required double laborCost,
    required double deposit,
    required double remainingAmount,
    String? partsDescription,
  }) async {
    final cleanPhone = ticket.customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم هاتف العميل غير متوفر.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final fallbackMsg = buildPriceQuoteMessage(
      customerName: ticket.customerName,
      deviceModel: ticket.deviceModel,
      estimatedCost: estimatedCost,
      partsCost: partsCost,
      laborCost: laborCost,
      deposit: deposit,
      remainingAmount: remainingAmount,
      shopName: ticket.shopName ?? AppConstants.defaultShopName,
      partsDescription: partsDescription,
      ticketNumber: ticket.ticketNumber,
      ticketId: ticket.id,
    );

    UrlHelper.openWhatsApp(
      phone: ticket.customerPhone,
      message: fallbackMsg,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TicketsCubit, TicketsState>(
      builder: (context, state) {
        if (state is TicketsLoaded) {
          try {
            _ticket =
                state.allTickets.firstWhere((t) => t.id == widget.ticketId);
          } catch (_) {}
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (_ticket == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_forward_ios,
                    color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                    size: 20),
                onPressed: () => context.canPop() ? context.pop() : context.go('/tickets'),
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(
                color: TarmeemColors.primaryContainer,
              ),
            ),
          );
        }

        final ticket = _ticket!;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_forward_ios,
                  color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                  size: 20),
              onPressed: () => context.canPop() ? context.pop() : context.go('/tickets'),
            ),
            centerTitle: true,
            title: Column(
              children: [
                Text(
                  'تفاصيل الصيانة',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ticket.shopName ?? 'ورشة الصيانة',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.print_outlined),
                tooltip: ticket.status == TicketStatus.delivered ? 'طباعة الفاتورة' : 'طباعة الإيصال',
                onPressed: () => _printReceipt(context, ticket),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: TarmeemColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.handyman, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ── Delivered status banner (if delivered) ─────────────────
                if (ticket.status == TicketStatus.delivered) ...[
                  _DeliveredBanner(
                    ticket: ticket,
                    onSendThankYou: () {
                      final msg = buildDeliveredThankYouMessage(
                        customerName: ticket.customerName,
                        deviceModel: ticket.deviceModel,
                        shopName: ticket.shopName ?? AppConstants.defaultShopName,
                        ticketNumber: ticket.ticketNumber,
                        ticketId: ticket.id,
                        totalPaid: ticket.deposit,
                        remainingAmount: ticket.remainingAmount,
                      );
                      UrlHelper.openWhatsApp(
                        phone: ticket.customerPhone,
                        message: msg,
                        context: context,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Cancelled status banner (if cancelled) ─────────────────
                if (ticket.status == TicketStatus.cancelled) ...[
                  _CancelledBanner(
                    ticket: ticket,
                    onSendWhatsApp: () {
                      final msg = buildCancelledPickupMessage(
                        customerName: ticket.customerName,
                        deviceModel: ticket.deviceModel,
                        shopName: ticket.shopName ?? AppConstants.defaultShopName,
                        ticketNumber: ticket.ticketNumber,
                        ticketId: ticket.id,
                        inspectionFee: ticket.estimatedCost,
                        remainingAmount: ticket.remainingAmount,
                      );
                      UrlHelper.openWhatsApp(
                        phone: ticket.customerPhone,
                        message: msg,
                        context: context,
                      );
                    },
                    onPrintReceipt: () => _printReceipt(context, ticket),
                    onReopen: () => _confirmReopenTicket(context, ticket),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Ticket header ─────────────────────────────────────────
                _TicketHeader(ticket: ticket),
                const SizedBox(height: 16),

                // ── Device Photos Card (Intake & After-Repair) ────────────
                _DevicePhotosCard(
                  ticket: ticket,
                  onAddPhoto: _showAddPhotoSheet,
                  onZoom: _showImageZoom,
                  onDeletePhoto: _confirmDeletePhoto,
                  isUploading: _isUploadingPhoto,
                ),
                const SizedBox(height: 16),

                // ── Customer info ─────────────────────────────────────────
                _CustomerInfoRow(ticket: ticket),
                const SizedBox(height: 16),

                // ── Status selector ───────────────────────────────────────
                _StatusSelector(
                  ticket: ticket,
                  onRequestPriceEstimation: _showPriceEstimationSheet,
                  onDeliveryRequested: _handleDeliverySettlement,
                  onCancellationRequested: _handleCancellationSettlement,
                  onReopenRequested: _confirmReopenTicket,
                ),
                const SizedBox(height: 16),

                // ── WhatsApp notify ───────────────────────────────────────
                _WhatsAppNotify(ticket: ticket),
                const SizedBox(height: 16),

                // ── Spare parts management card ───────────────────────────
                _SparePartsCard(
                  ticket: ticket,
                  onManageParts: () => _showManagePartsSheet(context, ticket),
                ),
                const SizedBox(height: 16),

                // ── Financial summary ─────────────────────────────────────
                _FinancialSummary(
                  ticket: ticket,
                  onManageParts: () => _showManagePartsSheet(context, ticket),
                  onEstimatePrice: () => _showPriceEstimationSheet(context, ticket),
                  onSendQuote: () {
                    _sendPriceQuoteWorkflow(
                      context,
                      ticket,
                      estimatedCost: ticket.estimatedCost,
                      partsCost: ticket.partsCost,
                      laborCost: ticket.laborCost,
                      deposit: ticket.deposit,
                      remainingAmount: ticket.remainingAmount,
                      partsDescription: ticket.partsDescription,
                    );
                  },
                ),
                const SizedBox(height: 16),


                // ── Status history timeline ───────────────────────────────
                _StatusTimeline(history: ticket.statusHistory),
                const SizedBox(height: 24),

                // ── Bottom actions ────────────────────────────────────────
                if (ticket.status == TicketStatus.delivered) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'طباعة الفاتورة',
                          icon: const Icon(Icons.print_outlined, size: 18),
                          onPressed: () => _printReceipt(context, ticket),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final msg = buildDeliveredThankYouMessage(
                              customerName: ticket.customerName,
                              deviceModel: ticket.deviceModel,
                              shopName: ticket.shopName ?? AppConstants.defaultShopName,
                              ticketNumber: ticket.ticketNumber,
                              ticketId: ticket.id,
                              totalPaid: ticket.deposit,
                              remainingAmount: ticket.remainingAmount,
                            );
                            UrlHelper.openWhatsApp(
                              phone: ticket.customerPhone,
                              message: msg,
                              context: context,
                            );
                          },
                          icon: const Icon(Icons.chat_outlined, size: 18, color: Colors.white),
                          label: const Text(
                            'شكر بواتساب',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _confirmReopenTicket(context, ticket),
                      icon: const Icon(Icons.lock_open_outlined, size: 16, color: TarmeemColors.outline),
                      label: const Text(
                        'إعادة فتح التذكرة للتعديل 🔓',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: TarmeemColors.outline,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ] else if (ticket.status == TicketStatus.cancelled) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'إيصال استرجاع',
                          icon: const Icon(Icons.print_outlined, size: 18),
                          onPressed: () => _printReceipt(context, ticket),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final msg = buildCancelledPickupMessage(
                              customerName: ticket.customerName,
                              deviceModel: ticket.deviceModel,
                              shopName: ticket.shopName ?? AppConstants.defaultShopName,
                              ticketNumber: ticket.ticketNumber,
                              ticketId: ticket.id,
                              inspectionFee: ticket.estimatedCost,
                              remainingAmount: ticket.remainingAmount,
                            );
                            UrlHelper.openWhatsApp(
                              phone: ticket.customerPhone,
                              message: msg,
                              context: context,
                            );
                          },
                          icon: const Icon(Icons.chat_outlined, size: 18, color: Colors.white),
                          label: const Text(
                            'إشعار بواتساب',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _confirmReopenTicket(context, ticket),
                      icon: const Icon(Icons.refresh_outlined, size: 16, color: TarmeemColors.outline),
                      label: const Text(
                        'إعادة فتح التذكرة لمتابعة الصيانة 🔄',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: TarmeemColors.outline,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'طباعة إيصال',
                          icon: const Icon(Icons.print_outlined, size: 18),
                          onPressed: () => _printReceipt(context, ticket),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: 'تعديل البيانات',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<TicketsCubit>(),
                                child: EditTicketScreen(ticket: ticket),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── PDF Receipt Generation ────────────────────────────────────────────────────

/// Generates and prints/shares an Arabic PDF receipt/invoice for the given ticket.
Future<void> _printReceipt(BuildContext context, TicketEntity ticket) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text('جارِ تجهيز الفاتورة باللغة العربية للطباعة... 🖨️'),
        ],
      ),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );

  pw.Font arabicFont;
  pw.Font arabicBoldFont;

  try {
    arabicFont = await PdfGoogleFonts.cairoRegular();
    arabicBoldFont = await PdfGoogleFonts.cairoBold();
  } catch (_) {
    try {
      arabicFont = await PdfGoogleFonts.amiriRegular();
      arabicBoldFont = await PdfGoogleFonts.amiriBold();
    } catch (_) {
      arabicFont = pw.Font.helvetica();
      arabicBoldFont = pw.Font.helveticaBold();
    }
  }

  final isDelivered = ticket.status == TicketStatus.delivered;
  final isReady = ticket.status == TicketStatus.readyForPickup;
  final isCancelled = ticket.status == TicketStatus.cancelled;
  final receiptTitle = isCancelled
      ? 'إيصال استرجاع جهاز (بدون إصلاح)'
      : (isDelivered
          ? 'فاتورة صيانة وتسليم نهائية'
          : (isReady ? 'إشعار جاهزية وفاتورة صيانة' : 'إيصال استلام جهاز صيانة'));

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicBoldFont,
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Header (Shop Info on Right, Ticket# and Date on Left in RTL) ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Right side in RTL (first child): Shop details
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      ticket.shopName ?? 'ورشة ترميم للصيانة',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: isCancelled ? PdfColor.fromHex('#991B1B') : PdfColor.fromHex('#134E4A'),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: isCancelled
                            ? PdfColor.fromHex('#FEE2E2')
                            : (isDelivered ? PdfColor.fromHex('#D1FAE5') : PdfColor.fromHex('#F0FDF4')),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(
                          color: isCancelled
                              ? PdfColor.fromHex('#FECACA')
                              : (isDelivered ? PdfColor.fromHex('#A7F3D0') : PdfColor.fromHex('#BBF7D0')),
                        ),
                      ),
                      child: pw.Text(
                        receiptTitle,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: isCancelled
                              ? PdfColor.fromHex('#991B1B')
                              : (isDelivered ? PdfColor.fromHex('#065F46') : PdfColor.fromHex('#16A34A')),
                        ),
                      ),
                    ),
                    if (ticket.shopPhone != null && ticket.shopPhone!.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'هاتف الورشة: ${ticket.shopPhone}',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                      ),
                    ],
                    if (ticket.shopAddress != null && ticket.shopAddress!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'العنوان: ${ticket.shopAddress}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ],
                ),

                // Left side in RTL (second child): Ticket Number & Date
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#134E4A'),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        '#${ticket.ticketNumber}',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      formatDateArabic(ticket.createdAt),
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey300, thickness: 1),
            pw.SizedBox(height: 8),

            // ── Section 1: Customer & Device Info Card ──
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                children: [
                  _pdfRow('اسم العميل', ticket.customerName),
                  _pdfRow('رقم الهاتف', ticket.customerPhone),
                  _pdfRow('نوع وموديل الجهاز', ticket.deviceModel),
                  _pdfRow('وصف العطل أو المشكلة', ticket.issueDescription),
                  if (ticket.serialNumber != null && ticket.serialNumber!.isNotEmpty)
                    _pdfRow('الرقم التسلسلي (IMEI)', ticket.serialNumber!),
                  if (ticket.shelfLocation != null && ticket.shelfLocation!.isNotEmpty)
                    _pdfRow('موقع الرف بالورشة', ticket.shelfLocation!),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // ── Section 2: Financial Breakdown Card ──
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColor.fromHex('#134E4A'), width: 1.2),
              ),
              child: pw.Column(
                children: [
                  if (ticket.partsCost > 0) ...[
                    _pdfRow(
                      ticket.partsDescription != null && ticket.partsDescription!.isNotEmpty
                          ? 'قطع الغيار (${ticket.partsDescription})'
                          : 'تكلفة قطع الغيار',
                      formatCurrency(ticket.partsCost),
                    ),
                    _pdfRow('أجرة المصنعية والإصلاح', formatCurrency(ticket.laborCost)),
                    pw.Divider(color: PdfColors.grey200, thickness: 0.8),
                  ],
                  _pdfRow(
                    isCancelled ? 'رسوم الفحص والكشف' : 'إجمالي قيمة الفاتورة',
                    ticket.estimatedCost > 0
                        ? formatCurrency(ticket.estimatedCost)
                        : (isCancelled ? 'فحص مجاني (0 ج)' : 'تُحدد بعد المعاينة والفحص 🔍'),
                    isBold: true,
                    textColor: isCancelled ? PdfColor.fromHex('#991B1B') : PdfColor.fromHex('#134E4A'),
                  ),
                  if (ticket.deposit > 0) ...[
                    pw.SizedBox(height: 2),
                    _pdfRow(
                      'العربون المسدد',
                      formatCurrency(ticket.deposit),
                      textColor: PdfColor.fromHex('#059669'),
                    ),
                  ],
                  pw.Divider(color: PdfColors.grey200, thickness: 0.8),
                  pw.SizedBox(height: 2),
                  _pdfRow(
                    isCancelled
                        ? (ticket.remainingAmount <= 0 ? 'حالة الحساب' : 'المتبقي كرسوم فحص')
                        : (isDelivered
                            ? (ticket.remainingAmount <= 0 ? 'حالة الحساب' : 'المتبقي كدَين آجل')
                            : 'المبلغ المتبقي عند الاستلام'),
                    isCancelled
                        ? (ticket.remainingAmount <= 0 ? 'خالصة ومسددة بالكامل ✅' : formatCurrency(ticket.remainingAmount))
                        : (isDelivered
                            ? (ticket.remainingAmount <= 0 ? 'خالصة ومسددة بالكامل ✅' : formatCurrency(ticket.remainingAmount))
                            : (ticket.estimatedCost > 0 ? formatCurrency(ticket.remainingAmount) : 'يُحسب بعد الفحص')),
                    isBold: true,
                    textColor: (ticket.remainingAmount <= 0)
                        ? PdfColor.fromHex('#059669')
                        : (ticket.remainingAmount > 0 ? PdfColor.fromHex('#BA1A1A') : PdfColor.fromHex('#134E4A')),
                  ),
                ],
              ),
            ),
            pw.Spacer(),

            // ── Footer: Thank You + Online Tracking QR Code ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isCancelled
                            ? 'إقرار استلام: أقر أنا العميل باستلام جهازي الموضح أعلاه دون إصلاح وإبراء ذمة المركز تماماً.'
                            : 'شكراً لاختياركم ورشة ${ticket.shopName ?? 'ترميم للإصلاح والصيانة'} 🌷',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: isCancelled ? 8.5 : 9.5,
                          color: isCancelled ? PdfColor.fromHex('#991B1B') : PdfColor.fromHex('#134E4A'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'امسح رمز الاستجابة السريعة (QR) لمتابعة حالة جهازك وفاتورتك أونلاين في أي وقت.',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                      ),
                      if (ticket.shopPhone != null && ticket.shopPhone!.isNotEmpty)
                        pw.Text(
                          'للاستفسار والدعم: ${ticket.shopPhone}',
                          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: buildTrackingUrl(ticket.ticketNumber),
                  width: 50,
                  height: 50,
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => doc.save(),
    name: '${receiptTitle.replaceAll(' ', '_')}_${ticket.ticketNumber}',
  );
}

pw.Widget _pdfRow(
  String label,
  String value, {
  bool isBold = false,
  PdfColor? textColor,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: textColor ?? PdfColors.grey800,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: textColor ?? PdfColors.grey900,
          ),
        ),
      ],
    ),
  );
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _TicketHeader extends StatelessWidget {
  const _TicketHeader({required this.ticket});
  final TicketEntity ticket;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: TarmeemColors.outline),
                    const SizedBox(width: 4),
                    Text(
                      formatDateArabic(ticket.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: TarmeemColors.outline,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      'إيصال',
                      style:
                          Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${ticket.ticketNumber}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              ticket.deviceModel,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              ticket.issueDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (ticket.serialNumber != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_outlined,
                      size: 14, color: TarmeemColors.secondary),
                  const SizedBox(width: 6),
                  Text(
                    'سيريال الحرّ: ${ticket.serialNumber}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: TarmeemColors.secondary,
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

class _DevicePhotosCard extends StatelessWidget {
  const _DevicePhotosCard({
    required this.ticket,
    required this.onAddPhoto,
    required this.onZoom,
    required this.onDeletePhoto,
    required this.isUploading,
  });

  final TicketEntity ticket;
  final void Function(BuildContext context, {required bool isAfterRepair}) onAddPhoto;
  final void Function(BuildContext context, String path) onZoom;
  final void Function(BuildContext context, {required String path, required bool isAfterRepair}) onDeletePhoto;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_camera_back_outlined, size: 18, color: TarmeemColors.secondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'توثيق صور الجهاز',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isUploading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: TarmeemColors.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: TarmeemColors.primaryContainer),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'جارِ الرفع...',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TarmeemColors.primaryContainer),
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
                      Icon(Icons.cloud_done, size: 12, color: TarmeemColors.readyDot),
                      SizedBox(width: 4),
                      Text(
                        'سحابة الصور ☁️',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TarmeemColors.readyText),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Intake Photos
          _buildCategory(
            context: context,
            title: 'صور الاستلام (قبل الصيانة)',
            icon: Icons.camera_alt_outlined,
            color: const Color(0xFF2563EB),
            images: ticket.allImages,
            isAfterRepair: false,
          ),
          const SizedBox(height: 12),

          // 2. After-Repair Photos
          _buildCategory(
            context: context,
            title: 'صور توثيق الجهاز بعد الصيانة والإصلاح ✨',
            icon: Icons.verified_rounded,
            color: const Color(0xFF10B981),
            images: ticket.afterRepairImages,
            isAfterRepair: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCategory({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required List<String> images,
    required bool isAfterRepair,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? TarmeemColors.darkCardBorder
              : TarmeemColors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (images.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${images.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () => onAddPhoto(context, isAfterRepair: isAfterRepair),
                icon: const Icon(Icons.add_a_photo_outlined, size: 14),
                label: const Text('إضافة صورة', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (images.isNotEmpty)
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                reverse: true,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final p = images[idx];
                  final isRemote = p.startsWith('http');

                  Widget buildImg() {
                    if (isRemote) {
                      return Image.network(
                        p,
                        fit: BoxFit.cover,
                        width: 100,
                        height: 110,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 110,
                          color: TarmeemColors.surfaceContainerHigh,
                          child: const Icon(Icons.broken_image, color: TarmeemColors.outline),
                        ),
                      );
                    }
                    return kIsWeb
                        ? Image.network(p, fit: BoxFit.cover, width: 100, height: 110)
                        : Image.file(
                            File(p),
                            fit: BoxFit.cover,
                            width: 100,
                            height: 110,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 110,
                              color: TarmeemColors.surfaceContainerHigh,
                              child: const Icon(Icons.broken_image, color: TarmeemColors.outline),
                            ),
                          );
                  }

                  return GestureDetector(
                    onTap: () => onZoom(context, p),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: buildImg(),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAfterRepair ? 'بعد الصيانة ✨' : '#${idx + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: GestureDetector(
                            onTap: () => onDeletePhoto(context, path: p, isAfterRepair: isAfterRepair),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera_back_outlined, size: 16, color: color.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  Text(
                    isAfterRepair
                        ? 'لم يتم توثيق صورة للجهاز بعد الصيانة حتى الآن'
                        : 'لم يتم إرفاق صور للجهاز عند الاستلام',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
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

class _CustomerInfoRow extends StatelessWidget {
  const _CustomerInfoRow({required this.ticket});
  final TicketEntity ticket;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Row(
            children: [
              // Message button
              Material(
                color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.primaryFixed,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final cleanPhone = ticket.customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
                    if (cleanPhone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('رقم هاتف العميل غير متوفر.'), behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    final shop = ticket.shopName ?? AppConstants.defaultShopName;
                    final String msg;
                    if (ticket.status == TicketStatus.readyForPickup) {
                      msg = buildReadyForPickupMessage(
                        customerName: ticket.customerName,
                        deviceModel: ticket.deviceModel,
                        remainingAmount: ticket.remainingAmount,
                        shopName: shop,
                        ticketNumber: ticket.ticketNumber,
                        ticketId: ticket.id,
                        estimatedCost: ticket.estimatedCost,
                        partsCost: ticket.partsCost,
                        laborCost: ticket.laborCost,
                        deposit: ticket.deposit,
                        partsDescription: ticket.partsDescription,
                      );
                    } else if (ticket.status == TicketStatus.delivered) {
                      msg = buildDeliveredThankYouMessage(
                        customerName: ticket.customerName,
                        deviceModel: ticket.deviceModel,
                        shopName: shop,
                        ticketNumber: ticket.ticketNumber,
                        ticketId: ticket.id,
                        totalPaid: ticket.estimatedCost > 0 ? ticket.estimatedCost : ticket.deposit,
                        remainingAmount: ticket.remainingAmount,
                      );
                    } else {
                      msg = buildNewTicketReceiptMessage(
                        customerName: ticket.customerName,
                        ticketNumber: ticket.ticketNumber,
                        deviceModel: ticket.deviceModel,
                        estimatedCost: ticket.estimatedCost,
                        deposit: ticket.deposit,
                        remainingAmount: ticket.remainingAmount,
                        shopName: shop,
                        ticketId: ticket.id,
                        partsCost: ticket.partsCost,
                        partsDescription: ticket.partsDescription,
                      );
                    }
                    UrlHelper.openWhatsApp(
                      phone: ticket.customerPhone,
                      message: msg,
                      context: context,
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(Icons.chat_outlined,
                        color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Phone button
              Material(
                color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => UrlHelper.makePhoneCall(
                    ticket.customerPhone,
                    context: context,
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(Icons.phone_outlined,
                        color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Direct SMS button
              Material(
                color: isDark ? TarmeemColors.darkSurfaceContainerHigh : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final cleanPhone = ticket.customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
                    if (cleanPhone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('رقم هاتف العميل غير متوفر أو غير صالح.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    final shop = ticket.shopName ?? AppConstants.defaultShopName;
                    final String msg;
                    if (ticket.status == TicketStatus.readyForPickup) {
                      msg = 'أهلاً بك أ/ ${ticket.customerName}، جهازك (${ticket.deviceModel}) جاهز للاستلام بورشة $shop. المتبقي: ${formatCurrency(ticket.remainingAmount)}. رابط الفاتورة: ${buildTrackingUrl(ticket.ticketNumber)}';
                    } else if (ticket.status == TicketStatus.delivered) {
                      msg = 'شكراً لثقتكم بورشة $shop أ/ ${ticket.customerName}. تم تسليم جهازك (${ticket.deviceModel}) بنجاح. رابط الفاتورة: ${buildTrackingUrl(ticket.ticketNumber)}';
                    } else {
                      msg = 'أهلاً بك أ/ ${ticket.customerName}، تم تسجيل تذكرة صيانة لجهازك (${ticket.deviceModel}) برقم #${ticket.ticketNumber} بورشة $shop. رابط المتابعة: ${buildTrackingUrl(ticket.ticketNumber)}';
                    }
                    UrlHelper.sendSms(
                      phone: ticket.customerPhone,
                      message: msg,
                      context: context,
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(Icons.sms_outlined,
                        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/customer/${ticket.customerPhone}'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.arrow_back_ios,
                      size: 12, color: TarmeemColors.outline),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          ticket.customerName,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? TarmeemColors.darkOnSurface : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          ticket.customerPhone,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        ticket.customerName.isNotEmpty
                            ? ticket.customerName[0]
                            : '؟',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({
    required this.ticket,
    this.onRequestPriceEstimation,
    this.onDeliveryRequested,
    this.onCancellationRequested,
    this.onReopenRequested,
  });
  final TicketEntity ticket;
  final Future<void> Function(BuildContext context, TicketEntity ticket, {bool isTriggeredByReadyStatus})? onRequestPriceEstimation;
  final Future<void> Function(BuildContext context, TicketEntity ticket)? onDeliveryRequested;
  final Future<void> Function(BuildContext context, TicketEntity ticket)? onCancellationRequested;
  final Future<void> Function(BuildContext context, TicketEntity ticket)? onReopenRequested;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const repairStatuses = [
      TicketStatus.inDiagnosis,
      TicketStatus.waitingForPart,
      TicketStatus.readyForPickup,
      TicketStatus.delivered,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Text(
                'اضغط للتبديل الفوري',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Icon(Icons.tune_outlined,
                  size: 16, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
              const SizedBox(width: 6),
              Text(
                'تحديث حالة الصيانة',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? TarmeemColors.darkOnSurface : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.85,
            children: repairStatuses.map((status) {
              final isSelected = ticket.status == status;
              return _StatusCard(
                status: status,
                isSelected: isSelected,
                onTap: () async {
                  // If ticket is already closed (delivered or cancelled) and user taps another status
                  if (ticket.isCompleted && status != ticket.status) {
                    if (onReopenRequested != null) {
                      await onReopenRequested!(context, ticket);
                    }
                    return;
                  }

                  // If user selected readyForPickup and ticket is not yet priced (estimatedCost <= 0)
                  if (status == TicketStatus.readyForPickup && ticket.status != TicketStatus.readyForPickup) {
                    if (ticket.estimatedCost <= 0) {
                      if (onRequestPriceEstimation != null) {
                        await onRequestPriceEstimation!(context, ticket, isTriggeredByReadyStatus: true);
                      }
                      return;
                    }

                    // Offer to snap photo after repair if none attached yet
                    if (ticket.afterRepairImages.isEmpty) {
                      final photoChoice = await showModalBottomSheet<String>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (sheetCtx) => Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? TarmeemColors.darkSurfaceContainer : Colors.white,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'توثيق الجهاز بعد الصيانة 📸',
                                    style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.verified_rounded, color: TarmeemColors.readyDot),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'أصبح الجهاز جاهزاً! هل تود تصوير الجهاز بعد الإصلاح لحفظ صورته وإثبات جودة الصيانة للعميل؟',
                                style: Theme.of(sheetCtx).textTheme.bodyMedium?.copyWith(
                                      color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.pop(sheetCtx, 'camera'),
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text('التقاط صورة الآن بالكاميرا 📷'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TarmeemColors.primaryContainer,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.pop(sheetCtx, 'gallery'),
                                icon: const Icon(Icons.photo_library, size: 18),
                                label: const Text('اختيار صور من المعرض 🖼️'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => Navigator.pop(sheetCtx, 'skip'),
                                child: const Text('متابعة وإشعار العميل فوراً بدون صورة ⚡'),
                              ),
                            ],
                          ),
                        ),
                      );

                      if (photoChoice != null && photoChoice != 'skip' && context.mounted) {
                        try {
                          final picker = ImagePicker();
                          final List<XFile> pickedFiles = [];
                          if (photoChoice == 'gallery') {
                            final multi = await picker.pickMultiImage(
                              maxWidth: 1280,
                              maxHeight: 1280,
                              imageQuality: 85,
                            );
                            pickedFiles.addAll(multi);
                          } else {
                            final single = await picker.pickImage(
                              source: ImageSource.camera,
                              maxWidth: 1280,
                              maxHeight: 1280,
                              imageQuality: 85,
                            );
                            if (single != null) pickedFiles.add(single);
                          }

                          if (pickedFiles.isNotEmpty) {
                            // 1. Add locally and save immediately so status change is instantaneous
                            final List<String> localPaths = pickedFiles.map((f) => f.path).toList();
                            final list = List<String>.from(ticket.afterRepairImages)..addAll(localPaths);
                            final updatedTicket = ticket.copyWith(afterRepairImages: list);
                            await getIt<TicketRepository>().updateTicket(updatedTicket);

                            // 2. Cloud sync in background without stalling the status change dialog
                            if (SupabaseConfig.isConfigured) {
                              final storage = getIt<SupabaseStorageService>();
                              Future.microtask(() async {
                                TicketEntity current = updatedTicket;
                                bool changed = false;
                                for (int i = 0; i < pickedFiles.length; i++) {
                                  final f = pickedFiles[i];
                                  try {
                                    final publicUrl = await storage.uploadTicketImage(
                                      file: f,
                                      ticketNumber: '${ticket.ticketNumber}_after_${DateTime.now().millisecondsSinceEpoch % 100000}_$i',
                                    );
                                    if (publicUrl != null) {
                                      changed = true;
                                      final updatedList = List<String>.from(current.afterRepairImages);
                                      final idx = updatedList.indexOf(f.path);
                                      if (idx != -1) {
                                        updatedList[idx] = publicUrl;
                                      }
                                      current = current.copyWith(afterRepairImages: updatedList);
                                    }
                                  } catch (e) {
                                    debugPrint('Background after-repair upload notice: $e');
                                    break;
                                  }
                                }
                                if (changed) {
                                  await getIt<TicketRepository>().updateTicket(current);
                                }
                              });
                            }
                          }
                        } catch (e) {
                          debugPrint('Error uploading after-repair photo: $e');
                        }
                      }
                    }
                  }

                  if (!context.mounted) return;

                  // Require explicit confirmation/settlement before marking as delivered
                  if (status == TicketStatus.delivered && ticket.status != TicketStatus.delivered) {
                    if (onDeliveryRequested != null) {
                      await onDeliveryRequested!(context, ticket);
                      return;
                    }
                  }

                  if (!context.mounted) return;
                  context
                      .read<TicketsCubit>()
                      .updateStatus(ticket.id, status);

                  // Auto-dispatch WhatsApp & SMS alerts if status changed to readyForPickup
                  if (status == TicketStatus.readyForPickup && ticket.customerPhone.isNotEmpty) {
                    // 1. Send SMS silently via native SIM without opening SMS app
                    final smsService = getIt<NativeSmsService>();
                    smsService.sendReadyForPickup(
                      phone: ticket.customerPhone,
                      customerName: ticket.customerName,
                      deviceModel: ticket.deviceModel,
                      remainingAmount: ticket.remainingAmount,
                      ticketId: ticket.id,
                      ticketNumber: ticket.ticketNumber,
                      shopName: ticket.shopName,
                    );

                    // 2. Open WhatsApp directly with ready-for-pickup message
                    final message = buildReadyForPickupMessage(
                      customerName: ticket.customerName,
                      deviceModel: ticket.deviceModel,
                      remainingAmount: ticket.remainingAmount,
                      shopName: ticket.shopName ?? 'ورشة الصيانة',
                      ticketNumber: ticket.ticketNumber,
                      ticketId: ticket.id,
                      estimatedCost: ticket.estimatedCost,
                      partsCost: ticket.partsCost,
                      laborCost: ticket.laborCost,
                      deposit: ticket.deposit,
                      partsDescription: ticket.partsDescription,
                    );
                    UrlHelper.openWhatsApp(
                      phone: ticket.customerPhone,
                      message: message,
                      context: context,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم إرسال رسالة SMS وفتح واتساب لإشعار العميل بالاستلام 📱✅'),
                          backgroundColor: TarmeemColors.readyDot,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          _CancelledActionCard(
            isSelected: ticket.status == TicketStatus.cancelled,
            onTap: () async {
              if (ticket.status == TicketStatus.cancelled) {
                if (onReopenRequested != null) {
                  await onReopenRequested!(context, ticket);
                }
                return;
              }
              if (onCancellationRequested != null) {
                await onCancellationRequested!(context, ticket);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _CancelledActionCard extends StatelessWidget {
  const _CancelledActionCard({
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFDC2626))
              : (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.3) : const Color(0xFFFEF2F2)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEF4444)
                : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.arrow_back_ios_new,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626)),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isSelected ? 'مسترجع بدون إصلاح (الحالة الحالية)' : 'إلغاء الإصلاح / استرجاع بدون صيانة',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.assignment_return_outlined,
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isSelected ? 'اضغط لإعادة فتح التذكرة للصيانة مجدداً 🔄' : 'تسوية رسوم الكشف والعربون وإخلاء طرف الورشة 🛑',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  final TicketStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData icon;
    switch (status) {
      case TicketStatus.inDiagnosis:
        icon = Icons.search_outlined;
      case TicketStatus.waitingForPart:
        icon = Icons.inventory_2_outlined;
      case TicketStatus.readyForPickup:
        icon = Icons.check_circle_outlined;
      case TicketStatus.delivered:
        icon = Icons.done_all_outlined;
      case TicketStatus.cancelled:
        icon = Icons.assignment_return_outlined;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryContainer)
              : (isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.7)
                        : (isDark ? TarmeemColors.darkOnSurfaceVariant.withValues(alpha: 0.5) : TarmeemColors.outline),
                    shape: BoxShape.circle,
                  ),
                ),
                const Spacer(),
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              status.label,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatsAppNotify extends StatelessWidget {
  const _WhatsAppNotify({required this.ticket});
  final TicketEntity ticket;

  @override
  Widget build(BuildContext context) {
    if (ticket.status != TicketStatus.readyForPickup) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final message = buildReadyForPickupMessage(
      customerName: ticket.customerName,
      deviceModel: ticket.deviceModel,
      remainingAmount: ticket.remainingAmount,
      shopName: ticket.shopName ?? 'ورشتنا',
      ticketNumber: ticket.ticketNumber,
      ticketId: ticket.id,
      estimatedCost: ticket.estimatedCost,
      partsCost: ticket.partsCost,
      laborCost: ticket.laborCost,
      deposit: ticket.deposit,
      partsDescription: ticket.partsDescription,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? TarmeemColors.darkReadyBackground : TarmeemColors.readyBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'واتساب رسمي',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.play_arrow_outlined,
                  color: TarmeemColors.secondary, size: 18),
              const SizedBox(width: 6),
              Text(
                'إشعار فوري للعميل',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? TarmeemColors.darkOnSurface : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '« $message »',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                height: 1.6,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'إبلاغ العميل عبر واتساب (جاهز للاستلام)',
            icon: const Icon(Icons.chat_outlined, size: 18),
            onPressed: () {
              UrlHelper.openWhatsApp(
                phone: ticket.customerPhone,
                message: message,
                context: context,
              );
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(Icons.sms_outlined,
                  size: 18, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
              label: Text(
                'إرسال SMS عبر تطبيق الرسائل 💬',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE)),
                backgroundColor: isDark ? TarmeemColors.darkSurfaceContainerHigh : const Color(0xFFEEF2FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                final shop = ticket.shopName ?? AppConstants.defaultShopName;
                final smsMsg =
                    'أهلاً بك أ/ ${ticket.customerName}، جهازك (${ticket.deviceModel}) جاهز للاستلام بورشة $shop. المتبقي: ${formatCurrency(ticket.remainingAmount)}. رابط الفاتورة: ${buildTrackingUrl(ticket.ticketNumber)}';
                UrlHelper.sendSms(
                  phone: ticket.customerPhone,
                  message: smsMsg,
                  context: context,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialSummary extends StatelessWidget {
  const _FinancialSummary({
    required this.ticket,
    required this.onManageParts,
    required this.onEstimatePrice,
    required this.onSendQuote,
  });
  final TicketEntity ticket;
  final VoidCallback onManageParts;
  final VoidCallback onEstimatePrice;
  final VoidCallback onSendQuote;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasParts = ticket.partsCost > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: onManageParts,
                      icon: Icon(Icons.settings_suggest_outlined,
                          size: 14, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                      label: Text(
                        hasParts ? 'القطع' : '+ قطع',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: isDark
                            ? TarmeemColors.darkSurfaceContainerHigh
                            : TarmeemColors.primaryFixed.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (ticket.deposit > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? TarmeemColors.darkReadyBackground : TarmeemColors.readyBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'عربون مسدد',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ملخص الحسابات',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? TarmeemColors.darkOnSurface : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.payments_outlined,
                          size: 16, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _FinancialItem(
                label: 'المتبقي',
                amount: ticket.remainingAmount,
                customValueText: ticket.estimatedCost <= 0 ? 'بعد الفحص' : null,
                color: ticket.estimatedCost <= 0
                    ? (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant)
                    : (ticket.remainingAmount == 0
                        ? (isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText)
                        : (isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface)),
              ),
              const SizedBox(width: 10),
              _FinancialItem(
                label: 'العربون المدفوع',
                amount: ticket.deposit,
                color: TarmeemColors.waitingText,
              ),
              const SizedBox(width: 10),
              _FinancialItem(
                label: 'إجمالي الفاتورة',
                amount: ticket.estimatedCost,
                customValueText: ticket.estimatedCost <= 0 ? 'قيد الفحص 🔍' : null,
                color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                isLarge: true,
              ),
            ],
          ),
          if (ticket.estimatedCost <= 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'التكلفة الإجمالية والمتبقي قيد التحديد بعد انتهاء الفحص والمعاينة الفنية.',
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onEstimatePrice,
                      icon: const Icon(Icons.request_quote_outlined, size: 16),
                      label: const Text(
                        'تحديد سعر الصيانة / إرسال عرض السعر للعميل 💰',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEstimatePrice,
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'تعديل السعر',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSendQuote,
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'إرسال عرض السعر 💬',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (ticket.partsCost > 0 || ticket.estimatedCost > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
                ),
              ),
              child: Column(
                children: [
                  if (hasParts) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatCurrency(ticket.partsCost),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'سعر بيع قطع الغيار للعميل ${ticket.partsDescription != null && ticket.partsDescription!.isNotEmpty ? "(${ticket.partsDescription})" : ""}:',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.build_circle_outlined,
                                  size: 16, color: Color(0xFFEA580C)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (ticket.partsWholesaleCost > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatCurrency(ticket.partsWholesaleCost),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'سعر شراء القطعة (جملة على الورشة):',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.shopping_bag_outlined,
                                    size: 16, color: Color(0xFF475569)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (ticket.partsProfit > 0 && ticket.partsCost > 0 && ticket.partsWholesaleCost > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '+${formatCurrency(ticket.partsProfit)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'مكسبك في قطعة الغيار ✨:',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.trending_up,
                                    size: 16, color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 14, thickness: 0.5),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatCurrency(ticket.laborCost),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'أجرة اليد / المصنعية:',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.handyman_outlined,
                                size: 16, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 14, thickness: 0.5),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatCurrency(ticket.netProfit),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'صافي أرباح الورشة المؤكد ✨:',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                                          fontWeight: FontWeight.w700,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.trending_up,
                                    size: 18, color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (ticket.partsProfit > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '(أجرة المصنعية ${formatCurrency(ticket.laborCost)} + مكسب القطعة ${formatCurrency(ticket.partsProfit)})',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
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

class _SparePartsCard extends StatelessWidget {
  const _SparePartsCard({required this.ticket, required this.onManageParts});
  final TicketEntity ticket;
  final VoidCallback onManageParts;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasParts = ticket.partsCost > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasParts
              ? (isDark ? const Color(0xFF7C2D12) : const Color(0xFFFED7AA))
              : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (ticket.status == TicketStatus.delivered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'مسجلة ومغلقة 🔒',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: onManageParts,
                    icon: Icon(hasParts ? Icons.edit_outlined : Icons.add_circle_outline, size: 15),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        hasParts ? 'تعديل القطع' : 'إضافة قطعة غيار',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasParts
                          ? (isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow)
                          : TarmeemColors.secondary,
                      foregroundColor: hasParts
                          ? (isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface)
                          : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'قطع الغيار',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? TarmeemColors.darkOnSurface : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.extension_outlined, size: 18, color: TarmeemColors.secondary),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasParts) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C1810) : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatCurrency(ticket.partsCost),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          ticket.partsDescription != null && ticket.partsDescription!.isNotEmpty
                              ? ticket.partsDescription!
                              : 'قطعة غيار مستهلكة',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (ticket.partsWholesaleCost > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatCurrency(ticket.partsWholesaleCost),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        Text(
                          'سعر شراء القطعة (جملة على الورشة):',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (ticket.partsProfit > 0 && ticket.partsCost > 0 && ticket.partsWholesaleCost > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '+${formatCurrency(ticket.partsProfit)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                          ),
                        ),
                        Text(
                          'مكسبك في قطعة الغيار ✨:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? TarmeemColors.darkReadyText : TarmeemColors.readyText,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '💡 سعر بيع القطعة مدرج في فاتورة العميل، وسعر الشراء يُخصم لحساب صافي أرباحك الصافية المؤكدة.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'لم تُسجل أي قطع غيار لهذا الجهاز حتى الآن (صيانة مصنعية فقط). اضغط لإضافة قطعة غيار وتحديث إجمالي الفاتورة والأرباح تلقائياً في أي وقت.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
  }
}

class _FinancialItem extends StatelessWidget {
  const _FinancialItem({
    required this.label,
    required this.amount,
    required this.color,
    this.customValueText,
    this.isLarge = false,
  });

  final String label;
  final double amount;
  final Color color;
  final String? customValueText;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                customValueText ?? formatCurrency(amount, currencySymbol: ''),
                style: TextStyle(
                  fontSize: isLarge ? 20 : 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            if (customValueText == null)
              Text(
                'ج.م',
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.7),
                ),
              )
            else
              const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.history});
  final List<StatusHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              const Spacer(),
              Icon(Icons.history_outlined,
                  size: 16, color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer),
              const SizedBox(width: 6),
              Text(
                'سجل مسار الإصلاح',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? TarmeemColors.darkOnSurface : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...history.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isFirst = i == 0;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline line + dot
                Column(
                  children: [
                    if (!isFirst)
                      Container(
                        width: 1,
                        height: 20,
                        color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant,
                      ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isFirst
                            ? (isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryContainer)
                            : (isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerLow),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFirst
                              ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                              : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant),
                        ),
                      ),
                      child: Icon(
                        isFirst
                            ? Icons.check_rounded
                            : Icons.radio_button_unchecked_outlined,
                        size: 14,
                        color: isFirst
                            ? Colors.white
                            : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outlineVariant),
                      ),
                    ),
                    if (i < history.length - 1)
                      Container(
                        width: 1,
                        height: 60,
                        color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              formatRelativeTime(item.timestamp),
                              style:
                                  Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: TarmeemColors.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                item.status.label,
                                style:
                                    Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: isFirst
                                      ? (isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer)
                                      : (isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface),
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (item.note != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.note!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}


class _QuickPricePill extends StatelessWidget {
  const _QuickPricePill({required this.label, required this.onTap});
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
          border: Border.all(
            color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? TarmeemColors.darkOnSurface : null,
              ),
        ),
      ),
    );
  }
}

class _DeliveredBanner extends StatelessWidget {
  const _DeliveredBanner({
    required this.ticket,
    required this.onSendThankYou,
  });

  final TicketEntity ticket;
  final VoidCallback onSendThankYou;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFullyPaid = ticket.remainingAmount <= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified,
                  color: Color(0xFF10B981),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'تم تسليم هذا الجهاز وإغلاق التذكرة بنجاح',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF065F46),
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isFullyPaid
                          ? '✅ الفاتورة مسددة وخالصة بالكامل (${formatCurrency(ticket.estimatedCost)})'
                          : '⚠️ متبقي دَين آجل على العميل: ${formatCurrency(ticket.remainingAmount)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isFullyPaid
                            ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                            : TarmeemColors.error,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSendThankYou,
              icon: const Icon(Icons.chat_outlined, size: 16, color: Colors.white),
              label: const Text(
                'إرسال رسالة الشكر والفاتورة عبر واتساب 💬',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner({
    required this.ticket,
    required this.onSendWhatsApp,
    required this.onPrintReceipt,
    required this.onReopen,
  });

  final TicketEntity ticket;
  final VoidCallback onSendWhatsApp;
  final VoidCallback onPrintReceipt;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasInspectionFee = ticket.estimatedCost > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF450A0A), const Color(0xFF2B0B0B)]
              : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_return_outlined,
                  color: Color(0xFFEF4444),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'تم إلغاء الإصلاح - الجهاز مسترجع للعميل',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF991B1B),
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasInspectionFee
                          ? '🔍 رسوم الفحص والكشف: ${formatCurrency(ticket.estimatedCost)}'
                          : '✅ فحص مجاني - تم إخلاء طرف العميل بدون رسوم',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrintReceipt,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text(
                    'إيصال استرجاع',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : const Color(0xFF991B1B),
                    side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSendWhatsApp,
                  icon: const Icon(Icons.chat_outlined, size: 16, color: Colors.white),
                  label: const Text(
                    'إشعار بواتساب 💬',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onReopen,
            icon: const Icon(Icons.refresh_outlined, size: 15, color: TarmeemColors.outline),
            label: const Text(
              'إعادة فتح التذكرة لمتابعة الصيانة 🔄',
              style: TextStyle(fontSize: 12, color: TarmeemColors.outline),
            ),
          ),
        ],
      ),
    );
  }
}



