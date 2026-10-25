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
  test('lunesEntre cuenta lunes inclusivos', () {
    expect(lunesEntre(DateTime(2026, 10, 1), DateTime(2026, 10, 15)), 2);
    expect(lunesEntre(DateTime(2026, 10, 16), DateTime(2026, 10, 31)), 2);
    expect(lunesEntre(DateTime(2026, 10, 1), DateTime(2026, 10, 31)), 4);
    expect(lunesEntre(DateTime(2026, 11, 1), DateTime(2026, 11, 30)), 5);
  });

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
      periodoInicio: DateTime(2026, 1, 1),
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
    expect(r.totalEgresos, 160.77);
    expect(r.neto, 2939.23);

    final bono = r.lineas.firstWhere((l) => l.codigo == 'BONO_ALIM');
    expect(bono.esSalarial, isFalse);

    // IVSS: 4% semanal (3000 × 12 / 52) por 4 lunes de enero 2026.
    final ivss = r.lineas.firstWhere((l) => l.codigo == 'IVSS');
    expect(ivss.cantidad, 4);
    expect(ivss.monto, 110.77);
  });

  test('concepto fijo no salarial se calcula por cantidad', () {
    final motor = PayrollEngine({'dias_mes': 30});
    final r = motor.calcular(
      salarioMensual: 3000,
      frecuencia: 'mensual',
      ingreso: DateTime(2020, 1, 1),
      periodoInicio: DateTime(2026, 1, 1),
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
      periodoInicio: DateTime(2026, 1, 1),
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
      periodoInicio: DateTime(2026, 1, 1),
      periodoFin: DateTime(2026, 1, 31),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('HE_NOCT', 'ingreso'),
      ],
      novedades: [EntradaNovedad('HE_NOCT', 0, 100)],
    );

    expect(r.lineas.firstWhere((l) => l.codigo == 'HE_NOCT').monto, 100);
  });

  test('IVSS semanal sin tope en quincena de 2 lunes', () {
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
      periodoInicio: DateTime(2026, 10, 1),
      periodoFin: DateTime(2026, 10, 15),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('FERIADO', 'ingreso'),
        _concepto('IVSS', 'egreso', esSalarial: false),
      ],
      novedades: [EntradaNovedad('FERIADO', 1, 0)],
    );

    expect(r.totalIngresoSalarial, 48160.75);
    final ivss = r.lineas.firstWhere((l) => l.codigo == 'IVSS');
    expect(ivss.cantidad, 2);
    expect(ivss.monto, 1616.58);
    expect(r.aporteIvss, 4445.61);
  });

  test('IVSS con tope 5 reparte el máximo mensual por lunes', () {
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
      periodoInicio: DateTime(2026, 10, 1),
      periodoFin: DateTime(2026, 10, 15),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('FERIADO', 'ingreso'),
        _concepto('IVSS', 'egreso', esSalarial: false),
      ],
      novedades: [EntradaNovedad('FERIADO', 1, 0)],
    );

    final ivss = r.lineas.firstWhere((l) => l.codigo == 'IVSS');
    expect(ivss.cantidad, 2);
    expect(ivss.monto, 13);
    expect(r.aporteIvss, 35.75);
  });

  test('IVSS semanal sin tope en nómina mensual', () {
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
      periodoInicio: DateTime(2026, 10, 1),
      periodoFin: DateTime(2026, 10, 31),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('IVSS', 'egreso', esSalarial: false),
      ],
      novedades: [],
    );

    final ivss = r.lineas.firstWhere((l) => l.codigo == 'IVSS');
    expect(ivss.cantidad, 4);
    expect(ivss.monto, 3233.17);
    expect(r.aporteIvss, 8891.22);
  });

  test('IVSS mensual con tope 5 queda en 26 Bs', () {
    final motor = PayrollEngine({
      'dias_mes': 30,
      'ivss_empleado_pct': 0.04,
      'ivss_patrono_pct': 0.11,
      'ivss_tope_salarios_min': 5,
      'salario_minimo_mensual': 130,
    });
    final r = motor.calcular(
      salarioMensual: 87565,
      frecuencia: 'mensual',
      ingreso: DateTime(2020, 1, 1),
      periodoInicio: DateTime(2026, 10, 1),
      periodoFin: DateTime(2026, 10, 31),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('IVSS', 'egreso', esSalarial: false),
      ],
      novedades: [],
    );

    final ivss = r.lineas.firstWhere((l) => l.codigo == 'IVSS');
    expect(ivss.cantidad, 4);
    expect(ivss.monto, 26);
    expect(r.aporteIvss, 71.50);
  });

  test('IVSS con tope en mes de 5 lunes y quincena de 3 lunes', () {
    final motor = PayrollEngine({
      'dias_mes': 30,
      'ivss_empleado_pct': 0.04,
      'ivss_patrono_pct': 0.11,
      'ivss_tope_salarios_min': 5,
      'salario_minimo_mensual': 130,
    });
    final mes = motor.calcular(
      salarioMensual: 87565,
      frecuencia: 'mensual',
      ingreso: DateTime(2020, 1, 1),
      periodoInicio: DateTime(2026, 11, 1),
      periodoFin: DateTime(2026, 11, 30),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('IVSS', 'egreso', esSalarial: false),
      ],
      novedades: [],
    );
    final quincena = motor.calcular(
      salarioMensual: 87565,
      frecuencia: 'quincenal',
      ingreso: DateTime(2020, 1, 1),
      periodoInicio: DateTime(2026, 11, 16),
      periodoFin: DateTime(2026, 11, 30),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('IVSS', 'egreso', esSalarial: false),
      ],
      novedades: [],
    );

    expect(mes.lineas.firstWhere((l) => l.codigo == 'IVSS').monto, 26);
    expect(mes.aporteIvss, 71.50);
    expect(quincena.lineas.firstWhere((l) => l.codigo == 'IVSS').cantidad, 3);
    expect(quincena.lineas.firstWhere((l) => l.codigo == 'IVSS').monto, 15.60);
    expect(quincena.aporteIvss, 42.90);
  });

  test('IVSS con tope no recorta si el salario está bajo el tope', () {
    final motor = PayrollEngine({
      'dias_mes': 30,
      'ivss_empleado_pct': 0.04,
      'ivss_patrono_pct': 0.11,
      'ivss_tope_salarios_min': 5,
      'salario_minimo_mensual': 130,
    });
    final r = motor.calcular(
      salarioMensual: 600,
      frecuencia: 'mensual',
      ingreso: DateTime(2020, 1, 1),
      periodoInicio: DateTime(2026, 10, 1),
      periodoFin: DateTime(2026, 10, 31),
      conceptos: [
        _concepto('SUELDO', 'ingreso'),
        _concepto('IVSS', 'egreso', esSalarial: false),
      ],
      novedades: [],
    );

    expect(r.lineas.firstWhere((l) => l.codigo == 'IVSS').monto, 22.15);
    expect(r.aporteIvss, 60.92);
  });
}
