// Motor de cálculo de nómina. Todos los valores legales vienen de la tabla
// `parametros_legales` (no hay cifras fijas), porque la LOT 1997 adjunta fue
// reemplazada por la LOTTT 2012 y los porcentajes de IVSS/RPE/FAOV no están
// en los documentos adjuntos. Validar siempre contra la normativa vigente.

import 'dart:math';

class LineaRecibo {
  final String codigo;
  final String nombre;
  final String tipo; // 'ingreso' | 'egreso'
  final double cantidad;
  final double monto;
  final String? baseLegal;
  final bool esSalarial;
  LineaRecibo({
    required this.codigo,
    required this.nombre,
    required this.tipo,
    required this.cantidad,
    required this.monto,
    this.baseLegal,
    this.esSalarial = true,
  });
}

class EntradaNovedad {
  final String conceptoCodigo;
  final double cantidad;
  final double monto;
  EntradaNovedad(this.conceptoCodigo, this.cantidad, this.monto);
}

class EntradaConcepto {
  final String codigo, nombre, tipo;
  final String? baseLegal;
  final bool esSalarial;
  final String calculo; // fijo | porcentaje_salario | manual
  final double valor;
  EntradaConcepto({
    required this.codigo,
    required this.nombre,
    required this.tipo,
    required this.esSalarial,
    required this.calculo,
    required this.valor,
    this.baseLegal,
  });
}

class ResultadoRecibo {
  final List<LineaRecibo> lineas;
  final double salarioDiario, totalIngresos, totalEgresos, neto;
  final double aportesPatronales;
  final double aporteIvss, aporteRpe, aporteFaov, aporteLopcymat;
  ResultadoRecibo(this.lineas, this.salarioDiario, this.totalIngresos,
      this.totalEgresos, this.neto, this.aportesPatronales,
      {this.aporteIvss = 0,
      this.aporteRpe = 0,
      this.aporteFaov = 0,
      this.aporteLopcymat = 0});

  double get totalIngresoSalarial => r2(lineas
      .where((l) => l.tipo == 'ingreso' && l.esSalarial)
      .fold<double>(0, (s, l) => s + l.monto));

  /// Ingresos no salariales: suman al neto pero no a la base de aportes.
  double get totalIngresoExtra => r2(lineas
      .where((l) => l.tipo == 'ingreso' && !l.esSalarial)
      .fold<double>(0, (s, l) => s + l.monto));
}

double r2(double v) => (v * 100).roundToDouble() / 100;

/// Cantidad de lunes (inclusive) entre [inicio] y [fin].
int lunesEntre(DateTime inicio, DateTime fin) {
  if (fin.isBefore(inicio)) return 0;
  var d = DateTime(inicio.year, inicio.month, inicio.day);
  final f = DateTime(fin.year, fin.month, fin.day);
  var n = 0;
  while (!d.isAfter(f)) {
    if (d.weekday == DateTime.monday) n++;
    d = d.add(const Duration(days: 1));
  }
  return n;
}

class PayrollEngine {
  final Map<String, double> p;
  PayrollEngine(this.p);

  double _g(String k, [double d = 0]) => p[k] ?? d;

  double salarioDiario(double mensual) => mensual / _g('dias_mes', 30);
  double salarioHora(double mensual, {double? horas}) =>
      salarioDiario(mensual) / (horas ?? _g('horas_jornada_diurna', 8));

  /// Años completos de servicio a la fecha dada.
  int anios(DateTime ingreso, DateTime hasta) {
    var a = hasta.year - ingreso.year;
    if (hasta.month < ingreso.month ||
        (hasta.month == ingreso.month && hasta.day < ingreso.day)) a--;
    return a < 0 ? 0 : a;
  }

  /// Días de vacaciones (Art. 219): base + 1 por año adicional, tope.
  double diasVacaciones(int anios) {
    if (anios < 1) return 0;
    final d = _g('vacaciones_dias_base', 15) +
        (anios - 1) * _g('vacaciones_dia_adicional', 1);
    final m = _g('vacaciones_dias_max', 30);
    return d > m ? m : d;
  }

  /// Días de bono vacacional (Art. 223).
  double diasBonoVacacional(int anios) {
    if (anios < 1) return 0;
    final d = _g('bono_vac_dias_base', 7) +
        (anios - 1) * _g('bono_vac_dia_adicional', 1);
    final m = _g('bono_vac_dias_max', 21);
    return d > m ? m : d;
  }

