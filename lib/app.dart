import 'package:flutter/material.dart';

import 'app/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';

class AirsoftApp extends StatefulWidget {
  const AirsoftApp({super.key});

  @override
  State<AirsoftApp> createState() => _AirsoftAppState();
}

class _AirsoftAppState extends State<AirsoftApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FieldOps',

      // FIX 1: Call theme functions properly
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),

      // FIX 2: themeMode belongs here (MaterialApp, not HomeScreen)
      themeMode: _themeMode,

      // FIX 3: Localization fix (no static delegates in your file)
      localizationsDelegates: AppLocalizations.delegates,
      supportedLocales: AppLocalizations.supportedLocales,

      debugShowCheckedModeBanner: false,

      // FIX 4: HomeScreen no longer takes themeMode
      home: AuthGate(
        onThemeChanged: _setThemeMode,
      ),
    );
  }
}
