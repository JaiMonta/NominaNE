import 'package:intl/intl.dart';

enum TipoPeriodoNomina { semanal, mensual, trimestral, semestral, anual }

class RangoNomina {
  final DateTime inicio;
  final DateTime fin;

  const RangoNomina(this.inicio, this.fin);
}

RangoNomina rangoNomina(TipoPeriodoNomina tipo, DateTime referencia) {
  final ref = DateTime(referencia.year, referencia.month, referencia.day);

  switch (tipo) {
    case TipoPeriodoNomina.semanal:
      final lunes = ref.subtract(Duration(days: ref.weekday - 1));
      return RangoNomina(lunes, lunes.add(const Duration(days: 6)));

    case TipoPeriodoNomina.mensual:
      return RangoNomina(
        DateTime(ref.year, ref.month, 1),
        DateTime(ref.year, ref.month + 1, 0),
      );

    case TipoPeriodoNomina.trimestral:
      final trimestre = ((ref.month - 1) ~/ 3);
      final inicioMes = trimestre * 3 + 1;
      return RangoNomina(
        DateTime(ref.year, inicioMes, 1),
        DateTime(ref.year, inicioMes + 3, 0),
      );

    case TipoPeriodoNomina.semestral:
      final semestre = ref.month <= 6 ? 0 : 1;
      final inicioMes = semestre * 6 + 1;
      return RangoNomina(
        DateTime(ref.year, inicioMes, 1),
        DateTime(ref.year, inicioMes + 6, 0),
      );

    case TipoPeriodoNomina.anual:
      return RangoNomina(
        DateTime(ref.year, 1, 1),
        DateTime(ref.year, 12, 31),
      );
  }
}

String etiquetaNomina(TipoPeriodoNomina tipo, RangoNomina r) {
  final f = DateFormat('dd/MM/yyyy');
  switch (tipo) {
    case TipoPeriodoNomina.semanal:
      return 'Semana ${f.format(r.inicio)} al ${f.format(r.fin)}';
    case TipoPeriodoNomina.mensual:
      final texto = DateFormat('MMMM yyyy', 'es').format(r.inicio);
      return 'Mes de ${texto[0].toUpperCase()}${texto.substring(1)}';
    case TipoPeriodoNomina.trimestral:
      final numero = ((r.inicio.month - 1) ~/ 3) + 1;
      return 'Trimestre $numero ${r.inicio.year}';
    case TipoPeriodoNomina.semestral:
      final numero = r.inicio.month <= 6 ? 1 : 2;
      return 'Semestre $numero ${r.inicio.year}';
    case TipoPeriodoNomina.anual:
      return 'Año ${r.inicio.year}';
  }
}
