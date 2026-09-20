import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

class SubscriptionState extends Equatable {
  const SubscriptionState({
    required this.isLicensed,
    required this.isTrial,
    required this.isExpired,
    required this.trialDaysRemaining,
    this.planName = 'نسخة تجريبية مجانية',
    this.errorMessage,
    this.successMessage,
  });

  final bool isLicensed;
  final bool isTrial;
  final bool isExpired;
  final int trialDaysRemaining;
  final String planName;
  final String? errorMessage;
  final String? successMessage;

  SubscriptionState copyWith({
    bool? isLicensed,
    bool? isTrial,
    bool? isExpired,
    int? trialDaysRemaining,
    String? planName,
    String? errorMessage,
    String? successMessage,
  }) {
    return SubscriptionState(
      isLicensed: isLicensed ?? this.isLicensed,
      isTrial: isTrial ?? this.isTrial,
      isExpired: isExpired ?? this.isExpired,
      trialDaysRemaining: trialDaysRemaining ?? this.trialDaysRemaining,
      planName: planName ?? this.planName,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        isLicensed,
        isTrial,
        isExpired,
        trialDaysRemaining,
        planName,
        errorMessage,
        successMessage,
      ];
}

class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit()
      : super(const SubscriptionState(
          isLicensed: false,
          isTrial: true,
          isExpired: false,
          trialDaysRemaining: 14,
        ));

  static const String _keyTrialStart = 'subscription_trial_start_v1';
  static const String _keyIsLicensed = 'subscription_is_licensed_v1';
  static const String _keyPlanName = 'subscription_plan_name_v1';
  static const int trialDurationDays = 14;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Loads current trial and license status from local storage, then syncs with Firestore cloud.
  Future<void> checkSubscription() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Initial local fast-load from cache
    final localIsLicensed = prefs.getBool(_keyIsLicensed) ?? false;
    final localPlanName = prefs.getString(_keyPlanName) ?? 'نسخة تجريبية مجانية';

