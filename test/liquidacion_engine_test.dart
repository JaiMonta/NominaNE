import 'package:flutter_test/flutter_test.dart';
import 'package:nomina_app/core/liquidacion_engine.dart';

void main() {
  final engine = LiquidacionEngine(ParametrosLiquidacion());

  test('años y meses completos', () {
    expect(engine.aniosCompletos(DateTime(2026, 1, 1), DateTime(2026, 12, 31)), 0);
    expect(engine.aniosCompletos(DateTime(2026, 1, 1), DateTime(2027, 1, 1)), 1);
    expect(engine.mesesCompletos(DateTime(2026, 1, 1), DateTime(2026, 11, 12)), 10);
    expect(engine.mesesCompletos(DateTime(2026, 1, 1), DateTime(2026, 1, 31)), 0);
  });

  test('días de bono y vacaciones LOTTT', () {
    expect(engine.diasVacacionesAnio(1), 15);
    expect(engine.diasVacacionesAnio(2), 16);
    expect(engine.diasVacacionesAnio(16), 30);
    expect(engine.diasBonoAnio(1), 15);
    expect(engine.diasBonoAnio(2), 16);
    expect(engine.diasBonoAnio(16), 30);
  });

  test('liquidación de menos de un año calcula retroactivo, vacaciones y utilidades', () {
    final r = engine.calcular(LiquidacionEntrada(
      fechaIngreso: DateTime(2026, 1, 1),
      fechaEgreso: DateTime(2026, 11, 12),
      motivo: 'renuncia',
      salarioNormalMensualBs: 87565,
      tasaBcv: 875.65,
    ));

    expect(r.anios, 0);
    expect(r.meses, 10);
    expect(r.salarioIntegralDiario, closeTo(3283.6875, 0.01));
    expect(r.retroactivo, 98510.63);
    expect(r.prestaciones, 98510.63);
    expect(r.vacaciones, 0);
    expect(r.bono, 0);
    expect(r.utilidades, 72970.83);
    expect(r.neto, 244452.30);
    expect(r.totalUsd, closeTo(279.16, 0.02));
  });

  test('la garantía con intereses se compara con el retroactivo', () {
    final r = engine.calcular(LiquidacionEntrada(
      fechaIngreso: DateTime(2026, 1, 1),
      fechaEgreso: DateTime(2026, 11, 12),
      motivo: 'despido_injustificado',
      salarioNormalMensualBs: 87565,
      tasaBcv: 875.65,
      saldoGarantiaBs: 200000,
      interesesBs: 5000,
      aplicaIndemnizacion92: true,
    ));

    expect(r.garantia, 200000);
    expect(r.intereses, 5000);
    expect(r.prestaciones, 205000);
    expect(r.indemnizacion, 205000);
    expect(r.neto,
        closeTo(205000 + 205000 + 36485.42 + 36485.42 + 72970.83, 0.02));
  });

  test('las vacaciones disfrutadas del período actual se descuentan', () {
    final r = engine.calcular(LiquidacionEntrada(
      fechaIngreso: DateTime(2026, 1, 1),
      fechaEgreso: DateTime(2026, 11, 12),
      motivo: 'renuncia',
      salarioNormalMensualBs: 87565,
      tasaBcv: 875.65,
      diasVacacionesDisfrutadosPeriodo: 2,
      diasBonoPagadosPeriodo: 1,
    ));

    final vac = r.lineas.firstWhere((l) => l.codigo == 'VACACIONES_FRAC');
    final bono = r.lineas.firstWhere((l) => l.codigo == 'BONO_VAC_FRAC');
    expect(vac.dias, closeTo(10.5, 0.01));
    expect(bono.dias, closeTo(11.5, 0.01));
  });

  test('menos de 3 meses usa 5 días por mes o fracción', () {
    final r = engine.calcular(LiquidacionEntrada(
      fechaIngreso: DateTime(2026, 1, 1),
      fechaEgreso: DateTime(2026, 2, 10),
      motivo: 'renuncia',
      salarioNormalMensualBs: 87565,
      tasaBcv: 875.65,
    ));

    expect(r.prestaciones, closeTo(32836.88, 0.02));
    expect(r.lineas.any((l) => l.codigo == 'PRESTACIONES'), isTrue);
  });
}
