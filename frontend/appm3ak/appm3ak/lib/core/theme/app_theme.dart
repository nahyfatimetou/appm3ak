import 'package:flutter/material.dart';

/// Thème Ma3ak : design bleu, lisible, adapté au handicap visuel.
/// Respect des ratios de contraste WCAG 4.5:1 minimum.
class AppTheme {
  AppTheme._();

  /// Bleu principal (maquettes Login / Inscription / Profil)
  static const Color _primary = Color(0xFF1976D2);
  static const Color _primaryDark = Color(0xFF1565C0);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _error = Color(0xFFB71C1C);
  static const Color _onPrimary = Colors.white;
  static const Color _onSurface = Color(0xFF212121);
  static const Color _onSurfaceVariant = Color(0xFF616161);
  static const Color _outline = Color(0xFF9E9E9E);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: _primary,
          onPrimary: _onPrimary,
          primaryContainer: Color(0xFFBBDEFB),
          onPrimaryContainer: _primaryDark,
          secondary: Color(0xFF0288D1),
          onSecondary: Colors.white,
          surface: _surface,
          onSurface: _onSurface,
          onSurfaceVariant: _onSurfaceVariant,
          error: _error,
          onError: Colors.white,
          outline: _outline,
        ),
        scaffoldBackgroundColor: _surface,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: _primary,
          foregroundColor: _onPrimary,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(88, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(88, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _error),
          ),
          labelStyle: const TextStyle(fontSize: 16),
          hintStyle: const TextStyle(fontSize: 16),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _onSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _onSurface,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: _onSurface),
          bodyMedium: TextStyle(fontSize: 14, color: _onSurface),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        fontFamily: 'Roboto',
      );

  /// Couleurs dark mode (maquettes)
  static const Color _darkScaffold = Color(0xFF000000);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkSurfaceVariant = Color(0xFF2C2C2C);
  static const Color _darkPrimary = Color(0xFF5DDDF9); // bleu clair accent
  static const Color _darkOnSurface = Color(0xFFFFFFFF);
  static const Color _darkOnSurfaceVariant = Color(0xFFB0B0B0);
  static const Color _darkOutline = Color(0xFF8E8E8E);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _darkPrimary,
          onPrimary: Color(0xFF000000),
          primaryContainer: _primaryDark,
          onPrimaryContainer: Colors.white,
          secondary: Color(0xFF4DB6AC),
          onSecondary: Colors.black,
          surface: _darkSurface,
          onSurface: _darkOnSurface,
          surfaceContainerHighest: _darkSurfaceVariant,
          onSurfaceVariant: _darkOnSurfaceVariant,
          error: Color(0xFFCF6679),
          onError: Colors.black,
          outline: _darkOutline,
        ),
        scaffoldBackgroundColor: _darkScaffold,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: _darkSurface,
          foregroundColor: _darkOnSurface,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(88, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(88, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _darkSurfaceVariant,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _darkOutline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _darkOutline),
          ),
          labelStyle: const TextStyle(fontSize: 16, color: _darkOnSurface),
          hintStyle: const TextStyle(fontSize: 16, color: _darkOnSurfaceVariant),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _darkOnSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _darkOnSurface,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: _darkOnSurface),
          bodyMedium: TextStyle(fontSize: 14, color: _darkOnSurface),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _darkOnSurface),
        ),
        fontFamily: 'Roboto',
      );
}