    var startMillis = prefs.getInt(_keyTrialStart);
    if (startMillis == null) {
      startMillis = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_keyTrialStart, startMillis);
    }

    final startDate = DateTime.fromMillisecondsSinceEpoch(startMillis);
    final elapsedDays = DateTime.now().difference(startDate).inDays;
    final localRemaining = (trialDurationDays - elapsedDays).clamp(0, trialDurationDays);
    final localIsExpired = !localIsLicensed && localRemaining <= 0;

    emit(SubscriptionState(
      isLicensed: localIsLicensed,
      isTrial: !localIsLicensed && !localIsExpired,
      isExpired: localIsExpired,
      trialDaysRemaining: localRemaining,
      planName: localIsLicensed
          ? localPlanName
          : (localIsExpired ? 'انتهت الفترة التجريبية' : 'تجريبي (متبقي $localRemaining يوم)'),
    ));

    // 2. Cloud Firestore Real-time Sync
    try {
      final shopId = prefs.getString(AppConstants.prefShopId);
      if (shopId == null || shopId.isEmpty) return;

      final shopDocRef = _firestore.collection('shops').doc(shopId);
      final snapshot = await shopDocRef.get();

      if (snapshot.exists) {
        final data = snapshot.data();
        final sub = data?['subscription'] as Map<String, dynamic>?;

        if (sub != null) {
          final status = sub['status'] as String? ?? 'trial';
          final plan = sub['plan'] as String? ?? 'ترخيص الورشة';
          final expiresAtTs = sub['expiresAt'] as Timestamp?;
          final trialEndsAtTs = sub['trialEndsAt'] as Timestamp?;

          if (status == 'active') {
            bool stillValid = true;
            if (expiresAtTs != null) {
              stillValid = DateTime.now().isBefore(expiresAtTs.toDate());
            }
            if (stillValid) {
              await prefs.setBool(_keyIsLicensed, true);
              await prefs.setString(_keyPlanName, plan);
              emit(state.copyWith(
                isLicensed: true,
                isTrial: false,
                isExpired: false,
                trialDaysRemaining: 0,
                planName: plan,
              ));
              return;
            }
          }

          // Check cloud trial end timestamp
          if (trialEndsAtTs != null) {
            final trialEnd = trialEndsAtTs.toDate();
            final remainingHours = trialEnd.difference(DateTime.now()).inHours;
            final remainingDays = (remainingHours / 24).ceil().clamp(0, trialDurationDays);
            final cloudExpired = remainingHours <= 0;

            await prefs.setBool(_keyIsLicensed, false);
            emit(state.copyWith(
              isLicensed: false,
              isTrial: !cloudExpired,
              isExpired: cloudExpired,
              trialDaysRemaining: remainingDays,
              planName: cloudExpired ? 'انتهت الفترة التجريبية' : 'تجريبي (متبقي $remainingDays يوم)',
            ));
            return;
          }
        }
      } else {
        // Seed initial shop document with cloud trial
        final trialEnd = DateTime.now().add(const Duration(days: trialDurationDays));
        final shopName = prefs.getString(AppConstants.prefShopName) ?? 'ورشة صيانة جديدة';
        await shopDocRef.set({
          'shopName': shopName,
          'subscription': {
            'status': 'trial',
            'plan': 'نسخة تجريبية مجانية',
            'trialStartsAt': FieldValue.serverTimestamp(),
            'trialEndsAt': Timestamp.fromDate(trialEnd),
            'createdAt': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Cloud subscription sync error (using cached state): $e');
    }
  }

  /// Activates the app with a valid license key or promo code against Firestore cloud.
  Future<bool> activateKey(String rawKey) async {
    final key = rawKey.trim().toUpperCase();

    // Accepted fallback master license keys for offline / admin override:
    final masterKeys = [
      'TARMEEM-PRO-2026',
      'TARMEEM-LIFETIME',
      'TARMEEM-VIP',
      'FIXLY-2026',
      'TARMIM-EGYPT-PRO',
    ];

    final isMasterKey = masterKeys.contains(key) ||
        (key.startsWith('TRM-') && key.length >= 8);

    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString(AppConstants.prefShopId);

      // Check Firestore /license_keys/{key}
      final keyDocRef = _firestore.collection('license_keys').doc(key);
      final keySnap = await keyDocRef.get();

      if (keySnap.exists) {
        final keyData = keySnap.data()!;
        final isRedeemed = keyData['isRedeemed'] as bool? ?? false;
        if (isRedeemed) {
          emit(state.copyWith(
            errorMessage: 'تم استخدام كود الترخيص هذا مسبقاً على حساب آخر.',
            successMessage: null,
          ));
          return false;
        }

        final planName = keyData['planName'] as String? ?? 'ترخيص دائم للمحل (Pro)';

        // Redeem the key in Firestore
        await keyDocRef.update({
          'isRedeemed': true,
          'redeemedByShopId': shopId ?? 'unknown',
          'redeemedAt': FieldValue.serverTimestamp(),
        });

        // Update shop subscription in Firestore
        if (shopId != null && shopId.isNotEmpty) {
          await _firestore.collection('shops').doc(shopId).set({
            'subscription': {
              'status': 'active',
              'plan': planName,
              'licenseKey': key,
              'activatedAt': FieldValue.serverTimestamp(),
            },
          }, SetOptions(merge: true));
        }

        await prefs.setBool(_keyIsLicensed, true);
        await prefs.setString(_keyPlanName, planName);

        emit(state.copyWith(
          isLicensed: true,
          isTrial: false,
          isExpired: false,
          trialDaysRemaining: 0,
          planName: planName,
          successMessage: 'تم تفعيل ترخيص المحل بنجاح سحابياً! شكراً لانضمامك إلى تِرميم 💎',
          errorMessage: null,
        ));
        return true;
      } else if (isMasterKey) {
        const planName = 'ترخيص دائم للمحل (Pro)';
        if (shopId != null && shopId.isNotEmpty) {
          try {
            await _firestore.collection('shops').doc(shopId).set({
              'subscription': {
                'status': 'active',
                'plan': planName,
                'licenseKey': key,
                'activatedAt': FieldValue.serverTimestamp(),
              },
            }, SetOptions(merge: true));
          } catch (_) {}
        }

        await prefs.setBool(_keyIsLicensed, true);
        await prefs.setString(_keyPlanName, planName);

        emit(state.copyWith(
          isLicensed: true,
          isTrial: false,
          isExpired: false,
          trialDaysRemaining: 0,
          planName: planName,
          successMessage: 'تم تفعيل ترخيص المحل بنجاح! شكراً لانضمامك إلى تِرميم.',
          errorMessage: null,
        ));
        return true;
      } else {
        emit(state.copyWith(
          errorMessage: 'كود التفعيل غير صالح، يرجى التواصل مع إدارة التطبيق للحصول على ترخيص.',
          successMessage: null,
        ));
        return false;
      }
    } catch (e) {
      if (isMasterKey) {
        // Fallback local activation if offline
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyIsLicensed, true);
        await prefs.setString(_keyPlanName, 'ترخيص دائم للمحل (Pro)');

        emit(state.copyWith(
          isLicensed: true,
          isTrial: false,
          isExpired: false,
          trialDaysRemaining: 0,
          planName: 'ترخيص دائم للمحل (Pro)',
          successMessage: 'تم تفعيل ترخيص المحل بنجاح! شكراً لانضمامك إلى تِرميم.',
          errorMessage: null,
        ));
        return true;
      }
      emit(state.copyWith(
        errorMessage: 'حدث خطأ أثناء التحقق من الترخيص: $e',
        successMessage: null,
      ));
      return false;
    }
  }
}

