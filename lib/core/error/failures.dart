import 'package:equatable/equatable.dart';

/// Base class for all failure representations in the application.
abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Network/connectivity failure (e.g. device is offline).
class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'لا يوجد اتصال بالإنترنت، تم حفظ البيانات محلياً وسيتم المزامنة تلقائياً.',
  ]);
}

/// Server or database failure (e.g. Firebase or Supabase error).
class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'حدث خطأ في الخادم السحابي، يرجى المحاولة لاحقاً.',
  ]);
}

/// Local cache / persistence failure.
class CacheFailure extends Failure {
  const CacheFailure([
    super.message = 'تعذر قراءة أو حفظ البيانات على ذاكرة الجهاز.',
  ]);
}

/// Authentication or authorization failure.
class AuthFailure extends Failure {
  const AuthFailure([
    super.message = 'خطأ في المصادقة، يرجى إعادة تسجيل الدخول.',
  ]);
}

/// Input validation failure.
class ValidationFailure extends Failure {
  const ValidationFailure([
    super.message = 'البيانات المدخلة غير صحيحة، يرجى التأكد وإعادة المحاولة.',
  ]);
}

/// Subscription or trial expired failure.
class SubscriptionFailure extends Failure {
  const SubscriptionFailure([
    super.message = 'انتهت الفترة التجريبية للورشة، يرجى الاشتراك لمتابعة العمل.',
  ]);
}
