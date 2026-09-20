import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../data/branch_model.dart';

class BranchesState extends Equatable {
  const BranchesState({
    this.branches = const [],
    this.activeBranch,
    this.isLoading = false,
    this.error,
  });

  final List<BranchEntity> branches;
  final BranchEntity? activeBranch;
  final bool isLoading;
  final String? error;

  BranchesState copyWith({
    List<BranchEntity>? branches,
    BranchEntity? activeBranch,
    bool clearActiveBranch = false,
    bool? isLoading,
    String? error,
  }) {
    return BranchesState(
      branches: branches ?? this.branches,
      activeBranch: clearActiveBranch ? null : (activeBranch ?? this.activeBranch),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [branches, activeBranch, isLoading, error];
}

class BranchesCubit extends Cubit<BranchesState> {
  BranchesCubit() : super(const BranchesState());

  CollectionReference<Map<String, dynamic>> _branchesCol(String shopId) =>
      FirebaseFirestore.instance.collection('shops').doc(shopId).collection('branches');

  /// Loads branches for the active shop.
  Future<void> loadBranches() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString(AppConstants.prefShopId);
      final shopName = prefs.getString('current_shop_name') ?? prefs.getString(AppConstants.prefShopName) ?? 'المحل الرئيسي';
      final shopPhone = prefs.getString('current_shop_phone') ?? prefs.getString(AppConstants.prefShopPhone);
      final shopAddress = prefs.getString(AppConstants.prefShopAddress);

      if (shopId == null || shopId.isEmpty) {
        // Fallback single main branch
        final mainBranch = BranchEntity(
          id: 'main',
          shopId: 'default',
          name: 'الفرع الرئيسي',
          phone: shopPhone,
          address: shopAddress,
          isMain: true,
        );
        emit(state.copyWith(
          branches: [mainBranch],
          activeBranch: mainBranch,
          isLoading: false,
        ));
        return;
      }

      final snapshot = await _branchesCol(shopId).get();

      List<BranchEntity> list = snapshot.docs
          .map((doc) => BranchModel.fromJson(doc.data(), doc.id))
          .toList();

      if (list.isEmpty) {
        // Seed initial default main branch
        final mainModel = BranchModel(
          id: 'main',
          shopId: shopId,
          name: '$shopName (الرئيسي)',
          phone: shopPhone,
          address: shopAddress,
          isMain: true,
          isActive: true,
        );
        try {
          await _branchesCol(shopId).doc('main').set(mainModel.toJson());
        } catch (_) {}
        list = [mainModel];
      }

      final savedBranchId = prefs.getString('current_branch_id');
      BranchEntity active = list.firstWhere(
        (b) => b.id == savedBranchId,
        orElse: () => list.firstWhere((b) => b.isMain, orElse: () => list.first),
      );

      await prefs.setString('current_branch_id', active.id);
      await prefs.setString('current_branch_name', active.name);

      emit(state.copyWith(
        branches: list,
        activeBranch: active,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Sets the currently active branch in state and SharedPreferences (null for all branches).
  Future<void> selectBranch(BranchEntity? branch) async {
    final prefs = await SharedPreferences.getInstance();
    if (branch != null) {
      await prefs.setString('current_branch_id', branch.id);
      await prefs.setString('current_branch_name', branch.name);
      emit(state.copyWith(activeBranch: branch, clearActiveBranch: false));
    } else {
      await prefs.remove('current_branch_id');
      await prefs.remove('current_branch_name');
      emit(state.copyWith(clearActiveBranch: true));
    }
  }

  /// Creates a new branch for the shop with optional login PIN.
  Future<bool> addBranch({
    required String name,
    String? phone,
    String? pin,
    String? address,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString(AppConstants.prefShopId);
      if (shopId == null || shopId.isEmpty) return false;

      final docRef = _branchesCol(shopId).doc();
      String? cleanPhone;
      if (phone != null && phone.trim().isNotEmpty) {
        cleanPhone = phone.trim().replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
        if (cleanPhone.startsWith('20') && cleanPhone.length > 10) {
          cleanPhone = '0${cleanPhone.substring(2)}';
        } else if (!cleanPhone.startsWith('0') && cleanPhone.length == 10) {
          cleanPhone = '0$cleanPhone';
        }
      }

      final cleanPin = pin?.trim();

      // Check PIN conflict with owner password or existing branches
      if (cleanPin != null && cleanPin.isNotEmpty) {
        final ownerPass = prefs.getString('shop_pass_$shopId');
        if (ownerPass != null && ownerPass.trim() == cleanPin) {
          emit(state.copyWith(error: 'يرجى اختيار رمز PIN للفرع مختلف عن الرقم السري للمالك لتحديد هوية الدخول بدقة'));
          return false;
        }

        for (final existingBranch in state.branches) {
          if (existingBranch.pin != null && existingBranch.pin!.trim() == cleanPin) {
            emit(state.copyWith(error: 'رمز الدخول (PIN) مستخدم بالفعل لـ "${existingBranch.name}"، يرجى اختيار رمز مختلف'));
            return false;
          }
        }
      }

      final model = BranchModel(
        id: docRef.id,
        shopId: shopId,
        name: name.trim(),
        phone: cleanPhone,
        pin: cleanPin,
        address: address?.trim(),
        isMain: false,
        isActive: true,
      );

      await docRef.set(model.toJson());

      // If phone is distinct from shopId, register direct branch login index in /branch_logins/{cleanPhone}
      if (cleanPhone != null && cleanPhone.isNotEmpty && cleanPhone != shopId && cleanPin != null && cleanPin.isNotEmpty) {
        final shopName = prefs.getString(AppConstants.prefShopName) ?? 'الورشة الرئيسية';
        try {
          await FirebaseFirestore.instance.collection('branch_logins').doc(cleanPhone).set({
            'shopId': shopId,
            'branchId': docRef.id,
            'branchName': name.trim(),
            'shopName': shopName,
            'phone': cleanPhone,
            'pin': cleanPin,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('branch_logins register error: $e');
        }
      }

      await loadBranches();
      return true;
    } catch (e) {
      emit(state.copyWith(error: 'خطأ في إضافة الفرع: $e'));
      return false;
    }
  }
}
