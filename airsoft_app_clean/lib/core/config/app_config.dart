import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'Airsoft App';
  static const String appVersion = 'v1.0.0';
  static const String appCredit = 'Created by Nineteen - Airsoft Online Japan';

  // Replace these with your real Supabase project values.
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  static bool get hasValidSupabaseConfig {
    return supabaseUrl.startsWith('https://') &&
        !supabaseUrl.contains('YOUR_PROJECT') &&
        supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';
  }

  static Future<void> initializeSupabase() async {
    if (!hasValidSupabaseConfig) {
      return;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
