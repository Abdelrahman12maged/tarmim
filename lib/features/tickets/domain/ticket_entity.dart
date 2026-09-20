/// Ticket entity — pure domain object with no Flutter/package imports.
///
/// Represents a single repair ticket in the Tarmeem system.
import '../../../core/constants/app_constants.dart';

/// Immutable entity representing a repair ticket.
class TicketEntity {
  const TicketEntity({
    required this.id,
    required this.ticketNumber,
    required this.customerName,
    required this.customerPhone,
    required this.deviceType,
    required this.deviceModel,
    required this.issueDescription,
    required this.estimatedCost,
    required this.deposit,
    this.partsCost = 0.0,
    this.partsWholesaleCost = 0.0,
    this.partsDescription,
    required this.status,
    required this.statusHistory,
    required this.createdAt,
    this.technicianName,
    this.shelfLocation,
    this.serialNumber,
    this.imageUrl,
    this.images = const [],
    this.afterRepairImages = const [],
    this.sendWhatsAppLink = true,
    this.shopId,
    this.customerId,
    this.shopName,
    this.shopPhone,
    this.shopAddress,
    this.branchId = 'main',
    this.branchName = 'الفرع الرئيسي',
  });

  final String id;
  final String ticketNumber; // e.g. "TR-4082"
  final String customerName;
  final String customerPhone;
  final DeviceType deviceType;
  final String deviceModel; // e.g. "ساعة رولكس أوتوماتيك"
  final String issueDescription;
  final double estimatedCost;
  final double deposit;
  final double partsCost; // سعر بيع قطع الغيار للعميل (المضاف على الفاتورة)
  final double partsWholesaleCost; // تمن / تكلفة شراء قطعة الغيار على الورشة
  final String? partsDescription; // وصف أو اسم قطعة الغيار (اختياري)
  final TicketStatus status;
  final List<StatusHistoryEntry> statusHistory;
  final DateTime createdAt;
  final String? technicianName;
  final String? shelfLocation;
  final String? serialNumber;
  final String? imageUrl;
  final List<String> images;
  final List<String> afterRepairImages;
  final bool sendWhatsAppLink;
  final String? shopId;
  final String? customerId;
  final String? shopName;
  final String? shopPhone;
  final String? shopAddress;
  final String branchId;
  final String branchName;

  /// Returns all intake images, falling back to [imageUrl] if [images] is empty.
  List<String> get allImages {
    if (images.isNotEmpty) return images;
    if (imageUrl != null && imageUrl!.isNotEmpty) return [imageUrl!];
    return const [];
  }

  /// Remaining amount the customer owes. Returns 0 if cost is not yet estimated.
  double get remainingAmount => (estimatedCost > 0)
      ? (estimatedCost - deposit).clamp(0.0, double.infinity)
      : 0.0;

  /// Labor / service fee: remaining value after deducting spare parts customer price.
  double get laborCost => (estimatedCost - partsCost).clamp(0.0, double.infinity);

  /// Profit margin on spare parts:
  /// (Customer selling price - Workshop wholesale purchase cost).
  /// If partsWholesaleCost is 0 or not set, parts profit defaults to 0.
  double get partsProfit => (partsCost > 0 && partsWholesaleCost > 0)
      ? (partsCost - partsWholesaleCost).clamp(0.0, double.infinity)
      : 0.0;

  /// Net workshop profit:
  /// Labor fee + spare parts profit
  /// = (estimatedCost - partsCost) + (partsCost - partsWholesaleCost)
  /// = estimatedCost - (partsWholesaleCost > 0 ? partsWholesaleCost : partsCost)
  double get netProfit {
    if (estimatedCost <= 0) return 0.0;
    final actualWholesale = partsWholesaleCost > 0 ? partsWholesaleCost : partsCost;
    return (estimatedCost - actualWholesale).clamp(0.0, double.infinity);
  }

  /// Returns true if this ticket was cancelled / returned without repair.
  bool get isCancelled => status == TicketStatus.cancelled;

  /// Returns true if this ticket has been delivered.
  bool get isDelivered => status == TicketStatus.delivered;

  /// Returns true if this ticket is finished/closed (delivered or cancelled).
  bool get isCompleted => status.isCompleted;

  /// Returns a copy of this entity with the given fields replaced.
  TicketEntity copyWith({
    String? id,
    String? ticketNumber,
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
    TicketStatus? status,
    List<StatusHistoryEntry>? statusHistory,
    DateTime? createdAt,
    String? technicianName,
    String? shelfLocation,
    String? serialNumber,
    String? imageUrl,
    List<String>? images,
    List<String>? afterRepairImages,
    bool? sendWhatsAppLink,
    String? shopId,
    String? customerId,
    String? shopName,
    String? shopPhone,
    String? shopAddress,
    String? branchId,
    String? branchName,
  }) {
    return TicketEntity(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
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
      status: status ?? this.status,
      statusHistory: statusHistory ?? this.statusHistory,
      createdAt: createdAt ?? this.createdAt,
      technicianName: technicianName ?? this.technicianName,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      serialNumber: serialNumber ?? this.serialNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      afterRepairImages: afterRepairImages ?? this.afterRepairImages,
      sendWhatsAppLink: sendWhatsAppLink ?? this.sendWhatsAppLink,
      shopId: shopId ?? this.shopId,
      customerId: customerId ?? this.customerId,
      shopName: shopName ?? this.shopName,
      shopPhone: shopPhone ?? this.shopPhone,
      shopAddress: shopAddress ?? this.shopAddress,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
    );
  }
}

/// A single entry in the status history timeline.
class StatusHistoryEntry {
  const StatusHistoryEntry({
    required this.status,
    required this.timestamp,
    this.note,
    this.technicianName,
  });

  final TicketStatus status;
  final DateTime timestamp;
  final String? note;
  final String? technicianName;
}
