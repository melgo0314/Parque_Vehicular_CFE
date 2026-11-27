import 'package:flutter/material.dart';

// Define los colores y estilos globales de la aplicación.
class AppTheme {
  // Colores principales de la identidad visual.
  static const Color cfeGreen = Color(0xFF008A45);
  static const Color pearlWhite = Color(0xFFF4F6F4);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color accentYellow = Color(0xFFFFBF00);

  // Colores para textos y elementos neutros.
  static const Color primaryText = Color(0xFF26352C);
  static const Color secondaryText = Color(0xFF52635A);
  static const Color accentText = Color(0xFF1D261F);
  static const Color border = Color(0xFFD7DED7);
  static const Color roleSurface = Color(0xFFE6EBE3);

  // Colores para estados de alerta y advertencia.
  static const Color alertOrange = Color(0xFFFF9800);
  static const Color warningSurface = Color(0xFFFFF1CC);
  static const Color warningText = Color(0xFF7A4D00);

  // Colores para errores.
  static const Color errorRed = Color(0xFFB3261E);
  static const Color errorSurface = Color(0xFFFCE8E6);

  // Colores para mensajes informativos.
  static const Color infoBlue = Color(0xFF174A8B);
  static const Color infoSurface = Color(0xFFE3ECFA);

  // Colores para avatares y estados operativos.
  static const Color avatarSurface = Color(0xFFE1EFE7);
  static const Color avatarText = Color(0xFF075C35);
  static const Color operationalSurface = Color(0xFFE1F0E7);
  static const Color operationalText = Color(0xFF075C35);

  // Devuelve el color de fondo asociado al estado de un vehículo.
  // Entrada: estado del vehículo, por ejemplo, operativo o en_taller.
  // Salida: color de fondo correspondiente al estado indicado.
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

  // Devuelve el color de texto e icono asociado al estado de un vehículo.
  // Entrada: estado del vehículo, por ejemplo, operativo o en_taller.
  // Salida: color de texto e icono correspondiente al estado indicado.
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

  // Configuración del tema claro que se aplica en toda la aplicación.
  // Entrada: ninguna.
  // Salida: ThemeData con Material 3, colores y estilos de componentes.
  static ThemeData get lightTheme {
    // Genera la paleta de Material 3 a partir del color principal.
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
      // Activa Material 3 y aplica los colores generales de la aplicación.
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pearlWhite,

      // Estilo de la barra superior.
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

      // Estilo y decoración de los campos de texto.
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

      // Estilo de los botones elevados principales.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cfeGreen,
          foregroundColor: pureWhite,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Estilo de los botones rellenos secundarios.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cfeGreen,
          foregroundColor: pureWhite,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Estilo de los botones con contorno.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cfeGreen,
          minimumSize: const Size(double.infinity, 46),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

      // Estilo de los botones de texto.
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

      // Tamaño y área táctil mínima de los botones de icono.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      // Estilo del botón de acción flotante.
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