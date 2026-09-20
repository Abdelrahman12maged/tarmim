/// Supabase configuration and client initialization.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  /// Placeholders to guard against unconfigured runs
  static const String placeholderUrl = 'https://your-project.supabase.co';
  static const String placeholderAnonKey = 'your-anon-key-here';

  /// Compile-time environment credentials or safe placeholders
  static const String defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: placeholderUrl,
  );
  static const String defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: placeholderAnonKey,
  );
  static const String defaultPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );
  static const String defaultBucket = String.fromEnvironment(
    'SUPABASE_BUCKET',
    defaultValue: 'ticket-images',
  );

  /// SharedPreferences storage keys
  static const String prefUrlKey = 'pref_supabase_url';
  static const String prefAnonKey = 'pref_supabase_anon_key';
  static const String prefBucketKey = 'pref_supabase_bucket';

  static String _activeUrl = defaultUrl;
  static String _activeAnonKey = defaultAnonKey;
  static String _activeBucket = defaultBucket;

  static SupabaseClient? _customClient;
  static bool _isInitialized = false;

  /// Getters for active values
  static String get activeUrl => _activeUrl;
  static String get activeAnonKey => _activeAnonKey;
  static String get activeBucket => _activeBucket;
  static bool get isInitialized => _isInitialized || _customClient != null;

  /// Checks if valid credentials have been set.
  static bool get isConfigured =>
      _activeUrl.trim().isNotEmpty &&
      _activeUrl != placeholderUrl &&
      _activeUrl.startsWith('http') &&
      _activeAnonKey.trim().isNotEmpty &&
      _activeAnonKey != placeholderAnonKey;

  /// Loads configuration from [SharedPreferences] and initializes Supabase client.
  static Future<bool> initialize({SharedPreferences? prefs}) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final savedUrl = p.getString(prefUrlKey)?.trim();
      final savedKey = p.getString(prefAnonKey)?.trim();
      final savedBucket = p.getString(prefBucketKey)?.trim();

      if (savedUrl != null && savedUrl.isNotEmpty && savedUrl != placeholderUrl) {
        _activeUrl = savedUrl;
      } else {
        _activeUrl = defaultUrl;
      }

      if (savedKey != null && savedKey.isNotEmpty && savedKey != placeholderAnonKey) {
        _activeAnonKey = savedKey;
      } else {
        _activeAnonKey = defaultAnonKey;
      }

      if (savedBucket != null && savedBucket.isNotEmpty) {
        _activeBucket = savedBucket;
      } else {
        _activeBucket = defaultBucket;
      }

      if (!isConfigured) {
        debugPrint(
          'Supabase is not configured yet with valid project credentials. '
          'Images will use local storage / fallback until configured in Settings.',
        );
        return false;
      }

      // Initialize Supabase singleton
      try {
        await Supabase.initialize(
          url: _activeUrl,
          anonKey: _activeAnonKey,
        );
        _isInitialized = true;
        debugPrint('Supabase initialized successfully via singleton.');
        return true;
      } catch (e) {
        debugPrint('Supabase.initialize warning (may already be initialized): $e');
        // Fallback to standalone client if singleton was already initialized
        _customClient = SupabaseClient(_activeUrl, _activeAnonKey);
        _isInitialized = true;
        return true;
      }
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      return false;
    }
  }

  /// Updates credentials, saves them to SharedPreferences, and reinitializes client.
  static Future<bool> updateCredentials({
    required String url,
    required String anonKey,
    String? bucket,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final cleanUrl = url.trim();
    final cleanKey = anonKey.trim();
    final cleanBucket = (bucket != null && bucket.trim().isNotEmpty)
        ? bucket.trim()
        : defaultBucket;

    await p.setString(prefUrlKey, cleanUrl);
    await p.setString(prefAnonKey, cleanKey);
    await p.setString(prefBucketKey, cleanBucket);

    _activeUrl = cleanUrl;
    _activeAnonKey = cleanKey;
    _activeBucket = cleanBucket;

    if (!isConfigured) {
      _customClient = null;
      _isInitialized = false;
      return false;
    }

    try {
      _customClient = SupabaseClient(_activeUrl, _activeAnonKey);
      _isInitialized = true;
      debugPrint('Supabase client updated and reconnected successfully.');
      return true;
    } catch (e) {
      debugPrint('Error updating Supabase client: $e');
      return false;
    }
  }

  /// Safe accessor to the client. Returns null if not configured/initialized.
  static SupabaseClient? get clientSafe {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Primary client accessor.
  static SupabaseClient get client {
    if (_customClient != null) return _customClient!;
    return Supabase.instance.client;
  }
}
