import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_repository.dart';
import '../admin/banned_screen.dart';
import '../shell/airsoft_home_shell.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    this.currentLocale,
    this.onLocaleChanged,
    this.currentThemeMode,
    this.onThemeModeChanged,
  });

  final Locale? currentLocale;
  final ValueChanged<Locale?>? onLocaleChanged;
  final ThemeMode? currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        Supabase.instance.client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        if (session == null) {
          return const LoginScreen();
        }

        return FutureBuilder<AdminBanRecord?>(
          future: AdminRepository().getActiveBanForCurrentUser(),
          builder: (context, banSnapshot) {
            if (banSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (banSnapshot.data != null) {
              return BannedScreen(ban: banSnapshot.data!);
            }

            return AirsoftHomeShell(
              currentLocale: currentLocale,
              onLocaleChanged: onLocaleChanged,
              currentThemeMode: currentThemeMode,
              onThemeModeChanged: onThemeModeChanged,
            );
          },
        );
      },
    );
  }
}
