import 'package:flutter/material.dart';

class AppTheme {
  // Colores principales
  static const Color cfeGreen = Color(0xFF008A45);
  static const Color pearlWhite = Color(0xFFF4F6F4);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color accentYellow = Color(0xFFFFBF00);

  // Texto y elementos neutros
  static const Color primaryText = Color(0xFF26352C);
  static const Color secondaryText = Color(0xFF52635A);
  static const Color accentText = Color(0xFF1D261F);
  static const Color border = Color(0xFFD7DED7);
  static const Color roleSurface = Color(0xFFE6EBE3);

  // Estados 
  static const Color alertOrange = Color(0xFFFF9800);
  static const Color warningSurface = Color(0xFFFFF1CC);
  static const Color warningText = Color(0xFF7A4D00);

  static const Color errorRed = Color(0xFFB3261E);
  static const Color errorSurface = Color(0xFFFCE8E6);

  static const Color infoBlue = Color(0xFF174A8B);
  static const Color infoSurface = Color(0xFFE3ECFA);

  // Estado operativo
  static const Color avatarSurface = Color(0xFFE1EFE7);
  static const Color avatarText = Color(0xFF075C35);
  static const Color operationalSurface = Color(0xFFE1F0E7);
  static const Color operationalText = Color(0xFF075C35);

  // Color de fondo para un estado de vehículo.
  static Color vehicleStatusSurface(String estado) {
    switch (estado.toLowerCase()) {
      case 'baja':
      case 'servicio_vencido':
        return errorSurface;
      case 'en_taller':
        return infoSurface;
      case 'servicio_proximo':
        return warningSurface;
      case 'operativo':
      default:
        return operationalSurface;
    }
  }

  // Color de texto e icono para un estado de vehículo.
  static Color vehicleStatusText(String estado) {
    switch (estado.toLowerCase()) {
      case 'baja':
      case 'servicio_vencido':
        return errorRed;
      case 'en_taller':
        return infoBlue;
      case 'servicio_proximo':
        return warningText;
      case 'operativo':
      default:
        return operationalText;
    }
  }

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: cfeGreen,
      primary: cfeGreen,
      onPrimary: pureWhite,
      surface: pureWhite,
      onSurface: primaryText,
      onSurfaceVariant: secondaryText,
      error: errorRed,
      outline: border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pearlWhite,

      appBarTheme: const AppBarTheme(
        backgroundColor: cfeGreen,
        foregroundColor: pureWhite,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: pureWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pureWhite,
        labelStyle: const TextStyle(color: secondaryText),
        hintStyle: const TextStyle(color: secondaryText),
        helperStyle: const TextStyle(color: secondaryText),
        prefixIconColor: cfeGreen,
        suffixIconColor: secondaryText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cfeGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cfeGreen,
          foregroundColor: pureWhite,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cfeGreen,
          foregroundColor: pureWhite,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cfeGreen,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: cfeGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cfeGreen,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentYellow,
        foregroundColor: accentText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}