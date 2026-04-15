import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.local.dart';

class AppConfig {
  static const String supabaseUrl = AppConfigLocal.supabaseUrl;
  static const String supabaseAnonKey = AppConfigLocal.supabaseAnonKey;
  static const String appVersion = 'v1.0.0';
  static const String appCredit = 'Developed for the Airsoft community.';

  static Future<void> initializeSupabase() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}