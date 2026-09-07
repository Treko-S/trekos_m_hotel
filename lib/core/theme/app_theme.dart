import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta Moderna "Hotel 3Vagos"
  static const Color primaryBlue = Color(0xFF2563EB);    // Azul vibrante de acción
  static const Color primaryDark = Color(0xFF0F172A);    // Azul/Negro oscuro para textos principales
  static const Color accentCyan = Color(0xFF0284C7);     // Celeste corporativo para logo y detalles
  static const Color bgLight = Color(0xFFF8FAFC);        // Fondo general ultra-limpio
  static const Color cardBg = Color(0xFFFFFFFF);         // Blanco puro de tarjetas
  static const Color cardBorder = Color(0xFFE2E8F0);     // Borde suave de separación
  static const Color textMuted = Color(0xFF64748B);      // Texto secundario gris slate

  // Estados de Habitación
  static const Color greenText = Color(0xFF16A34A);
  static const Color greenBg = Color(0xFFDCFCE7);
  static const Color orangeText = Color(0xFFD97706);
  static const Color orangeBg = Color(0xFFFEF3C7);
  static const Color blueText = Color(0xFF2563EB);
  static const Color blueBg = Color(0xFFE0F2FE);
  static const Color redText = Color(0xFFE11D48);
  static const Color redBg = Color(0xFFFFE4E6);

  // Compatibilidad con vistas previas
  static const Color navyLuxury = primaryDark;
  static const Color goldLuxury = Color(0xFFD97706);
  static const Color bgCream = bgLight;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: accentCyan,
        surface: cardBg,
      ),
      scaffoldBackgroundColor: bgLight,
      textTheme: GoogleFonts.poppinsTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
        color: cardBg,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
