class HorarioJornada {
  final int entradaMin;
  final int salidaMin;

  const HorarioJornada({required this.entradaMin, required this.salidaMin});
}

class HorariosAsistencia {
  final Map<String, HorarioJornada> jornadas;
  final int toleranciaMin;

  const HorariosAsistencia({
    required this.jornadas,
    required this.toleranciaMin,
  });

  factory HorariosAsistencia.fromAjustes(List<Map<String, dynamic>> ajustes) {
    final valores = <String, String>{};
    for (final a in ajustes) {
      final clave = a['clave']?.toString();
      if (clave != null) valores[clave] = a['valor']?.toString() ?? '';
    }

    int minutos(String clave, int fallback) =>
        _parseMinutos(valores[clave]) ?? fallback;

    final tolerancia =
        int.tryParse((valores['asistencia_tolerancia_min'] ?? '').trim()) ?? 5;

    return HorariosAsistencia(
      jornadas: {
        'diurna': HorarioJornada(
          entradaMin: minutos('asistencia_diurna_entrada', 7 * 60),
          salidaMin: minutos('asistencia_diurna_salida', 16 * 60),
        ),
        'nocturna': HorarioJornada(
          entradaMin: minutos('asistencia_nocturna_entrada', 22 * 60),
          salidaMin: minutos('asistencia_nocturna_salida', 6 * 60),
        ),
        'mixta': HorarioJornada(
          entradaMin: minutos('asistencia_mixta_entrada', 10 * 60),
          salidaMin: minutos('asistencia_mixta_salida', 19 * 60),
        ),
      },
      toleranciaMin: tolerancia < 0 ? 0 : tolerancia,
    );
  }

  HorarioJornada? para(String? jornada) => jornadas[jornada];
}

class ResultadoRetardo {
  final int retardos;
  final int minutos;

  const ResultadoRetardo(this.retardos, this.minutos);

  static const cero = ResultadoRetardo(0, 0);
}

ResultadoRetardo calcularRetardo({
  required DateTime fecha,
  required DateTime? entrada,
  required HorarioJornada? horario,
  required int toleranciaMin,
}) {
  if (entrada == null || horario == null) return ResultadoRetardo.cero;

  final inicio = DateTime(
    fecha.year,
    fecha.month,
    fecha.day,
    horario.entradaMin ~/ 60,
    horario.entradaMin % 60,
  );
  final limite = inicio.add(Duration(minutes: toleranciaMin));
  if (!entrada.isAfter(limite)) return ResultadoRetardo.cero;

  return ResultadoRetardo(1, entrada.difference(inicio).inMinutes);
}

int? _parseMinutos(String? valor) {
  final match = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$')
      .firstMatch((valor ?? '').trim());
  if (match == null) return null;
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
}
