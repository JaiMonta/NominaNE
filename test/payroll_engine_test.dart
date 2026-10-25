import 'package:flutter_test/flutter_test.dart';
import 'package:nomina_app/core/payroll_engine.dart';

EntradaConcepto _concepto(
  String codigo,
  String tipo, {
  bool esSalarial = true,
  String calculo = 'manual',
  double valor = 0,
}) =>
    EntradaConcepto(
      codigo: codigo,
      nombre: codigo,
      tipo: tipo,
      esSalarial: esSalarial,
      calculo: calculo,
      valor: valor,
    );

void main() {
  test('ingreso no salarial suma al neto pero no a la base de aportes', () {
    final motor = PayrollEngine({
      'dias_mes': 30,
      'horas_jornada_diurna': 8,
      'ivss_empleado_pct': 0.04,
      'rpe_empleado_pct': 0,
      'faov_empleado_pct': 0,
      'salario_minimo_mensual': 0,
    });

    final r = motor.calcular(
      salarioMensual: 3000,
      frecuencia: 'mensual',
      ingreso: DateTime(2020, 1, 1),
      periodoFin: DateTime(2026, 1, 31),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('BONO_ALIM', 'ingreso', esSalarial: false),
        _concepto('PRESTAMO', 'egreso', esSalarial: false),
        _concepto('IVSS', 'egreso', esSalarial: false),
      ],
      novedades: [
        EntradaNovedad('BONO_ALIM', 1, 100),
        EntradaNovedad('PRESTAMO', 1, 50),
      ],
    );

    expect(r.totalIngresoSalarial, 3000);
    expect(r.totalIngresoExtra, 100);
    expect(r.totalIngresos, 3100);
    expect(r.totalEgresos, 170);
    expect(r.neto, 2930);

    final bono = r.lineas.firstWhere((l) => l.codigo == 'BONO_ALIM');
    expect(bono.esSalarial, isFalse);

    // IVSS se calcula solo sobre el sueldo salarial (3000), no sobre el extra.
    final ivss = r.lineas.firstWhere((l) => l.codigo == 'IVSS');
    expect(ivss.monto, 120);
  });

  test('concepto fijo no salarial se calcula por cantidad', () {
    final motor = PayrollEngine({'dias_mes': 30});
    final r = motor.calcular(
      salarioMensual: 3000,
      frecuencia: 'mensual',
      ingreso: DateTime(2020, 1, 1),
      periodoFin: DateTime(2026, 1, 31),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('BONO_ALIM', 'ingreso',
            esSalarial: false, calculo: 'fijo', valor: 50),
      ],
      novedades: [EntradaNovedad('BONO_ALIM', 2, 0)],
    );

    expect(r.totalIngresoExtra, 100);
    expect(r.lineas.firstWhere((l) => l.codigo == 'BONO_ALIM').monto, 100);
  });

  test('HE_NOCT calcula hora extra nocturna con recargos aditivos', () {
    final motor = PayrollEngine({
      'dias_mes': 30,
      'horas_jornada_diurna': 8,
      'recargo_hora_extra': 0.5,
      'recargo_nocturno': 0.3,
    });
    final r = motor.calcular(
      salarioMensual: 2400, // salario diario 80, salario hora 10
      frecuencia: 'mensual',
      ingreso: DateTime(2020, 1, 1),
      periodoFin: DateTime(2026, 1, 31),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('HE_NOCT', 'ingreso'),
      ],
      novedades: [EntradaNovedad('HE_NOCT', 8, 0)],
    );

    // 8 horas * 10 Bs/h * (1 + 0,50 + 0,30) = 144 Bs.
    final linea = r.lineas.firstWhere((l) => l.codigo == 'HE_NOCT');
    expect(linea.cantidad, 8);
    expect(linea.monto, 144);
    expect(r.totalIngresos, 2544);
  });

  test('HE_NOCT usa el monto manual si no se indica cantidad', () {
    final motor = PayrollEngine({'dias_mes': 30});
    final r = motor.calcular(
      salarioMensual: 2400,
      frecuencia: 'mensual',
      ingreso: DateTime(2020, 1, 1),
      periodoFin: DateTime(2026, 1, 31),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('HE_NOCT', 'ingreso'),
      ],
      novedades: [EntradaNovedad('HE_NOCT', 0, 100)],
    );

    expect(r.lineas.firstWhere((l) => l.codigo == 'HE_NOCT').monto, 100);
  });

  test('IVSS sin tope usa toda la base salarial', () {
    final motor = PayrollEngine({
      'dias_mes': 30,
      'horas_jornada_diurna': 8,
      'recargo_feriado': 0.5,
      'ivss_empleado_pct': 0.04,
      'ivss_patrono_pct': 0.11,
      'ivss_tope_salarios_min': 0,
      'salario_minimo_mensual': 130,
    });
    final r = motor.calcular(
      salarioMensual: 87565,
      frecuencia: 'quincenal',
      ingreso: DateTime(2020, 1, 1),
      periodoFin: DateTime(2026, 10, 15),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('FERIADO', 'ingreso'),
        _concepto('IVSS', 'egreso', esSalarial: false),
      ],
      novedades: [EntradaNovedad('FERIADO', 1, 0)],
    );

    expect(r.totalIngresoSalarial, 48160.75);
    expect(r.lineas.firstWhere((l) => l.codigo == 'IVSS').monto, 1926.43);
    expect(r.aporteIvss, 5297.68);
  });

  test('IVSS con tope 5 y mínimo 130 conserva el tope', () {
    final motor = PayrollEngine({
      'dias_mes': 30,
      'horas_jornada_diurna': 8,
      'recargo_feriado': 0.5,
      'ivss_empleado_pct': 0.04,
      'ivss_patrono_pct': 0.11,
      'ivss_tope_salarios_min': 5,
      'salario_minimo_mensual': 130,
    });
    final r = motor.calcular(
      salarioMensual: 87565,
      frecuencia: 'quincenal',
      ingreso: DateTime(2020, 1, 1),
      periodoFin: DateTime(2026, 10, 15),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('FERIADO', 'ingreso'),
        _concepto('IVSS', 'egreso', esSalarial: false),
      ],
      novedades: [EntradaNovedad('FERIADO', 1, 0)],
    );

    expect(r.lineas.firstWhere((l) => l.codigo == 'IVSS').monto, 13);
    expect(r.aporteIvss, 35.75);
  });

  test('IVSS sin tope en nómina mensual usa el salario completo', () {
    final motor = PayrollEngine({
      'dias_mes': 30,
      'ivss_empleado_pct': 0.04,
      'ivss_patrono_pct': 0.11,
      'ivss_tope_salarios_min': 0,
      'salario_minimo_mensual': 130,
    });
    final r = motor.calcular(
      salarioMensual: 87565,
      frecuencia: 'mensual',
      ingreso: DateTime(2020, 1, 1),
      periodoFin: DateTime(2026, 10, 31),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('IVSS', 'egreso', esSalarial: false),
      ],
      novedades: [],
    );

    expect(r.lineas.firstWhere((l) => l.codigo == 'IVSS').monto, 3502.60);
    expect(r.aporteIvss, 9632.15);
  });
}
