import 'package:equatable/equatable.dart';

/// Entity representing a physical shop branch in the Tarmeem system.
class BranchEntity extends Equatable {
  const BranchEntity({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.pin,
    this.address,
    this.isMain = false,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final String name;
  final String? phone;
  final String? pin;
  final String? address;
  final bool isMain;
  final bool isActive;
  final DateTime? createdAt;

  factory BranchEntity.fromJson(Map<String, dynamic> json, String docId) {
    return BranchEntity(
      id: docId,
      shopId: json['shopId'] as String? ?? '',
      name: json['name'] as String? ?? 'فرع بدون اسم',
      phone: json['phone'] as String?,
      pin: (json['pin'] ?? json['password'])?.toString(),
      address: json['address'] as String?,
      isMain: json['isMain'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  factory BranchEntity.fromEntity(BranchEntity entity) => entity;

  Map<String, dynamic> toJson() {
    return {
      'shopId': shopId,
      'name': name,
      'phone': phone,
      'pin': pin,
      'address': address,
      'isMain': isMain,
      'isActive': isActive,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  BranchEntity copyWith({
    String? id,
    String? shopId,
    String? name,
    String? phone,
    String? pin,
    String? address,
    bool? isMain,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return BranchEntity(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      pin: pin ?? this.pin,
      address: address ?? this.address,
      isMain: isMain ?? this.isMain,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        shopId,
        name,
        phone,
        pin,
        address,
        isMain,
        isActive,
        createdAt,
      ];
}
