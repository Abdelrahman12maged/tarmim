/// Tarmeem (ترميم) — Repair Shop Ticket Management App
///
/// Entry point:
/// 1. Configures dependency injection
/// 2. Loads persisted theme
/// 3. Wraps app with BlocProviders and MaterialApp.router
/// 4. Sets RTL directionality and Arabic localization
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'core/di/injection.dart';
import 'core/network/supabase_client.dart';
import 'core/router/app_router.dart';
import 'core/services/native_sms_service.dart';
import 'core/services/shop_profile_service.dart';
import 'core/services/workshop_notification_service.dart';
import 'core/sync/sync_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/url_strategy.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/settings/presentation/theme_cubit.dart';
import 'features/subscription/presentation/subscription_cubit.dart';
import 'features/branches/presentation/branches_cubit.dart';
import 'features/tickets/presentation/tickets_cubit.dart';
import 'firebase_options.dart';

void main() async {
  configureAppUrlStrategy();
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Lock to portrait orientation on mobile devices
  if (!kIsWeb) {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (e) {
      debugPrint('Orientation lock error: $e');
    }
  }

  // Configure all dependencies
  configureDependencies();

  // Setup local SharedPreferences and register in GetIt
  final prefs = await SharedPreferences.getInstance();
  if (!getIt.isRegistered<SharedPreferences>()) {
    getIt.registerSingleton<SharedPreferences>(prefs);
  }

  // Initialize Supabase (loads persisted credentials if configured)
  await SupabaseConfig.initialize(prefs: prefs);

  // Setup local sync manager
  final syncManager = SyncManager(prefs)..init();
  if (!getIt.isRegistered<SyncManager>()) {
    getIt.registerSingleton<SyncManager>(syncManager);
  }

  // Register professional native SMS service
  final nativeSmsService = NativeSmsService(prefs);
  if (!getIt.isRegistered<NativeSmsService>()) {
    getIt.registerSingleton<NativeSmsService>(nativeSmsService);
  }


  // Register workshop profile service
  final shopProfileService = ShopProfileService(prefs);
  if (!getIt.isRegistered<ShopProfileService>()) {
    getIt.registerSingleton<ShopProfileService>(shopProfileService);
  }

  // Check subscription and trial state
  try {
    await getIt<SubscriptionCubit>().checkSubscription();
  } catch (e) {
    debugPrint('Subscription check error: $e');
  }

  // Load persisted theme
  try {
    await getIt<ThemeCubit>().loadTheme();
  } catch (e) {
    debugPrint('Theme load error: $e');
  }

  // Load branches
  try {
    await getIt<BranchesCubit>().loadBranches();
  } catch (e) {
    debugPrint('Branches load error: $e');
  }

  // Check saved user session
  try {
    await getIt<AuthCubit>().checkSession();
  } catch (e) {
    debugPrint('Auth check error: $e');
  }

  // Start loading tickets
  try {
    getIt<TicketsCubit>().loadTickets();
  } catch (e) {
    debugPrint('Tickets load error: $e');
  }

  // Initialize Workshop Notification Service & Schedule 3:00 AM Closing Recap
  if (!kIsWeb) {
    try {
      final notifService = WorkshopNotificationService();
      await notifService.init();
      // Pre-schedule daily closing recap at 3:00 AM & morning briefing at 10:00 AM
      await notifService.scheduleDailyClosingRecap(
        deliveredCount: 0,
        totalRevenue: 0,
        readyWaitingCount: 0,
      );
      await notifService.scheduleDailyMorningBriefing(
        inDiagnosisCount: 0,
        readyCount: 0,
      );
    } catch (e) {
      debugPrint('Notification service error: $e');
    }
  }

  // Remove native & web splash screen
  FlutterNativeSplash.remove();

  runApp(const TarmeemApp());
}

class TarmeemApp extends StatefulWidget {
  const TarmeemApp({super.key});

  @override
  State<TarmeemApp> createState() => _TarmeemAppState();
}

class _TarmeemAppState extends State<TarmeemApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildAppRouter(authCubit: getIt<AuthCubit>());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Global cubits accessible throughout the app
        BlocProvider.value(value: getIt<ThemeCubit>()),
        BlocProvider.value(value: getIt<AuthCubit>()),
        BlocProvider.value(value: getIt<BranchesCubit>()),
        BlocProvider.value(value: getIt<TicketsCubit>()),
        BlocProvider.value(value: getIt<SubscriptionCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            // ── App metadata ───────────────────────────────────────────
            title: 'ترميم',
            debugShowCheckedModeBanner: false,

            // ── Themes ────────────────────────────────────────────────
            theme: TarmeemTheme.light,
            darkTheme: TarmeemTheme.dark,
            themeMode: themeState.themeMode,

            // ── Localization / RTL ────────────────────────────────────
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [
              Locale('ar', 'EG'),
              Locale('ar', 'SA'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // ── Router ────────────────────────────────────────────────
            routerConfig: _router,

            // ── RTL wrapper ───────────────────────────────────────────
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