  /// Días de prestación de antigüedad acreditados en un mes (Art. 108).
  double diasAntiguedadMes(DateTime ingreso, DateTime finMes) {
    final meses =
        (finMes.year - ingreso.year) * 12 + finMes.month - ingreso.month;
    return meses >= 3 ? _g('antiguedad_dias_mes', 5) : 0;
  }

  /// Días de períodos por frecuencia.
  double diasPeriodo(String frecuencia) {
    switch (frecuencia) {
      case 'semanal':
        return 7;
      case 'quincenal':
        return _g('dias_mes', 30) / 2;
      default:
        return _g('dias_mes', 30);
    }
  }

  ResultadoRecibo calcular({
    required double salarioMensual,
    required String frecuencia,
    required DateTime ingreso,
    required DateTime periodoInicio,
    required DateTime periodoFin,
    required List<EntradaConcepto> conceptos,
    required List<EntradaNovedad> novedades,
    double aplicarUtilidadesDias = 0,
    double riesgoLopcymat = 0,
    bool soloSueldo = false,
  }) {
    final lineas = <LineaRecibo>[];
    final sd = salarioDiario(salarioMensual);
    final sh = salarioHora(salarioMensual);
    final mapa = <String, EntradaConcepto>{
      for (final c in conceptos) c.codigo.trim().toUpperCase(): c
    };

    void ing(String cod, double cant, double monto) {
      final c = mapa[cod.trim().toUpperCase()];
      if (c == null || monto == 0) return;
      lineas.add(LineaRecibo(
          codigo: cod.trim().toUpperCase(),
          nombre: c.nombre,
          tipo: 'ingreso',
          cantidad: cant,
          monto: r2(monto),
          baseLegal: c.baseLegal,
          esSalarial: c.esSalarial));
    }

    void egr(String cod, double cant, double monto) {
      final c = mapa[cod.trim().toUpperCase()];
      if (c == null || monto == 0) return;
      lineas.add(LineaRecibo(
          codigo: cod.trim().toUpperCase(),
          nombre: c.nombre,
          tipo: 'egreso',
          cantidad: cant,
          monto: r2(monto),
          baseLegal: c.baseLegal,
          esSalarial: c.esSalarial));
    }

    // 1. Sueldo del período
    final dias = diasPeriodo(frecuencia);
    ing('SUELDO', dias, sd * dias);

    // 2. Novedades (horas extra, recargos, feriados, bonos, préstamos...)
    for (final n in soloSueldo ? const <EntradaNovedad>[] : novedades) {
      final codigo = n.conceptoCodigo.trim().toUpperCase();
      final c = mapa[codigo];
      if (c == null) continue;
      double monto = n.monto;
      switch (codigo) {
        case 'HE_DIURNA':
          if (n.cantidad > 0) {
            monto = n.cantidad * sh * (1 + _g('recargo_hora_extra', .5));
          }
          break;
        case 'HE_NOCT':
          if (n.cantidad > 0) {
            // Los recargos de hora extra (50%) y nocturno (30%) se suman
            // sobre el salario hora: 1 + 0,50 + 0,30 = 1,80.
            monto = n.cantidad *
                sh *
                (1 + _g('recargo_hora_extra', .5) + _g('recargo_nocturno', .3));
          }
          break;
        case 'REC_NOCT':
          if (n.cantidad > 0) {
            monto = n.cantidad * sh * _g('recargo_nocturno', .3);
          }
          break;
        case 'FERIADO':
          if (n.cantidad > 0) {
            monto = n.cantidad * sd * (1 + _g('recargo_feriado', .5));
          }
          break;
        case 'VACACIONES':
        case 'BONO_VAC':
          if (n.monto == 0) monto = n.cantidad * sd; // cantidad = días
          break;
        default:
          if (n.monto == 0) {
            if (c.calculo == 'porcentaje_salario') {
              monto = salarioMensual * c.valor * (dias / _g('dias_mes', 30));
            } else if (c.calculo == 'fijo') {
              monto = c.valor * (n.cantidad == 0 ? 1 : n.cantidad);
            }
          }
      }
      if (c.tipo == 'ingreso') {
        ing(c.codigo, n.cantidad, monto);
      } else {
        egr(c.codigo, n.cantidad, monto);
      }
    }

    // 3. Vacaciones, bono vacacional y utilidades (si se solicitan)
    // VACACIONES / BONO_VAC se cargan como novedad con cantidad en días
    // (ver diasVacaciones / diasBonoVacacional para sugerir la cantidad).
    if (!soloSueldo && aplicarUtilidadesDias > 0) {
      ing('UTILIDADES', aplicarUtilidadesDias, sd * aplicarUtilidadesDias);
    }

    // 4. Deducciones de ley sobre base salarial
    final baseSalarial = lineas
        .where((l) => l.tipo == 'ingreso' && l.esSalarial)
        .fold<double>(0, (s, l) => s + l.monto);

    // IVSS: retención semanal (salario anual / 52) por cada lunes del período,
    // con tope mensual de N salarios mínimos repartido entre los lunes del mes.
    var ivssPatrono = 0.0;
    if (!soloSueldo) {
      final pctIvssEmp = _g('ivss_empleado_pct', .04);
      final pctIvssPat = _g('ivss_patrono_pct', .09);
      final topeMensual =
          _g('ivss_tope_salarios_min', 5) * _g('salario_minimo_mensual', 0);
      final salarioSemanal = salarioMensual * 12 / 52;
      var ivssEmpleado = 0.0;
      var lunes = 0;
      var dia = DateTime(
          periodoInicio.year, periodoInicio.month, periodoInicio.day);
      final finDia =
          DateTime(periodoFin.year, periodoFin.month, periodoFin.day);
      while (!dia.isAfter(finDia)) {
        if (dia.weekday == DateTime.monday) {
          lunes++;
          final lunesMes = lunesEntre(
              DateTime(dia.year, dia.month, 1),
              DateTime(dia.year, dia.month + 1, 0));
          final topeEmp = topeMensual > 0 && lunesMes > 0
              ? topeMensual * pctIvssEmp / lunesMes
              : double.infinity;
          final topePat = topeMensual > 0 && lunesMes > 0
              ? topeMensual * pctIvssPat / lunesMes
              : double.infinity;
          ivssEmpleado += min(salarioSemanal * pctIvssEmp, topeEmp);
          ivssPatrono += min(salarioSemanal * pctIvssPat, topePat);
        }
        dia = dia.add(const Duration(days: 1));
      }
      egr('IVSS', lunes.toDouble(), ivssEmpleado);
      egr('RPE', 0, baseSalarial * _g('rpe_empleado_pct', .005));
      egr('FAOV', 0, baseSalarial * _g('faov_empleado_pct', .01));
    }

    // 5. Límite de cuotas de préstamo: máx 1/3 del ingreso (Art. 165)
    final totalIng0 = lineas
        .where((l) => l.tipo == 'ingreso')
        .fold<double>(0, (s, l) => s + l.monto);
    final idxPrest = lineas.indexWhere((l) => l.codigo == 'PRESTAMO');
    if (idxPrest >= 0 && lineas[idxPrest].monto > totalIng0 / 3) {
      final l = lineas[idxPrest];
      lineas[idxPrest] = LineaRecibo(
          codigo: l.codigo,
          nombre: '${l.nombre} (limitado a 1/3)',
          tipo: l.tipo,
          cantidad: l.cantidad,
          monto: r2(totalIng0 / 3),
          baseLegal: l.baseLegal,
          esSalarial: l.esSalarial);
    }

    // Totales
    final totI = r2(lineas
        .where((l) => l.tipo == 'ingreso')
        .fold<double>(0, (s, l) => s + l.monto));
    final totE = r2(lineas
        .where((l) => l.tipo == 'egreso')
        .fold<double>(0, (s, l) => s + l.monto));

    // Aportes patronales (desglosados por concepto)
    final aIvss = r2(ivssPatrono);
    final aRpe =
        soloSueldo ? 0.0 : r2(baseSalarial * _g('rpe_patrono_pct', .02));
    final aFaov =
        soloSueldo ? 0.0 : r2(baseSalarial * _g('faov_patrono_pct', .02));
    final aLop = soloSueldo
        ? 0.0
        : r2(baseSalarial *
            (riesgoLopcymat > 0
                ? riesgoLopcymat
                : _g('lopcymat_patrono_pct', .0075)));
    final aportes = r2(aIvss + aRpe + aFaov + aLop);

    return ResultadoRecibo(lineas, r2(sd), totI, totE, r2(totI - totE), aportes,
        aporteIvss: aIvss,
        aporteRpe: aRpe,
        aporteFaov: aFaov,
        aporteLopcymat: aLop);
  }
}
