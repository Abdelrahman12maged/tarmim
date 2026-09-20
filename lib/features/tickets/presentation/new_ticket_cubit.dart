/// New Ticket Cubit and state.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/ticket_entity.dart';
import '../domain/ticket_repository.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection.dart';
import '../../subscription/presentation/subscription_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── State ─────────────────────────────────────────────────────────────────

class NewTicketState extends Equatable {
  const NewTicketState({
    this.customerName = '',
    this.customerPhone = '',
    this.deviceType = DeviceType.mobile,
    this.deviceModel = '',
    this.issueDescription = '',
    this.estimatedCost = 0,
    this.deposit = 0,
    this.partsCost = 0,
    this.partsWholesaleCost = 0,
    this.partsDescription,
    this.sendWhatsAppLink = true,
    this.imageUrl,
    this.images = const [],
    this.isSubmitting = false,
    this.isSuccess = false,
    this.error,
    this.createdTicket,
  });

  final String customerName;
  final String customerPhone;
  final DeviceType deviceType;
  final String deviceModel;
  final String issueDescription;
  final double estimatedCost;
  final double deposit;
  final double partsCost;
  final double partsWholesaleCost;
  final String? partsDescription;
  final bool sendWhatsAppLink;
  final String? imageUrl;
  final List<String> images;
  final bool isSubmitting;
  final bool isSuccess;
  final String? error;
  final TicketEntity? createdTicket;

  double get remainingAmount => (estimatedCost > 0)
      ? (estimatedCost - deposit).clamp(0.0, double.infinity)
      : 0.0;
  double get laborCost => (estimatedCost - partsCost).clamp(0.0, double.infinity);
  double get partsProfit => (partsCost > 0 && partsWholesaleCost > 0)
      ? (partsCost - partsWholesaleCost).clamp(0.0, double.infinity)
      : 0.0;
  double get netProfit {
    if (estimatedCost <= 0) return 0.0;
    final actualWholesale = partsWholesaleCost > 0 ? partsWholesaleCost : partsCost;
    return (estimatedCost - actualWholesale).clamp(0.0, double.infinity);
  }

  NewTicketState copyWith({
    String? customerName,
    String? customerPhone,
    DeviceType? deviceType,
    String? deviceModel,
    String? issueDescription,
    double? estimatedCost,
    double? deposit,
    double? partsCost,
    double? partsWholesaleCost,
    String? partsDescription,
    bool? sendWhatsAppLink,
    String? imageUrl,
    List<String>? images,
    bool? isSubmitting,
    bool? isSuccess,
    String? error,
    TicketEntity? createdTicket,
  }) {
    return NewTicketState(
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deviceType: deviceType ?? this.deviceType,
      deviceModel: deviceModel ?? this.deviceModel,
      issueDescription: issueDescription ?? this.issueDescription,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      deposit: deposit ?? this.deposit,
      partsCost: partsCost ?? this.partsCost,
      partsWholesaleCost: partsWholesaleCost ?? this.partsWholesaleCost,
      partsDescription: partsDescription ?? this.partsDescription,
      sendWhatsAppLink: sendWhatsAppLink ?? this.sendWhatsAppLink,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      createdTicket: createdTicket ?? this.createdTicket,
    );
  }

  bool get isValid =>
      customerName.trim().isNotEmpty &&
      deviceModel.trim().isNotEmpty &&
      issueDescription.trim().length >= 5;

  @override
  List<Object?> get props => [
        customerName, customerPhone, deviceType, deviceModel,
        issueDescription, estimatedCost, deposit, partsCost, partsWholesaleCost, partsDescription, sendWhatsAppLink,
        imageUrl, images,
        isSubmitting, isSuccess, error, createdTicket,
      ];
}

// ── Cubit ─────────────────────────────────────────────────────────────────

class NewTicketCubit extends Cubit<NewTicketState> {
  NewTicketCubit(this._repository) : super(const NewTicketState());

  final TicketRepository _repository;

  void setCustomerName(String v) => emit(state.copyWith(customerName: v));
  void setCustomerPhone(String v) => emit(state.copyWith(customerPhone: v));
  void setDeviceType(DeviceType v) => emit(state.copyWith(deviceType: v));
  void setDeviceModel(String v) => emit(state.copyWith(deviceModel: v));
  void setIssueDescription(String v) =>
      emit(state.copyWith(issueDescription: v));
  void setEstimatedCost(double v) => emit(state.copyWith(estimatedCost: v));
  void setDeposit(double v) => emit(state.copyWith(deposit: v));

  void setLaborCost(double labor) {
    emit(state.copyWith(estimatedCost: labor + state.partsCost));
  }

  void setPartsWholesaleCost(double wholesale) {
    emit(state.copyWith(partsWholesaleCost: wholesale));
  }

  void setPartsCost(double parts, {bool autoUpdateTotal = true}) {
    if (autoUpdateTotal) {
      final currentLabor = state.laborCost;
      emit(state.copyWith(
        partsCost: parts,
        estimatedCost: currentLabor + parts,
      ));
    } else {
      emit(state.copyWith(partsCost: parts));
    }
  }

