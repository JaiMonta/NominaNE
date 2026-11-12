import 'dart:math';

import '../models/liquidacion_models.dart';

double _r2(double v) => (v * 100).roundToDouble() / 100;
double _r4(double v) => (v * 10000).roundToDouble() / 10000;

class ParametrosLiquidacion {
  final double diasMes;
  final double salarioIntegralDivisor;
  final double prestacionesDiasTrimestre;
  final double prestacionesDiasAnioExtra;
  final double prestacionesDiasExtraMax;
  final double prestacionesRetroDiasAnio;
  final double prestacionesFraccionMeses;
  final double prestacionesMesesMinimos;
  final double prestacionesDiasMesMenos3;
  final double vacacionesDiasBase;
  final double vacacionesDiaAdicional;
  final double vacacionesDiasMax;
  final double bonoVacDiasBase;
  final double bonoVacDiaAdicional;
  final double bonoVacDiasMax;
  final double utilidadesDiasEmpresa;
  final double utilidadesEjercicioInicioMes;

  ParametrosLiquidacion({
    this.diasMes = 30,
    this.salarioIntegralDivisor = 360,
    this.prestacionesDiasTrimestre = 15,
    this.prestacionesDiasAnioExtra = 2,
    this.prestacionesDiasExtraMax = 30,
    this.prestacionesRetroDiasAnio = 30,
    this.prestacionesFraccionMeses = 6,
    this.prestacionesMesesMinimos = 3,
    this.prestacionesDiasMesMenos3 = 5,
    this.vacacionesDiasBase = 15,
    this.vacacionesDiaAdicional = 1,
    this.vacacionesDiasMax = 30,
    this.bonoVacDiasBase = 15,
    this.bonoVacDiaAdicional = 1,
    this.bonoVacDiasMax = 30,
    this.utilidadesDiasEmpresa = 30,
    this.utilidadesEjercicioInicioMes = 1,
  });

  factory ParametrosLiquidacion.fromMap(Map<String, double> m) =>
      ParametrosLiquidacion(
        diasMes: _g(m, 'dias_mes', 30),
        salarioIntegralDivisor: _g(m, 'salario_integral_divisor', 360),
        prestacionesDiasTrimestre:
            _g(m, 'prestaciones_dias_trimestre', 15),
        prestacionesDiasAnioExtra:
            _g(m, 'prestaciones_dias_anio_extra', 2),
        prestacionesDiasExtraMax:
            _g(m, 'prestaciones_dias_extra_max', 30),
        prestacionesRetroDiasAnio:
            _g(m, 'prestaciones_retro_dias_anio', 30),
        prestacionesFraccionMeses:
            _g(m, 'prestaciones_fraccion_meses', 6),
        prestacionesMesesMinimos:
            _g(m, 'prestaciones_meses_minimos', 3),
        prestacionesDiasMesMenos3:
            _g(m, 'prestaciones_dias_mes_menos3', 5),
        vacacionesDiasBase: _g(m, 'vacaciones_dias_base', 15),
        vacacionesDiaAdicional:
            _g(m, 'vacaciones_dia_adicional', 1),
        vacacionesDiasMax: _g(m, 'vacaciones_dias_max', 30),
        bonoVacDiasBase: _g(m, 'bono_vac_dias_base', 15),
        bonoVacDiaAdicional: _g(m, 'bono_vac_dia_adicional', 1),
        bonoVacDiasMax: _g(m, 'bono_vac_dias_max', 30),
        utilidadesDiasEmpresa: _g(m, 'dias_utilidades_empresa', 30),
        utilidadesEjercicioInicioMes:
            _g(m, 'utilidades_ejercicio_inicio_mes', 1),
      );

  static double _g(Map<String, double> m, String k, double d) =>
      m[k] ?? d;
}

class LiquidacionEntrada {
  final DateTime fechaIngreso;
  final DateTime fechaEgreso;
  final String motivo;
  final double salarioNormalMensualBs;
  final double salarioNormalMensualUsd;
  final double tasaBcv;
  final double saldoGarantiaBs;
  final double interesesBs;
  final double diasVacacionesPendientes;
  final double diasBonoPendientes;
  final double diasVacacionesDisfrutadosPeriodo;
  final double diasBonoPagadosPeriodo;
  final double diasUtilidadesEmpresa;
  final double salarioPendienteBs;
  final double otrosIngresosBs;
  final double deduccionesBs;
  final bool aplicaIndemnizacion92;

