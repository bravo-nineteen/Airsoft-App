import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_repository.dart';
import '../admin/banned_screen.dart';
import '../shell/airsoft_home_shell.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class AuthGate extends StatefulWidget {
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
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AdminRepository _adminRepository = AdminRepository();

  Session? _session;
  AdminBanRecord? _activeBan;
  String? _banLookupUserId;
  bool _isCheckingBan = false;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _refreshBanStatus();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final needed = await OnboardingScreen.needsOnboarding();
    if (!mounted) return;
    setState(() => _needsOnboarding = needed);
  }

  Future<void> _refreshBanStatus() async {
    final Session? session = _session;
    if (session == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeBan = null;
        _banLookupUserId = null;
        _isCheckingBan = false;
      });
      return;
    }

    final String userId = session.user.id;
    if (_isCheckingBan && _banLookupUserId == userId) {
      return;
    }

    setState(() {
      _banLookupUserId = userId;
      _isCheckingBan = true;
    });

    try {
      final AdminBanRecord? ban =
          await _adminRepository.getActiveBanForCurrentUser();
      if (!mounted || _session?.user.id != userId) {
        return;
      }

      setState(() {
        _activeBan = ban;
      });
    } catch (_) {
      if (!mounted || _session?.user.id != userId) {
        return;
      }

      setState(() {
        _activeBan = null;
      });
    } finally {
      if (mounted && _session?.user.id == userId) {
        setState(() {
          _isCheckingBan = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        Supabase.instance.client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final Session? session = snapshot.data?.session;

        if (_session?.user.id != session?.user.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _session = session;
              _activeBan = null;
              _banLookupUserId = session?.user.id;
              _needsOnboarding = false;
            });
            _refreshBanStatus();
            _checkOnboarding();
          });
        }

        if (session == null) {
          return const LoginScreen();
        }

        if (_activeBan != null) {
          return BannedScreen(ban: _activeBan!);
        }

        if (_needsOnboarding) {
          return OnboardingScreen(
            onComplete: () {
              if (mounted) setState(() => _needsOnboarding = false);
            },
          );
        }

        return Stack(
          children: <Widget>[
            AirsoftHomeShell(
              currentLocale: widget.currentLocale,
              onLocaleChanged: widget.onLocaleChanged,
              currentThemeMode: widget.currentThemeMode,
              onThemeModeChanged: widget.onThemeModeChanged,
            ),
            if (_isCheckingBan)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        );
      },
    );
  }
}
