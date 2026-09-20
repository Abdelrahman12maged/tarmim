import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/buttons.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../tickets/presentation/tickets_cubit.dart';
import 'branches_cubit.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BranchesCubit>().loadBranches();
  }

  void _showAddBranchSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final pinController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                        Text(
                          'إضافة فرع جديد للمحل',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TarmeemTextField(
                      controller: nameController,
                      label: 'اسم الفرع',
                      hint: 'مثال: فرع الدقي / فرع المعادي',
                      prefixIcon: const Icon(Icons.storefront_outlined),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'يرجى كتابة اسم الفرع';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TarmeemTextField(
                      controller: phoneController,
                      label: 'رقم هاتف الفرع (اختياري: اتركه فارغاً لاستخدام نفس هاتف المحل)',
                      hint: '01xxxxxxxxx',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    const SizedBox(height: 12),
                    TarmeemTextField(
                      controller: pinController,
                      label: 'الرقم السري / PIN لدخول الفرع (مطلوب)',
                      hint: 'مثال: 1235 (رمز مختلف عن رمز المالك لتمييز الفرع)',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      validator: (val) {
                        if (val == null || val.trim().length < 4) {
                          return 'الرقم السري لدخول الفرع يجب أن يكون 4 أرقام على الأقل';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TarmeemTextField(
                      controller: addressController,
                      label: 'عنوان الفرع (اختياري)',
                      hint: 'مثال: 15 شارع التحرير، الدقي',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: isSaving ? 'جارِ الحفظ...' : 'حفظ وإضافة الفرع',
                      icon: isSaving ? null : const Icon(Icons.add_business_rounded, color: Colors.white),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => isSaving = true);
                              final cubit = context.read<BranchesCubit>();
                              final success = await cubit.addBranch(
                                name: nameController.text.trim(),
                                phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                                pin: pinController.text.trim().isEmpty ? null : pinController.text.trim(),
                                address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                              );
                              if (context.mounted) {
                                Navigator.pop(bottomSheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success
                                        ? 'تم إضافة الفرع وبيانات دخوله بنجاح! 🏢'
                                        : 'تعذر إضافة الفرع، يرجى المحاولة ثانية'),
                                    backgroundColor: success ? TarmeemColors.readyDot : TarmeemColors.secondary,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('إدارة فروع المحل'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBranchSheet(context),
        backgroundColor: TarmeemColors.primaryContainer,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة فرع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: BlocConsumer<BranchesCubit, BranchesState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: TarmeemColors.secondary,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.branches.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.branches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, size: 64, color: isDark ? TarmeemColors.darkOutline : TarmeemColors.outline),
                  const SizedBox(height: 16),
                  const Text('لا توجد فروع مسجلة حتى الآن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('يمكنك إضافة فرعك الأول بالضغط على الزر أدناه'),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.branches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final branch = state.branches[index];
              final isActive = state.activeBranch?.id == branch.id;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isActive
                        ? TarmeemColors.primaryContainer
                        : (isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder),
                    width: isActive ? 2 : 1,
                  ),
                ),
                color: isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? (isDark ? TarmeemColors.darkPrimaryContainer : TarmeemColors.primaryFixed)
                                  : (isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerHigh),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              branch.isMain ? Icons.domain_rounded : Icons.store_mall_directory_rounded,
                              color: isActive ? TarmeemColors.primaryContainer : TarmeemColors.outline,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        branch.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (branch.isMain) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: TarmeemColors.primaryContainer.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'الرئيسي',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: TarmeemColors.primaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                  const SizedBox(height: 4),
                                  Text(
                                    branch.phone != null && branch.phone!.isNotEmpty
                                        ? '📞 هاتف الدخول: ${branch.phone}'
                                        : '📞 هاتف الدخول: هاتف المحل الرئيسي',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                    ),
                                  ),
                                if (branch.pin != null && branch.pin!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '🔑 رمز الدخول (PIN): ${branch.pin}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer,
                                    ),
                                  ),
                                ],
                                if (branch.address != null && branch.address!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '📍 ${branch.address}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: TarmeemColors.readyDot.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: TarmeemColors.readyDot),
                                  SizedBox(width: 4),
                                  Text(
                                    'الفرع المفعّل حالياً',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: TarmeemColors.readyDot,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            TextButton.icon(
                              onPressed: () async {
                                final branchesCubit = context.read<BranchesCubit>();
                                await branchesCubit.selectBranch(branch);
                                if (context.mounted) {
                                  // Switch active branch in TicketsCubit to filter tickets
                                  getIt<TicketsCubit>().switchBranch(branch.id);
                                  context.read<AuthCubit>().updateActiveBranch(
                                    branchId: branch.id,
                                    branchName: branch.name,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تم تفعيل "${branch.name}" بنجاح! 🏢'),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: const Text('تفعيل هذا الفرع'),
                              style: TextButton.styleFrom(
                                foregroundColor: TarmeemColors.primaryContainer,
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
      ),
    );
  }
}