  LiquidacionEntrada({
    required this.fechaIngreso,
    required this.fechaEgreso,
    required this.motivo,
    required this.salarioNormalMensualBs,
    this.salarioNormalMensualUsd = 0,
    this.tasaBcv = 0,
    this.saldoGarantiaBs = 0,
    this.interesesBs = 0,
    this.diasVacacionesPendientes = 0,
    this.diasBonoPendientes = 0,
    this.diasVacacionesDisfrutadosPeriodo = 0,
    this.diasBonoPagadosPeriodo = 0,
    this.diasUtilidadesEmpresa = 30,
    this.salarioPendienteBs = 0,
    this.otrosIngresosBs = 0,
    this.deduccionesBs = 0,
    this.aplicaIndemnizacion92 = false,
  });
}

class LineaLiquidacion {
  final String codigo;
  final String nombre;
  final String tipo;
  final double dias;
  final double base;
  final double monto;
  final String baseLegal;

  LineaLiquidacion({
    required this.codigo,
    required this.nombre,
    required this.tipo,
    this.dias = 0,
    this.base = 0,
    required this.monto,
    required this.baseLegal,
  });
}

class ResultadoLiquidacion {
  final int anios;
  final int meses;
  final int dias;
  final double salarioNormalDiario;
  final double salarioIntegralDiario;
  final double garantia;
  final double intereses;
  final double retroactivo;
  final double prestaciones;
  final double vacaciones;
  final double bono;
  final double utilidades;
  final double indemnizacion;
  final double salarioPendiente;
  final double otrosIngresos;
  final double deducciones;
  final double totalIngresos;
  final double totalDeducciones;
  final double neto;
  final double totalUsd;
  final List<LineaLiquidacion> lineas;
  final List<String> advertencias;

  ResultadoLiquidacion({
    required this.anios,
    required this.meses,
    required this.dias,
    required this.salarioNormalDiario,
    required this.salarioIntegralDiario,
    required this.garantia,
    required this.intereses,
    required this.retroactivo,
    required this.prestaciones,
    required this.vacaciones,
    required this.bono,
    required this.utilidades,
    required this.indemnizacion,
    required this.salarioPendiente,
    required this.otrosIngresos,
    required this.deducciones,
    required this.totalIngresos,
    required this.totalDeducciones,
    required this.neto,
    required this.totalUsd,
    required this.lineas,
    required this.advertencias,
  });
}

class LiquidacionEngine {
  final ParametrosLiquidacion p;
  LiquidacionEngine(this.p);

  int aniosCompletos(DateTime desde, DateTime hasta) {
    var a = hasta.year - desde.year;
    if (hasta.month < desde.month ||
        (hasta.month == desde.month && hasta.day < desde.day)) {
      a--;
    }
    return max(0, a);
  }

  int mesesCompletos(DateTime desde, DateTime hasta) {
    var m = (hasta.year - desde.year) * 12 + hasta.month - desde.month;
    if (hasta.day < desde.day) m--;
    return max(0, m);
  }

  double diasVacacionesAnio(int anio) {
    if (anio < 1) return 0;
    final d = p.vacacionesDiasBase +
        (anio - 1) * p.vacacionesDiaAdicional;
    return min(d, p.vacacionesDiasMax);
  }

  double diasBonoAnio(int anio) {
    if (anio < 1) return 0;
    final d = p.bonoVacDiasBase + (anio - 1) * p.bonoVacDiaAdicional;
    return min(d, p.bonoVacDiasMax);
  }

