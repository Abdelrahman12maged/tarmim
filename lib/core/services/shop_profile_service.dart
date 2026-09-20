import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../di/injection.dart';

/// Data class holding the workshop / repair shop's public contact & business profile.
class ShopProfile {
  final String name;
  final String phone;
  final String address;
  final String hours;
  final String warranty;

  const ShopProfile({
    required this.name,
    required this.phone,
    required this.address,
    required this.hours,
    required this.warranty,
  });

  factory ShopProfile.defaults() {
    return const ShopProfile(
      name: AppConstants.defaultShopName,
      phone: AppConstants.defaultShopPhone,
      address: AppConstants.defaultShopAddress,
      hours: AppConstants.defaultShopHours,
      warranty: AppConstants.defaultShopWarranty,
    );
  }
}

/// Service managing the workshop's identity, contact information, and operating details.
class ShopProfileService {
  final SharedPreferences _prefs;

  ShopProfileService([SharedPreferences? prefs])
      : _prefs = prefs ?? getIt<SharedPreferences>();

  /// Returns current shop profile from preferences or defaults.
  ShopProfile getProfile() {
    final name = _prefs.getString(AppConstants.prefShopName) ?? AppConstants.defaultShopName;
    final phone = _prefs.getString(AppConstants.prefShopPhone) ?? AppConstants.defaultShopPhone;
    final address = _prefs.getString(AppConstants.prefShopAddress) ?? AppConstants.defaultShopAddress;
    final hours = _prefs.getString(AppConstants.prefShopHours) ?? AppConstants.defaultShopHours;
    final warranty = _prefs.getString(AppConstants.prefShopWarranty) ?? AppConstants.defaultShopWarranty;

    return ShopProfile(
      name: name.trim().isNotEmpty ? name.trim() : AppConstants.defaultShopName,
      phone: phone.trim().isNotEmpty ? phone.trim() : AppConstants.defaultShopPhone,
      address: address.trim().isNotEmpty ? address.trim() : AppConstants.defaultShopAddress,
      hours: hours.trim().isNotEmpty ? hours.trim() : AppConstants.defaultShopHours,
      warranty: warranty.trim().isNotEmpty ? warranty.trim() : AppConstants.defaultShopWarranty,
    );
  }

  /// Updates and persists the workshop's profile both locally and to Firestore.
  Future<void> saveProfile({
    required String name,
    required String phone,
    required String address,
    required String hours,
    required String warranty,
  }) async {
    await _prefs.setString(AppConstants.prefShopName, name.trim());
    await _prefs.setString(AppConstants.prefShopPhone, phone.trim());
    await _prefs.setString(AppConstants.prefShopAddress, address.trim());
    await _prefs.setString(AppConstants.prefShopHours, hours.trim());
    await _prefs.setString(AppConstants.prefShopWarranty, warranty.trim());

    // Also sync to Firestore under shops collection if possible
    try {
      final shopId = _prefs.getString(AppConstants.prefShopId) ?? phone.trim();
      if (shopId.isNotEmpty) {
        await FirebaseFirestore.instance.collection(AppConstants.shopsCollection).doc(shopId).set({
          'name': name.trim(),
          'phone': phone.trim(),
          'address': address.trim(),
          'hours': hours.trim(),
          'warranty': warranty.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('ShopProfile Firestore sync error: $e');
    }
  }
}
