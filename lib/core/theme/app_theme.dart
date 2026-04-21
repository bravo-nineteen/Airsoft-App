import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color darkBackground = Color(0xFF101513);
  static const Color darkSurface = Color(0xFF17201C);
  static const Color olive = Color(0xFF657153);
  static const Color sand = Color(0xFFD2C29A);
  static const Color oliveLight = Color(0xFF8A9A6B);

  static const Color lightBackground = Color(0xFFF3F1EA);
  static const Color lightSurface = Color(0xFFFFFFFF);

  static ThemeData dark({double fontScale = 1.0}) {
    final TextTheme base = Typography.material2021().white;
    final TextTheme textTheme = _scaledTextTheme(base, fontScale);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: olive,
        secondary: sand,
        surface: darkSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: sand,
          foregroundColor: Colors.black,
          elevation: 4,
          shadowColor: Colors.black54,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: oliveLight,
          foregroundColor: Colors.black,
          elevation: 5,
          shadowColor: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: sand,
          side: BorderSide(color: sand.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: sand,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 48,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: sand),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: olive,
        labelStyle: textTheme.bodyMedium ?? const TextStyle(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      textTheme: textTheme,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: sand,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static ThemeData light({double fontScale = 1.0}) {
    final TextTheme base = Typography.material2021().black;
    final TextTheme textTheme = _scaledTextTheme(
      base,
      fontScale,
    ).apply(
      bodyColor: const Color(0xFF1C231B),
      displayColor: const Color(0xFF1C231B),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: olive,
        secondary: sand,
        surface: lightSurface,
        onPrimary: Colors.white,
        onSecondary: Color(0xFF1C231B),
        onSurface: Color(0xFF1C231B),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: olive,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: olive,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: olive,
          side: const BorderSide(color: olive),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: olive,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: Color(0xFF1C231B),
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 48,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: olive),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurface,
        selectedColor: sand,
        labelStyle: textTheme.bodyMedium ?? const TextStyle(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      textTheme: textTheme,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: olive,
        unselectedItemColor: Colors.black54,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static ThemeData lightTheme({double fontScale = 1.0}) {
    return light(fontScale: fontScale);
  }

  static ThemeData darkTheme({double fontScale = 1.0}) {
    return dark(fontScale: fontScale);
  }

  static TextTheme _scaledTextTheme(TextTheme base, double scale) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontSize: 57 * scale),
      displayMedium: base.displayMedium?.copyWith(fontSize: 45 * scale),
      displaySmall: base.displaySmall?.copyWith(fontSize: 36 * scale),
      headlineLarge: base.headlineLarge?.copyWith(fontSize: 28 * scale),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 24 * scale),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 21 * scale),
      titleLarge: base.titleLarge?.copyWith(fontSize: 19 * scale),
      titleMedium: base.titleMedium?.copyWith(fontSize: 15 * scale),
      titleSmall: base.titleSmall?.copyWith(fontSize: 14 * scale),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16 * scale),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14 * scale),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12 * scale),
      labelLarge: base.labelLarge?.copyWith(fontSize: 14 * scale),
      labelMedium: base.labelMedium?.copyWith(fontSize: 12 * scale),
      labelSmall: base.labelSmall?.copyWith(fontSize: 11 * scale),
    );
  }
}
