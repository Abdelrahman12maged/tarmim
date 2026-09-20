/// App router — GoRouter configuration with persistent StatefulShellRoute.
///
/// Auth-guarded routes redirect to /login if not authenticated.
/// The /track/:ticketId route is PUBLIC (no auth guard).
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/tickets/presentation/home_screen.dart';
import '../../features/tickets/presentation/new_ticket_screen.dart';
import '../../features/tickets/presentation/ticket_detail_screen.dart';
import '../../features/tickets/presentation/new_ticket_cubit.dart';
import '../../features/tickets/presentation/tickets_cubit.dart';
import '../../features/customers/presentation/customer_profile_screen.dart';
import '../../features/customers/presentation/customers_list_screen.dart';
import '../../features/customers/presentation/customer_cubit.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/subscription/presentation/subscription_paywall_screen.dart';
import '../../features/tracking/presentation/customer_portal_lookup_screen.dart';
import '../../features/tracking/presentation/tracking_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/sms_settings_screen.dart';
import '../../features/settings/presentation/supabase_settings_screen.dart';
import '../../features/settings/presentation/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/branches/presentation/branch_management_screen.dart';
import '../../features/branches/presentation/branches_cubit.dart';
import '../widgets/main_scaffold.dart';
import '../di/injection.dart';

/// Route name constants.
abstract class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String home = '/';
  static const String customers = '/customers';
  static const String dashboard = '/dashboard';
  static const String settings = '/settings';
  static const String smsSettings = '/settings/sms';
  static const String supabaseSettings = '/settings/supabase';
  static const String newTicket = '/ticket/new';
  static const String ticketDetail = '/ticket/:id';
  static const String customerProfile = '/customer/:phone';
  static const String tracking = '/track/:ticketId';
  static const String subscription = '/subscription';
  static const String branches = '/settings/branches';
}

/// Builds the app's [GoRouter].
///
/// On Web: Exclusively serves the customer tracking portal.
/// On Mobile: Serves the full workshop management app.
GoRouter buildAppRouter({required AuthCubit authCubit}) {
  if (kIsWeb) {
    String initialLoc = '/';
    try {
      final base = Uri.base;
      if (base.path.startsWith('/track')) {
        initialLoc = base.path;
      } else if (base.hasFragment && base.fragment.contains('/track')) {
        final frag = base.fragment.replaceAll('#', '');
        initialLoc = frag.startsWith('/') ? frag : '/$frag';
      }
    } catch (_) {}

    return GoRouter(
      initialLocation: initialLoc,
      redirect: (context, state) {
        final path = state.uri.path;
        if (path == '/' || path.startsWith('/track')) {
          return null;
        }
        return '/';
      },
      routes: [
        GoRoute(
          path: '/',
          name: 'customerPortal',
          builder: (context, state) => const CustomerPortalLookupScreen(),
        ),
        GoRoute(
          path: AppRoutes.tracking,
          name: 'tracking',
          builder: (context, state) {
            final ticketId = state.pathParameters['ticketId'] ?? '';
            return BlocProvider.value(
              value: getIt<TicketsCubit>(),
              child: TrackingScreen(ticketId: ticketId),
            );
          },
        ),
      ],
      errorBuilder: (context, state) => const CustomerPortalLookupScreen(),
    );
  }

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: _AuthListenable(authCubit),
    redirect: (context, state) {
      final isPublicRoute = state.uri.path.startsWith('/track');
      if (isPublicRoute) return null;

      final prefs = getIt<SharedPreferences>();
      final hasSeenOnboarding = OnboardingScreen.hasSeen(prefs);
      final isOnboardingRoute = state.uri.path == AppRoutes.onboarding;

      if (!hasSeenOnboarding && !isOnboardingRoute) {
        return AppRoutes.onboarding;
      }

      final isAuthenticated = authCubit.state is AuthAuthenticated;
      if (!isAuthenticated && !isOnboardingRoute && state.uri.path != AppRoutes.login) {
        return AppRoutes.login;
      }
      if (isAuthenticated && state.uri.path == AppRoutes.login) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      // ── Public routes ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => BlocProvider.value(
          value: authCubit,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.tracking,
        name: 'tracking',
        builder: (context, state) {
          final ticketId = state.pathParameters['ticketId'] ?? '';
          return BlocProvider.value(
            value: getIt<TicketsCubit>(),
            child: TrackingScreen(ticketId: ticketId),
          );
        },
      ),

      // ── Main Persistent Bottom Navigation Shell ─────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home (Tickets & Maintenance)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (context, state) => BlocProvider.value(
                  value: getIt<TicketsCubit>(),
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),

          // Branch 1: Customers
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.customers,
                name: 'customers',
                builder: (context, state) => BlocProvider.value(
                  value: getIt<TicketsCubit>(),
                  child: const CustomersListScreen(),
                ),
              ),
            ],
          ),

          // Branch 2: Dashboard & Reports (Replaces Items)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                name: 'dashboard',
                builder: (context, state) => BlocProvider.value(
                  value: getIt<TicketsCubit>(),
                  child: const DashboardScreen(),
                ),
              ),
            ],
          ),

          // Branch 3: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: 'settings',
                builder: (context, state) => MultiBlocProvider(
                  providers: [
                    BlocProvider.value(value: getIt<ThemeCubit>()),
                    BlocProvider.value(value: authCubit),
                  ],
                  child: const SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Detailed Push Screens (Outside shell with Back button) ──────
      GoRoute(
        path: AppRoutes.newTicket,
        name: 'newTicket',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final prefilledName = extra?['customerName'] as String?;
          final prefilledPhone = extra?['customerPhone'] as String?;
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) {
                  final cubit = getIt<NewTicketCubit>();
                  if (prefilledName != null && prefilledName.isNotEmpty) {
                    cubit.setCustomerName(prefilledName);
                  }
                  if (prefilledPhone != null && prefilledPhone.isNotEmpty) {
                    cubit.setCustomerPhone(prefilledPhone);
                  }
                  return cubit;
                },
              ),
            ],
            child: const NewTicketScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.ticketDetail,
        name: 'ticketDetail',
        builder: (context, state) {
          final ticketId = state.pathParameters['id'] ?? '';
          return BlocProvider.value(
            value: getIt<TicketsCubit>(),
            child: TicketDetailScreen(ticketId: ticketId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.customerProfile,
        name: 'customerProfile',
        builder: (context, state) {
          final phone = state.pathParameters['phone'] ?? '';
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => getIt<CustomerCubit>()),
            ],
            child: CustomerProfileScreen(customerPhone: phone),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.subscription,
        name: 'subscription',
        builder: (context, state) => const SubscriptionPaywallScreen(),
      ),
      GoRoute(
        path: AppRoutes.smsSettings,
        name: 'smsSettings',
        builder: (context, state) => const SmsSettingsScreen(),
      ),

      GoRoute(
        path: AppRoutes.supabaseSettings,
        name: 'supabaseSettings',
        builder: (context, state) => const SupabaseSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.branches,
        name: 'branches',
        builder: (context, state) => BlocProvider.value(
          value: getIt<BranchesCubit>(),
          child: const BranchManagementScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('الصفحة غير موجودة: ${state.uri}'),
      ),
    ),
  );
}

/// Listenable adapter to notify GoRouter when AuthCubit changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(AuthCubit cubit) {
    cubit.stream.listen((_) => notifyListeners());
  }
}
