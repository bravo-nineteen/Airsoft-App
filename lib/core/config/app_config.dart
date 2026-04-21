import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.local.dart';

class AppConfig {
  static const String supabaseUrl = AppConfigLocal.supabaseUrl;
  static const String supabaseAnonKey = AppConfigLocal.supabaseAnonKey;
  static const String appCredit = 'Developed for the Airsoft community.';

  static Future<void> initializeSupabase() async {
    final hasPlaceholderUrl =
        supabaseUrl.contains('YOUR_PROJECT') ||
        supabaseUrl.trim().isEmpty;
    final hasPlaceholderKey =
        supabaseAnonKey.contains('YOUR_REAL_ANON_KEY') ||
        supabaseAnonKey.trim().isEmpty;

    if (hasPlaceholderUrl || hasPlaceholderKey) {
      throw StateError(
        'Supabase is not configured. Update lib/core/config/app_config.local.dart with your project URL and anon key.',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}