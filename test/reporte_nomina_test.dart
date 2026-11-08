import 'package:flutter_test/flutter_test.dart';
import 'package:nomina_app/core/periodo_nomina.dart';
import 'package:nomina_app/models/models.dart';
import 'package:nomina_app/services/reporte_nomina_csv.dart';
import 'package:nomina_app/services/reporte_nomina_service.dart';

void main() {
  test('rango semanal de lunes a domingo', () {
    final r = rangoNomina(
        TipoPeriodoNomina.semanal, DateTime(2026, 10, 28));
    expect(r.inicio, DateTime(2026, 10, 26));
    expect(r.fin, DateTime(2026, 11, 1));
  });

  test('rango mensual respeta febrero bisiesto', () {
    final r = rangoNomina(
        TipoPeriodoNomina.mensual, DateTime(2028, 2, 10));
    expect(r.inicio, DateTime(2028, 2, 1));
    expect(r.fin, DateTime(2028, 2, 29));
  });

  test('rango trimestral y semestral', () {
    final t = rangoNomina(
        TipoPeriodoNomina.trimestral, DateTime(2026, 11, 15));
    expect(t.inicio, DateTime(2026, 10, 1));
    expect(t.fin, DateTime(2026, 12, 31));

    final s = rangoNomina(
        TipoPeriodoNomina.semestral, DateTime(2026, 8, 1));
    expect(s.inicio, DateTime(2026, 7, 1));
    expect(s.fin, DateTime(2026, 12, 31));
  });

  test('rango anual', () {
    final r = rangoNomina(
        TipoPeriodoNomina.anual, DateTime(2026, 6, 15));
    expect(r.inicio, DateTime(2026, 1, 1));
    expect(r.fin, DateTime(2026, 12, 31));
  });

  test('CSV incluye detalle y aportes patronales', () {
    final nomina = Nomina.fromJson({
      'id': 'n1',
      'nombre': 'Octubre',
      'frecuencia': 'mensual',
      'estado': 'aprobada',
      'modalidad_nomina': 'normal',
      'periodo_inicio': '2026-10-01',
      'periodo_fin': '2026-10-31',
      'total_ingresos': 1000,
      'total_egresos': 100,
      'total_neto': 900,
      'total_aportes_patronales': 50,
      'total_aporte_ivss': 10,
      'total_aporte_rpe': 5,
      'total_aporte_faov': 10,
      'total_aporte_lopcymat': 5,
      'total_aporte_ince': 20,
    });
    final recibo = Recibo.fromJson({
      'id': 'r1',
      'empleado_id': 'e1',
      'empleados': {
        'nombres': 'Ana',
        'apellidos': 'Pérez',
        'cedula': '12345678'
      },
      'total_ingresos': 1000,
      'total_egresos': 100,
      'neto': 900,
      'aportes_patronales': 50,
      'salario_mensual_usd': 100,
      'total_ingresos_usd': 10,
      'total_egresos_usd': 1,
      'neto_usd': 9,
      'aporte_ivss_patronal': 10,
      'aporte_rpe_patronal': 5,
      'aporte_faov_patronal': 10,
      'aporte_lopcymat_patronal': 5,
      'aporte_ince_patronal': 20,
      'tasa_bcv': 10,
    });
    final reporte = ReporteNomina(
      etiqueta: 'Mes de Octubre 2026',
      empresa: 'Empresa',
      rif: 'J-1',
      inicio: DateTime(2026, 10, 1),
      fin: DateTime(2026, 10, 31),
      nominas: [
        NominaReporte(nomina: nomina, recibos: [
          ReciboReporte(recibo: recibo, detalle: [
            {
              'concepto_codigo': 'SUELDO',
              'concepto_nombre': 'Sueldo',
              'tipo': 'ingreso',
              'cantidad': 1,
              'monto': 1000,
              'monto_usd': 100,
              'base_legal': 'LOT',
              'es_salarial': true,
            }
          ])
        ])
      ],
    );

    final csv = construirCsvReporte(reporte);
    expect(csv, contains('"Nómina";"Período"'));
    expect(csv, contains('"SUELDO";"Sueldo";"ingreso"'));
    expect(csv, contains('"INCES patronal"'));
    expect(csv, contains('"20.00"'));
  });
}