  void setPartsDescription(String v) {
    emit(state.copyWith(partsDescription: v.trim().isEmpty ? null : v.trim()));
  }

  void toggleWhatsApp() =>
      emit(state.copyWith(sendWhatsAppLink: !state.sendWhatsAppLink));

  void setImageUrl(String? path) {
    if (path == null) {
      emit(state.copyWith(imageUrl: null, images: const []));
    } else {
      final updated = List<String>.from(state.images);
      if (!updated.contains(path)) updated.insert(0, path);
      emit(state.copyWith(imageUrl: path, images: updated));
    }
  }

  void addImage(String path) {
    final updated = List<String>.from(state.images)..add(path);
    emit(state.copyWith(
      images: updated,
      imageUrl: updated.isNotEmpty ? updated.first : null,
    ));
  }

  void addImages(List<String> paths) {
    final updated = List<String>.from(state.images)..addAll(paths);
    emit(state.copyWith(
      images: updated,
      imageUrl: updated.isNotEmpty ? updated.first : null,
    ));
  }

  void removeImage(int index) {
    if (index < 0 || index >= state.images.length) return;
    final updated = List<String>.from(state.images)..removeAt(index);
    emit(state.copyWith(
      images: updated,
      imageUrl: updated.isNotEmpty ? updated.first : null,
    ));
  }

  void replaceImageUrl(String oldUrl, String newUrl) {
    final currentImages = List<String>.from(state.images);
    final idx = currentImages.indexOf(oldUrl);
    if (idx != -1) {
      currentImages[idx] = newUrl;
    } else {
      currentImages.add(newUrl);
    }
    emit(state.copyWith(
      images: currentImages,
      imageUrl: currentImages.isNotEmpty ? currentImages.first : null,
    ));
  }

  void updateImages(List<String> images) {
    emit(state.copyWith(
      images: images,
      imageUrl: images.isNotEmpty ? images.first : null,
    ));
  }

  void addToDeposit(double amount) {
    emit(state.copyWith(deposit: state.deposit + amount));
  }

  void setFullDeposit() {
    emit(state.copyWith(deposit: state.estimatedCost));
  }

  Future<void> submit() async {
    if (!state.isValid) return;

    final subCubit = getIt<SubscriptionCubit>();
    if (subCubit.state.isExpired) {
      emit(state.copyWith(
        isSubmitting: false,
        error: 'انتهت الفترة التجريبية للمحل. يرجى الاشتراك وتفعيل كود الترخيص لمتابعة إنشاء التذاكر 🔒',
      ));
      return;
    }

    emit(state.copyWith(isSubmitting: true, error: null));

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedShopName = prefs.getString(AppConstants.prefShopName) ??
          prefs.getString('current_shop_name');
      final activeShopName =
          (savedShopName != null && savedShopName.trim().isNotEmpty)
              ? savedShopName.trim()
              : AppConstants.defaultShopName;
      final activeShopPhone = prefs.getString(AppConstants.prefShopPhone) ??
          AppConstants.defaultShopPhone;
      final activeShopAddress = prefs.getString(AppConstants.prefShopAddress) ??
          AppConstants.defaultShopAddress;
      final savedShopId = prefs.getString(AppConstants.prefShopId);
      final activeBranchId = prefs.getString('current_branch_id') ?? 'main';
      final activeBranchName = prefs.getString('current_branch_name') ?? 'الفرع الرئيسي';

      final ticket = TicketEntity(
        id: '',
        ticketNumber: '',
        customerName: state.customerName.trim(),
        customerPhone: state.customerPhone.trim(),
        deviceType: state.deviceType,
        deviceModel: state.deviceModel.trim(),
        issueDescription: state.issueDescription.trim(),
        estimatedCost: state.estimatedCost,
        deposit: state.deposit,
        partsCost: state.partsCost,
        partsWholesaleCost: state.partsWholesaleCost,
        partsDescription: state.partsDescription,
        status: TicketStatus.inDiagnosis,
        statusHistory: [
          StatusHistoryEntry(
            status: TicketStatus.inDiagnosis,
            timestamp: DateTime.now(),
            note: 'استلام وتسجيل الغرض في الورشة.',
          ),
        ],
        createdAt: DateTime.now(),
        imageUrl: state.imageUrl ?? (state.images.isNotEmpty ? state.images.first : null),
        images: state.images,
        sendWhatsAppLink: state.sendWhatsAppLink,
        shopId: savedShopId,
        shopName: activeShopName,
        shopPhone: activeShopPhone,
        shopAddress: activeShopAddress,
        branchId: activeBranchId,
        branchName: activeBranchName,
      );

      final created = await _repository.createTicket(ticket);
      emit(state.copyWith(
        isSubmitting: false,
        isSuccess: true,
        createdTicket: created,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        error: 'حدث خطأ أثناء الحفظ. يرجى المحاولة مجدداً',
      ));
    }
  }
}
