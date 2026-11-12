import 'package:flutter_test/flutter_test.dart';
import 'package:nomina_app/models/liquidacion_models.dart';
import 'package:nomina_app/models/models.dart';
import 'package:nomina_app/services/liquidacion_pdf_service.dart';

void main() {
  test('genera PDF de liquidación', () async {
    final l = Liquidacion(
      empleadoId: 'e1',
      fechaIngreso: DateTime(2026, 1, 1),
      fechaEgreso: DateTime(2026, 11, 12),
      motivo: 'renuncia',
      fechaCalculo: DateTime(2026, 11, 12),
      tasaBcv: 875.65,
      salarioNormalUsd: 100,
      salarioNormalBs: 87565,
      salarioIntegralBs: 3283.6875,
      anios: 0,
      meses: 10,
      dias: 12,
      garantiaBs: 196000,
      interesesBs: 0,
      retroactivoBs: 98510.63,
      prestacionesBs: 196000,
      vacacionesBs: 0,
      bonoVacBs: 0,
      utilidadesBs: 72970.83,
      netoBs: 305456.25,
      totalUsd: 348.83,
    );
    final e = Empleado(
        cedula: '123',
        nombres: 'Ana',
        apellidos: 'Pérez',
        cargo: 'Obrero',
        fechaIngreso: DateTime(2026, 1, 1),
        salarioMensualUsd: 100);
    final bytes = await buildLiquidacionPdf(
      liquidacion: l,
      detalle: [
        LiquidacionDetalle(
            codigo: 'PRESTACIONES',
            nombre: 'Prestaciones sociales',
            tipo: 'ingreso',
            monto: 196000,
            baseLegal: 'LOTTT Art. 142'),
        LiquidacionDetalle(
            codigo: 'UTILIDADES',
            nombre: 'Utilidades fraccionadas',
            tipo: 'ingreso',
            monto: 72970.83,
            baseLegal: 'LOTTT Art. 131'),
      ],
      empleado: e,
      empresa: 'Empresa',
      rif: 'J-123',
    );
    expect(bytes.length, greaterThan(1000));
  });
}
