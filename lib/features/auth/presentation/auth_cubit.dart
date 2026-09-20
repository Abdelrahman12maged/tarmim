/// Auth Cubit and state for login and registration flow.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

// ── State ─────────────────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.shopId,
    this.shopName,
    this.phone,
    this.branchId = 'main',
    this.branchName,
    this.isOwner = true,
  });

  final String shopId;
  final String? shopName;
  final String? phone;
  final String branchId;
  final String? branchName;
  final bool isOwner;

  AuthAuthenticated copyWith({
    String? shopId,
    String? shopName,
    String? phone,
    String? branchId,
    String? branchName,
    bool? isOwner,
  }) {
    return AuthAuthenticated(
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      phone: phone ?? this.phone,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      isOwner: isOwner ?? this.isOwner,
    );
  }

  @override
  List<Object?> get props => [shopId, shopName, phone, branchId, branchName, isOwner];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class AuthAccountNotFound extends AuthState {
  const AuthAccountNotFound({required this.phone});
  final String phone;
  @override
  List<Object?> get props => [phone];
}

// ── Cubit ─────────────────────────────────────────────────────────────────

/// Manages authentication and shop account registration with Firestore and SharedPreferences.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthUnauthenticated());

  /// Normalizes Egyptian phone number (e.g. 01012345678).
  static String normalizePhone(String raw) {
    var p = raw.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (p.startsWith('20') && p.length > 10) {
      p = '0${p.substring(2)}';
    } else if (!p.startsWith('0') && p.length == 10) {
      p = '0$p';
    }
    return p;
  }

  /// Checks if there is already a stored session.
  Future<void> checkSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedShopId = prefs.getString(AppConstants.prefShopId);
      final savedShopName = prefs.getString('current_shop_name');
      final savedPhone = prefs.getString('current_shop_phone');
      final savedBranchId = prefs.getString('current_branch_id') ?? 'main';
      final savedBranchName = prefs.getString('current_branch_name');
      final isOwner = prefs.getBool('is_shop_owner') ?? true;

      if (savedShopId != null && savedShopId.isNotEmpty) {
        emit(AuthAuthenticated(
          shopId: savedShopId,
          shopName: savedShopName,
          phone: savedPhone,
          branchId: savedBranchId,
          branchName: savedBranchName,
          isOwner: isOwner,
        ));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (_) {
      emit(const AuthUnauthenticated());
    }
  }

  /// Updates the active branch in AuthState (for owners switching branches).
  void updateActiveBranch({String? branchId, String? branchName}) {
    if (state is AuthAuthenticated) {
      final current = state as AuthAuthenticated;
      emit(current.copyWith(
        branchId: branchId ?? current.branchId,
        branchName: branchName ?? current.branchName,
      ));
    }
  }

  /// Logs in with phone number and password / secret code.
  Future<void> login({
    required String phone,
    required String password,
  }) async {
    final cleanPhone = normalizePhone(phone);
    final cleanPass = password.trim();

    if (cleanPhone.length < 10) {
      emit(const AuthError('يرجى إدخال رقم هاتف مصري صحيح (11 رقم)'));
      return;
    }
    if (cleanPass.length < 4) {
      emit(const AuthError('الرقم السري يجب أن يكون 4 خانات على الأقل'));
      return;
    }

    emit(const AuthLoading());

    try {
      // 1. Check if this is the Shop Owner (Main Branch)
      DocumentSnapshot<Map<String, dynamic>>? shopDoc;
      try {
        shopDoc = await FirebaseFirestore.instance
            .collection('shops')
            .doc(cleanPhone)
            .get();
      } catch (e) {
        debugPrint('Firestore shop fetch error: $e');
      }

      if (shopDoc != null && shopDoc.exists && shopDoc.data() != null) {
        final data = shopDoc.data()!;
        final savedPass = (data['password'] ?? data['pin'] ?? '').toString();

        // 1.a) Check if the user entered the Shop Owner's password
        if (savedPass == cleanPass) {
          final shopName = data['shopName'] as String? ?? 'ورشة الصيانة';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_shop_owner', true);
          await _saveSession(cleanPhone, shopName, cleanPhone);
          emit(AuthAuthenticated(
            shopId: cleanPhone,
            shopName: shopName,
            phone: cleanPhone,
            branchId: 'main',
            branchName: '$shopName (الرئيسي)',
            isOwner: true,
          ));
          return;
        }

        // 1.b) If password doesn't match owner, check if this PIN matches any Sub-Branch of this shop!
        try {
          final branchesSnapshot = await FirebaseFirestore.instance
              .collection('shops')
              .doc(cleanPhone)
              .collection('branches')
              .get();

          for (final branchDoc in branchesSnapshot.docs) {
            final bData = branchDoc.data();
            final branchPin = (bData['pin'] ?? bData['password'] ?? '').toString().trim();
            if (branchPin.isNotEmpty && branchPin == cleanPass) {
              final branchId = branchDoc.id;
              final branchName = bData['name'] as String? ?? 'فرع تابع';
              final shopName = data['shopName'] as String? ?? 'ورشة الصيانة';

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(AppConstants.prefShopId, cleanPhone);
              await prefs.setString(AppConstants.prefShopName, shopName);
              await prefs.setString(AppConstants.prefShopPhone, cleanPhone);
              await prefs.setString('current_shop_name', shopName);
              await prefs.setString('current_shop_phone', cleanPhone);
              await prefs.setString('current_branch_id', branchId);
              await prefs.setString('current_branch_name', branchName);
              await prefs.setBool('is_shop_owner', false);

              emit(AuthAuthenticated(
                shopId: cleanPhone,
                shopName: shopName,
                phone: cleanPhone,
                branchId: branchId,
                branchName: branchName,
                isOwner: false,
              ));
              return;
            }
          }
        } catch (e) {
          debugPrint('Sub-branch PIN lookup error: $e');
        }

        // Neither owner password nor any branch PIN matched
        emit(const AuthError('الرقم السري غير صحيح، يرجى المحاولة مجدداً'));
        return;
      }

      // 2. Check if this is a Sub-Branch Login
      DocumentSnapshot<Map<String, dynamic>>? branchDoc;
      try {
        branchDoc = await FirebaseFirestore.instance
            .collection('branch_logins')
            .doc(cleanPhone)
            .get();
      } catch (e) {
        debugPrint('Firestore branch login fetch error: $e');
      }

      if (branchDoc != null && branchDoc.exists && branchDoc.data() != null) {
        final bData = branchDoc.data()!;
        final savedPin = (bData['pin'] ?? bData['password'] ?? '').toString();
        if (savedPin == cleanPass) {
          final parentShopId = bData['shopId'] as String? ?? '';
          final branchId = bData['branchId'] as String? ?? 'main';
          final branchName = bData['branchName'] as String? ?? 'فرع تابع';
          final shopName = bData['shopName'] as String? ?? 'ورشة الصيانة';

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.prefShopId, parentShopId);
          await prefs.setString(AppConstants.prefShopName, shopName);
          await prefs.setString(AppConstants.prefShopPhone, cleanPhone);
          await prefs.setString('current_shop_name', shopName);
          await prefs.setString('current_shop_phone', cleanPhone);
          await prefs.setString('current_branch_id', branchId);
          await prefs.setString('current_branch_name', branchName);
          await prefs.setBool('is_shop_owner', false);

          emit(AuthAuthenticated(
            shopId: parentShopId,
            shopName: shopName,
            phone: cleanPhone,
            branchId: branchId,
            branchName: branchName,
            isOwner: false,
          ));
          return;
        } else {
          emit(const AuthError('الرقم السري الخاص بالفرع غير صحيح، يرجى مراجعة إدارة المحل'));
          return;
        }
      }

      // 3. Check local storage fallback (offline mode)
      final prefs = await SharedPreferences.getInstance();
      final localPass = prefs.getString('shop_pass_$cleanPhone');
      if (localPass != null) {
        if (localPass == cleanPass) {
          final shopName = prefs.getString('shop_name_$cleanPhone') ?? 'ورشة الصيانة';
          await prefs.setBool('is_shop_owner', true);
          await _saveSession(cleanPhone, shopName, cleanPhone);
          emit(AuthAuthenticated(
            shopId: cleanPhone,
            shopName: shopName,
            phone: cleanPhone,
            branchId: 'main',
            isOwner: true,
          ));
          return;
        } else {
          emit(const AuthError('الرقم السري غير صحيح، يرجى المحاولة مجدداً'));
          return;
        }
      }

      // 4. If account doesn't exist anywhere, notify UI
      emit(AuthAccountNotFound(phone: cleanPhone));
    } catch (e) {
      emit(AuthError('حدث خطأ أثناء تسجيل الدخول: $e'));
    }
  }

  /// Registers a new shop account with phone number, password, and shop name.
  Future<void> register({
    required String phone,
    required String password,
    required String shopName,
  }) async {
    final cleanPhone = normalizePhone(phone);
    final cleanPass = password.trim();
    final cleanName = shopName.trim().isNotEmpty ? shopName.trim() : 'ورشة $cleanPhone';

    if (cleanPhone.length < 10) {
      emit(const AuthError('يرجى إدخال رقم هاتف مصري صحيح (11 رقم)'));
      return;
    }
    if (cleanPass.length < 4) {
      emit(const AuthError('الرقم السري يجب أن يكون 4 خانات على الأقل'));
      return;
    }

    emit(const AuthLoading());

    try {
      // 1. Guard against overwriting an existing workshop account
      try {
        final existingDoc = await FirebaseFirestore.instance
            .collection('shops')
            .doc(cleanPhone)
            .get();

        if (existingDoc.exists && existingDoc.data() != null) {
          emit(AuthError('رقم الهاتف ($cleanPhone) مسجل بالفعل باسم ورشة أخرى. يرجى الانتقال إلى «تسجيل الدخول» أو التواصل مع الدعم.'));
          return;
        }
      } catch (e) {
        debugPrint('Firestore existing check error: $e');
      }

      // 2. Comprehensive Provisioning for new workshop
      await _provisionNewShop(cleanPhone, cleanPass, cleanName);
      await _saveSession(cleanPhone, cleanName, cleanPhone);

      emit(AuthAuthenticated(
        shopId: cleanPhone,
        shopName: cleanName,
        phone: cleanPhone,
      ));
    } catch (e) {
      emit(AuthError('حدث خطأ أثناء إنشاء حساب الورشة: $e'));
    }
  }

  Future<void> _provisionNewShop(
    String phone,
    String password,
    String shopName,
  ) async {
    final trialEnd = DateTime.now().add(const Duration(days: 14));
    final shopDocRef = FirebaseFirestore.instance.collection('shops').doc(phone);

    // Save shop master document with cloud trial info
    try {
      await shopDocRef.set({
        'shopId': phone,
        'phone': phone,
        'password': password,
        'shopName': shopName,
        'createdAt': FieldValue.serverTimestamp(),
        'subscription': {
          'status': 'trial',
          'plan': 'نسخة تجريبية مجانية',
          'trialStartsAt': FieldValue.serverTimestamp(),
          'trialEndsAt': Timestamp.fromDate(trialEnd),
          'createdAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      // Provision initial default main branch
      await shopDocRef.collection('branches').doc('main').set({
        'shopId': phone,
        'name': '$shopName (الرئيسي)',
        'phone': phone,
        'isMain': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore provision shop error: $e');
    }

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_pass_$phone', password);
    await prefs.setString('shop_name_$phone', shopName);
    await prefs.setInt('subscription_trial_start_v1', DateTime.now().millisecondsSinceEpoch);
    await prefs.setBool('subscription_is_licensed_v1', false);
    await prefs.setString('current_branch_id', 'main');
    await prefs.setString('current_branch_name', '$shopName (الرئيسي)');
  }

  Future<void> _saveSession(String shopId, String shopName, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefShopId, shopId);
    await prefs.setString(AppConstants.prefShopName, shopName);
    await prefs.setString(AppConstants.prefShopPhone, phone);
    await prefs.setString('current_shop_name', shopName);
    await prefs.setString('current_shop_phone', phone);
    if (!prefs.containsKey('current_branch_id')) {
      await prefs.setString('current_branch_id', 'main');
      await prefs.setString('current_branch_name', '$shopName (الرئيسي)');
    }
  }

  /// Logs out and clears stored session.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefShopId);
    await prefs.remove(AppConstants.prefShopName);
    await prefs.remove(AppConstants.prefShopPhone);
    await prefs.remove('current_shop_name');
    await prefs.remove('current_shop_phone');
    await prefs.remove('current_branch_id');
    await prefs.remove('current_branch_name');
    await prefs.remove('is_shop_owner');
    emit(const AuthUnauthenticated());
  }
}
