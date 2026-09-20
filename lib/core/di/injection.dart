/// Dependency injection via get_it.
///
/// Register all data sources, repositories, use cases, and cubits here.
/// Import this file wherever service locator access is needed via [getIt].
import 'package:get_it/get_it.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/tickets/data/firebase_ticket_datasource.dart';
import '../../features/tickets/data/ticket_datasource.dart';
import '../../features/tickets/data/ticket_repository_impl.dart';
import '../../features/tickets/domain/ticket_repository.dart';
import '../../features/tickets/presentation/tickets_cubit.dart';
import '../../features/tickets/presentation/new_ticket_cubit.dart';
import '../../features/customers/presentation/customer_cubit.dart';
import '../../features/settings/presentation/theme_cubit.dart';
import '../../features/subscription/presentation/subscription_cubit.dart';
import '../../features/branches/presentation/branches_cubit.dart';
import '../services/supabase_storage_service.dart';

/// Global service locator instance.
final GetIt getIt = GetIt.instance;

/// Registers all dependencies.
///
/// Call this once in [main] before [runApp].
void configureDependencies() {
  // ── Services ────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<SupabaseStorageService>(
    () => SupabaseStorageService(),
  );

  // ── Data sources ───────────────────────────────────────────────────────
  // Registered with Firebase Cloud Firestore data source
  getIt.registerLazySingleton<TicketDataSource>(
    () => FirebaseTicketDataSource(),
  );

  // ── Repositories ───────────────────────────────────────────────────────
  getIt.registerLazySingleton<TicketRepository>(
    () => TicketRepositoryImpl(getIt<TicketDataSource>()),
  );

  // ── Cubits ─────────────────────────────────────────────────────────────
  // Auth — singleton so router can access it for redirect guard
  getIt.registerLazySingleton<AuthCubit>(() => AuthCubit());

  // Theme — singleton so it persists across navigation
  getIt.registerLazySingleton<ThemeCubit>(() => ThemeCubit());

  // Branches — singleton for multi-branch management
  getIt.registerLazySingleton<BranchesCubit>(() => BranchesCubit());

  // Tickets — singleton for live stream across screens
  getIt.registerLazySingleton<TicketsCubit>(
    () => TicketsCubit(getIt<TicketRepository>()),
  );

  // New ticket — factory so each new-ticket screen gets a fresh state
  getIt.registerFactory<NewTicketCubit>(
    () => NewTicketCubit(getIt<TicketRepository>()),
  );

  // Customer — factory so each customer screen gets a fresh state
  getIt.registerFactory<CustomerCubit>(
    () => CustomerCubit(getIt<TicketRepository>()),
  );

  // Subscription — singleton for trial and paywall tracking
  getIt.registerLazySingleton<SubscriptionCubit>(() => SubscriptionCubit());
}

