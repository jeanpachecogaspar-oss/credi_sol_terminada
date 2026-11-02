import 'package:flutter/material.dart';

class AppColors {
  static const Color azul = Color(0xFF1E88E5);
  static const Color azulOscuro = Color(0xFF1565C0);
  static const Color rojo = Color(0xFFE53935);
  static const Color amarillo = Color(0xFFFDD835);
  static const Color dorado = Color(0xFFF2B705);
  static const Color verde = Color(0xFF2E9E6B);
  static const Color ambar = Color(0xFFB38600);
  static const Color gris = Color(0xFF6B7A90);
  static const Color fondo = Color(0xFFF4F7FC);
  static const Color campo = Color(0xFFF7F8FA);
  static const Color texto = Color(0xFF1A1A2E);
}

class AppTheme {
  static OutlineInputBorder _borde(Color color, double ancho) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: color == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: color, width: ancho),
      );

  static ThemeData get claro {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.azul,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.azul,
      secondary: AppColors.dorado,
      error: AppColors.rojo,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.fondo,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.texto,
        displayColor: AppColors.texto,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.texto,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.azul,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.azul,
          minimumSize: const Size(64, 50),
          side: const BorderSide(color: AppColors.azul),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.azul,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.campo,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey.shade400),
        border: _borde(Colors.transparent, 0),
        enabledBorder: _borde(Colors.transparent, 0),
        focusedBorder: _borde(AppColors.azul, 1.5),
        errorBorder: _borde(AppColors.rojo, 1),
        focusedErrorBorder: _borde(AppColors.rojo, 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.texto,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.azul,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.azul),
      dividerTheme: const DividerThemeData(color: Color(0xFFE8ECF3), thickness: 1),
    );
  }
}