/// Ticket data model with JSON serialization for Firestore.
///
/// Extends [TicketEntity] with fromJson/toJson methods.
import '../domain/ticket_entity.dart';
import '../../../core/constants/app_constants.dart';

/// Data model for a repair ticket, with Firestore serialization support.
class TicketModel extends TicketEntity {
  const TicketModel({
    required super.id,
    required super.ticketNumber,
    required super.customerName,
    required super.customerPhone,
    required super.deviceType,
    required super.deviceModel,
    required super.issueDescription,
    required super.estimatedCost,
    required super.deposit,
    super.partsCost = 0.0,
    super.partsWholesaleCost = 0.0,
    super.partsDescription,
    required super.status,
    required super.statusHistory,
    required super.createdAt,
    super.technicianName,
    super.shelfLocation,
    super.serialNumber,
    super.imageUrl,
    super.images = const [],
    super.afterRepairImages = const [],
    super.sendWhatsAppLink,
    super.shopId,
    super.customerId,
    super.shopName,
    super.shopPhone,
    super.shopAddress,
    super.branchId = 'main',
    super.branchName = 'الفرع الرئيسي',
  });

  /// Deserializes a Firestore document into a [TicketModel].
  factory TicketModel.fromJson(Map<String, dynamic> json, String docId) {
    final statusHistory = (json['statusHistory'] as List<dynamic>? ?? [])
        .map((e) => StatusHistoryEntry(
              status: TicketStatus.fromValue(e['status'] as String? ?? ''),
              timestamp: _parseTimestamp(e['timestamp']),
              note: e['note'] as String?,
              technicianName: e['technicianName'] as String?,
            ))
        .toList();

    final rawImages = json['images'] as List<dynamic>? ?? json['photos'] as List<dynamic>?;
    final parsedImages = rawImages?.map((e) => e.toString()).toList() ?? <String>[];
    final singleImage = json['imageUrl'] as String? ?? json['image_url'] as String?;
    if (parsedImages.isEmpty && singleImage != null && singleImage.isNotEmpty) {
      parsedImages.add(singleImage);
    }

    final rawAfterImages = json['afterRepairImages'] as List<dynamic>? ?? json['after_repair_images'] as List<dynamic>?;
    final parsedAfterImages = rawAfterImages?.map((e) => e.toString()).toList() ?? <String>[];

    return TicketModel(
      id: docId,
      ticketNumber: json['ticketNumber'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? '',
      deviceType: _parseDeviceType(json['deviceType'] as String?),
      deviceModel: json['deviceModel'] as String? ?? '',
      issueDescription: json['issueDescription'] as String? ?? '',
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      deposit: (json['deposit'] as num?)?.toDouble() ?? 0.0,
      partsCost: (json['partsCost'] as num?)?.toDouble() ?? (json['parts_cost'] as num?)?.toDouble() ?? 0.0,
      partsWholesaleCost: (json['partsWholesaleCost'] as num?)?.toDouble() ?? (json['parts_wholesale_cost'] as num?)?.toDouble() ?? 0.0,
      partsDescription: json['partsDescription'] as String? ?? json['parts_description'] as String?,
      status: TicketStatus.fromValue(json['status'] as String? ?? ''),
      statusHistory: statusHistory,
      createdAt: _parseTimestamp(json['createdAt']),
      technicianName: json['technicianName'] as String?,
      shelfLocation: json['shelfLocation'] as String?,
      serialNumber: json['serialNumber'] as String?,
      imageUrl: singleImage ?? (parsedImages.isNotEmpty ? parsedImages.first : null),
      images: parsedImages,
      afterRepairImages: parsedAfterImages,
      sendWhatsAppLink: json['sendWhatsAppLink'] as bool? ?? true,
      shopId: json['shopId'] as String?,
      customerId: json['customerId'] as String?,
      shopName: json['shopName'] as String?,
      shopPhone: json['shopPhone'] as String?,
      shopAddress: json['shopAddress'] as String?,
      branchId: json['branchId'] as String? ?? 'main',
      branchName: json['branchName'] as String? ?? 'الفرع الرئيسي',
    );
  }

  /// Creates a [TicketModel] from a domain [TicketEntity].
  factory TicketModel.fromEntity(TicketEntity entity) {
    return TicketModel(
      id: entity.id,
      ticketNumber: entity.ticketNumber,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      deviceType: entity.deviceType,
      deviceModel: entity.deviceModel,
      issueDescription: entity.issueDescription,
      estimatedCost: entity.estimatedCost,
      deposit: entity.deposit,
      partsCost: entity.partsCost,
      partsWholesaleCost: entity.partsWholesaleCost,
      partsDescription: entity.partsDescription,
      status: entity.status,
      statusHistory: entity.statusHistory,
      createdAt: entity.createdAt,
      technicianName: entity.technicianName,
      shelfLocation: entity.shelfLocation,
      serialNumber: entity.serialNumber,
      imageUrl: entity.imageUrl,
      images: entity.images,
      afterRepairImages: entity.afterRepairImages,
      sendWhatsAppLink: entity.sendWhatsAppLink,
      shopId: entity.shopId,
      customerId: entity.customerId,
      shopName: entity.shopName,
      shopPhone: entity.shopPhone,
      shopAddress: entity.shopAddress,
      branchId: entity.branchId,
      branchName: entity.branchName,
    );
  }

  /// Creates a [TicketModel] from a generic key-value map.
  factory TicketModel.fromMap(Map<String, dynamic> map) {
    final docId = map['id'] as String? ?? '';
    return TicketModel.fromJson(map, docId);
  }

  /// Converts this model into a map containing the id.
  Map<String, dynamic> toMap() {
    final map = toJson();
    map['id'] = id;
    return map;
  }

  /// Returns this instance as a pure domain [TicketEntity].
  TicketEntity toEntity() => this;


  /// Serializes to a Firestore-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'ticketNumber': ticketNumber,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deviceType': deviceType.name,
      'deviceModel': deviceModel,
      'issueDescription': issueDescription,
      'estimatedCost': estimatedCost,
      'deposit': deposit,
      'partsCost': partsCost,
      'partsWholesaleCost': partsWholesaleCost,
      'partsDescription': partsDescription,
      'status': status.value,
      'statusHistory': statusHistory
          .map((e) => {
                'status': e.status.value,
                'timestamp': e.timestamp.toIso8601String(),
                'note': e.note,
                'technicianName': e.technicianName,
              })
          .toList(),
      'createdAt': createdAt.toIso8601String(),
      'technicianName': technicianName,
      'shelfLocation': shelfLocation,
      'serialNumber': serialNumber,
      'imageUrl': imageUrl ?? (images.isNotEmpty ? images.first : null),
      'image_url': imageUrl ?? (images.isNotEmpty ? images.first : null),
      'images': images,
      'afterRepairImages': afterRepairImages,
      'after_repair_images': afterRepairImages,
      'sendWhatsAppLink': sendWhatsAppLink,
      'shopId': shopId,
      'customerId': customerId,
      'shopName': shopName,
      'shopPhone': shopPhone,
      'shopAddress': shopAddress,
      'branchId': branchId,
      'branchName': branchName,
    };
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    // Firestore Timestamp — handled via toString fallback
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  static DeviceType _parseDeviceType(String? value) {
    switch (value) {
      case 'mobile':
        return DeviceType.mobile;
      case 'laptop':
        return DeviceType.laptop;
      case 'watch':
        return DeviceType.watch;
      case 'home':
        return DeviceType.home;
      default:
        return DeviceType.other;
    }
  }
}
