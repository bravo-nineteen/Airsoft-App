import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';

class AirsoftApp extends StatefulWidget {
  const AirsoftApp({
    super.key,
    required this.navigatorKey,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<AirsoftApp> createState() => _AirsoftAppState();
}

class _AirsoftAppState extends State<AirsoftApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;

  void updateThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  void updateLocale(Locale? locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'FieldOps',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) {
          return supportedLocales.first;
        }

        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode) {
            return supported;
          }
        }

        return supportedLocales.first;
      },
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AuthGate(
        currentLocale: _locale,
        onLocaleChanged: updateLocale,
        currentThemeMode: _themeMode,
        onThemeModeChanged: updateThemeMode,
      ),
    );
  }
}
