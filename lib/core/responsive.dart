import 'package:flutter/material.dart';

/// Ancho a partir del cual se considera pantalla de escritorio.
const double kBreakpoint = 700;

bool esMovil(BuildContext context) => MediaQuery.sizeOf(context).width < kBreakpoint;

/// Ancho para el contenido de un diálogo: acotado por [max] en escritorio y
/// ajustado al ancho disponible en móvil.
double anchoDialogo(BuildContext context, double max) {
  final disponible = MediaQuery.sizeOf(context).width - 48;
  return disponible < max ? disponible : max;
}

/// Diálogo con área segura y desplazamiento, apto para móvil.
Future<T?> showDialogApp<T>(BuildContext context, Widget child) => showDialog<T>(
      context: context,
      useSafeArea: true,
      builder: (_) => child,
    );
