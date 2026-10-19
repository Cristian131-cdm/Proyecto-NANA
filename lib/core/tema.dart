import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ColoresNana {
  static const morado = Color(0xFF5B3FA8);
  static const moradoClaro = Color(0xFFEDE7FA);
  static const lila = Color(0xFF9B83E0);
  static const azul = Color(0xFF2F6FED);
  static const fondo = Color(0xFFFBFAFE);
  static const tinta = Color(0xFF241B3D);
  static const alerta = Color(0xFF8F5200);
  static const alertaClaro = Color(0xFFFFF1D6);
  static const ok = Color(0xFF1F8A4C);
  static const okClaro = Color(0xFFDFF4E7);
}

class TemaNana {
  // Aplica la fuente a un solo estilo (compatible con tu versión de Flutter)
  static TextStyle? _f(TextStyle? s) =>
      GoogleFonts.atkinsonHyperlegible(textStyle: s);

  static ThemeData get tema {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ColoresNana.morado,
        secondary: ColoresNana.azul,
      ),
    );
    final t = base.textTheme;

    final textos = TextTheme(
      displayLarge: _f(t.displayLarge),
      displayMedium: _f(t.displayMedium),
      displaySmall: _f(t.displaySmall),
      headlineLarge: _f(t.headlineLarge),
      headlineMedium: _f(t.headlineMedium),
      headlineSmall: _f(t.headlineSmall),
      titleLarge: _f(t.titleLarge),
      titleMedium: _f(t.titleMedium),
      titleSmall: _f(t.titleSmall),
      bodyLarge: _f(t.bodyLarge),
      bodyMedium: _f(t.bodyMedium),
      bodySmall: _f(t.bodySmall),
      labelLarge: _f(t.labelLarge),
      labelMedium: _f(t.labelMedium),
      labelSmall: _f(t.labelSmall),
    ).apply(bodyColor: ColoresNana.tinta, displayColor: ColoresNana.tinta);

    return base.copyWith(
      scaffoldBackgroundColor: ColoresNana.fondo,
      textTheme: textos,
      appBarTheme: AppBarTheme(
        backgroundColor: ColoresNana.fondo,
        foregroundColor: ColoresNana.morado,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textos.titleLarge?.copyWith(
          color: ColoresNana.morado,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColoresNana.morado,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 64),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
    );
  }
}
