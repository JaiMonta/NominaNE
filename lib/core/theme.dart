import 'package:flutter/material.dart';

/// Paleta "seria": gris azulado (primario) y gris claro (superficies).
class Paleta {
  static const primario = Color(0xFF455A64);
  static const primarioOsc = Color(0xFF90A4AE);
  static const grisClaro = Color(0xFFECEFF1);
  static const surfaceClaro = Color(0xFFF4F6F8);
  static const bordeClaro = Color(0xFFB0BEC5);
  static const textoClaro = Color(0xFF263238);
  static const secundarioClaro = Color(0xFF607D8B);

  static const fondoOscuro = Color(0xFF12181D);
  static const surfaceOscuro = Color(0xFF1E272E);
  static const bordeOscuro = Color(0xFF37474F);
  static const textoOscuro = Color(0xFFECEFF1);
  static const secundarioOscuro = Color(0xFFB0BEC5);

  static const ingreso = Color(0xFF2E7D32);
  static const egreso = Color(0xFFC62828);
}

/// Modo de tema global (system por defecto), cambiable desde el AppBar.
final ValueNotifier<ThemeMode> modoTema = ValueNotifier<ThemeMode>(ThemeMode.system);

void alternarModoTema() {
  modoTema.value = switch (modoTema.value) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  };
}

IconData get iconoModoTema => switch (modoTema.value) {
      ThemeMode.system => Icons.brightness_auto,
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
    };

final ThemeData appLight = _build(Brightness.light);
final ThemeData appDark = _build(Brightness.dark);

ThemeData _build(Brightness b) {
  final oscuro = b == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(seedColor: oscuro ? Paleta.primarioOsc : Paleta.primario, brightness: b)
          .copyWith(
    primary: oscuro ? Paleta.primarioOsc : Paleta.primario,
    onPrimary: oscuro ? const Color(0xFF102027) : Colors.white,
    primaryContainer: oscuro ? const Color(0xFF37474F) : const Color(0xFFCFD8DC),
    onPrimaryContainer: oscuro ? Paleta.textoOscuro : Paleta.textoClaro,
    secondary: oscuro ? Paleta.secundarioOscuro : Paleta.secundarioClaro,
    onSecondary: oscuro ? const Color(0xFF102027) : Colors.white,
    surface: oscuro ? Paleta.surfaceOscuro : Paleta.surfaceClaro,
    onSurface: oscuro ? Paleta.textoOscuro : Paleta.textoClaro,
    surfaceContainerHighest: oscuro ? const Color(0xFF263238) : const Color(0xFFE8ECF0),
    onSurfaceVariant: oscuro ? Paleta.secundarioOscuro : Paleta.secundarioClaro,
    outline: oscuro ? Paleta.bordeOscuro : Paleta.bordeClaro,
    outlineVariant: oscuro ? const Color(0xFF2A343B) : const Color(0xFFD5DDE2),
  );

  final fondo = oscuro ? Paleta.fondoOscuro : Paleta.grisClaro;
  final tarjeta = oscuro ? Paleta.surfaceOscuro : Colors.white;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: fondo,
    appBarTheme: AppBarThemeData(
      backgroundColor: oscuro ? Paleta.surfaceOscuro : Paleta.primario,
      foregroundColor: oscuro ? Paleta.textoOscuro : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: tarjeta,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: oscuro ? Paleta.surfaceOscuro : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: oscuro ? Paleta.surfaceOscuro : Colors.white,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      selectedLabelTextStyle:
          TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: oscuro ? Paleta.surfaceOscuro : Colors.white,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: oscuro ? const Color(0xFF263238) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: TextStyle(color: scheme.onSurface, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    ),
  );
}