  ResultadoLiquidacion calcular(LiquidacionEntrada e) {
    final advertencias = <String>[];
    final anios = aniosCompletos(e.fechaIngreso, e.fechaEgreso);
    final int totalMeses =
        max<int>(0, mesesCompletos(e.fechaIngreso, e.fechaEgreso));
    final int meses = totalMeses % 12;
    final int dias = max<int>(
        0, e.fechaEgreso.difference(e.fechaIngreso).inDays - totalMeses * 30);

    final normalDiario = e.salarioNormalMensualBs / p.diasMes;
    final utilidadesDias = e.diasUtilidadesEmpresa.clamp(30.0, 120.0);
    final diasBonoIntegral = diasBonoAnio(anios + 1);
    final alicuotaUtilidades =
        normalDiario * utilidadesDias / p.salarioIntegralDivisor;
    final alicuotaBono =
        normalDiario * diasBonoIntegral / p.salarioIntegralDivisor;
    final integralDiario = normalDiario + alicuotaUtilidades + alicuotaBono;

    if (e.tasaBcv <= 0) {
      advertencias.add('La tasa BCV no es válida.');
    }
    if (e.saldoGarantiaBs <= 0 && e.interesesBs <= 0) {
      advertencias.add(
          'No hay saldo de garantía cargado; el cálculo usará el retroactivo.');
    }

    final lineas = <LineaLiquidacion>[];
    double garantia = _r2(e.saldoGarantiaBs);
    double intereses = _r2(e.interesesBs);
    double retroactivo = 0;
    double prestaciones = 0;

    if (totalMeses < p.prestacionesMesesMinimos) {
      final mesesPago = totalMeses +
          (e.fechaEgreso.day > e.fechaIngreso.day ? 1 : 0);
      prestaciones =
          _r2(p.prestacionesDiasMesMenos3 * mesesPago * integralDiario);
      retroactivo = prestaciones;
      lineas.add(LineaLiquidacion(
        codigo: 'PRESTACIONES',
        nombre: 'Prestaciones sociales (menos de 3 meses)',
        tipo: 'ingreso',
        dias: p.prestacionesDiasMesMenos3 * mesesPago,
        base: integralDiario,
        monto: prestaciones,
        baseLegal: 'LOTTT Art. 142 literal e',
      ));
    } else {
      final fraccion = mesesCompletos(
          DateTime(e.fechaIngreso.year + anios, e.fechaIngreso.month,
              e.fechaIngreso.day),
          e.fechaEgreso);
      final aniosRetro = anios +
          (fraccion > p.prestacionesFraccionMeses ? 1 : 0);
      retroactivo = _r2(
          p.prestacionesRetroDiasAnio * aniosRetro * integralDiario);
      final opcionGarantia = _r2(garantia + intereses);
      prestaciones = max(opcionGarantia, retroactivo);
      lineas.add(LineaLiquidacion(
        codigo: 'PRESTACIONES',
        nombre: 'Prestaciones sociales (mayor entre garantía y retroactivo)',
        tipo: 'ingreso',
        base: integralDiario,
        monto: prestaciones,
        baseLegal: 'LOTTT Art. 142 literales a, b, c y d',
      ));
    }

    final vacaciones = _r2(
        e.diasVacacionesPendientes * normalDiario);
    final bono =
        _r2(e.diasBonoPendientes * normalDiario);
    if (vacaciones > 0) {
      lineas.add(LineaLiquidacion(
        codigo: 'VACACIONES_PEND',
        nombre: 'Vacaciones vencidas no disfrutadas',
        tipo: 'ingreso',
        dias: e.diasVacacionesPendientes,
        base: normalDiario,
        monto: vacaciones,
        baseLegal: 'LOTTT Art. 195',
      ));
    }
    if (bono > 0) {
      lineas.add(LineaLiquidacion(
        codigo: 'BONO_VAC_PEND',
        nombre: 'Bono vacacional vencido no pagado',
        tipo: 'ingreso',
        dias: e.diasBonoPendientes,
        base: normalDiario,
        monto: bono,
        baseLegal: 'LOTTT Art. 192',
      ));
    }

    final aniversario = DateTime(e.fechaIngreso.year + anios,
        e.fechaIngreso.month, e.fechaIngreso.day);
    final mesesFraccion = min(11, mesesCompletos(aniversario, e.fechaEgreso));
    final diasVacacionesFraccion = max(
        0.0,
        diasVacacionesAnio(anios + 1) * mesesFraccion / 12 -
            e.diasVacacionesDisfrutadosPeriodo);
    final diasBonoFraccion = max(
        0.0,
        diasBonoAnio(anios + 1) * mesesFraccion / 12 -
            e.diasBonoPagadosPeriodo);
    final vacacionesFraccion = _r2(diasVacacionesFraccion * normalDiario);
    final bonoFraccion = _r2(diasBonoFraccion * normalDiario);
    if (vacacionesFraccion > 0) {
      lineas.add(LineaLiquidacion(
        codigo: 'VACACIONES_FRAC',
        nombre: 'Vacaciones fraccionadas del año en curso',
        tipo: 'ingreso',
        dias: diasVacacionesFraccion,
        base: normalDiario,
        monto: vacacionesFraccion,
        baseLegal: 'LOTTT Art. 196',
      ));
    }
    if (bonoFraccion > 0) {
      lineas.add(LineaLiquidacion(
        codigo: 'BONO_VAC_FRAC',
        nombre: 'Bono vacacional fraccionado',
        tipo: 'ingreso',
        dias: diasBonoFraccion,
        base: normalDiario,
        monto: bonoFraccion,
        baseLegal: 'LOTTT Arts. 192 y 196',
      ));
    }

    final inicioEjercicio = _inicioEjercicio(e.fechaEgreso);
    final desdeUtilidades =
        inicioEjercicio.isAfter(e.fechaIngreso) ? inicioEjercicio : e.fechaIngreso;
    final mesesUtilidades =
        min(12, mesesCompletos(desdeUtilidades, e.fechaEgreso));
    final diasUtilidades = _r2(utilidadesDias * mesesUtilidades / 12);
    final utilidades = _r2(diasUtilidades * normalDiario);
    if (utilidades > 0) {
      lineas.add(LineaLiquidacion(
        codigo: 'UTILIDADES',
        nombre: 'Utilidades fraccionadas',
        tipo: 'ingreso',
        dias: diasUtilidades,
        base: normalDiario,
        monto: utilidades,
        baseLegal: 'LOTTT Arts. 131 y 134',
      ));
    }

    final indemnizacion = e.aplicaIndemnizacion92 ? _r2(prestaciones) : 0.0;
    if (indemnizacion > 0) {
      lineas.add(LineaLiquidacion(
        codigo: 'INDEMNIZACION_92',
        nombre: 'Indemnización por terminación (Art. 92)',
        tipo: 'ingreso',
        base: prestaciones,
        monto: indemnizacion,
        baseLegal: 'LOTTT Art. 92',
      ));
    }

    final salarioPendiente = _r2(e.salarioPendienteBs);
    if (salarioPendiente > 0) {
      lineas.add(LineaLiquidacion(
        codigo: 'SALARIO_PENDIENTE',
        nombre: 'Salario pendiente',
        tipo: 'ingreso',
        monto: salarioPendiente,
        baseLegal: 'LOTTT Art. 104',
      ));
    }
    final otrosIngresos = _r2(e.otrosIngresosBs);
    if (otrosIngresos > 0) {
      lineas.add(LineaLiquidacion(
        codigo: 'OTROS_INGRESOS',
        nombre: 'Otros ingresos',
        tipo: 'ingreso',
        monto: otrosIngresos,
        baseLegal: '',
      ));
    }
    final deducciones = _r2(e.deduccionesBs);
    if (deducciones > 0) {
      lineas.add(LineaLiquidacion(
        codigo: 'DEDUCCIONES',
        nombre: 'Deducciones y anticipos',
        tipo: 'deduccion',
        monto: deducciones,
        baseLegal: 'LOTTT Art. 144 / préstamos',
      ));
    }

    final totalIngresos = _r2(lineas
        .where((l) => l.tipo == 'ingreso')
        .fold<double>(0, (s, l) => s + l.monto));
    final totalDeducciones = _r2(lineas
        .where((l) => l.tipo == 'deduccion')
        .fold<double>(0, (s, l) => s + l.monto));
    final neto = _r2(totalIngresos - totalDeducciones);
    final totalUsd =
        e.tasaBcv > 0 ? _r2(neto / e.tasaBcv) : 0.0;

    return ResultadoLiquidacion(
      anios: anios,
      meses: meses,
      dias: dias,
      salarioNormalDiario: _r4(normalDiario),
      salarioIntegralDiario: _r4(integralDiario),
      garantia: garantia,
      intereses: intereses,
      retroactivo: retroactivo,
      prestaciones: prestaciones,
      vacaciones: vacaciones,
      bono: bono,
      utilidades: utilidades,
      indemnizacion: indemnizacion,
      salarioPendiente: salarioPendiente,
      otrosIngresos: otrosIngresos,
      deducciones: deducciones,
      totalIngresos: totalIngresos,
      totalDeducciones: totalDeducciones,
      neto: neto,
      totalUsd: totalUsd,
      lineas: lineas,
      advertencias: advertencias,
    );
  }

  DateTime _inicioEjercicio(DateTime hasta) {
    final mes = p.utilidadesEjercicioInicioMes.clamp(1, 12).toInt();
    var inicio = DateTime(hasta.year, mes, 1);
    if (inicio.isAfter(hasta)) inicio = DateTime(hasta.year - 1, mes, 1);
    return inicio;
  }
}

List<LiquidacionDetalle> detallesDesdeResultado(
    ResultadoLiquidacion r, String? liquidacionId) {
  return [
    for (var i = 0; i < r.lineas.length; i++)
      LiquidacionDetalle(
        liquidacionId: liquidacionId,
        codigo: r.lineas[i].codigo,
        nombre: r.lineas[i].nombre,
        tipo: r.lineas[i].tipo,
        dias: r.lineas[i].dias,
        base: r.lineas[i].base,
        monto: r.lineas[i].monto,
        baseLegal: r.lineas[i].baseLegal,
        orden: i,
      )
  ];
}
