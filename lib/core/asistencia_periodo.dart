enum TipoPeriodoAsistencia { semanal, quincenal, mensual }

class RangoAsistencia {
  final DateTime inicio;
  final DateTime fin;

  const RangoAsistencia(this.inicio, this.fin);
}

RangoAsistencia rangoAsistencia(
    TipoPeriodoAsistencia tipo, DateTime referencia) {
  final ref = DateTime(referencia.year, referencia.month, referencia.day);

  switch (tipo) {
    case TipoPeriodoAsistencia.semanal:
      final lunes = ref.subtract(Duration(days: ref.weekday - 1));
      return RangoAsistencia(lunes, lunes.add(const Duration(days: 6)));

    case TipoPeriodoAsistencia.quincenal:
      final primero = DateTime(ref.year, ref.month, 1);
      final ultimo = DateTime(ref.year, ref.month + 1, 0);
      if (ref.day <= 15) {
        return RangoAsistencia(primero, DateTime(ref.year, ref.month, 15));
      }
      return RangoAsistencia(DateTime(ref.year, ref.month, 16), ultimo);

    case TipoPeriodoAsistencia.mensual:
      final primero = DateTime(ref.year, ref.month, 1);
      final ultimo = DateTime(ref.year, ref.month + 1, 0);
      return RangoAsistencia(primero, ultimo);
  }
}
