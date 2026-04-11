import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app/localization/app_localizations.dart';
import '../app/router.dart';
import '../app/theme/app_theme.dart';

class AirsoftApp extends StatefulWidget {
  const AirsoftApp({super.key});

  @override
  State<AirsoftApp> createState() => _AirsoftAppState();
}

class _AirsoftAppState extends State<AirsoftApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  double _fontScale = 1.0;
  Locale _locale = const Locale('en');

  void _updateThemeMode(ThemeMode value) {
    setState(() {
      _themeMode = value;
    });
  }

  void _updateFontScale(double value) {
    setState(() {
      _fontScale = value;
    });
  }

  void _updateLocale(Locale value) {
    setState(() {
      _locale = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      themeMode: _themeMode,
      fontScale: _fontScale,
      locale: _locale,
      updateThemeMode: _updateThemeMode,
      updateFontScale: _updateFontScale,
      updateLocale: _updateLocale,
      child: MaterialApp(
        title: 'Airsoft App',
        debugShowCheckedModeBanner: false,
        locale: _locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(fontScale: _fontScale),
        darkTheme: AppTheme.dark(fontScale: _fontScale),
        themeMode: _themeMode,
        initialRoute: AppRouter.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}

class AppStateScope extends InheritedWidget {
  const AppStateScope({
    super.key,
    required this.themeMode,
    required this.fontScale,
    required this.locale,
    required this.updateThemeMode,
    required this.updateFontScale,
    required this.updateLocale,
    required super.child,
  });

  final ThemeMode themeMode;
  final double fontScale;
  final Locale locale;
  final ValueChanged<ThemeMode> updateThemeMode;
  final ValueChanged<double> updateFontScale;
  final ValueChanged<Locale> updateLocale;

  static AppStateScope of(BuildContext context) {
    final AppStateScope? result =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(result != null, 'No AppStateScope found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(AppStateScope oldWidget) {
    return themeMode != oldWidget.themeMode ||
        fontScale != oldWidget.fontScale ||
        locale != oldWidget.locale;
  }
}
